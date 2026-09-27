import 'package:flutter/material.dart';
import '../../config/app_config.dart';
import '../../theme/app_theme.dart';
import 'tactile_key_button.dart';

/// Inline non-dismissing accordion keypad drawer for keyboard accessory bar.
class KeypadDrawer extends StatefulWidget {
  final ValueChanged<String> onKeyTap;
  final bool isKeyboardVisible;
  final VoidCallback onClose;
  final VoidCallback onCustomize;
  final VoidCallback? onTriggerHaptic;
  final AppThemeExtension theme;

  const KeypadDrawer({
    super.key,
    required this.onKeyTap,
    required this.isKeyboardVisible,
    required this.onClose,
    required this.onCustomize,
    this.onTriggerHaptic,
    required this.theme,
  });

  @override
  State<KeypadDrawer> createState() => _KeypadDrawerState();
}

class _KeypadDrawerState extends State<KeypadDrawer> {
  bool? _userDrawerExpanded;

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;
    final textScale = MediaQuery.textScalerOf(context).scale(1.0);
    final isExpanded = _userDrawerExpanded ?? !widget.isKeyboardVisible;
    final baseHeight = isExpanded ? 280.0 : 180.0;
    final minH = isExpanded ? 260.0 : 168.0;
    final maxH = isExpanded ? 340.0 : 220.0;
    final drawerHeight = (baseHeight * textScale.clamp(1.0, 1.35)).clamp(minH, maxH);

    return DefaultTabController(
      length: 3,
      child: Container(
        height: drawerHeight,
        decoration: BoxDecoration(
          color: theme.surface,
          border: Border(
            top: BorderSide(color: theme.border, width: 1),
            bottom: BorderSide(color: theme.border, width: 1),
          ),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 2, 4, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.keyboard_double_arrow_up_rounded, color: theme.secondaryAccent, size: 18),
                      const SizedBox(width: 6),
                      Text(
                        'Extended Keys',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: theme.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        constraints: const BoxConstraints(
                          minWidth: AppTouchTarget.min,
                          minHeight: AppTouchTarget.min,
                        ),
                        icon: Icon(
                          isExpanded ? Icons.unfold_less_rounded : Icons.unfold_more_rounded,
                          color: theme.secondaryAccent,
                          size: 20,
                        ),
                        tooltip: isExpanded ? 'Compact drawer' : 'Expand drawer',
                        onPressed: () {
                          widget.onTriggerHaptic?.call();
                          setState(() {
                            _userDrawerExpanded = !isExpanded;
                          });
                        },
                      ),
                      IconButton(
                        constraints: const BoxConstraints(
                          minWidth: AppTouchTarget.min,
                          minHeight: AppTouchTarget.min,
                        ),
                        icon: Icon(Icons.tune_rounded, color: theme.secondaryAccent, size: 18),
                        tooltip: 'Customize Accessory Keys',
                        onPressed: widget.onCustomize,
                      ),
                      IconButton(
                        constraints: const BoxConstraints(
                          minWidth: AppTouchTarget.min,
                          minHeight: AppTouchTarget.min,
                        ),
                        icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 22),
                        tooltip: 'Collapse keys',
                        onPressed: () {
                          widget.onTriggerHaptic?.call();
                          setState(() {
                            _userDrawerExpanded = null;
                          });
                          widget.onClose();
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
            TabBar(
              labelColor: theme.primaryAccent,
              unselectedLabelColor: theme.textSecondary,
              indicatorColor: theme.primaryAccent,
              labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              unselectedLabelStyle: const TextStyle(fontSize: 12),
              tabs: const [
                Tab(text: 'Control Keys'),
                Tab(text: 'Navigation'),
                Tab(text: 'Function (F1-F12)'),
              ],
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _buildDrawerGrid(context, AccessoryBarConfig.controlKeys, theme),
                  _buildDrawerGrid(context, AccessoryBarConfig.navigationKeys, theme),
                  _buildDrawerGrid(context, AccessoryBarConfig.functionKeys, theme),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawerGrid(BuildContext context, List<TerminalKeyShortcut> items, AppThemeExtension theme) {
    final textScale = MediaQuery.textScalerOf(context).scale(1.0);
    final childAspectRatio = (2.2 / textScale).clamp(1.1, 2.4);

    return GridView.builder(
      padding: const EdgeInsets.all(8),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: childAspectRatio,
      ),
      itemCount: items.length,
      itemBuilder: (ctx, index) {
        final item = items[index];
        return TactileKeyButton(
          theme: theme,
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          onTap: () {
            widget.onTriggerHaptic?.call();
            widget.onKeyTap(item.sequence);
          },
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                item.label,
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: theme.textPrimary,
                ),
              ),
              if (item.description != null) ...[
                const SizedBox(height: 1),
                Text(
                  item.description!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 9.5,
                    color: theme.textSecondary,
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
