import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

/// Persistent session (tmux) configuration panel for ServerFormScreen.
class TmuxConfigPanel extends StatelessWidget {
  final bool persistSession;
  final ValueChanged<bool> onPersistChanged;
  final TextEditingController sessionNameController;
  final AppThemeExtension theme;

  const TmuxConfigPanel({
    super.key,
    required this.persistSession,
    required this.onPersistChanged,
    required this.sessionNameController,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: theme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(
          color: persistSession
              ? theme.primaryAccent.withValues(alpha: 0.5)
              : theme.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SwitchListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            title: Text(
              'Persistent Session (tmux)',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: theme.textPrimary,
              ),
            ),
            subtitle: Text(
              'Keeps background processes running across reconnections.',
              style: TextStyle(
                fontSize: 12,
                color: theme.textSecondary,
                height: 1.3,
              ),
            ),
            value: persistSession,
            activeThumbColor: theme.primaryAccent,
            onChanged: onPersistChanged,
          ),
          if (persistSession) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              child: TextFormField(
                controller: sessionNameController,
                decoration: const InputDecoration(
                  labelText: 'Session Name (optional, defaults to "shelllite")',
                  hintText: 'shelllite',
                  prefixIcon: Icon(Icons.terminal_rounded, size: 20),
                ),
                autocorrect: false,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
