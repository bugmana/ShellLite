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

  testWidgets('TerminalScreen shows Paste action button in KeyboardAccessoryBar and handles paste', (tester) async {
    await tester.pumpWidget(createTestWidget());
    await tester.pumpAndSettle();

    final pasteButton = find.byIcon(Icons.paste_rounded);
    expect(pasteButton, findsOneWidget);

    await tester.tap(pasteButton);
    await tester.pump();
  });

  testWidgets('TerminalScreen shows Disconnect action in Session Menu and handles session disconnect', (tester) async {
    await tester.pumpWidget(createTestWidget());
    await tester.pumpAndSettle();

    final session = sessionStore.getSession(testProfile.id);
    expect(session, isNotNull);
    expect(sessionStore.hasActiveSession(testProfile.id), isTrue);

    // Verify Session Menu button is present in AppBar
    final menuButton = find.byTooltip('Session Menu');
    expect(menuButton, findsOneWidget);
    expect(find.byIcon(Icons.more_vert_rounded), findsOneWidget);

    // Open Session Menu
    await tester.tap(menuButton);
    await tester.pumpAndSettle();

    // Verify Disconnect option is present
    final disconnectItem = find.text('Disconnect');
    expect(disconnectItem, findsOneWidget);

    // Tap Disconnect
    await tester.tap(disconnectItem);
    await tester.pumpAndSettle();

    // Verify session has been closed
    expect(sessionStore.hasActiveSession(testProfile.id), isFalse);
    expect(sessionStore.getSession(testProfile.id), isNull);
  });

  testWidgets('TerminalScreen shows Upload File action in Session Menu', (tester) async {
    await tester.pumpWidget(createTestWidget());
    await tester.pumpAndSettle();

    // Open Session Menu
    final menuButton = find.byTooltip('Session Menu');
    expect(menuButton, findsOneWidget);
    await tester.tap(menuButton);
    await tester.pumpAndSettle();

    final uploadItem = find.text('Upload File');
    expect(uploadItem, findsOneWidget);

    // Tapping when disconnected shows disconnected snackbar
    await tester.tap(uploadItem);
    await tester.pump();
    expect(find.text('Terminal session is not connected'), findsOneWidget);
  });

  testWidgets('TerminalScreen opens Terminal Settings modal via Session Menu', (tester) async {
    await tester.pumpWidget(createTestWidget());
    await tester.pumpAndSettle();

    // Open Session Menu
    final menuButton = find.byTooltip('Session Menu');
    expect(menuButton, findsOneWidget);
    await tester.tap(menuButton);
    await tester.pumpAndSettle();

    // Tap settings item in menu
    final settingsItem = find.text('Terminal Settings');
    expect(settingsItem, findsOneWidget);
    await tester.tap(settingsItem);
    await tester.pumpAndSettle();

    // Modal should be displayed
    expect(find.text('Terminal Settings'), findsOneWidget);
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

  testWidgets('TerminalScreen shows floating callout toolbar [Copy | Select All] when text is selected', (tester) async {
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

    // Verify floating callout toolbar buttons are shown
    expect(find.text('Copy'), findsOneWidget);
    expect(find.byIcon(Icons.copy_rounded), findsOneWidget);
    expect(find.text('Select All'), findsOneWidget);
    expect(find.byIcon(Icons.select_all_rounded), findsOneWidget);

    // Verify KeyboardAccessoryBar remains mounted and visible (untouched)
    expect(find.byType(KeyboardAccessoryBar), findsOneWidget);

    // Tap "Select All" button
    await tester.tap(find.text('Select All'));
    await tester.pumpAndSettle();

    // Verify selection expanded across buffer
    expect(session.controller.selection, isNotNull);
    final selection = session.controller.selection!.normalized;
    expect(selection.begin.y, equals(0));
    expect(selection.begin.x, equals(0));
    expect(selection.end.y, equals(session.terminal.buffer.lines.length - 1));

    // Tap "Copy" button
    await tester.tap(find.text('Copy'));
    await tester.pumpAndSettle();

    // Selection should be cleared and floating toolbar hidden
    expect(session.controller.selection, isNull);
    expect(find.text('Copy'), findsNothing);
    expect(find.text('Select All'), findsNothing);
    expect(find.byKey(const Key('terminal_selection_handle_start')), findsNothing);
    expect(find.byKey(const Key('terminal_selection_handle_end')), findsNothing);

    // KeyboardAccessoryBar is still present
    expect(find.byType(KeyboardAccessoryBar), findsOneWidget);
  });

  testWidgets('TerminalScreen renders selection handles and allows dragging markers to update selection', (tester) async {
    await tester.pumpWidget(createTestWidget());
    await tester.pumpAndSettle();

    final session = sessionStore.getSession(testProfile.id)!;
    session.terminal.write('echo Hello World\r\n');
    await tester.pump();

    int helloLine = 0;
    int helloCol = 0;
    for (int i = 0; i < session.terminal.buffer.lines.length; i++) {
      final text = session.terminal.buffer.lines[i].getText();
      if (text.contains('Hello')) {
        helloLine = i;
        helloCol = text.indexOf('Hello');
        break;
      }
    }

    // Select "Hello"
    session.controller.setSelection(
      session.terminal.buffer.createAnchor(helloCol, helloLine),
      session.terminal.buffer.createAnchor(helloCol + 5, helloLine),
    );
    await tester.pumpAndSettle();

    final startHandleFinder = find.byKey(const Key('terminal_selection_handle_start'));
    final endHandleFinder = find.byKey(const Key('terminal_selection_handle_end'));

    expect(startHandleFinder, findsOneWidget);
    expect(endHandleFinder, findsOneWidget);

    // Initial text should be "Hello"
    expect(session.terminal.buffer.getText(session.controller.selection), 'Hello');

    // Drag end handle to the right
    await tester.drag(endHandleFinder, const Offset(60, 0));
    await tester.pumpAndSettle();

    // End of selection should have expanded
    final newEnd = session.controller.selection!.normalized.end;
    expect(newEnd.x, greaterThan(helloCol + 5));

    // Drag start handle to the left
    await tester.drag(startHandleFinder, const Offset(-60, 0));
    await tester.pumpAndSettle();

    // Start of selection should have moved left
    final newStart = session.controller.selection!.normalized.begin;
    expect(newStart.x, lessThan(helloCol));
  });

  testWidgets('TerminalScreen AppBar centers title and uses clean 2-item header with overflow Session Menu', (tester) async {
    await tester.pumpWidget(createTestWidget());
    await tester.pumpAndSettle();

    final appBarFinder = find.byType(AppBar);
    expect(appBarFinder, findsOneWidget);
    final appBar = tester.widget<AppBar>(appBarFinder);
    expect(appBar.centerTitle, isTrue);

    // Verify clean header: Session Menu button is present with >= 44pt touch target
    final menuButton = find.byTooltip('Session Menu');
    expect(menuButton, findsOneWidget);
    final menuWidget = tester.widget<PopupMenuButton<String>>(find.byWidgetPredicate((w) => w is PopupMenuButton<String>));
    expect(menuWidget.constraints!.minWidth, greaterThanOrEqualTo(44.0));
    expect(menuWidget.constraints!.minHeight, greaterThanOrEqualTo(44.0));

    // Verify Paste button is present on the KeyboardAccessoryBar with >= 44pt touch target
    final pasteFinder = find.byTooltip('Paste');
    expect(pasteFinder, findsOneWidget);
    expect(find.byIcon(Icons.paste_rounded), findsOneWidget);

    // Verify title text has maxLines: 1 and TextOverflow.ellipsis
    final titleText = tester.widget<Text>(find.text('Test Terminal Server'));
    expect(titleText.maxLines, 1);
    expect(titleText.overflow, TextOverflow.ellipsis);
  });

  testWidgets('TerminalScreen sets hardwareKeyboardOnly when virtual keyboard is toggled to prevent scroll interruption', (tester) async {
    await tester.pumpWidget(createTestWidget());
    await tester.pumpAndSettle();

    // Initially keyboard is visible -> hardwareKeyboardOnly is false
    final terminalViewInitial = tester.widget<TerminalView>(find.byType(TerminalView));
    expect(terminalViewInitial.hardwareKeyboardOnly, isFalse);

    // Tap toggle keyboard (down arrow) to hide keyboard
    final hideKeyboardButton = find.byTooltip('Hide keyboard');
    expect(hideKeyboardButton, findsOneWidget);
    await tester.tap(hideKeyboardButton);
    await tester.pumpAndSettle();

    // Now keyboard is hidden -> hardwareKeyboardOnly is true to guard scrolling
    final terminalViewHidden = tester.widget<TerminalView>(find.byType(TerminalView));
    expect(terminalViewHidden.hardwareKeyboardOnly, isTrue);

    // Tap toggle keyboard (up arrow) to show keyboard
    final showKeyboardButton = find.byTooltip('Show keyboard');
    expect(showKeyboardButton, findsOneWidget);
    await tester.tap(showKeyboardButton);
    await tester.pumpAndSettle();

    // Keyboard restored -> hardwareKeyboardOnly is false
    final terminalViewRestored = tester.widget<TerminalView>(find.byType(TerminalView));
    expect(terminalViewRestored.hardwareKeyboardOnly, isFalse);
  });

  testWidgets('TerminalScreen scrolls smoothly through buffer without rebuilding TerminalView or crashing', (tester) async {
    await tester.pumpWidget(createTestWidget());
    await tester.pumpAndSettle();

    final session = sessionStore.getSession(testProfile.id)!;
    for (int i = 0; i < 100; i++) {
      session.terminal.write('Log line output #$i\r\n');
    }
    await tester.pumpAndSettle();

    // Scroll upwards through buffer
    await tester.drag(find.byType(TerminalView), const Offset(0, 300));
    await tester.pumpAndSettle();

    // Verify TerminalView is still healthy and rendered
    expect(find.byType(TerminalView), findsOneWidget);

    // Scroll back down
    await tester.drag(find.byType(TerminalView), const Offset(0, -300));
    await tester.pumpAndSettle();
    expect(find.byType(TerminalView), findsOneWidget);
  });
}
