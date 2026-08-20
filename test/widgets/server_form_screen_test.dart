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

  testWidgets('ServerFormScreen creates a new server with password auth', (tester) async {
    await tester.pumpWidget(createTestWidget());
    await tester.pumpAndSettle();

    // Verify Title
    expect(find.text('New Server'), findsOneWidget);

    // Enter details
    await tester.enterText(find.widgetWithText(TextFormField, 'Display Name'), 'Ubuntu Test Server');
    await tester.enterText(find.widgetWithText(TextFormField, 'Host / IP Address'), '127.0.0.1');
    await tester.enterText(find.widgetWithText(TextFormField, 'Username'), 'testuser');
    await tester.enterText(find.widgetWithText(TextFormField, 'Password'), 'TestUserPass123!');

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

  testWidgets('ServerFormScreen toggles between Password and SSH Key without leaking input text', (tester) async {
    await tester.pumpWidget(createTestWidget());
    await tester.pumpAndSettle();

    // Enter a password first
    await tester.enterText(find.widgetWithText(TextFormField, 'Password'), 'MySecretPassword');
    await tester.pump();

    // Switch to SSH Key mode
    await tester.tap(find.text('SSH Key'));
    await tester.pumpAndSettle();

    // SSH key field should be visible and empty (not holding MySecretPassword)
    expect(find.text('OpenSSH Private Key'), findsOneWidget);
    final keyFieldFinder = find.byWidgetPredicate(
      (w) => w is TextField && (w.decoration?.hintText?.contains('BEGIN OPENSSH') ?? false),
    );
    expect(keyFieldFinder, findsOneWidget);
    expect((tester.widget(keyFieldFinder) as TextField).controller?.text, isEmpty);

    // Switch back to Password mode
    await tester.tap(find.text('Password'));
    await tester.pumpAndSettle();

    // Password field should still have the original password
    expect(find.text('MySecretPassword'), findsOneWidget);
  });

  testWidgets('ServerFormScreen generate key and clear key workflow', (tester) async {
    await tester.pumpWidget(createTestWidget());
    await tester.pumpAndSettle();

    // Switch to SSH Key mode
    await tester.tap(find.text('SSH Key'));
    await tester.pumpAndSettle();

    // Tap Generate
    await tester.tap(find.text('Generate'));
    await tester.pumpAndSettle();

    // Dialog should open
    expect(find.text('SSH Key Generator'), findsOneWidget);

    // Tap 'Use Key in Profile'
    await tester.tap(find.text('Use Key in Profile'));
    await tester.pumpAndSettle();

    // Verify the key text is populated and contains OPENSSH PRIVATE KEY
    final keyFieldFinder = find.byWidgetPredicate(
      (w) => w is TextField && (w.decoration?.hintText?.contains('BEGIN OPENSSH') ?? false),
    );
    expect(keyFieldFinder, findsOneWidget);
    expect(
      (tester.widget(keyFieldFinder) as TextField).controller?.text,
      contains('BEGIN OPENSSH PRIVATE KEY'),
    );
    expect(find.text('Clear'), findsOneWidget);

    // Tap Clear
    await tester.tap(find.text('Clear'));
    await tester.pumpAndSettle();

    // Verify key is cleared
    expect((tester.widget(keyFieldFinder) as TextField).controller?.text, isEmpty);
  });

  testWidgets('ServerFormScreen validates required fields', (tester) async {
    await tester.pumpWidget(createTestWidget());
    await tester.pumpAndSettle();

    // Tap Save without entering anything
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    // Validation errors should show
    expect(find.text('Display name is required'), findsOneWidget);
    expect(find.text('Host is required'), findsOneWidget);
    expect(find.text('Username is required'), findsOneWidget);
    expect(find.text('Password is required'), findsOneWidget);

    expect(serverStore.profiles, isEmpty);
  });

  testWidgets('ServerFormScreen validates invalid SSH key format', (tester) async {
    await tester.pumpWidget(createTestWidget());
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextFormField, 'Display Name'), 'Invalid Key Server');
    await tester.enterText(find.widgetWithText(TextFormField, 'Host / IP Address'), '127.0.0.1');
    await tester.enterText(find.widgetWithText(TextFormField, 'Username'), 'testuser');

    // Switch to SSH Key mode
    await tester.tap(find.text('SSH Key'));
    await tester.pumpAndSettle();

    // Enter invalid key
    final keyFieldFinder = find.byWidgetPredicate(
      (w) => w is TextField && (w.decoration?.hintText?.contains('BEGIN OPENSSH') ?? false),
    );
    await tester.enterText(keyFieldFinder, 'invalid-key-data-not-pem');
    await tester.pump();

    // Tap Save
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    // Error message should be visible
    expect(find.textContaining('Key must be wrapped in PEM headers'), findsOneWidget);
    expect(serverStore.profiles, isEmpty);
  });
}
