import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/terminal_settings_store.dart';
import '../theme/app_theme.dart';

class CustomizeAccessoryKeysModal extends StatelessWidget {
  const CustomizeAccessoryKeysModal({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const CustomizeAccessoryKeysModal(),
    );
  }

  void _showAddKeyDialog(BuildContext context) {
    final theme = context.appTheme;
    final store = context.read<TerminalSettingsStore>();
    final labelController = TextEditingController();
    final sequenceController = TextEditingController();
    final descriptionController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    void insertCode(String code) {
      final text = sequenceController.text;
      final sel = sequenceController.selection;
      if (sel.isValid && sel.start >= 0 && sel.end >= 0) {
        final newText = text.replaceRange(sel.start, sel.end, code);
        sequenceController.value = TextEditingValue(
          text: newText,
          selection: TextSelection.collapsed(offset: sel.start + code.length),
        );
      } else {
        sequenceController.text = text + code;
      }
    }

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
            Icon(Icons.add_circle_outline_rounded, color: theme.primaryAccent, size: 22),
            const SizedBox(width: 8),
            Text(
              'Add Custom Key',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: theme.textPrimary,
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Key Label',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: theme.textSecondary,
                  ),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: labelController,
                  autofocus: true,
                  style: TextStyle(color: theme.textPrimary, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'e.g. ^X, sudo, :wq',
                    hintStyle: TextStyle(color: theme.textSecondary.withValues(alpha: 0.6)),
                    filled: true,
                    fillColor: theme.cardSurface,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: theme.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: theme.border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: theme.primaryAccent, width: 1.5),
                    ),
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'Label is required';
                    }
                    if (val.trim().length > 12) {
                      return 'Label is too long (max 12 chars)';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),
                Text(
                  'Sequence / Text',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: theme.textSecondary,
                  ),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: sequenceController,
                  style: TextStyle(
                    color: theme.textPrimary,
                    fontSize: 14,
                    fontFamily: 'monospace',
                  ),
                  decoration: InputDecoration(
                    hintText: r'e.g. \x18, \e, ^C, git status\n',
                    hintStyle: TextStyle(color: theme.textSecondary.withValues(alpha: 0.6)),
                    filled: true,
                    fillColor: theme.cardSurface,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: theme.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: theme.border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: theme.primaryAccent, width: 1.5),
                    ),
                  ),
                  validator: (val) {
                    if (val == null || val.isEmpty) {
                      return 'Key sequence is required';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 10),
                Text(
                  'Quick Insert Escape Codes:',
                  style: TextStyle(
                    fontSize: 11,
                    color: theme.textSecondary,
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    _buildCodeChip(dialogCtx, theme, r'\e', 'Esc', insertCode),
                    _buildCodeChip(dialogCtx, theme, r'\t', 'Tab', insertCode),
                    _buildCodeChip(dialogCtx, theme, r'\n', 'Enter', insertCode),
                    _buildCodeChip(dialogCtx, theme, '^C', 'SIGINT', insertCode),
                    _buildCodeChip(dialogCtx, theme, '^D', 'EOF', insertCode),
                    _buildCodeChip(dialogCtx, theme, '^Z', 'SIGTSTP', insertCode),
                    _buildCodeChip(dialogCtx, theme, '^R', 'Reverse', insertCode),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  'Description (Optional)',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: theme.textSecondary,
                  ),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: descriptionController,
                  style: TextStyle(color: theme.textPrimary, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'e.g. Save and quit editor',
                    hintStyle: TextStyle(color: theme.textSecondary.withValues(alpha: 0.6)),
                    filled: true,
                    fillColor: theme.cardSurface,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: theme.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: theme.border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: theme.primaryAccent, width: 1.5),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: Text('Cancel', style: TextStyle(color: theme.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.primaryAccent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () {
              if (formKey.currentState?.validate() ?? false) {
                store.addCustomAccessoryKey(
                  label: labelController.text,
                  sequence: sequenceController.text,
                  description: descriptionController.text,
                );
                Navigator.of(dialogCtx).pop();
              }
            },
            child: const Text('Add Key', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildCodeChip(
    BuildContext context,
    AppThemeExtension theme,
    String code,
    String label,
    void Function(String) onInsert,
  ) {
    return InkWell(
      borderRadius: BorderRadius.circular(6),
      onTap: () {
        HapticFeedback.selectionClick();
        onInsert(code);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: theme.cardSurface,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: theme.border),
        ),
        child: Text(
          '$code ($label)',
          style: TextStyle(
            fontSize: 11,
            fontFamily: 'monospace',
            fontWeight: FontWeight.w600,
            color: theme.primaryAccent,
          ),
        ),
      ),
    );
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
              'Reset Accessory Keys?',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: theme.textPrimary,
              ),
            ),
          ],
        ),
        content: Text(
          'This will reset your terminal keyboard accessory bar back to the default layout (Tab, Arrows, Esc, ^C, ^D, etc.).',
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

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
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
              padding: const EdgeInsets.fromLTRB(16, 6, 12, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Icon(Icons.tune_rounded, color: theme.secondaryAccent, size: 22),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Customize Accessory Keys',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: theme.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Drag to reorder, toggle, or add custom keys',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: theme.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
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
                      IconButton(
                        icon: const Icon(Icons.close_rounded, size: 20),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Divider(color: theme.border, height: 1),
            // Reorderable list of keys
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                itemCount: keys.length,
                itemBuilder: (ctx, index) {
                  final item = keys[index];
                  return Container(
                    key: ValueKey(item.id),
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
                          IconButton(
                            icon: const Icon(Icons.arrow_upward_rounded, size: 18),
                            tooltip: 'Move up',
                            color: index > 0 ? theme.textPrimary : theme.border,
                            onPressed: index > 0
                                ? () => store.reorderAccessoryKeys(index, index - 1)
                                : null,
                          ),
                          IconButton(
                            icon: const Icon(Icons.arrow_downward_rounded, size: 18),
                            tooltip: 'Move down',
                            color: index < keys.length - 1 ? theme.textPrimary : theme.border,
                            onPressed: index < keys.length - 1
                                ? () => store.reorderAccessoryKeys(index, index + 2)
                                : null,
                          ),
                          if (item.isCustom)
                            IconButton(
                              icon: Icon(Icons.delete_outline_rounded, color: theme.error, size: 20),
                              tooltip: 'Delete custom key',
                              onPressed: () => store.removeAccessoryKey(index),
                            ),
                          Switch(
                            value: item.isEnabled,
                            activeThumbColor: theme.primaryAccent,
                            onChanged: (_) => store.toggleAccessoryKeyVisibility(index),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
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
}
