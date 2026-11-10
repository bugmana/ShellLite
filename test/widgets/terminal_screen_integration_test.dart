import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import 'package:xterm/xterm.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late StorageService storageService;
  late SessionStore sessionStore;
  late TerminalSettingsStore terminalSettingsStore;
  late ServerProfile testProfile;

  setUp(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.getData') return {'text': ''};
      return null;
    });
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    storageService = StorageService(prefs: prefs);
    sessionStore = SessionStore(storageService: storageService);
    terminalSettingsStore =
        TerminalSettingsStore(storageService: storageService);

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
        ChangeNotifierProvider<TerminalSettingsStore>.value(
            value: terminalSettingsStore),
        Provider<StorageService>.value(value: storageService),
      ],
      child: MaterialApp(
        theme: AppTheme.buildTheme(TerminalThemePresets.obsidian),
        home: TerminalScreen(profile: testProfile),
      ),
    );
  }

  Widget keyboardTestWidget() => MaterialApp(
        theme: AppTheme.buildTheme(TerminalThemePresets.obsidian),
        home: TerminalScreen(profile: testProfile),
      );

  for (final hideBeforeInactive in [false, true]) {
    testWidgets(
        'resume restores typing after background keyboard dismissal (insets first=$hideBeforeInactive)',
        (tester) async {
      addTearDown(tester.view.resetViewInsets);
      await tester.pumpWidget(keyboardTestWidget());
      await tester.pumpAndSettle();
      tester.view.viewInsets = const FakeViewPadding(bottom: 280);
      await tester.pumpAndSettle();
      if (hideBeforeInactive) {
        tester.view.viewInsets = FakeViewPadding.zero;
      }
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      if (!hideBeforeInactive) {
        tester.view.viewInsets = FakeViewPadding.zero;
      }
      await tester.pumpAndSettle();
      tester.testTextInput.log.clear();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      final terminal = tester.widget<TerminalView>(find.byType(TerminalView));
      expect(terminal.hardwareKeyboardOnly, isFalse);
      expect(terminal.focusNode!.hasFocus, isTrue);
      expect(
          tester.testTextInput.log
              .any((call) => call.method == 'TextInput.show'),
          isTrue);
      expect(find.byTooltip('Hide keyboard'), findsOneWidget);
    });
  }

  for (final systemDismissal in [false, true]) {
    testWidgets(
        'resume respects an intentionally hidden keyboard (system=$systemDismissal)',
        (tester) async {
      addTearDown(tester.view.resetViewInsets);
      await tester.pumpWidget(keyboardTestWidget());
      await tester.pumpAndSettle();
      tester.view.viewInsets = const FakeViewPadding(bottom: 280);
      await tester.pumpAndSettle();
      if (systemDismissal) {
        tester.view.viewInsets = FakeViewPadding.zero;
      } else {
        await tester.tap(find.byTooltip('Hide keyboard'));
      }
      await tester.pumpAndSettle();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.view.viewInsets = FakeViewPadding.zero;
      await tester.pumpAndSettle();
      tester.testTextInput.log.clear();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(
          tester
              .widget<TerminalView>(find.byType(TerminalView))
              .hardwareKeyboardOnly,
          isTrue);
      expect(find.byTooltip('Show keyboard'), findsOneWidget);
      expect(
          tester.testTextInput.log
              .any((call) => call.method == 'TextInput.show'),
          isFalse);
    });
  }

  testWidgets(
      'a keyboard that stays visible during resume can still be dismissed',
      (tester) async {
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpWidget(keyboardTestWidget());
    await tester.pumpAndSettle();
    tester.view.viewInsets = const FakeViewPadding(bottom: 280);
    await tester.pumpAndSettle();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    tester.view.viewInsets = FakeViewPadding.zero;
    await tester.pumpAndSettle();
    expect(find.byTooltip('Show keyboard'), findsOneWidget);
    expect(
        tester
            .widget<TerminalView>(find.byType(TerminalView))
            .hardwareKeyboardOnly,
        isTrue);
  });

  testWidgets('resume does not focus the terminal underneath another screen',
      (tester) async {
    final editorFocus = FocusNode();
    addTearDown(editorFocus.dispose);
    await tester.pumpWidget(keyboardTestWidget());
    await tester.pumpAndSettle();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    final terminalContext = tester.element(find.byType(TerminalScreen));
    Navigator.of(terminalContext).push(MaterialPageRoute<void>(
        builder: (_) => Scaffold(
            body: TextField(focusNode: editorFocus, autofocus: true))));
    await tester.pumpAndSettle();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    final terminal = tester
        .widget<TerminalView>(find.byType(TerminalView, skipOffstage: false));
    expect(terminal.focusNode!.hasFocus, isFalse);
    expect(editorFocus.hasFocus, isTrue);
  });

  for (final width in [320.0, 800.0]) {
    testWidgets(
        'URL taps stay local while remote mouse reporting is enabled at width $width',
        (tester) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();
      final session = sessionStore.getSession(testProfile.id)!;
      const url = 'https://github.com/bugmana/ShellLite/releases/tag/v1.11.2';
      session.terminal
          .write('\x1b[?1049h\x1b[2J\x1b[H$url\r\n\x1b[?1000h\x1b[?1006h');
      expect(
          session.terminal.buffer.lines[0].getText(), startsWith('https://'));
      final sent = <String>[];
      session.terminal.onOutput = sent.add;
      await tester.pumpAndSettle();
      final view = find.byType(TerminalView);
      final state = tester.state<TerminalViewState>(view);
      final render = state.renderTerminal;
      final originalInputs = session.controller.pointerInput;
      final point = render.localToGlobal(
          render.getOffset(const CellOffset(8, 0)) + const Offset(2, 4));
      await tester.tapAt(point);
      await tester.pumpAndSettle();
      expect(sent, isEmpty,
          reason: 'URL taps must not reach the remote browser opener');
      expect(
          session.terminal.buffer.getText(session.controller.selection), url);
      expect(find.text('Copy link'), findsOneWidget);
      expect(session.controller.pointerInput, same(originalInputs));
      sent.clear();
      final ordinaryPoint = render.localToGlobal(
          render.getOffset(const CellOffset(4, 10)) + const Offset(2, 4));
      await tester.tapAt(ordinaryPoint);
      await tester.pumpAndSettle();
      expect(sent.any((value) => value.startsWith('\x1b[<0;')), isTrue,
          reason: 'Ordinary remote terminal clicks must keep working');
      sent.clear();
      final gesture = await tester.startGesture(point);
      expect(session.controller.pointerInput.inputs.contains(PointerInput.tap),
          isFalse);
      await gesture.moveBy(const Offset(0, -80));
      await gesture.cancel();
      await tester.pumpAndSettle();
      expect(session.controller.pointerInput, same(originalInputs));
      expect(sent, isEmpty);
      await tester.pump(const Duration(milliseconds: 350));
    });
  }
}
