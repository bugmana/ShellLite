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

    test('resolveButtonId returns standard XTerm button codes (not shifted by +4)', () {
      expect(ShellLiteMouseHandler.resolveButtonId(TerminalMouseButton.left), 0);
      expect(ShellLiteMouseHandler.resolveButtonId(TerminalMouseButton.middle), 1);
      expect(ShellLiteMouseHandler.resolveButtonId(TerminalMouseButton.right), 2);
      expect(ShellLiteMouseHandler.resolveButtonId(TerminalMouseButton.wheelUp), 64);
      expect(ShellLiteMouseHandler.resolveButtonId(TerminalMouseButton.wheelDown), 65);
      expect(ShellLiteMouseHandler.resolveButtonId(TerminalMouseButton.wheelLeft), 66);
      expect(ShellLiteMouseHandler.resolveButtonId(TerminalMouseButton.wheelRight), 67);
    });

    test('ignores events when MouseMode is none', () {
      final state = _FakeTerminalState(
        mouseMode: MouseMode.none,
        mouseReportMode: MouseReportMode.sgr,
      );
      final event = TerminalMouseEvent(
        button: TerminalMouseButton.wheelUp,
        buttonState: TerminalMouseButtonState.down,
        position: const CellOffset(0, 0),
        state: state,
        platform: TerminalTargetPlatform.unknown,
      );

      expect(handler(event), isNull);
    });

    test('ignores wheel events in clickOnly mode', () {
      final state = _FakeTerminalState(
        mouseMode: MouseMode.clickOnly,
        mouseReportMode: MouseReportMode.sgr,
      );
      final event = TerminalMouseEvent(
        button: TerminalMouseButton.wheelUp,
        buttonState: TerminalMouseButtonState.down,
        position: const CellOffset(0, 0),
        state: state,
        platform: TerminalTargetPlatform.unknown,
      );

      expect(handler(event), isNull);
    });

    test('ignores wheel release events in scroll modes', () {
      final state = _FakeTerminalState(
        mouseMode: MouseMode.upDownScroll,
        mouseReportMode: MouseReportMode.sgr,
      );
      final event = TerminalMouseEvent(
        button: TerminalMouseButton.wheelUp,
        buttonState: TerminalMouseButtonState.up,
        position: const CellOffset(0, 0),
        state: state,
        platform: TerminalTargetPlatform.unknown,
      );

      expect(handler(event), isNull);
    });

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
    });

    test('emits standard SGR sequence for normal button press and release', () {
      final state = _FakeTerminalState(
        mouseMode: MouseMode.upDownScroll,
        mouseReportMode: MouseReportMode.sgr,
      );

      final pressEvent = TerminalMouseEvent(
        button: TerminalMouseButton.left,
        buttonState: TerminalMouseButtonState.down,
        position: const CellOffset(0, 0),
        state: state,
        platform: TerminalTargetPlatform.unknown,
      );
      expect(handler(pressEvent), '\x1b[<0;1;1M');

      final releaseEvent = TerminalMouseEvent(
        button: TerminalMouseButton.left,
        buttonState: TerminalMouseButtonState.up,
        position: const CellOffset(0, 0),
        state: state,
        platform: TerminalTargetPlatform.unknown,
      );
      expect(handler(releaseEvent), '\x1b[<0;1;1m');
    });

    test('emits standard normal mode sequence with 1-based coordinates', () {
      final state = _FakeTerminalState(
        mouseMode: MouseMode.upDownScroll,
        mouseReportMode: MouseReportMode.normal,
      );

      final wheelUpEvent = TerminalMouseEvent(
        button: TerminalMouseButton.wheelUp,
        buttonState: TerminalMouseButtonState.down,
        position: const CellOffset(0, 0),
        state: state,
        platform: TerminalTargetPlatform.unknown,
      );
      // buttonId 64 -> 32 + 64 = 96 ('`')
      // col 0 -> 1-based 1 -> 32 + 1 = 33 ('!')
      // row 0 -> 1-based 1 -> 32 + 1 = 33 ('!')
      expect(handler(wheelUpEvent), '\x1b[M`!!');
    });

    test('emits standard urxvt mode sequence', () {
      final state = _FakeTerminalState(
        mouseMode: MouseMode.upDownScroll,
        mouseReportMode: MouseReportMode.urxvt,
      );

      final wheelUpEvent = TerminalMouseEvent(
        button: TerminalMouseButton.wheelUp,
        buttonState: TerminalMouseButtonState.down,
        position: const CellOffset(1, 2),
        state: state,
        platform: TerminalTargetPlatform.unknown,
      );
      // 32 + 64 = 96; col 1 -> 2; row 2 -> 3
      expect(handler(wheelUpEvent), '\x1b[96;2;3M');
    });

    test('tmux compatibility: wheel events never set shift modifier mask (+4)', () {
      // In xterm-4.0.0, the default handler assigned wheelUp = 68 (64+4) and wheelDown = 69 (65+4).
      // Under SGR DECSET 1006 protocol, +4 is the SHIFT modifier flag, which makes tmux decode
      // wheel events as S-WheelUpPane / S-WheelDownPane and silently discard them.
      // ShellLiteMouseHandler must always emit unshifted 64 and 65.
      final state = _FakeTerminalState(
        mouseMode: MouseMode.upDownScroll,
        mouseReportMode: MouseReportMode.sgr,
      );

      final wheelUp = TerminalMouseEvent(
        button: TerminalMouseButton.wheelUp,
        buttonState: TerminalMouseButtonState.down,
        position: const CellOffset(0, 0),
        state: state,
        platform: TerminalTargetPlatform.unknown,
      );
      final wheelDown = TerminalMouseEvent(
        button: TerminalMouseButton.wheelDown,
        buttonState: TerminalMouseButtonState.down,
        position: const CellOffset(0, 0),
        state: state,
        platform: TerminalTargetPlatform.unknown,
      );

      expect(handler(wheelUp), '\x1b[<64;1;1M');
      expect(handler(wheelDown), '\x1b[<65;1;1M');
      expect(ShellLiteMouseHandler.resolveButtonId(TerminalMouseButton.wheelUp) & 4, 0,
          reason: 'Shift modifier bit (+4) must be 0 for standard wheelUp');
      expect(ShellLiteMouseHandler.resolveButtonId(TerminalMouseButton.wheelDown) & 4, 0,
          reason: 'Shift modifier bit (+4) must be 0 for standard wheelDown');
    });
  });
}
