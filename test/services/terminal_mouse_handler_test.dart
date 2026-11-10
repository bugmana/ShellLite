import 'package:flutter_test/flutter_test.dart';
import 'package:xterm/xterm.dart';
import 'package:shell_lite/services/terminal_mouse_handler.dart';

class _FakeTerminalState implements TerminalState {
  @override
  final MouseMode mouseMode;

  @override
  final MouseReportMode mouseReportMode;

  _FakeTerminalState({
    required this.mouseMode,
    required this.mouseReportMode,
  });

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('ShellLiteMouseHandler', () {
    const handler = ShellLiteMouseHandler();

    test('emits standard SGR sequence 64 for wheelUp and 65 for wheelDown', () {
      final state = _FakeTerminalState(
        mouseMode: MouseMode.upDownScroll,
        mouseReportMode: MouseReportMode.sgr,
      );

      final wheelUpEvent = TerminalMouseEvent(
        button: TerminalMouseButton.wheelUp,
        buttonState: TerminalMouseButtonState.down,
        position: const CellOffset(9, 4), // 0-based: col 10, row 5
        state: state,
        platform: TerminalTargetPlatform.unknown,
      );
      expect(handler(wheelUpEvent), '\x1b[<64;10;5M');

      final wheelDownEvent = TerminalMouseEvent(
        button: TerminalMouseButton.wheelDown,
        buttonState: TerminalMouseButtonState.down,
        position: const CellOffset(9, 4),
        state: state,
        platform: TerminalTargetPlatform.unknown,
      );
      expect(handler(wheelDownEvent), '\x1b[<65;10;5M');
      expect(
          handler(TerminalMouseEvent(
            button: TerminalMouseButton.wheelUp,
            buttonState: TerminalMouseButtonState.up,
            position: const CellOffset(9, 4),
            state: state,
            platform: TerminalTargetPlatform.unknown,
          )),
          isNull);
    });
  });
}
