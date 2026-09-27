import 'package:flutter/material.dart';
import '../../services/file_transfer_service.dart';
import '../../theme/app_theme.dart';

/// List of staged files selected for upload with remove buttons.
class SelectedFileList extends StatelessWidget {
  final List<FileTransferItem> files;
  final bool isUploading;
  final ValueChanged<int> onRemove;
  final AppThemeExtension theme;

  const SelectedFileList({
    super.key,
    required this.files,
    required this.isUploading,
    required this.onRemove,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: theme.cardSurface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.border),
      ),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: files.length,
        separatorBuilder: (_, __) => Divider(height: 1, color: theme.border),
        itemBuilder: (context, index) {
          final file = files[index];
          return ListTile(
            dense: true,
            leading: Icon(Icons.insert_drive_file_outlined, size: 20, color: theme.primaryAccent),
            title: Text(
              file.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 13, color: theme.textPrimary, fontWeight: FontWeight.w500),
            ),
            subtitle: Text(
              file.formattedSize,
              style: TextStyle(fontSize: 11, color: theme.textSecondary),
            ),
            trailing: IconButton(
              icon: Icon(Icons.close, size: 16, color: theme.textSecondary),
              onPressed: isUploading ? null : () => onRemove(index),
            ),
          );
        },
      ),
    );
  }
}
