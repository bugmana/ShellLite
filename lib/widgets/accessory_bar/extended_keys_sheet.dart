import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../config/app_config.dart';
import '../../providers/terminal_settings_store.dart';
import '../../theme/app_theme.dart';
import '../customize_accessory_keys_modal.dart';
import 'tactile_key_button.dart';

/// Modal bottom sheet alternative for extended accessory keys.
class ExtendedKeysSheet extends StatelessWidget {
  final ValueChanged<String> onKeyTap;
  final bool autoDismiss;

  const ExtendedKeysSheet({
    super.key,
    required this.onKeyTap,
    this.autoDismiss = false,
  });

  void _triggerHaptic(BuildContext context) {
    try {
      final store = Provider.of<TerminalSettingsStore>(context, listen: false);
      if (store.hapticFeedbackEnabled) {
        HapticFeedback.lightImpact();
      }
    } catch (_) {
      HapticFeedback.lightImpact();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.appTheme;

    return DefaultTabController(
      length: 3,
      child: Container(
        height: MediaQuery.of(context).size.height * 0.55,
        decoration: BoxDecoration(
          color: theme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
          border: Border.all(color: theme.border),
        ),
        child: SafeArea(
          child: Column(
            children: [
              const SheetDragHandle(),
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 12, 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.keyboard_double_arrow_up_rounded, color: theme.secondaryAccent, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'Extended Keys & Shortcuts',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: theme.textPrimary,
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        IconButton(
                          constraints: const BoxConstraints(minWidth: AppTouchTarget.min, minHeight: AppTouchTarget.min),
                          icon: Icon(Icons.tune_rounded, color: theme.secondaryAccent, size: 20),
                          tooltip: 'Customize Accessory Keys',
                          onPressed: () {
                            Navigator.of(context).pop();
                            CustomizeAccessoryKeysModal.show(context);
                          },
                        ),
                        IconButton(
                          constraints: const BoxConstraints(minWidth: AppTouchTarget.min, minHeight: AppTouchTarget.min),
                          icon: const Icon(Icons.close_rounded, size: 20),
                          onPressed: () => Navigator.of(context).pop(),
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
                tabs: const [
                  Tab(text: 'Control Keys'),
                  Tab(text: 'Navigation'),
                  Tab(text: 'Function (F1-F12)'),
                ],
              ),
              Expanded(
                child: TabBarView(
                  children: [
                    _buildGrid(context, AccessoryBarConfig.controlKeys, theme),
                    _buildGrid(context, AccessoryBarConfig.navigationKeys, theme),
                    _buildGrid(context, AccessoryBarConfig.functionKeys, theme),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGrid(BuildContext context, List<TerminalKeyShortcut> items, AppThemeExtension theme) {
    final textScale = MediaQuery.textScalerOf(context).scale(1.0);
    final childAspectRatio = (2.1 / textScale).clamp(1.1, 2.1);

    return GridView.builder(
      padding: const EdgeInsets.all(14),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: childAspectRatio,
      ),
      itemCount: items.length,
      itemBuilder: (ctx, index) {
        final item = items[index];
        return TactileKeyButton(
          theme: theme,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          onTap: () {
            _triggerHaptic(context);
            if (autoDismiss) {
              Navigator.of(ctx).pop();
            }
            onKeyTap(item.sequence);
          },
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                item.label,
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: theme.textPrimary,
                ),
              ),
              if (item.description != null) ...[
                const SizedBox(height: 2),
                Text(
                  item.description!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10,
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
