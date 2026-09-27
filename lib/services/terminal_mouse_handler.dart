import 'package:xterm/xterm.dart';

/// Custom [TerminalMouseHandler] that corrects mouse wheel button encoding.
///
/// The default implementation in `xterm-4.0.0` incorrectly defines
/// `TerminalMouseButton.wheelUp` as `64 + 4` (= 68) and `wheelDown` as `64 + 5` (= 69).
/// Under standard XTerm SGR (DECSET 1006) protocol, bit 2 (+4) represents the Shift modifier,
/// causing tmux to interpret incoming scroll events as `S-WheelUpPane` and `S-WheelDownPane`.
/// Because tmux has no default bindings for shifted wheel events, it silently drops them.
///
/// [ShellLiteMouseHandler] maps wheelUp to 64, wheelDown to 65, wheelLeft to 66,
/// and wheelRight to 67, and fixes the 1-based vertical row coordinate offset in legacy modes.
class ShellLiteMouseHandler implements TerminalMouseHandler {
  const ShellLiteMouseHandler();

  static int resolveButtonId(TerminalMouseButton button) {
    switch (button) {
      case TerminalMouseButton.left:
        return 0;
      case TerminalMouseButton.middle:
        return 1;
      case TerminalMouseButton.right:
        return 2;
      case TerminalMouseButton.wheelUp:
        return 64;
      case TerminalMouseButton.wheelDown:
        return 65;
      case TerminalMouseButton.wheelLeft:
        return 66;
      case TerminalMouseButton.wheelRight:
        return 67;
    }
  }

  @override
  String? call(TerminalMouseEvent event) {
    final mode = event.state.mouseMode;
    if (mode == MouseMode.none) {
      return null;
    }

    if (mode == MouseMode.clickOnly) {
      if (event.buttonState == TerminalMouseButtonState.down &&
          event.button.id < 3) {
        return _report(event);
      }
      return null;
    }

    // MouseMode.upDownScroll, upDownScrollDrag, upDownScrollMove
    if (event.button.isWheel && event.buttonState == TerminalMouseButtonState.up) {
      // Up events are never reported for mouse wheel buttons.
      return null;
    }

    return _report(event);
  }

  String _report(TerminalMouseEvent event) {
    final buttonId = resolveButtonId(event.button);
    final x = event.position.x + 1;
    final y = event.position.y + 1;
    final reportMode = event.state.mouseReportMode;

    switch (reportMode) {
      case MouseReportMode.normal:
      case MouseReportMode.utf:
        final encodedButton = event.buttonState == TerminalMouseButtonState.up ? 3 : buttonId;
        final btn = String.fromCharCode(32 + encodedButton);
        final col = (reportMode == MouseReportMode.normal && x > 223) ||
                (reportMode == MouseReportMode.utf && x > 2015)
            ? '\x00'
            : String.fromCharCode(32 + x);
        final row = (reportMode == MouseReportMode.normal && y > 223) ||
                (reportMode == MouseReportMode.utf && y > 2015)
            ? '\x00'
            : String.fromCharCode(32 + y);
        return '\x1b[M$btn$col$row';

      case MouseReportMode.sgr:
        final upDown = event.buttonState == TerminalMouseButtonState.down ? 'M' : 'm';
        return '\x1b[<$buttonId;$x;$y$upDown';

      case MouseReportMode.urxvt:
        final encodedButton = 32 + (event.buttonState == TerminalMouseButtonState.up ? 3 : buttonId);
        return '\x1b[$encodedButton;$x;${y}M';
    }
  }
}
