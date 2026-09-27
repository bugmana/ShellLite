import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

/// Tactile key button with micro-depression scale animation and haptic styling.
class TactileKeyButton extends StatefulWidget {
  final VoidCallback onTap;
  final Widget child;
  final BoxConstraints? constraints;
  final EdgeInsetsGeometry? padding;
  final AlignmentGeometry? alignment;
  final bool isInterrupt;
  final AppThemeExtension theme;
  final Color? backgroundColor;
  final Border? customBorder;

  const TactileKeyButton({
    super.key,
    required this.onTap,
    required this.child,
    required this.theme,
    this.constraints,
    this.padding,
    this.alignment,
    this.isInterrupt = false,
    this.backgroundColor,
    this.customBorder,
  });

  @override
  State<TactileKeyButton> createState() => _TactileKeyButtonState();
}

class _TactileKeyButtonState extends State<TactileKeyButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final disableAnimations = MediaQuery.disableAnimationsOf(context);
    final theme = widget.theme;

    return AnimatedScale(
      scale: disableAnimations || !_isPressed ? 1.0 : 0.94,
      duration: const Duration(milliseconds: 60),
      curve: Curves.easeOutCubic,
      child: Material(
        color: _isPressed
            ? theme.primaryAccent.withValues(alpha: 0.18)
            : (widget.backgroundColor ?? theme.cardSurface),
        borderRadius: BorderRadius.circular(AppRadius.sm),
        child: InkWell(
          canRequestFocus: false,
          borderRadius: BorderRadius.circular(AppRadius.sm),
          onTapDown: (_) => setState(() => _isPressed = true),
          onTapUp: (_) => setState(() => _isPressed = false),
          onTapCancel: () => setState(() => _isPressed = false),
          onTap: widget.onTap,
          child: Container(
            constraints: widget.constraints ??
                const BoxConstraints(
                  minWidth: AppTouchTarget.min,
                  minHeight: AppTouchTarget.min,
                ),
            padding: widget.padding ?? const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            alignment: widget.alignment ?? Alignment.center,
            decoration: BoxDecoration(
              border: widget.customBorder ??
                  Border.all(
                    color: widget.isInterrupt
                        ? theme.error.withValues(alpha: 0.5)
                        : (_isPressed ? theme.primaryAccent : theme.border),
                    width: 1,
                  ),
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: widget.child,
          ),
        ),
      ),
    );
  }
}
