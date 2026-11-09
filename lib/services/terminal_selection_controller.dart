import 'package:xterm/xterm.dart';

/// Keeps printed URL selection local to the app.
class TerminalSelectionController extends TerminalController {
  TerminalSelectionController(this.terminal);
  final Terminal terminal;

  BufferRange? linkAt(CellOffset position, {CellOffset? through}) {
    if (position.y < 0 || position.y >= terminal.buffer.lines.length) {
      return null;
    }
    final buffer = terminal.buffer;
    var first = position.y;
    var last = position.y;
    while (first > 0 && buffer.lines[first].isWrapped) {
      first--;
    }
    while (last + 1 < buffer.lines.length && buffer.lines[last + 1].isWrapped) {
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
      // Query/fragment punctuation may be part of an opaque auth token.
      final hasPayload =
          source.substring(match.start, end).contains(RegExp(r'[?#]'));
      while (!hasPayload &&
          end > match.start &&
          '.,;:!?'.contains(source[end - 1])) {
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

      final hit = List.generate(end - match.start, (i) => match.start + i).any(
          (i) =>
              starts[i].y == position.y &&
              (through == null
                  ? position.x >= starts[i].x && position.x < ends[i].x
                  : starts[i].x >= position.x && starts[i].x < through.x));
      if (hit) return BufferRangeLine(starts[match.start], ends[end - 1]);
    }
    return null;
  }

  bool selectLinkAt(CellOffset position) {
    final link = linkAt(position);
    if (link == null) return false;
    super.setSelection(terminal.buffer.createAnchorFromOffset(link.begin),
        terminal.buffer.createAnchorFromOffset(link.end),
        mode: SelectionMode.line);
    return true;
  }

  @override
  void setSelection(CellAnchor base, CellAnchor extent, {SelectionMode? mode}) {
    final word = terminal.buffer.getWordBoundary(base.offset);
    if (selection == null &&
        word != null &&
        word.begin.isEqual(base.offset) &&
        word.end.isEqual(extent.offset)) {
      final link = linkAt(base.offset, through: extent.offset);
      if (link != null) {
        base.dispose();
        extent.dispose();
        super.setSelection(terminal.buffer.createAnchorFromOffset(link.begin),
            terminal.buffer.createAnchorFromOffset(link.end),
            mode: mode);
        return;
      }
    }
    super.setSelection(base, extent, mode: mode);
  }
}
