import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

/// Floating callout toolbar [Copy | Select All] positioned near text selection.
class TerminalSelectionToolbar extends StatelessWidget {
  final Offset startOffset;
  final Offset endOffset;
  final double lineHeight;
  final double canvasWidth;
  final double canvasHeight;
  final bool isDisconnected;
  final VoidCallback? onOpenLink;
  final VoidCallback onCopy;
  final VoidCallback onSelectAll;
  final AppThemeExtension theme;

  const TerminalSelectionToolbar({
    super.key,
    required this.startOffset,
    required this.endOffset,
    required this.lineHeight,
    required this.canvasWidth,
    required this.canvasHeight,
    required this.isDisconnected,
    this.onOpenLink,
    required this.onCopy,
    required this.onSelectAll,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    const toolbarHeight = 48.0;
    final estimatedWidth =
        math.min(canvasWidth - 16, onOpenLink == null ? 220.0 : 340.0);

    final isSingleLine =
        (endOffset.dy - startOffset.dy).abs() < lineHeight * 1.5;
    final centerX =
        isSingleLine ? (startOffset.dx + endOffset.dx) / 2 : startOffset.dx;
    final left = (centerX - (estimatedWidth / 2))
        .clamp(
          AppSpacing.sm,
          math.max(AppSpacing.sm, canvasWidth - estimatedWidth - AppSpacing.sm),
        )
        .toDouble();

    final topBoundary = (isDisconnected ? 48.0 : 0.0) + 8.0;
    final preferredTop = startOffset.dy - toolbarHeight - 10.0;
    final top = (preferredTop >= topBoundary
            ? preferredTop
            : (endOffset.dy + lineHeight + 10.0).clamp(
                topBoundary,
                math.max(topBoundary, canvasHeight - toolbarHeight - 8.0),
              ))
        .toDouble();

    return Positioned(
      left: left,
      top: top,
      child: Material(
        color: Colors.transparent,
        child: Container(
          height: toolbarHeight,
          width: estimatedWidth,
          decoration: BoxDecoration(
            color: theme.cardSurface,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: theme.border, width: 1.0),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.4),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.md),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (onOpenLink != null)
                    TextButton(
                        onPressed: onOpenLink, child: const Text('Open link')),
                  InkWell(
                    key: const Key('terminal_selection_copy_button'),
                    onTap: onCopy,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.copy_rounded,
                              size: 15, color: theme.primaryAccent),
                          const SizedBox(width: 6),
                          Text(
                            onOpenLink == null ? 'Copy' : 'Copy link',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: theme.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Container(
                    width: 1,
                    height: 18,
                    color: theme.border,
                  ),
                  InkWell(
                    key: const Key('terminal_selection_select_all_button'),
                    onTap: onSelectAll,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.select_all_rounded,
                              size: 16, color: theme.textSecondary),
                          const SizedBox(width: 6),
                          Text(
                            'Select All',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: theme.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
