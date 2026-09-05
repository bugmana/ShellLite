import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shell_lite/models/auth_method.dart';
import 'package:shell_lite/models/server_profile.dart';
import 'package:shell_lite/providers/session_store.dart';
import 'package:shell_lite/providers/terminal_settings_store.dart';
import 'package:shell_lite/screens/terminal_screen.dart';
import 'package:shell_lite/services/storage_service.dart';
import 'package:shell_lite/theme/app_theme.dart';
import 'package:shell_lite/theme/terminal_theme_presets.dart';
import 'package:shell_lite/widgets/keyboard_accessory_bar.dart';
import 'package:xterm/xterm.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late StorageService storageService;
  late SessionStore sessionStore;
  late TerminalSettingsStore terminalSettingsStore;
  late ServerProfile testProfile;

  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    storageService = StorageService(prefs: prefs);
    sessionStore = SessionStore(storageService: storageService);
    terminalSettingsStore = TerminalSettingsStore(storageService: storageService);

    await terminalSettingsStore.load();

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
    final upKey = find.text('↑');
    final downKey = find.text('↓');
    final leftKey = find.text('←');
    final rightKey = find.text('→');
    final escKey = find.text('Esc');

    expect(tabKey, findsOneWidget);
    expect(shiftTabKey, findsOneWidget);
    expect(upKey, findsOneWidget);
    expect(downKey, findsOneWidget);
    expect(leftKey, findsOneWidget);
    expect(rightKey, findsOneWidget);
    expect(escKey, findsOneWidget);

    // Verify TerminalView has a focusNode attached
    final terminalViewFinder = find.byType(TerminalView);
    expect(terminalViewFinder, findsOneWidget);
    final terminalView = tester.widget<TerminalView>(terminalViewFinder);
    expect(terminalView.focusNode, isNotNull);
    expect(terminalView.focusNode!.hasFocus, isTrue);

    await tester.tap(tabKey);
    await tester.pump();
    expect(terminalView.focusNode!.hasFocus, isTrue);

    await tester.tap(shiftTabKey);
    await tester.pump();
    expect(terminalView.focusNode!.hasFocus, isTrue);

    await tester.tap(upKey);
    await tester.pump();
    expect(terminalView.focusNode!.hasFocus, isTrue);

    await tester.tap(downKey);
    await tester.pump();
    expect(terminalView.focusNode!.hasFocus, isTrue);

    await tester.tap(leftKey);
    await tester.pump();
    expect(terminalView.focusNode!.hasFocus, isTrue);

    await tester.tap(rightKey);
    await tester.pump();
    expect(terminalView.focusNode!.hasFocus, isTrue);

    await tester.tap(escKey);
    await tester.pump();
    expect(terminalView.focusNode!.hasFocus, isTrue);
  });

  testWidgets('TerminalScreen shows Paste action button in AppBar and handles paste', (tester) async {
    await tester.pumpWidget(createTestWidget());
    await tester.pumpAndSettle();

    final pasteButton = find.byIcon(Icons.paste_rounded);
    expect(pasteButton, findsOneWidget);

    await tester.tap(pasteButton);
    await tester.pump();
  });

  testWidgets('TerminalScreen handles popup menu actions and does not contain duplicate upload or paste', (tester) async {
    await tester.pumpWidget(createTestWidget());
    await tester.pumpAndSettle();

    final session = sessionStore.getSession(testProfile.id);
    expect(session, isNotNull);

    // Open popup menu
    final moreButton = find.byTooltip('More actions');
    expect(moreButton, findsOneWidget);
    await tester.tap(moreButton);
    await tester.pumpAndSettle();

    // Verify clear screen, reconnect, disconnect are in menu, and gesture tips is removed
    expect(find.text('Clear Screen'), findsOneWidget);
    expect(find.text('Reconnect'), findsOneWidget);
    expect(find.text('Disconnect Session'), findsOneWidget);
    expect(find.text('Gesture Tips'), findsNothing);

    // Verify duplicate upload and paste are removed from menu
    expect(find.text('Upload File'), findsNothing);
    expect(find.text('Paste'), findsNothing);

    // Tap Clear Screen
    await tester.tap(find.text('Clear Screen'));
    await tester.pumpAndSettle();
  });

  testWidgets('TerminalScreen shows Upload File action button in AppBar', (tester) async {
    await tester.pumpWidget(createTestWidget());
    await tester.pumpAndSettle();

    final uploadButton = find.byIcon(Icons.cloud_upload_outlined);
    expect(uploadButton, findsOneWidget);

    // Tapping when disconnected shows disconnected snackbar
    await tester.tap(uploadButton);
    await tester.pump();
    expect(find.text('Terminal session is not connected'), findsOneWidget);
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

  testWidgets('TerminalScreen keyboard toggle button toggles between down arrow and up arrow', (tester) async {
    await tester.pumpWidget(createTestWidget());
    await tester.pumpAndSettle();

    final terminalViewFinder = find.byType(TerminalView);
    expect(terminalViewFinder, findsOneWidget);
    final terminalView = tester.widget<TerminalView>(terminalViewFinder);
    expect(terminalView.focusNode!.hasFocus, isTrue);

    // Initially keyboard is open -> down arrow icon is shown
    final downArrowButton = find.byIcon(Icons.keyboard_arrow_down_rounded);
    expect(downArrowButton, findsOneWidget);

    // Tap to close keyboard
    await tester.tap(downArrowButton);
    await tester.pumpAndSettle();

    // Now up arrow icon is shown
    final upArrowButton = find.byIcon(Icons.keyboard_arrow_up_rounded);
    expect(upArrowButton, findsOneWidget);

    // Tap to re-open keyboard
    await tester.tap(upArrowButton);
    await tester.pumpAndSettle();

    // Down arrow icon is shown again
    expect(find.byIcon(Icons.keyboard_arrow_down_rounded), findsOneWidget);
    expect(terminalView.focusNode!.hasFocus, isTrue);
  });

  testWidgets('TerminalScreen shows floating copy bar when text is selected', (tester) async {
    await tester.pumpWidget(createTestWidget());
    await tester.pumpAndSettle();

    final session = sessionStore.getSession(testProfile.id)!;
    session.terminal.write('echo Hello World\r\n');
    await tester.pump();

    // Select text using controller
    session.controller.setSelection(
      session.terminal.buffer.createAnchor(0, 0),
      session.terminal.buffer.createAnchor(10, 0),
    );
    await tester.pumpAndSettle();

    // Verify Copy button is shown
    expect(find.text('Copy'), findsOneWidget);
    expect(find.byIcon(Icons.copy_rounded), findsOneWidget);

    // Tap Copy button
    await tester.tap(find.text('Copy'));
    await tester.pumpAndSettle();

    // Selection should be cleared and copy bar hidden
    expect(session.controller.selection, isNull);
    expect(find.text('Copy'), findsNothing);
  });
}
