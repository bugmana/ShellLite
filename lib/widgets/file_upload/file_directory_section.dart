import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

/// Button with refresh icon to trigger remote directory re-detection.
class GestureToRefresh extends StatelessWidget {
  final VoidCallback onTap;
  final AppThemeExtension theme;

  const GestureToRefresh({super.key, required this.onTap, required this.theme});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: Row(
          children: [
            Icon(Icons.refresh_rounded, size: 13, color: theme.primaryAccent),
            const SizedBox(width: 3),
            Text(
              'Re-detect',
              style: TextStyle(fontSize: 11, color: theme.primaryAccent, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }
}

/// Remote destination folder input section with re-detect button and quick path chips.
class FileDirectorySection extends StatelessWidget {
  final TextEditingController controller;
  final bool isLoading;
  final bool isUploading;
  final VoidCallback onRefresh;
  final ValueChanged<String> onQuickSelect;
  final AppThemeExtension theme;

  const FileDirectorySection({
    super.key,
    required this.controller,
    required this.isLoading,
    required this.isUploading,
    required this.onRefresh,
    required this.onQuickSelect,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Remote Destination Folder',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: theme.textSecondary,
              ),
            ),
            if (isLoading)
              const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else
              GestureToRefresh(
                onTap: onRefresh,
                theme: theme,
              ),
          ],
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          enabled: !isUploading,
          style: TextStyle(
            color: theme.textPrimary,
            fontSize: 13,
            fontFamily: 'monospace',
          ),
          decoration: InputDecoration(
            hintText: '/home/user or ~',
            hintStyle: TextStyle(color: theme.textSecondary.withValues(alpha: 0.6)),
            prefixIcon: Icon(Icons.folder_open_rounded, size: 18, color: theme.primaryAccent),
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
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            _buildQuickChip('.', 'Current'),
            _buildQuickChip('~', '~ (Home)'),
            _buildQuickChip('/tmp', '/tmp'),
            _buildQuickChip('/var/www', '/var/www'),
          ],
        ),
      ],
    );
  }

  Widget _buildQuickChip(String path, String label) {
    return ActionChip(
      label: Text(label, style: const TextStyle(fontSize: 11)),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      backgroundColor: theme.cardSurface,
      side: BorderSide(color: theme.border),
      onPressed: isUploading ? null : () => onQuickSelect(path),
    );
  }
}
