import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:xterm/xterm.dart';
import '../../theme/app_theme.dart';
import '../../widgets/terminal_selection_handle.dart';
import 'terminal_selection_toolbar.dart';

/// Overlay widget managing terminal selection handles and floating toolbar.
class TerminalSelectionOverlay extends StatelessWidget {
  final Terminal terminal;
  final TerminalController controller;
  final ScrollController scrollController;
  final dynamic renderTerminal;
  final GlobalKey terminalViewKey;
  final double canvasWidth;
  final double canvasHeight;
  final bool isDisconnected;
  final AppThemeExtension theme;

  const TerminalSelectionOverlay({
    super.key,
    required this.terminal,
    required this.controller,
    required this.scrollController,
    required this.renderTerminal,
    required this.terminalViewKey,
    required this.canvasWidth,
    required this.canvasHeight,
    required this.isDisconnected,
    required this.theme,
  });

  void _copySelection(BuildContext context) {
    HapticFeedback.lightImpact();
    final selection = controller.selection;
    if (selection != null) {
      final text = terminal.buffer.getText(selection);
      Clipboard.setData(ClipboardData(text: text));
      controller.clearSelection();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Copied to clipboard'),
          duration: const Duration(seconds: 1),
          behavior: SnackBarBehavior.floating,
          backgroundColor: theme.cardSurface,
        ),
      );
    }
    SemanticsService.sendAnnouncement(
      View.of(context),
      'Selection copied to clipboard',
      TextDirection.ltr,
    );
  }

  void _selectAll() {
    HapticFeedback.selectionClick();
    if (terminal.buffer.lines.length == 0) return;
    final lastLine = terminal.buffer.lines.length - 1;
    final lastCol = terminal.viewWidth;
    controller.setSelection(
      terminal.buffer.createAnchor(0, 0),
      terminal.buffer.createAnchor(lastCol, lastLine),
    );
  }

  void _handleStartHandleDrag(
    DragUpdateDetails details,
    BufferRange normalized,
  ) {
    final renderBox = terminalViewKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null || renderTerminal == null) return;

    final localPos = renderBox.globalToLocal(details.globalPosition);
    final lineHeight = renderTerminal.lineHeight as double;

    final targetOffset = Offset(localPos.dx, localPos.dy - (lineHeight * 0.5));
    final cellOffset = renderTerminal.getCellOffset(targetOffset) as CellOffset;

    final currentEnd = normalized.end;
    CellOffset lastValidStart;
    if (currentEnd.x > 0) {
      lastValidStart = CellOffset(currentEnd.x - 1, currentEnd.y);
    } else if (currentEnd.y > 0) {
      lastValidStart = CellOffset(terminal.viewWidth - 1, currentEnd.y - 1);
    } else {
      lastValidStart = const CellOffset(0, 0);
    }

    final newStart = cellOffset.isAfter(lastValidStart) ? lastValidStart : cellOffset;

    if (!newStart.isEqual(normalized.begin)) {
      controller.setSelection(
        terminal.buffer.createAnchorFromOffset(newStart),
        terminal.buffer.createAnchorFromOffset(currentEnd),
        mode: controller.selectionMode,
      );
      HapticFeedback.selectionClick();
    }
  }

  void _handleEndHandleDrag(
    DragUpdateDetails details,
    BufferRange normalized,
  ) {
    final renderBox = terminalViewKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null || renderTerminal == null) return;

    final localPos = renderBox.globalToLocal(details.globalPosition);
    final lineHeight = renderTerminal.lineHeight as double;

    final targetOffset = Offset(localPos.dx, localPos.dy - (lineHeight * 0.5));
    final cellOffset = renderTerminal.getCellOffset(targetOffset) as CellOffset;

    final targetEnd = CellOffset(
      (cellOffset.x + 1).clamp(1, terminal.viewWidth),
      cellOffset.y,
    );

    final minEnd = CellOffset(
      (normalized.begin.x + 1).clamp(1, terminal.viewWidth),
      normalized.begin.y,
    );

    final newEnd = targetEnd.isBefore(minEnd) ? minEnd : targetEnd;

    if (!newEnd.isEqual(normalized.end)) {
      controller.setSelection(
        terminal.buffer.createAnchorFromOffset(normalized.begin),
        terminal.buffer.createAnchorFromOffset(newEnd),
        mode: controller.selectionMode,
      );
      HapticFeedback.selectionClick();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([controller, scrollController]),
      builder: (context, _) {
        final selection = controller.selection?.normalized;
        if (selection == null) return const SizedBox.shrink();
        if (renderTerminal == null) return const SizedBox.shrink();

        final Offset startOffset;
        final Offset endOffset;
        double lineHeight = 16.0;

        try {
          lineHeight = renderTerminal.lineHeight as double;
          startOffset = renderTerminal.getOffset(selection.begin) as Offset;
          endOffset = renderTerminal.getOffset(selection.end) as Offset;
        } catch (_) {
          return const SizedBox.shrink();
        }

        final isStartVisible =
            startOffset.dy + lineHeight >= 0 && startOffset.dy <= canvasHeight;
        final isEndVisible =
            endOffset.dy + lineHeight >= 0 && endOffset.dy <= canvasHeight;
        final isAnyVisible =
            isStartVisible || isEndVisible || (startOffset.dy < 0 && endOffset.dy > canvasHeight);
        if (!isAnyVisible) return const SizedBox.shrink();

        final isStartNearBottom =
            (canvasHeight - (startOffset.dy + lineHeight)) < 32.0;
        final isEndNearBottom =
            (canvasHeight - (endOffset.dy + lineHeight)) < 32.0;

        return Stack(
          children: [
            if (isStartVisible)
              TerminalSelectionHandle(
                handleKey: const Key('terminal_selection_handle_start'),
                position: TerminalHandlePosition.left,
                offset: startOffset,
                lineHeight: lineHeight,
                color: theme.primaryAccent,
                invertStem: isStartNearBottom,
                onDragUpdate: (details) => _handleStartHandleDrag(
                  details,
                  selection,
                ),
              ),
            if (isEndVisible)
              TerminalSelectionHandle(
                handleKey: const Key('terminal_selection_handle_end'),
                position: TerminalHandlePosition.right,
                offset: endOffset,
                lineHeight: lineHeight,
                color: theme.primaryAccent,
                invertStem: isEndNearBottom,
                onDragUpdate: (details) => _handleEndHandleDrag(
                  details,
                  selection,
                ),
              ),
            TerminalSelectionToolbar(
              startOffset: startOffset,
              endOffset: endOffset,
              lineHeight: lineHeight,
              canvasWidth: canvasWidth,
              canvasHeight: canvasHeight,
              isDisconnected: isDisconnected,
              onCopy: () => _copySelection(context),
              onSelectAll: _selectAll,
              theme: theme,
            ),
          ],
        );
      },
    );
  }
}
