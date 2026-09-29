import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../config/app_config.dart';
import '../providers/terminal_settings_store.dart';
import '../theme/app_theme.dart';
import '../widgets/accessory_bar/add_custom_key_dialog.dart';
import '../widgets/accessory_bar/tactile_key_button.dart';

class TerminalKeysScreen extends StatelessWidget {
  const TerminalKeysScreen({super.key});

  static Future<void> open(BuildContext context) {
    return Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const TerminalKeysScreen()),
    );
  }

  void _showAddKeyDialog(BuildContext context) {
    AddCustomKeyDialog.show(context);
  }

  void _confirmReset(BuildContext context) {
    final theme = context.appTheme;
    final store = context.read<TerminalSettingsStore>();

    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: theme.surface,
        shape: RoundedRectangleBorder(
          side: BorderSide(color: theme.border),
          borderRadius: BorderRadius.circular(14),
        ),
        title: Row(
          children: [
            Icon(Icons.restore_rounded, color: theme.warning, size: 22),
            const SizedBox(width: 8),
            Text(
              'Reset Terminal Keys?',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: theme.textPrimary,
              ),
            ),
          ],
        ),
        content: Text(
          'This will reset your terminal keys and shortcuts back to the default layout (Tab, Arrows, Esc, ^C, ^D, etc.).',
          style: TextStyle(color: theme.textSecondary, fontSize: 13, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: Text('Cancel', style: TextStyle(color: theme.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.warning,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () {
              store.resetAccessoryKeysToDefault();
              Navigator.of(dialogCtx).pop();
            },
            child: const Text('Reset Layout', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.appTheme;
    final store = context.watch<TerminalSettingsStore>();
    final keys = store.configuredAccessoryKeys;

    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Terminal Keys & Shortcuts'),
          actions: [
            IconButton(
              icon: Icon(Icons.add_rounded, color: theme.primaryAccent, size: 22),
              tooltip: 'Add Custom Key',
              onPressed: () => _showAddKeyDialog(context),
            ),
            IconButton(
              icon: Icon(Icons.restore_rounded, color: theme.textSecondary, size: 20),
              tooltip: 'Reset Defaults',
              onPressed: () => _confirmReset(context),
            ),
            const SizedBox(width: 4),
          ],
          bottom: TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            labelColor: theme.primaryAccent,
            unselectedLabelColor: theme.textSecondary,
            indicatorColor: theme.primaryAccent,
            dividerColor: theme.border,
            tabs: const [
              Tab(text: 'Key Bar Layout'),
              Tab(text: 'Function (F1–F12)'),
              Tab(text: 'Navigation'),
              Tab(text: 'Control Keys'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildKeyBarLayoutTab(context, theme, store, keys),
            _buildPresetGridTab(context, theme, store, AccessoryBarConfig.functionKeys),
            _buildPresetGridTab(context, theme, store, AccessoryBarConfig.navigationKeys),
            _buildPresetGridTab(context, theme, store, AccessoryBarConfig.controlKeys),
          ],
        ),
      ),
    );
  }

  Widget _buildKeyBarLayoutTab(
    BuildContext context,
    AppThemeExtension theme,
    TerminalSettingsStore store,
    List<AccessoryKeyItem> keys,
  ) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'STICKY MODIFIERS',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                  color: theme.primaryAccent,
                ),
              ),
              const SizedBox(height: 6),
              _buildModifierTile(
                theme: theme,
                label: 'Ctrl',
                title: 'Ctrl Sticky Modifier',
                subtitle: 'Tap to latch next key, double-tap to lock (Ctrl+Key)',
                isEnabled: store.ctrlModifierEnabled,
                onChanged: (_) => store.toggleCtrlModifier(),
              ),
              _buildModifierTile(
                theme: theme,
                label: 'Alt',
                title: 'Alt / Meta Sticky Modifier',
                subtitle: 'Tap to prefix next key with ESC, double-tap to lock (Alt+Key)',
                isEnabled: store.altModifierEnabled,
                onChanged: (_) => store.toggleAltModifier(),
              ),
              const SizedBox(height: 8),
              Text(
                'SHORTCUT KEYS & MACROS',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                  color: theme.textSecondary,
                ),
              ),
            ],
          ),
        ),
        // Reorderable list of keys
        Expanded(
          child: ReorderableListView.builder(
            buildDefaultDragHandles: false,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            itemCount: keys.length,
            onReorderItem: (oldIndex, newIndex) {
              store.reorderAccessoryKeys(
                oldIndex,
                oldIndex < newIndex ? newIndex + 1 : newIndex,
              );
            },
            itemBuilder: (ctx, index) {
              final item = keys[index];
              return Semantics(
                key: ValueKey(item.id),
                customSemanticsActions: {
                  if (index > 0)
                    const CustomSemanticsAction(label: 'Move up'): () {
                      store.reorderAccessoryKeys(index, index - 1);
                    },
                  if (index < keys.length - 1)
                    const CustomSemanticsAction(label: 'Move down'): () {
                      store.reorderAccessoryKeys(index, index + 2);
                    },
                },
                child: Container(
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  decoration: BoxDecoration(
                    color: item.isEnabled ? theme.cardSurface : theme.cardSurface.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: item.isEnabled ? theme.border : theme.border.withValues(alpha: 0.4),
                    ),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                    leading: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: item.isEnabled
                            ? theme.primaryAccent.withValues(alpha: 0.15)
                            : theme.surface,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: item.isEnabled
                              ? theme.primaryAccent.withValues(alpha: 0.5)
                              : theme.border,
                        ),
                      ),
                      child: Text(
                        item.label,
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: item.isEnabled ? theme.textPrimary : theme.textSecondary,
                        ),
                      ),
                    ),
                    title: Text(
                      item.description ?? (item.isCustom ? 'Custom Macro' : 'Default Shortcut'),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: item.isEnabled ? theme.textPrimary : theme.textSecondary,
                      ),
                    ),
                    subtitle: Text(
                      _formatSequencePreview(item.sequence),
                      style: TextStyle(
                        fontSize: 11,
                        fontFamily: 'monospace',
                        color: theme.textSecondary,
                      ),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (item.isCustom)
                          IconButton(
                            constraints: const BoxConstraints(
                              minWidth: AppTouchTarget.min,
                              minHeight: AppTouchTarget.min,
                            ),
                            icon: Icon(Icons.delete_outline_rounded, color: theme.error, size: 20),
                            tooltip: 'Delete custom key',
                            onPressed: () => store.removeAccessoryKey(index),
                          ),
                        Switch(
                          value: item.isEnabled,
                          activeThumbColor: theme.primaryAccent,
                          onChanged: (_) => store.toggleAccessoryKeyVisibility(index),
                        ),
                        ReorderableDragStartListener(
                          index: index,
                          child: Container(
                            constraints: const BoxConstraints(
                              minWidth: AppTouchTarget.min,
                              minHeight: AppTouchTarget.min,
                            ),
                            alignment: Alignment.center,
                            child: Icon(
                              Icons.drag_handle_rounded,
                              color: theme.textSecondary,
                              size: 22,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildPresetGridTab(
    BuildContext context,
    AppThemeExtension theme,
    TerminalSettingsStore store,
    List<TerminalKeyShortcut> items,
  ) {
    final textScale = MediaQuery.textScalerOf(context).scale(1.0);
    final childAspectRatio = (2.2 / textScale).clamp(1.1, 2.2);

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
        final isOnBar = store.configuredAccessoryKeys.any((k) => k.sequence == item.sequence && k.isEnabled);

        return TactileKeyButton(
          theme: theme,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          backgroundColor: isOnBar ? theme.primaryAccent.withValues(alpha: 0.12) : theme.cardSurface,
          customBorder: Border.all(
            color: isOnBar ? theme.primaryAccent.withValues(alpha: 0.6) : theme.border,
            width: isOnBar ? 1.5 : 1,
          ),
          onTap: () {
            if (store.hapticFeedbackEnabled) {
              HapticFeedback.lightImpact();
            }
            final existingIndex = store.configuredAccessoryKeys.indexWhere((k) => k.sequence == item.sequence);
            if (existingIndex >= 0) {
              final existingItem = store.configuredAccessoryKeys[existingIndex];
              store.toggleAccessoryKeyVisibility(existingIndex);
              final newState = !existingItem.isEnabled;
              ScaffoldMessenger.maybeOf(context)?.showSnackBar(
                SnackBar(
                  content: Text(newState ? 'Enabled "${item.label}" on key bar' : 'Disabled "${item.label}" from key bar'),
                  duration: const Duration(seconds: 1),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            } else {
              store.addCustomAccessoryKey(
                label: item.label,
                sequence: item.sequence,
                description: item.description,
              );
              ScaffoldMessenger.maybeOf(context)?.showSnackBar(
                SnackBar(
                  content: Text('Added "${item.label}" to key bar'),
                  duration: const Duration(seconds: 1),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            }
          },
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    item.label,
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: isOnBar ? theme.primaryAccent : theme.textPrimary,
                    ),
                  ),
                  if (isOnBar) ...[
                    const SizedBox(width: 4),
                    Icon(Icons.check_circle_rounded, size: 12, color: theme.primaryAccent),
                  ],
                ],
              ),
              if (item.description != null) ...[
                const SizedBox(height: 2),
                Text(
                  item.description!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 10,
                    color: isOnBar ? theme.textPrimary : theme.textSecondary,
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  String _formatSequencePreview(String seq) {
    if (seq == '\t') return 'Code: Tab (\\t)';
    if (seq == '\n') return 'Code: Enter (\\n)';
    if (seq == '\x1B') return 'Code: Esc (\\x1B)';
    if (seq == '\x1B[Z') return 'Code: Shift-Tab (\\x1B[Z)';
    if (seq == '\x1B[A') return 'Code: Up Arrow (\\x1B[A)';
    if (seq == '\x1B[B') return 'Code: Down Arrow (\\x1B[B)';
    if (seq == '\x1B[D') return 'Code: Left Arrow (\\x1B[D)';
    if (seq == '\x1B[C') return 'Code: Right Arrow (\\x1B[C)';
    if (seq.startsWith('\x1B')) return 'Code: Escape sequence (${seq.length} bytes)';
    if (seq.length == 1 && seq.codeUnitAt(0) < 32) {
      return 'Code: Ctrl+${String.fromCharCode(64 + seq.codeUnitAt(0))}';
    }
    return 'Text: "$seq"';
  }

  Widget _buildModifierTile({
    required AppThemeExtension theme,
    required String label,
    required String title,
    required String subtitle,
    required bool isEnabled,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 3),
      decoration: BoxDecoration(
        color: isEnabled ? theme.cardSurface : theme.cardSurface.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isEnabled ? theme.border : theme.border.withValues(alpha: 0.4),
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        leading: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: isEnabled
                ? theme.primaryAccent.withValues(alpha: 0.15)
                : theme.surface,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: isEnabled
                  ? theme.primaryAccent.withValues(alpha: 0.5)
                  : theme.border,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontFamily: 'monospace',
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: isEnabled ? theme.textPrimary : theme.textSecondary,
            ),
          ),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: isEnabled ? theme.textPrimary : theme.textSecondary,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(
            fontSize: 11,
            color: theme.textSecondary,
          ),
        ),
        trailing: Switch(
          value: isEnabled,
          activeThumbColor: theme.primaryAccent,
          onChanged: onChanged,
        ),
      ),
    );
  }
}
