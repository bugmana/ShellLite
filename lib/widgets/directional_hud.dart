import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';

enum HUDDirection {
  none,
  up,
  down,
  left,
  right,
}

/// Floating on-screen D-Pad / Directional Joystick overlay activated on press-and-hold.
/// - Up: Smooth scroll / History Up (\x1B[A)
/// - Down: Smooth scroll / History Down (\x1B[B)
/// - Right: Auto-fill command with Tab (\t)
/// - Left: Move cursor Left (\x1B[D)
class DirectionalHUDOverlay extends StatefulWidget {
  final Widget child;
  final ValueChanged<String> onAction;

  const DirectionalHUDOverlay({
    super.key,
    required this.child,
    required this.onAction,
  });

  @override
  State<DirectionalHUDOverlay> createState() => _DirectionalHUDOverlayState();
}

class _DirectionalHUDOverlayState extends State<DirectionalHUDOverlay> {
  Offset? _touchOrigin;
  Offset _dragOffset = Offset.zero;
  HUDDirection _activeDirection = HUDDirection.none;
  Timer? _repeatTimer;

  static const double _hudSize = 170.0;
  static const double _deadzone = 14.0;
  static const double _maxRadius = 55.0;

  void _onLongPressStart(LongPressStartDetails details) {
    HapticFeedback.mediumImpact();
    setState(() {
      _touchOrigin = details.localPosition;
      _dragOffset = Offset.zero;
      _activeDirection = HUDDirection.none;
    });
  }

  void _onLongPressMoveUpdate(LongPressMoveUpdateDetails details) {
    if (_touchOrigin == null) return;

    final rawDelta = details.localPosition - _touchOrigin!;
    final distance = rawDelta.distance;
    final clampedDistance = math.min(distance, _maxRadius);
    final directionVector = distance > 0 ? rawDelta / distance : Offset.zero;
    final clampedOffset = directionVector * clampedDistance;

    HUDDirection newDirection = HUDDirection.none;
    if (distance >= _deadzone) {
      if (rawDelta.dy.abs() > rawDelta.dx.abs()) {
        newDirection = rawDelta.dy < 0 ? HUDDirection.up : HUDDirection.down;
      } else {
        newDirection = rawDelta.dx > 0 ? HUDDirection.right : HUDDirection.left;
      }
    }

    if (newDirection != _activeDirection) {
      _onDirectionChanged(newDirection);
    }

    setState(() {
      _dragOffset = clampedOffset;
      _activeDirection = newDirection;
    });
  }

  void _onDirectionChanged(HUDDirection direction) {
    _repeatTimer?.cancel();
    _repeatTimer = null;

    if (direction == HUDDirection.none) return;

    HapticFeedback.selectionClick();
    _executeDirection(direction);

    // Smooth repetition intervals
    Duration initialDelay;
    Duration interval;

    switch (direction) {
      case HUDDirection.up:
      case HUDDirection.down:
        initialDelay = const Duration(milliseconds: 220);
        interval = const Duration(milliseconds: 100);
        break;
      case HUDDirection.left:
        initialDelay = const Duration(milliseconds: 220);
        interval = const Duration(milliseconds: 100);
        break;
      case HUDDirection.right:
        initialDelay = const Duration(milliseconds: 380);
        interval = const Duration(milliseconds: 300);
        break;
      case HUDDirection.none:
        return;
    }

    _repeatTimer = Timer(initialDelay, () {
      _repeatTimer = Timer.periodic(interval, (_) {
        if (_activeDirection == direction) {
          _executeDirection(direction);
        }
      });
    });
  }

  void _executeDirection(HUDDirection direction) {
    switch (direction) {
      case HUDDirection.up:
        widget.onAction('\x1B[A');
        break;
      case HUDDirection.down:
        widget.onAction('\x1B[B');
        break;
      case HUDDirection.right:
        widget.onAction('\t');
        break;
      case HUDDirection.left:
        widget.onAction('\x1B[D');
        break;
      case HUDDirection.none:
        break;
    }
  }

  void _onLongPressEnd([LongPressEndDetails? _]) {
    _repeatTimer?.cancel();
    _repeatTimer = null;
    setState(() {
      _touchOrigin = null;
      _dragOffset = Offset.zero;
      _activeDirection = HUDDirection.none;
    });
  }

