import 'package:flutter_test/flutter_test.dart';
import 'package:xterm/xterm.dart';
import 'package:shell_lite/services/terminal_selection_controller.dart';

void main() {
  test('expands a wrapped URL and preserves later handle edits', () {
    final terminal = Terminal()..resize(20, 10);
    terminal.write('Go https://example.com/login?code=123');
    final controller = TerminalSelectionController(terminal);
    controller.setSelection(
        terminal.buffer.createAnchor(5, 0), terminal.buffer.createAnchor(9, 0));
    expect(terminal.buffer.getText(controller.selection),
        'https://example.com/login?code=123');
    controller.setSelection(
        terminal.buffer.createAnchor(3, 0), terminal.buffer.createAnchor(8, 0));
    expect(terminal.buffer.getText(controller.selection), 'https');
    controller.dispose();
  });
  test('excludes unbalanced punctuation around a URL', () {
    final terminal = Terminal()..resize(100, 10);
    terminal.write('Visit (https://example.com/a(b)).');
    final controller = TerminalSelectionController(terminal);
    controller.setSelection(terminal.buffer.createAnchor(8, 0),
        terminal.buffer.createAnchor(12, 0));
    expect(terminal.buffer.getText(controller.selection),
        'https://example.com/a(b)');
    controller.dispose();
  });
}
