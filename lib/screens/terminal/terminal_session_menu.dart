import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

/// AppBar actions popup menu for terminal session actions (Upload, Settings, Disconnect).
class TerminalSessionMenu extends StatelessWidget {
  final VoidCallback onUpload;
  final VoidCallback onSettings;
  final VoidCallback onDisconnect;
  final VoidCallback? onPaste;
  final VoidCallback? onKeys;
  final AppThemeExtension theme;

  const TerminalSessionMenu({
    super.key,
    required this.onUpload,
    required this.onSettings,
    required this.onDisconnect,
    this.onPaste,
    this.onKeys,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      icon: Icon(Icons.more_vert_rounded, color: theme.textPrimary, size: 20),
      tooltip: 'Session Menu',
      padding: const EdgeInsets.all(10),
      constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
      color: theme.cardSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        side: BorderSide(color: theme.border, width: 1),
      ),
      onSelected: (value) {
        switch (value) {
          case 'paste':
            onPaste?.call();
            break;
          case 'keys':
            onKeys?.call();
            break;
          case 'upload':
            onUpload();
            break;
          case 'settings':
            onSettings();
            break;
          case 'disconnect':
            onDisconnect();
            break;
        }
      },
      itemBuilder: (context) => [
        if (onPaste != null)
          PopupMenuItem<String>(
            value: 'paste',
            child: Row(
              children: [
                Icon(Icons.paste_rounded, size: 18, color: theme.textSecondary),
                const SizedBox(width: AppSpacing.sm),
                Text('Paste Clipboard', style: TextStyle(color: theme.textPrimary, fontSize: 14)),
              ],
            ),
          ),
        if (onKeys != null)
          PopupMenuItem<String>(
            value: 'keys',
            child: Row(
              children: [
                Icon(Icons.keyboard_rounded, size: 18, color: theme.textSecondary),
                const SizedBox(width: AppSpacing.sm),
                Text('Keys & Shortcuts', style: TextStyle(color: theme.textPrimary, fontSize: 14)),
              ],
            ),
          ),
        if (onPaste != null || onKeys != null)
          const PopupMenuDivider(),
        PopupMenuItem<String>(
          value: 'upload',
          child: Row(
            children: [
              Icon(Icons.cloud_upload_outlined, size: 18, color: theme.textSecondary),
              const SizedBox(width: AppSpacing.sm),
              Text('Upload File', style: TextStyle(color: theme.textPrimary, fontSize: 14)),
            ],
          ),
        ),
        PopupMenuItem<String>(
          value: 'settings',
          child: Row(
            children: [
              Icon(Icons.tune_rounded, size: 18, color: theme.textSecondary),
              const SizedBox(width: AppSpacing.sm),
              Text('Settings', style: TextStyle(color: theme.textPrimary, fontSize: 14)),
            ],
          ),
        ),
        const PopupMenuDivider(),
        PopupMenuItem<String>(
          value: 'disconnect',
          child: Row(
            children: [
              Icon(Icons.power_settings_new_rounded, size: 18, color: theme.error),
              const SizedBox(width: AppSpacing.sm),
              Text(
                'Disconnect',
                style: TextStyle(
                  color: theme.error,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
