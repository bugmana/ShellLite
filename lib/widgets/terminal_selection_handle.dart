import 'package:flutter/material.dart';

/// Position of the selection marker handle.
enum TerminalHandlePosition { left, right }

/// Vertical line marker with a draggable knob for terminal text selection,
/// replicating the native highlight and selection handle experience on iOS and Android.
class TerminalSelectionHandle extends StatelessWidget {
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
  Widget build(BuildContext context) {
    const lineWidth = 3.0;
    const knobDiameter = 14.0;
    const touchWidth = 44.0;
    final touchHeight = lineHeight + knobDiameter + 16.0;

    // For the start (left) handle, the vertical line is anchored at x = 28 so
    // the touch target extends primarily to the left, preventing overlap when
    // selection is narrow. For the right handle, it extends to the right.
    final isStart = position == TerminalHandlePosition.left;
    final lineLocalX = isStart ? 28.0 : 16.0;
    final leftPos = offset.dx - lineLocalX;
    final topPos = invertStem ? (offset.dy - knobDiameter) : offset.dy;

    return Positioned(
      key: handleKey,
      left: leftPos,
      top: topPos,
      width: touchWidth,
      height: touchHeight,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanStart: (_) => onDragStart?.call(),
        onPanUpdate: onDragUpdate,
        onPanEnd: (_) => onDragEnd?.call(),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // Vertical line marker along the height of the line
            Positioned(
              left: lineLocalX - (lineWidth / 2),
              top: invertStem ? knobDiameter : 0,
              width: lineWidth,
              height: lineHeight,
              child: Container(
                decoration: BoxDecoration(
                  color: color,
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
              top: invertStem ? 0 : (lineHeight - 2),
              width: knobDiameter,
              height: knobDiameter,
              child: Container(
                decoration: BoxDecoration(
                  color: color,
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
