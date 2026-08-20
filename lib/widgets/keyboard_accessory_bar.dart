import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../config/app_config.dart';
import '../providers/terminal_settings_store.dart';
import '../theme/app_theme.dart';
import 'customize_accessory_keys_modal.dart';

class KeyboardAccessoryBar extends StatelessWidget {
  final ValueChanged<String> onKeyTap;
  final VoidCallback? onSnippetTap;
  final VoidCallback? onExtendedKeysTap;
  final List<TerminalKeyShortcut>? keys;

  static const List<TerminalKeyShortcut> defaultKeys = AccessoryBarConfig.defaultKeys;

  const KeyboardAccessoryBar({
    super.key,
    required this.onKeyTap,
    this.onSnippetTap,
    this.onExtendedKeysTap,
    this.keys,
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

  void _openExtendedKeysModal(BuildContext context) {
    if (onExtendedKeysTap != null) {
      onExtendedKeysTap!();
      return;
    }
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ExtendedKeysSheet(onKeyTap: onKeyTap),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.appTheme;
    TerminalSettingsStore? settingsStore;
    try {
      settingsStore = Provider.of<TerminalSettingsStore>(context, listen: true);
    } catch (_) {}

    final activeKeys = keys ?? settingsStore?.accessoryKeys ?? defaultKeys;

    return Container(
      height: AccessoryBarConfig.barHeight,
      decoration: BoxDecoration(
        color: theme.surface,
        border: Border(
          top: BorderSide(color: theme.border, width: 1),
        ),
      ),
      child: Row(
        children: [
          // Scrollable keys list (Starts with Tab, ⇧Tab on far left)
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              scrollDirection: Axis.horizontal,
              itemCount: activeKeys.length,
              separatorBuilder: (_, __) => const SizedBox(width: 6),
              itemBuilder: (context, index) => _buildKeyButton(context, activeKeys[index], theme),
            ),
          ),
          // Pinned right action area (Extended Keys & Snippet button)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
            decoration: BoxDecoration(
              border: Border(left: BorderSide(color: theme.border, width: 1)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildExtendedKeysButton(context, theme),
                if (onSnippetTap != null) ...[
                  const SizedBox(width: 6),
                  _buildSnippetIconButton(theme),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKeyButton(BuildContext context, TerminalKeyShortcut key, AppThemeExtension theme) {
    return Material(
      color: theme.cardSurface,
      borderRadius: BorderRadius.circular(6),
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: () {
          _triggerHaptic(context);
          onKeyTap(key.sequence);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 11),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            border: Border.all(color: theme.border, width: 1),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            key.label,
            style: TextStyle(
              color: theme.textPrimary,
              fontSize: 13,
              fontFamily: 'monospace',
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildExtendedKeysButton(BuildContext context, AppThemeExtension theme) {
    return Tooltip(
      message: 'More keys',
      child: Material(
        color: theme.cardSurface,
        borderRadius: BorderRadius.circular(6),
        child: InkWell(
          borderRadius: BorderRadius.circular(6),
          onTap: () => _openExtendedKeysModal(context),
          child: Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              border: Border.all(color: theme.border, width: 1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(
              Icons.keyboard_double_arrow_up_rounded,
              size: 18,
              color: theme.secondaryAccent,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSnippetIconButton(AppThemeExtension theme) {
    return Material(
      color: theme.primaryAccent.withValues(alpha: 0.18),
      borderRadius: BorderRadius.circular(6),
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: onSnippetTap,
        child: Container(
          width: 34,
          height: 34,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            border: Border.all(
              color: theme.primaryAccent.withValues(alpha: 0.6),
              width: 1,
            ),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(
            Icons.bolt_rounded,
            size: 19,
            color: theme.primaryAccent,
          ),
        ),
      ),
    );
  }
}

class ExtendedKeysSheet extends StatelessWidget {
  final ValueChanged<String> onKeyTap;

  const ExtendedKeysSheet({super.key, required this.onKeyTap});

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
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 12, 4),
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
                          icon: Icon(Icons.tune_rounded, color: theme.secondaryAccent, size: 20),
                          tooltip: 'Customize Accessory Keys',
                          onPressed: () {
                            Navigator.of(context).pop();
                            CustomizeAccessoryKeysModal.show(context);
                          },
                        ),
                        IconButton(
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
    return GridView.builder(
      padding: const EdgeInsets.all(14),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 2.1,
      ),
      itemCount: items.length,
      itemBuilder: (ctx, index) {
        final item = items[index];
        return Material(
          color: theme.cardSurface,
          borderRadius: BorderRadius.circular(8),
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () {
              _triggerHaptic(context);
              Navigator.of(context).pop();
              onKeyTap(item.sequence);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                border: Border.all(color: theme.border),
                borderRadius: BorderRadius.circular(8),
              ),
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
            ),
          ),
        );
      },
    );
  }
}