  @override
  void dispose() {
    _repeatTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return GestureDetector(
          behavior: HitTestBehavior.translucent,
          onLongPressStart: _onLongPressStart,
          onLongPressMoveUpdate: _onLongPressMoveUpdate,
          onLongPressEnd: _onLongPressEnd,
          onLongPressCancel: _onLongPressEnd,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              widget.child,
              if (_touchOrigin != null) _buildHUD(constraints),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHUD(BoxConstraints constraints) {
    final double left = (_touchOrigin!.dx - _hudSize / 2).clamp(
      8.0,
      constraints.maxWidth - _hudSize - 8.0,
    );
    final double top = (_touchOrigin!.dy - _hudSize / 2).clamp(
      8.0,
      constraints.maxHeight - _hudSize - 8.0,
    );

    return Positioned(
      left: left,
      top: top,
      width: _hudSize,
      height: _hudSize,
      child: IgnorePointer(
        child: AnimatedOpacity(
          opacity: _touchOrigin != null ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 150),
          child: Container(
            decoration: BoxDecoration(
              color: AppTheme.cardSurface.withOpacity(0.92),
              shape: BoxShape.circle,
              border: Border.all(
                color: _activeDirection != HUDDirection.none
                    ? AppTheme.terminalGreen.withOpacity(0.8)
                    : AppTheme.border,
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.55),
                  blurRadius: 18,
                  spreadRadius: 2,
                ),
                if (_activeDirection != HUDDirection.none)
                  BoxShadow(
                    color: AppTheme.terminalGreen.withOpacity(0.25),
                    blurRadius: 12,
                    spreadRadius: 1,
                  ),
              ],
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Top: Up Arrow
                Positioned(
                  top: 8,
                  child: _buildDirectionItem(
                    icon: Icons.arrow_upward_rounded,
                    label: 'Up',
                    isActive: _activeDirection == HUDDirection.up,
                  ),
                ),
                // Bottom: Down Arrow
                Positioned(
                  bottom: 8,
                  child: _buildDirectionItem(
                    icon: Icons.arrow_downward_rounded,
                    label: 'Down',
                    isActive: _activeDirection == HUDDirection.down,
                  ),
                ),
                // Right: Tab
                Positioned(
                  right: 8,
                  child: _buildDirectionItem(
                    icon: Icons.keyboard_tab_rounded,
                    label: 'Tab',
                    isActive: _activeDirection == HUDDirection.right,
                  ),
                ),
                // Left: Left Arrow
                Positioned(
                  left: 8,
                  child: _buildDirectionItem(
                    icon: Icons.arrow_back_rounded,
                    label: 'Left',
                    isActive: _activeDirection == HUDDirection.left,
                  ),
                ),
                // Center Thumb Indicator
                Transform.translate(
                  offset: _dragOffset,
                  child: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _activeDirection != HUDDirection.none
                          ? AppTheme.terminalGreen
                          : AppTheme.surface,
                      border: Border.all(
                        color: _activeDirection != HUDDirection.none
                            ? Colors.white
                            : AppTheme.border,
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.3),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                    child: Icon(
                      _activeDirection == HUDDirection.none
                          ? Icons.drag_indicator_rounded
                          : _getDirectionIcon(_activeDirection),
                      color: _activeDirection != HUDDirection.none
                          ? Colors.black
                          : AppTheme.textSecondary,
                      size: 18,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  IconData _getDirectionIcon(HUDDirection dir) {
    switch (dir) {
      case HUDDirection.up:
        return Icons.arrow_upward_rounded;
      case HUDDirection.down:
        return Icons.arrow_downward_rounded;
      case HUDDirection.left:
        return Icons.arrow_back_rounded;
      case HUDDirection.right:
        return Icons.keyboard_tab_rounded;
      case HUDDirection.none:
        return Icons.drag_indicator_rounded;
    }
  }

  Widget _buildDirectionItem({
    required IconData icon,
    required String label,
    required bool isActive,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: isActive ? AppTheme.terminalGreen.withOpacity(0.2) : Colors.transparent,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 18,
            color: isActive ? AppTheme.terminalGreen : AppTheme.textSecondary,
          ),
          const SizedBox(height: 1),
          Text(
            label,
            style: TextStyle(
              fontSize: 9,
              fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
              color: isActive ? AppTheme.terminalGreen : AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
