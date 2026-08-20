import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shell_lite/models/auth_method.dart';
import 'package:shell_lite/models/server_profile.dart';
import 'package:shell_lite/models/snippet.dart';
import 'package:shell_lite/providers/session_store.dart';
import 'package:shell_lite/providers/snippet_store.dart';
import 'package:shell_lite/providers/terminal_settings_store.dart';
import 'package:shell_lite/screens/terminal_screen.dart';
import 'package:shell_lite/services/storage_service.dart';
import 'package:shell_lite/theme/app_theme.dart';
import 'package:shell_lite/theme/terminal_theme_presets.dart';
import 'package:shell_lite/widgets/keyboard_accessory_bar.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late StorageService storageService;
  late SessionStore sessionStore;
  late TerminalSettingsStore terminalSettingsStore;
  late SnippetStore snippetStore;
  late ServerProfile testProfile;

  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    storageService = StorageService(prefs: prefs);
    sessionStore = SessionStore(storageService: storageService);
    terminalSettingsStore = TerminalSettingsStore(storageService: storageService);
    snippetStore = SnippetStore(storageService: storageService);

    await terminalSettingsStore.load();
    await snippetStore.load();

    testProfile = ServerProfile(
      id: 'test-server-1',
      displayName: 'Test Terminal Server',
      host: '127.0.0.1',
      port: 22,
      username: 'testuser',
      authMethod: const PasswordAuth(credentialTag: 'test-cred-tag'),
    );
  });

  tearDown(() {
    sessionStore.closeSession(testProfile.id);
  });

  Widget createTestWidget() {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<SessionStore>.value(value: sessionStore),
        ChangeNotifierProvider<TerminalSettingsStore>.value(value: terminalSettingsStore),
        ChangeNotifierProvider<SnippetStore>.value(value: snippetStore),
        Provider<StorageService>.value(value: storageService),
      ],
      child: MaterialApp(
        theme: AppTheme.buildTheme(TerminalThemePresets.obsidian),
        home: TerminalScreen(profile: testProfile),
      ),
    );
  }

  testWidgets('TerminalScreen initializes session and displays connecting status', (tester) async {
    await tester.pumpWidget(createTestWidget());
    await tester.pumpAndSettle();

    // Verify app bar title
    expect(find.text('Test Terminal Server'), findsOneWidget);

    // Verify active session created
    expect(sessionStore.hasActiveSession(testProfile.id), isTrue);
    final session = sessionStore.getSession(testProfile.id);
    expect(session, isNotNull);

    // Verify initial connection log in terminal buffer
    final bufferText = session!.terminal.buffer.getText();
    expect(bufferText, contains('Connecting to testuser@127.0.0.1:22'));
  });

  testWidgets('TerminalScreen renders KeyboardAccessoryBar and handles key shortcuts', (tester) async {
    await tester.pumpWidget(createTestWidget());
    await tester.pumpAndSettle();

    // Verify KeyboardAccessoryBar is present
    expect(find.byType(KeyboardAccessoryBar), findsOneWidget);

    // Find and tap accessory keys
    final tabKey = find.text('Tab');
    final shiftTabKey = find.text('⇧Tab');
    final ctrlCKey = find.text('^C');
    final ctrlDKey = find.text('^D');
    final escKey = find.text('Esc');

    expect(tabKey, findsOneWidget);
    expect(shiftTabKey, findsOneWidget);
    expect(ctrlCKey, findsOneWidget);
    expect(ctrlDKey, findsOneWidget);
    expect(escKey, findsOneWidget);

    await tester.tap(tabKey);
    await tester.pump();

    await tester.tap(shiftTabKey);
    await tester.pump();

    await tester.tap(ctrlCKey);
    await tester.pump();

    await tester.tap(ctrlDKey);
    await tester.pump();

    await tester.tap(escKey);
    await tester.pump();
  });

  testWidgets('TerminalScreen handles paste and clear screen from menu', (tester) async {
    await tester.pumpWidget(createTestWidget());
    await tester.pumpAndSettle();

    final session = sessionStore.getSession(testProfile.id);
    expect(session, isNotNull);

    // Open popup menu
    final moreButton = find.byTooltip('More actions');
    expect(moreButton, findsOneWidget);
    await tester.tap(moreButton);
    await tester.pumpAndSettle();

    // Verify paste, clear screen, reconnect, disconnect, gesture tips are in menu
    expect(find.text('Paste'), findsOneWidget);
    expect(find.text('Clear Screen'), findsOneWidget);
    expect(find.text('Reconnect'), findsOneWidget);
    expect(find.text('Disconnect Session'), findsOneWidget);
    expect(find.text('Gesture Tips'), findsOneWidget);

    // Tap Clear Screen
    await tester.tap(find.text('Clear Screen'));
    await tester.pumpAndSettle();
  });

  testWidgets('TerminalScreen opens Terminal Appearance modal', (tester) async {
    await tester.pumpWidget(createTestWidget());
    await tester.pumpAndSettle();

    // Tap appearance button in app bar
    final appearanceButton = find.byIcon(Icons.palette_outlined);
    expect(appearanceButton, findsOneWidget);
    await tester.tap(appearanceButton);
    await tester.pumpAndSettle();

    // Modal should be displayed
    expect(find.text('Terminal Appearance'), findsOneWidget);
    expect(find.text('Catppuccin Mocha'), findsOneWidget);

    // Select Catppuccin Mocha
    await tester.tap(find.text('Catppuccin Mocha'));
    await tester.pump();

    expect(terminalSettingsStore.themeId, 'catppuccin');
  });

  testWidgets('TerminalScreen opens Snippet Runner Sheet from More Actions menu', (tester) async {
    await snippetStore.deleteSnippet(snippetStore.snippets.first.id);
    await snippetStore.addSnippet(
      const Snippet(
        id: 'unique_snip_1',
        title: 'Custom Snippet For Test',
        command: 'echo custom_test\n',
      ),
    );

    await tester.pumpWidget(createTestWidget());
    await tester.pumpAndSettle();

    // Tap More Actions popup menu in app bar
    final moreButton = find.byTooltip('More actions');
    expect(moreButton, findsOneWidget);
    await tester.tap(moreButton);
    await tester.pumpAndSettle();

    // Tap Command Snippets in menu
    final snippetsMenuItem = find.text('Command Snippets');
    expect(snippetsMenuItem, findsOneWidget);
    await tester.tap(snippetsMenuItem);
    await tester.pumpAndSettle();

    // Snippet sheet should display
    expect(find.text('Custom Snippet For Test'), findsOneWidget);
    expect(find.text('echo custom_test'), findsOneWidget);

    // Tap the snippet to execute
    await tester.tap(find.text('Custom Snippet For Test'));
    await tester.pumpAndSettle();
  });
}
