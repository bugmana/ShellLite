import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../config/app_config.dart';
import '../../providers/terminal_settings_store.dart';
import '../../theme/app_theme.dart';

/// Dialog for adding a custom accessory key.
class AddCustomKeyDialog extends StatefulWidget {
  const AddCustomKeyDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      builder: (_) => const AddCustomKeyDialog(),
    );
  }

  @override
  State<AddCustomKeyDialog> createState() => _AddCustomKeyDialogState();
}

class _AddCustomKeyDialogState extends State<AddCustomKeyDialog> {
  late final TextEditingController _labelController;
  late final TextEditingController _sequenceController;
  late final TextEditingController _descriptionController;
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _labelController = TextEditingController();
    _sequenceController = TextEditingController();
    _descriptionController = TextEditingController();
  }

  @override
  void dispose() {
    _labelController.dispose();
    _sequenceController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _insertCode(String code) {
    final text = _sequenceController.text;
    final sel = _sequenceController.selection;
    if (sel.isValid && sel.start >= 0 && sel.end >= 0) {
      final newText = text.replaceRange(sel.start, sel.end, code);
      _sequenceController.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: sel.start + code.length),
      );
    } else {
      _sequenceController.text = text + code;
    }
  }

  void _applyPreset(TerminalKeyShortcut preset) {
    _labelController.text = preset.label;
    _sequenceController.text = preset.sequence;
    _descriptionController.text = preset.description ?? '';
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.appTheme;
    final store = context.read<TerminalSettingsStore>();

    return AlertDialog(
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
          key: _formKey,
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
                controller: _labelController,
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
                controller: _sequenceController,
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
                'Quick Presets (Extended Keys):',
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
                  _buildPresetChip(theme, const TerminalKeyShortcut(label: 'F1', sequence: '\x1BOP', description: 'Help / Menu')),
                  _buildPresetChip(theme, const TerminalKeyShortcut(label: 'F2', sequence: '\x1BOQ', description: 'User menu')),
                  _buildPresetChip(theme, const TerminalKeyShortcut(label: 'F5', sequence: '\x1B[15~', description: 'Copy / Refresh')),
                  _buildPresetChip(theme, const TerminalKeyShortcut(label: 'F10', sequence: '\x1B[21~', description: 'Quit / Exit')),
                  _buildPresetChip(theme, const TerminalKeyShortcut(label: 'F12', sequence: '\x1B[24~', description: 'Function 12')),
                  _buildPresetChip(theme, const TerminalKeyShortcut(label: 'Home', sequence: '\x1B[H', description: 'Cursor to start')),
                  _buildPresetChip(theme, const TerminalKeyShortcut(label: 'End', sequence: '\x1B[F', description: 'Cursor to end')),
                  _buildPresetChip(theme, const TerminalKeyShortcut(label: 'PgUp', sequence: '\x1B[5~', description: 'Page Up')),
                  _buildPresetChip(theme, const TerminalKeyShortcut(label: 'PgDn', sequence: '\x1B[6~', description: 'Page Down')),
                  _buildPresetChip(theme, const TerminalKeyShortcut(label: 'Del', sequence: '\x1B[3~', description: 'Forward delete')),
                ],
              ),
              const SizedBox(height: 12),
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
                  _buildCodeChip(theme, r'\e', 'Esc', _insertCode),
                  _buildCodeChip(theme, r'\t', 'Tab', _insertCode),
                  _buildCodeChip(theme, r'\n', 'Enter', _insertCode),
                  _buildCodeChip(theme, '^C', 'SIGINT', _insertCode),
                  _buildCodeChip(theme, '^D', 'EOF', _insertCode),
                  _buildCodeChip(theme, '^Z', 'SIGTSTP', _insertCode),
                  _buildCodeChip(theme, '^R', 'Reverse', _insertCode),
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
                controller: _descriptionController,
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
          onPressed: () => Navigator.of(context).pop(),
          child: Text('Cancel', style: TextStyle(color: theme.textSecondary)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: theme.primaryAccent,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          onPressed: () {
            if (_formKey.currentState?.validate() ?? false) {
              store.addCustomAccessoryKey(
                label: _labelController.text,
                sequence: _sequenceController.text,
                description: _descriptionController.text,
              );
              Navigator.of(context).pop();
            }
          },
          child: const Text('Add Key', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }

  Widget _buildCodeChip(
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

  Widget _buildPresetChip(
    AppThemeExtension theme,
    TerminalKeyShortcut preset,
  ) {
    return InkWell(
      borderRadius: BorderRadius.circular(6),
      onTap: () {
        HapticFeedback.selectionClick();
        _applyPreset(preset);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: theme.cardSurface,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: theme.border),
        ),
        child: Text(
          preset.label,
          style: TextStyle(
            fontSize: 11,
            fontFamily: 'monospace',
            fontWeight: FontWeight.w600,
            color: theme.secondaryAccent,
          ),
        ),
      ),
    );
  }
}
