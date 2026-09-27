import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

enum ModifierState { inactive, latched, locked }

/// Sticky modifier key button (Ctrl / Alt) with inactive, latched, and locked states.
class StickyModifierKey extends StatefulWidget {
  final String label;
  final ModifierState state;
  final VoidCallback onTap;
  final VoidCallback onDoubleTap;
  final AppThemeExtension theme;

  const StickyModifierKey({
    super.key,
    required this.label,
    required this.state,
    required this.onTap,
    required this.onDoubleTap,
    required this.theme,
  });

  @override
  State<StickyModifierKey> createState() => _StickyModifierKeyState();
}

class _StickyModifierKeyState extends State<StickyModifierKey> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final disableAnimations = MediaQuery.disableAnimationsOf(context);
    final theme = widget.theme;
    final state = widget.state;
    final activeBg = state == ModifierState.locked
        ? theme.primaryAccent
        : theme.primaryAccent.withValues(alpha: 0.22);
    final activeFg = state == ModifierState.locked
        ? AppTheme.computeOnPrimary(theme.primaryAccent)
        : theme.primaryAccent;

    return Semantics(
      toggled: state != ModifierState.inactive,
      label: '${widget.label} modifier, ${state.name}',
      hint: 'Tap to latch, double tap to lock',
      child: AnimatedScale(
        scale: disableAnimations || !_isPressed ? 1.0 : 0.94,
        duration: const Duration(milliseconds: 60),
        curve: Curves.easeOutCubic,
        child: GestureDetector(
          onTapDown: (_) => setState(() => _isPressed = true),
          onTapUp: (_) => setState(() => _isPressed = false),
          onTapCancel: () => setState(() => _isPressed = false),
          onTap: widget.onTap,
          onDoubleTap: widget.onDoubleTap,
          child: Container(
            constraints: const BoxConstraints(minWidth: AppTouchTarget.min, minHeight: AppTouchTarget.min),
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: state != ModifierState.inactive
                  ? activeBg
                  : (_isPressed ? theme.primaryAccent.withValues(alpha: 0.18) : theme.cardSurface),
              borderRadius: BorderRadius.circular(AppRadius.sm),
              border: Border.all(
                color: state != ModifierState.inactive
                    ? theme.primaryAccent
                    : (_isPressed ? theme.primaryAccent : theme.border),
                width: state == ModifierState.locked ? 2.0 : 1.0,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.label,
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: state != ModifierState.inactive ? activeFg : theme.textPrimary,
                  ),
                ),
                if (state == ModifierState.locked) ...[
                  const SizedBox(width: AppSpacing.xxs),
                  Icon(Icons.lock_rounded, size: 10, color: activeFg),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
