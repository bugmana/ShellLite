import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// Position of the selection marker handle.
enum TerminalHandlePosition { left, right }

/// Vertical line marker with a draggable knob for terminal text selection,
/// replicating the native highlight and selection handle experience on iOS and Android.
class TerminalSelectionHandle extends StatefulWidget {
  final ScrollController? scrollController;
  final Key? handleKey;
  final TerminalHandlePosition position;
  final Offset offset;
  final double lineHeight;
  final Color color;
  final void Function(DragUpdateDetails) onDragUpdate;
  final VoidCallback? onDragStart;
  final VoidCallback? onDragEnd;
  final bool invertStem;

  const TerminalSelectionHandle({
    super.key,
    this.handleKey,
    this.scrollController,
    required this.position,
    required this.offset,
    required this.lineHeight,
    required this.color,
    required this.onDragUpdate,
    this.onDragStart,
    this.onDragEnd,
    this.invertStem = false,
  });

  @override
  State<TerminalSelectionHandle> createState() =>
      _TerminalSelectionHandleState();
}

class _TerminalSelectionHandleState extends State<TerminalSelectionHandle> {
  Offset? _grabOffset;
  DragUpdateDetails? _lastDrag;
  Timer? _timer;

  void _stop() {
    _timer?.cancel();
    _timer = null;
    _grabOffset = null;
    _lastDrag = null;
  }

  void _update(DragUpdateDetails details) {
    _lastDrag = details;
    widget.onDragUpdate(DragUpdateDetails(
      globalPosition: details.globalPosition - (_grabOffset ?? Offset.zero),
      delta: details.delta,
    ));
  }

  @override
  void dispose() {
    _stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const lineWidth = 3.0;
    const knobDiameter = 14.0;
    const touchWidth = 44.0;
    final touchHeight = widget.lineHeight + knobDiameter + 16.0;

    // For the start (left) handle, the vertical line is anchored at x = 28 so
    // the touch target extends primarily to the left, preventing overlap when
    // selection is narrow. For the right handle, it extends to the right.
    final isStart = widget.position == TerminalHandlePosition.left;
    final lineLocalX = isStart ? 28.0 : 16.0;
    final leftPos = widget.offset.dx - lineLocalX;
    final topPos = widget.invertStem
        ? (widget.offset.dy - knobDiameter)
        : widget.offset.dy;

    return Positioned(
      key: widget.handleKey,
      left: leftPos,
      top: topPos,
      width: touchWidth,
      height: touchHeight,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanStart: (details) {
          final box = context.findRenderObject() as RenderBox;
          final anchor = box.localToGlobal(
              Offset(lineLocalX, widget.invertStem ? knobDiameter : 0));
          _grabOffset = details.globalPosition -
              anchor -
              Offset(0, widget.lineHeight * 0.5);
          widget.onDragStart?.call();
          _timer = Timer.periodic(const Duration(milliseconds: 40), (_) {
            final scroll = widget.scrollController;
            final drag = _lastDrag;
            if (scroll == null || !scroll.hasClients || drag == null) return;
            // The handles share the terminal canvas rather than its scrollable.
            final parent =
                context.findAncestorRenderObjectOfType<RenderStack>();
            if (parent == null) return;
            final local = parent.globalToLocal(drag.globalPosition);
            final direction = local.dy < 32
                ? -1
                : local.dy > parent.size.height - 32
                    ? 1
                    : 0;
            if (direction == 0) return;
            scroll.jumpTo((scroll.offset + direction * widget.lineHeight).clamp(
                scroll.position.minScrollExtent,
                scroll.position.maxScrollExtent));
            _update(drag);
          });
        },
        onPanUpdate: _update,
        onPanEnd: (_) {
          _stop();
          widget.onDragEnd?.call();
        },
        onPanCancel: _stop,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // Vertical line marker along the height of the line
            Positioned(
              left: lineLocalX - (lineWidth / 2),
              top: widget.invertStem ? knobDiameter : 0,
              width: lineWidth,
              height: widget.lineHeight,
              child: Container(
                decoration: BoxDecoration(
                  color: widget.color,
                  borderRadius: BorderRadius.circular(lineWidth / 2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.5),
                      blurRadius: 3,
                      spreadRadius: 0.5,
                    ),
                  ],
                ),
              ),
            ),
            // Circular touch handle knob (inverts to top if near bottom edge)
            Positioned(
              left: lineLocalX - (knobDiameter / 2),
              top: widget.invertStem ? 0 : (widget.lineHeight - 2),
              width: knobDiameter,
              height: knobDiameter,
              child: Container(
                decoration: BoxDecoration(
                  color: widget.color,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.35),
                    width: 1.0,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.5),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
