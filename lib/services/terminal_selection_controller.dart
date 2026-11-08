import 'package:xterm/xterm.dart';

/// Expands initial word selections to a printed URL, preserving later edits.
class TerminalSelectionController extends TerminalController {
  TerminalSelectionController(this.terminal);
  final Terminal terminal;

  @override
  void setSelection(CellAnchor base, CellAnchor extent, {SelectionMode? mode}) {
    if (selection == null && base.y == extent.y) {
      final buffer = terminal.buffer;
      var first = base.y;
      var last = base.y;
      while (first > 0 && buffer.lines[first].isWrapped) {
        first--;
      }
      while (
          last + 1 < buffer.lines.length && buffer.lines[last + 1].isWrapped) {
        last++;
      }
      final text = StringBuffer();
      final starts = <CellOffset>[];
      final ends = <CellOffset>[];
      for (var y = first; y <= last; y++) {
        final line = buffer.lines[y];
        for (var x = 0; x < terminal.viewWidth; x++) {
          final code = line.getCodePoint(x);
          if (code == 0 && line.getWidth(x) == 0) continue;
          final value = code == 0 ? ' ' : String.fromCharCode(code);
          text.write(value);
          for (var i = 0; i < value.length; i++) {
            starts.add(CellOffset(x, y));
            ends.add(CellOffset(x + (line.getWidth(x) > 1 ? 2 : 1), y));
          }
        }
      }
      for (final match
          in RegExp(r'''https?://[^\s<>"']+''').allMatches(text.toString())) {
        var end = match.end;
        final source = text.toString();
        while (end > match.start && '.,;:!?'.contains(source[end - 1])) {
          end--;
        }
        for (final pair in ['()', '[]', '{}']) {
          while (end > match.start && source[end - 1] == pair[1]) {
            final value = source.substring(match.start, end);
            if (pair[1].allMatches(value).length <=
                pair[0].allMatches(value).length) {
              break;
            }
            end--;
          }
        }
        final hit = starts.sublist(match.start, end).any((cell) =>
            cell.y == base.y && cell.x >= base.x && cell.x < extent.x);
        if (hit) {
          final from = starts[match.start];
          final to = ends[end - 1];
          base.dispose();
          extent.dispose();
          super.setSelection(buffer.createAnchorFromOffset(from),
              buffer.createAnchorFromOffset(to),
              mode: mode);
          return;
        }
      }
    }
    super.setSelection(base, extent, mode: mode);
  }
}
