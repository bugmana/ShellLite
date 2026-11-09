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

  testWidgets('ServerFormScreen creates a new server with password auth',
      (tester) async {
    await tester.pumpWidget(createTestWidget());
    await tester.pumpAndSettle();

    // Verify Title
    expect(find.text('New server'), findsOneWidget);

    // Enter details
    await tester.ensureVisible(find.text('More options'));
    await tester.tap(find.text('More options'));
    await tester.pumpAndSettle();
    await tester
        .ensureVisible(find.widgetWithText(TextFormField, 'Name (optional)'));
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Name (optional)'),
        'Ubuntu Test Server');
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Host'), '127.0.0.1');
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Username'), 'testuser');
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Password'), 'TestUserPass123!');

    // Tap Save
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    // Verify server profile is saved in ServerStore
    expect(serverStore.profiles.length, 1);
    final profile = serverStore.profiles.first;
    expect(profile.displayName, 'Ubuntu Test Server');
    expect(profile.host, '127.0.0.1');
    expect(profile.username, 'testuser');
    expect(profile.authMethod.type, AuthType.password);

    // Verify password saved
    final savedPassword = await serverStore.getCredential(profile);
    expect(savedPassword, 'TestUserPass123!');
  });

  testWidgets('ServerFormScreen uses host as name when name is blank',
      (tester) async {
    await tester.pumpWidget(createTestWidget());
    await tester.pumpAndSettle();

    // Verify Title
    expect(find.text('New server'), findsOneWidget);

    // Enter details
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Host'), '127.0.0.1');
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Username'), 'testuser');
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Password'), 'TestUserPass123!');

    // Tap Save
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    // Verify server profile is saved in ServerStore
    expect(serverStore.profiles.length, 1);
    final profile = serverStore.profiles.first;
    expect(profile.displayName, '127.0.0.1');
    expect(find.text('Paste & Parse SSH Command from Clipboard'), findsNothing);
    expect(profile.host, '127.0.0.1');
    expect(profile.username, 'testuser');
    expect(profile.authMethod.type, AuthType.password);

    // Verify password saved
    final savedPassword = await serverStore.getCredential(profile);
    expect(savedPassword, 'TestUserPass123!');
  });

  testWidgets(
      'ServerFormScreen toggles between Password and SSH key without leaking input text',
      (tester) async {
    await tester.pumpWidget(createTestWidget());
    await tester.pumpAndSettle();

    // Enter a password first
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Password'), 'MySecretPassword');
    await tester.pump();

    // Switch to SSH key mode
    await tester.tap(find.text('SSH key'));
    await tester.pumpAndSettle();

    // SSH key field should be visible and empty (not holding MySecretPassword)
    expect(find.text('Private key'), findsOneWidget);
    final keyFieldFinder = find.byWidgetPredicate(
      (w) =>
          w is TextField &&
          (w.decoration?.hintText?.contains('Paste your OpenSSH') ?? false),
    );
    expect(keyFieldFinder, findsOneWidget);
    expect(
        (tester.widget(keyFieldFinder) as TextField).controller?.text, isEmpty);

    // Switch back to Password mode
    await tester.tap(find.text('Password'));
    await tester.pumpAndSettle();

    // Password field should still have the original password
    expect(find.text('MySecretPassword'), findsOneWidget);
  });

  testWidgets(
      'existing private keys can be entered and cleared without generation',
      (tester) async {
    await tester.pumpWidget(createTestWidget());
    await tester.pumpAndSettle();
    await tester.tap(find.text('SSH key'));
    await tester.pumpAndSettle();
    expect(find.text('Generate'), findsNothing);
    final field = find.byWidgetPredicate((w) =>
        w is TextField &&
        (w.decoration?.hintText?.contains('Paste your OpenSSH') ?? false));
    await tester.enterText(field, 'invalid key');
    await tester.tap(find.text('Clear'));
    await tester.pump();
    expect((tester.widget(field) as TextField).controller!.text, isEmpty);
  });

  testWidgets('ServerFormScreen validates required fields', (tester) async {
    await tester.pumpWidget(createTestWidget());
    await tester.pumpAndSettle();

    // Tap Save without entering anything
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    // Validation errors should show
    expect(find.text('Display name is required'), findsNothing);
    expect(find.text('Host is required'), findsOneWidget);
    expect(find.text('Username is required'), findsOneWidget);
    expect(find.text('Password is required'), findsOneWidget);

    expect(serverStore.profiles, isEmpty);
  });

  testWidgets('ServerFormScreen validates invalid SSH key format',
      (tester) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(createTestWidget());
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('More options'));
    await tester.tap(find.text('More options'));
    await tester.pumpAndSettle();
    await tester
        .ensureVisible(find.widgetWithText(TextFormField, 'Name (optional)'));
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Name (optional)'),
        'Invalid Key Server');
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Host'), '127.0.0.1');
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Username'), 'testuser');

    // Switch to SSH key mode
    await tester.tap(find.text('SSH key'));
    await tester.pumpAndSettle();

    // Enter invalid key
    final keyFieldFinder = find.byWidgetPredicate(
      (w) =>
          w is TextField &&
          (w.decoration?.hintText?.contains('Paste your OpenSSH') ?? false),
    );
    await tester.enterText(keyFieldFinder, 'invalid-key-data-not-pem');
    await tester.pump();

    // Tap Save
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    // Error message should be visible
    expect(find.textContaining('Key must be wrapped in PEM headers'),
        findsOneWidget);
    expect(serverStore.profiles, isEmpty);
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
  for (final persistent in [false, true]) {
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
