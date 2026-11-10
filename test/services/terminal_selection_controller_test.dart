import 'package:flutter_test/flutter_test.dart';
import 'package:xterm/xterm.dart';
import 'package:shell_lite/services/terminal_selection_controller.dart';

void main() {
  test('excludes unbalanced punctuation around a URL', () {
    final terminal = Terminal()..resize(100, 10);
    terminal.write('Visit (https://example.com/a(b)).');
    final controller = TerminalSelectionController(terminal);
    final word = terminal.buffer.getWordBoundary(const CellOffset(8, 0))!;
    controller.setSelection(terminal.buffer.createAnchorFromOffset(word.begin),
        terminal.buffer.createAnchorFromOffset(word.end));
    expect(terminal.buffer.getText(controller.selection),
        'https://example.com/a(b)');
    controller.dispose();
  });
}
