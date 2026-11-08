import 'package:flutter_test/flutter_test.dart';
import 'package:xterm/xterm.dart';
import 'package:shell_lite/services/terminal_selection_controller.dart';

void main() {
  test('preserves broad initial selections and select all on a single line',
      () {
    final terminal = Terminal()..resize(100, 10);
    const output = 'before https://example.com after';
    terminal.write(output);
    final controller = TerminalSelectionController(terminal);
    controller.setSelection(terminal.buffer.createAnchor(0, 0),
        terminal.buffer.createAnchor(output.length, 0));
    expect(terminal.buffer.getText(controller.selection), output);
    controller.dispose();
  });
  test('preserves trailing query and fragment punctuation', () {
    for (final url in [
      'https://example.com/?token=abc!',
      'https://example.com/?token=abc?',
      'https://example.com/#abc;'
    ]) {
      final terminal = Terminal()..resize(100, 10);
      terminal.write(url);
      final controller = TerminalSelectionController(terminal);
      final word = terminal.buffer.getWordBoundary(const CellOffset(2, 0))!;
      controller.setSelection(
          terminal.buffer.createAnchorFromOffset(word.begin),
          terminal.buffer.createAnchorFromOffset(word.end));
      expect(terminal.buffer.getText(controller.selection), url);
      controller.dispose();
    }
  });
  test('expands a wrapped URL and preserves later handle edits', () {
    final terminal = Terminal()..resize(20, 10);
    terminal.write('Go https://example.com/login?code=123');
    final controller = TerminalSelectionController(terminal);
    final word = terminal.buffer.getWordBoundary(const CellOffset(5, 0))!;
    controller.setSelection(terminal.buffer.createAnchorFromOffset(word.begin),
        terminal.buffer.createAnchorFromOffset(word.end));
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
    final word = terminal.buffer.getWordBoundary(const CellOffset(8, 0))!;
    controller.setSelection(terminal.buffer.createAnchorFromOffset(word.begin),
        terminal.buffer.createAnchorFromOffset(word.end));
    expect(terminal.buffer.getText(controller.selection),
        'https://example.com/a(b)');
    controller.dispose();
  });
}
