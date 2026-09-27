import 'package:flutter/material.dart';
import '../../services/file_transfer_service.dart';
import '../../theme/app_theme.dart';

/// Progress view displayed during file upload with percentage and cancel button.
class FileUploadProgressView extends StatelessWidget {
  final String fileName;
  final int fileIndex;
  final int totalFiles;
  final int uploadedBytes;
  final int totalBytes;
  final double overallProgress;
  final VoidCallback onCancel;
  final AppThemeExtension theme;

  const FileUploadProgressView({
    super.key,
    required this.fileName,
    required this.fileIndex,
    required this.totalFiles,
    required this.uploadedBytes,
    required this.totalBytes,
    required this.overallProgress,
    required this.onCancel,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardSurface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: theme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'Uploading (${fileIndex + 1}/$totalFiles): $fileName',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontWeight: FontWeight.bold, color: theme.textPrimary, fontSize: 13),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${(overallProgress * 100).toStringAsFixed(0)}%',
                style: TextStyle(fontWeight: FontWeight.bold, color: theme.primaryAccent, fontSize: 13),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: overallProgress,
              minHeight: 4,
              backgroundColor: theme.border,
              valueColor: AlwaysStoppedAnimation<Color>(theme.primaryAccent),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${FileTransferService.formatBytes(uploadedBytes)} of ${FileTransferService.formatBytes(totalBytes)}',
                style: TextStyle(fontSize: 11, color: theme.textSecondary),
              ),
              TextButton(
                onPressed: onCancel,
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(50, 24),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  'Cancel',
                  style: TextStyle(color: theme.error, fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
