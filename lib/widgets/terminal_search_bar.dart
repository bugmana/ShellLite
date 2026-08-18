import 'package:flutter/material.dart';
import 'package:xterm/xterm.dart';
import '../theme/app_theme.dart';

class TerminalSearchMatch {
  final int lineIndex;
  final int startCol;
  final int endCol;

  const TerminalSearchMatch({
    required this.lineIndex,
    required this.startCol,
    required this.endCol,
  });
}

class TerminalSearchBar extends StatefulWidget {
  final Terminal terminal;
  final TerminalController? controller;
  final VoidCallback onClose;

  const TerminalSearchBar({
    super.key,
    required this.terminal,
    this.controller,
    required this.onClose,
  });

  @override
  State<TerminalSearchBar> createState() => _TerminalSearchBarState();
}

class _TerminalSearchBarState extends State<TerminalSearchBar> {
  final _searchController = TextEditingController();
  final _focusNode = FocusNode();

  List<TerminalSearchMatch> _matches = [];
  int _currentMatchIndex = -1;

  @override
  void initState() {
    super.initState();
    _focusNode.requestFocus();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _focusNode.dispose();
    widget.controller?.clearSelection();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    if (query.isEmpty) {
      setState(() {
        _matches = [];
        _currentMatchIndex = -1;
      });
      widget.controller?.clearSelection();
      return;
    }

    final newMatches = <TerminalSearchMatch>[];
    final buffer = widget.terminal.buffer;
    final lines = buffer.lines;
    final lowerQuery = query.toLowerCase();

    for (int y = 0; y < lines.length; y++) {
      final lineText = lines[y].getText().toLowerCase();
      int startIndex = 0;

      while ((startIndex = lineText.indexOf(lowerQuery, startIndex)) != -1) {
        newMatches.add(
          TerminalSearchMatch(
            lineIndex: y,
            startCol: startIndex,
            endCol: startIndex + query.length,
          ),
        );
        startIndex += query.length;
      }
    }

    setState(() {
      _matches = newMatches;
      _currentMatchIndex = newMatches.isNotEmpty ? 0 : -1;
    });

    if (newMatches.isNotEmpty) {
      _highlightMatch(0);
    } else {
      widget.controller?.clearSelection();
    }
  }

  void _nextMatch() {
    if (_matches.isEmpty) return;
    final nextIdx = (_currentMatchIndex + 1) % _matches.length;
    setState(() => _currentMatchIndex = nextIdx);
    _highlightMatch(nextIdx);
  }

  void _previousMatch() {
    if (_matches.isEmpty) return;
    final prevIdx = (_currentMatchIndex - 1 + _matches.length) % _matches.length;
    setState(() => _currentMatchIndex = prevIdx);
    _highlightMatch(prevIdx);
  }

  void _highlightMatch(int index) {
    if (index < 0 || index >= _matches.length) return;
    final match = _matches[index];
    final buffer = widget.terminal.buffer;

    try {
      final startAnchor = buffer.createAnchor(match.startCol, match.lineIndex);
      final endAnchor = buffer.createAnchor(match.endCol, match.lineIndex);
      widget.controller?.setSelection(startAnchor, endAnchor);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.appTheme;
    final matchCount = _matches.length;
    final currentPos = _currentMatchIndex >= 0 ? _currentMatchIndex + 1 : 0;

    return Material(
      color: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: theme.cardSurface.withValues(alpha: 0.98),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: theme.border, width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.4),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            Icon(Icons.search_rounded, size: 18, color: theme.textSecondary),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _searchController,
                focusNode: _focusNode,
                style: TextStyle(color: theme.textPrimary, fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'Search buffer...',
                  hintStyle: TextStyle(color: theme.textSecondary, fontSize: 13),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 6),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  filled: false,
                ),
                onChanged: _onSearchChanged,
              ),
            ),
            if (_searchController.text.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: matchCount > 0
                      ? theme.primaryAccent.withValues(alpha: 0.15)
                      : theme.border.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  matchCount > 0 ? '$currentPos of $matchCount' : 'No matches',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: matchCount > 0 ? theme.primaryAccent : theme.textSecondary,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              IconButton(
                icon: const Icon(Icons.keyboard_arrow_up_rounded, size: 20),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                tooltip: 'Previous match',
                onPressed: matchCount > 0 ? _previousMatch : null,
              ),
              IconButton(
                icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 20),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                tooltip: 'Next match',
                onPressed: matchCount > 0 ? _nextMatch : null,
              ),
            ],
            IconButton(
              icon: const Icon(Icons.close_rounded, size: 18),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
              tooltip: 'Close search',
              onPressed: widget.onClose,
            ),
          ],
        ),
      ),
    );
  }
}
