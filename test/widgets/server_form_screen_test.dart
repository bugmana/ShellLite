import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shell_lite/models/auth_method.dart';
import 'package:shell_lite/models/server_profile.dart';
import 'package:shell_lite/providers/server_store.dart';
import 'package:shell_lite/screens/server_form_screen.dart';
import 'package:shell_lite/services/storage_service.dart';
import 'package:shell_lite/theme/app_theme.dart';
import 'package:shell_lite/theme/terminal_theme_presets.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late StorageService storageService;
  late ServerStore serverStore;

  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    storageService = StorageService(prefs: prefs);
    serverStore = ServerStore(storageService: storageService);
    await serverStore.load();
  });

  Widget createTestWidget({ServerProfile? existingProfile}) {
    return ChangeNotifierProvider<ServerStore>.value(
      value: serverStore,
      child: MaterialApp(
        theme: AppTheme.buildTheme(TerminalThemePresets.obsidian),
        home: ServerFormScreen(existingProfile: existingProfile),
      ),
    );
  }

  testWidgets(
      'corrected fields clear errors and password can be cleared immediately',
      (tester) async {
    await tester.pumpWidget(createTestWidget());
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), '192.0.2.1');
    await tester.enterText(fields.at(1), 'test');
    await tester.enterText(fields.at(2), 'dummy-only');
    await tester.pump();
    expect(find.text('Host is required'), findsNothing);
    expect(find.text('Username is required'), findsNothing);
    expect(find.text('Password is required'), findsNothing);
    final clear = find.byTooltip('Clear password');
    expect(clear, findsOneWidget);
    await tester.ensureVisible(clear);
    await tester.tap(clear);
    await tester.pump();
    expect(find.byTooltip('Clear password'), findsNothing);
    expect(find.text('Password is required'), findsOneWidget);
  });

  testWidgets(
      'ServerFormScreen creates server with passphrase-protected SSH key',
      (tester) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    const encryptedKey = '''
-----BEGIN OPENSSH PRIVATE KEY-----
b3BlbnNzaC1rZXktdjEAAAAACmFlczI1Ni1jdHIAAAAGYmNyeXB0AAAAGAAAABC0l9Iobg
dIkpFRXIVcSMo9AAAAEAAAAAEAAAAzAAAAC3NzaC1lZDI1NTE5AAAAIDl6gJA/mTwGajQU
GysVNxbg5DLxNkxNMr1N6nMqmILLAAAAoAheLDCmikMrd30h6Z3ug4h7WsK8TjBYToUkhO
1fu5qRd6pgCCeQt0C5eeJMkCSNTP+HZyWT9Vc67VCvzaECjFfXYJUsRYdknAXEO4oFc9fg
v8qGMQTFoIajXQk8Gk9QLqGQ0nupn4fZ3BhHhMoDIx7DWLhlvHddSJzgkORIt4bV8ntzh8
AK9jJFzpo0q4FnYkalW4fo/nosGUM/bq5LR2M=
-----END OPENSSH PRIVATE KEY-----
''';
    const validPassphrase = '123456';

    await tester.pumpWidget(createTestWidget());
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('More options'));
    await tester.tap(find.text('More options'));
    await tester.pumpAndSettle();
    await tester
        .ensureVisible(find.widgetWithText(TextFormField, 'Name (optional)'));
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Name (optional)'),
        'Encrypted Key Server');
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Host'), '10.0.0.99');
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Username'), 'arch');

    // Switch to SSH key mode
    await tester.tap(find.text('SSH key'));
    await tester.pumpAndSettle();

    final keyFieldFinder = find.byWidgetPredicate(
      (w) =>
          w is TextField &&
          (w.decoration?.hintText?.contains('Paste your OpenSSH') ?? false),
    );
    await tester.enterText(keyFieldFinder, encryptedKey);
    await tester.pumpAndSettle();

    // Verify passphrase field indicates required
    final passFieldFinder =
        find.widgetWithText(TextFormField, 'Key Passphrase (Required)');
    expect(passFieldFinder, findsOneWidget);

    // Enter wrong passphrase first
    await tester.ensureVisible(passFieldFinder);
    await tester.enterText(passFieldFinder, 'wrongpassword');
    await tester.pumpAndSettle();

    // Tap Save - Should fail validation
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Incorrect passphrase'), findsOneWidget);
    expect(serverStore.profiles, isEmpty);

    // Enter correct passphrase
    await tester.enterText(passFieldFinder, validPassphrase);
    await tester.pumpAndSettle();

    // Tap Save - Should succeed
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(serverStore.profiles.length, 1);
    final savedProfile = serverStore.profiles.first;
    expect(savedProfile.displayName, 'Encrypted Key Server');
    expect(savedProfile.authMethod, isA<SSHKeyAuth>());
    final auth = savedProfile.authMethod as SSHKeyAuth;
    expect(auth.isPassphraseProtected, isTrue);

    final storedKey = await serverStore.getCredential(savedProfile);
    final storedPass = await serverStore.getKeyPassphrase(savedProfile);
    expect(storedKey, encryptedKey.trim());
    expect(storedPass, validPassphrase);
  });

  testWidgets('Startup command remains editable when tmux is enabled',
      (tester) async {
    await tester.pumpWidget(createTestWidget());
    await tester.pumpAndSettle();

    // Scroll down in ListView to reveal Persistent Session and Startup Command sections
    await tester.drag(
        find.byType(SingleChildScrollView).first, const Offset(0, -600));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('More options'));
    await tester.tap(find.text('More options'));
    await tester.pumpAndSettle();
    final initialCmdFinder = find.byKey(const Key('initialCommandField'));
    expect(initialCmdFinder, findsOneWidget);
    expect((tester.widget(initialCmdFinder) as TextFormField).enabled,
        isNot(false));

    // Toggle on Persistent Session (tmux)
    final tmuxSwitch =
        find.widgetWithText(SwitchListTile, 'Persistent Session (tmux)');
    expect(tmuxSwitch, findsOneWidget);
    await tester.ensureVisible(tmuxSwitch);
    await tester.tap(tmuxSwitch);
    await tester.pumpAndSettle();

    await tester.ensureVisible(initialCmdFinder);
    await tester.tap(initialCmdFinder);
    await tester.enterText(initialCmdFinder, 'htop');
    expect(find.text('Saved for connections without tmux.'), findsOneWidget);

    // Toggle off Persistent Session (tmux)
    await tester.ensureVisible(tmuxSwitch);
    await tester.tap(tmuxSwitch);
    await tester.pumpAndSettle();

    expect((tester.widget(initialCmdFinder) as TextFormField).enabled,
        isNot(false));
    expect((tester.widget(initialCmdFinder) as TextFormField).controller!.text,
        'htop');
  });
  for (final persistent in [true]) {
    testWidgets(
        'editing preserves collapsed advanced fields and credentials (tmux=$persistent)',
        (tester) async {
      final original = ServerProfile(
          id: 'existing',
          displayName: 'Custom name',
          host: 'old.example.com',
          port: 2222,
          username: 'alice',
          authMethod: const PasswordAuth(credentialTag: 'cred_existing'),
          initialCommand: 'cd /srv',
          persistSession: persistent,
          tmuxSessionName: 'work');
      await serverStore.addProfile(original, credential: ' saved-password ');
      await tester.pumpWidget(createTestWidget(existingProfile: original));
      await tester.pumpAndSettle();
      expect(find.text('More options'), findsOneWidget);
      expect(find.text('Custom name'), findsNothing);
      await tester.enterText(
          find.widgetWithText(TextFormField, 'Host'), 'new.example.com');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      final saved = serverStore.profiles.single;
      expect(saved.id, original.id);
      expect(saved.displayName, original.displayName);
      expect(saved.port, 2222);
      expect(saved.initialCommand, 'cd /srv');
      expect(saved.persistSession, persistent);
      expect(saved.tmuxSessionName, 'work');
      expect(await serverStore.getCredential(saved), ' saved-password ');
    });
  }
}
