import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xterm/xterm.dart';
import 'package:shell_lite/screens/terminal/terminal_selection_overlay.dart';
import 'package:shell_lite/services/terminal_selection_controller.dart';
import 'package:shell_lite/theme/app_theme.dart';
import 'package:shell_lite/theme/terminal_theme_presets.dart';

class _RenderTerminal {
  double get lineHeight => 16;
  Offset getOffset(CellOffset cell) => Offset(cell.x * 8, 100);
}

void main() {
  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('com.bugmana.shell_lite/platform'),
            (_) async => 32);
  });
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('com.bugmana.shell_lite/platform'), null);
  });
  for (final columns in [20]) {
    testWidgets('copies whole URL without browser actions at width $columns',
        (tester) async {
      String? copied;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map)['text'] as String;
        }
        return null;
      });
      addTearDown(() => TestDefaultBinaryMessengerBinding
          .instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null));
      final terminal = Terminal()..resize(columns, 10);
      const url = 'https://example.com/login?code=abc%2B!#done';
      terminal.write('Go $url');
      final shellInput = <String>[];
      terminal.onOutput = shellInput.add;
      final controller = TerminalSelectionController(terminal);
      final scroll = ScrollController();
      final word = terminal.buffer.getWordBoundary(const CellOffset(5, 0))!;
      controller.setSelection(
          terminal.buffer.createAnchorFromOffset(word.begin),
          terminal.buffer.createAnchorFromOffset(word.end));
      final theme = AppTheme.buildTheme(TerminalThemePresets.obsidian);
      await tester.pumpWidget(MaterialApp(
          theme: theme,
          home: Scaffold(
              body: Stack(children: [
            TerminalSelectionOverlay(
                terminal: terminal,
                controller: controller,
                scrollController: scroll,
                renderTerminal: _RenderTerminal(),
                terminalViewKey: GlobalKey(),
                canvasWidth: 800,
                canvasHeight: 500,
                isDisconnected: false,
                theme: theme.extension<AppThemeExtension>()!),
          ]))));
      expect(find.text('Open link'), findsNothing);
      expect(
          tester
              .getSize(find.byKey(const Key('terminal_selection_copy_button')))
              .height,
          greaterThanOrEqualTo(48));
      await tester.tap(find.text('Copy link'));
      await tester.pumpAndSettle();
      expect(copied, url);
      expect(shellInput, isEmpty);
      expect(controller.selection, isNull);
      expect(find.text('Copied to clipboard'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      controller.dispose();
      scroll.dispose();
    });
  }

  testWidgets(
      'clipboard failure keeps selection for retry and targets are large enough',
      (tester) async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') {
        throw PlatformException(code: 'denied');
      }
      return null;
    });
    addTearDown(() => TestDefaultBinaryMessengerBinding
        .instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null));
    final terminal = Terminal()..resize(80, 10);
    terminal.write('Hello');
    final controller = TerminalController();
    final scroll = ScrollController();
    controller.setSelection(
        terminal.buffer.createAnchor(0, 0), terminal.buffer.createAnchor(5, 0));
    final theme = AppTheme.buildTheme(TerminalThemePresets.obsidian);
    await tester.pumpWidget(MaterialApp(
        theme: theme,
        home: Scaffold(
            body: Stack(children: [
          TerminalSelectionOverlay(
              terminal: terminal,
              controller: controller,
              scrollController: scroll,
              renderTerminal: _RenderTerminal(),
              terminalViewKey: GlobalKey(),
              canvasWidth: 800,
              canvasHeight: 500,
              isDisconnected: false,
              theme: theme.extension<AppThemeExtension>()!),
        ]))));
    for (final key in [
      'terminal_selection_copy_button',
      'terminal_selection_select_all_button',
      'terminal_selection_handle_start'
    ]) {
      final size = tester.getSize(find.byKey(Key(key)));
      expect(size.width, greaterThanOrEqualTo(48));
      expect(size.height, greaterThanOrEqualTo(48));
    }
    await tester.tap(find.text('Copy'));
    await tester.pumpAndSettle();
    expect(find.text('Could not copy. Please try again.'), findsOneWidget);
    expect(controller.selection, isNotNull);
    expect(find.text('Copied to clipboard'), findsNothing);
    await tester.pumpWidget(const SizedBox());
    controller.dispose();
    scroll.dispose();
  });
}
