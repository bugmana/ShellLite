import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

/// Touch target to trigger file picker with upload icon and instructions.
class FilePickerDropzone extends StatelessWidget {
  final VoidCallback onTap;
  final AppThemeExtension theme;

  const FilePickerDropzone({
    super.key,
    required this.onTap,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
        decoration: BoxDecoration(
          color: theme.cardSurface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: theme.primaryAccent.withValues(alpha: 0.35),
            style: BorderStyle.solid,
            width: 1.5,
          ),
        ),
        child: Column(
          children: [
            Icon(Icons.file_upload_outlined, size: 36, color: theme.primaryAccent),
            const SizedBox(height: 8),
            Text(
              'Select Files to Upload',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: theme.textPrimary,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Tap to choose one or more files from your device',
              style: TextStyle(color: theme.textSecondary, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
