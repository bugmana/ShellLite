import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

/// Header for FileUploadModal displaying drag handle, title, server profile info, and close button.
class FileUploadHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool isComplete;
  final bool canClose;
  final VoidCallback onClose;
  final AppThemeExtension theme;

  const FileUploadHeader({
    super.key,
    required this.title,
    required this.subtitle,
    required this.isComplete,
    required this.canClose,
    required this.onClose,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 10, 10, 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: theme.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: isComplete
                      ? theme.success.withValues(alpha: 0.18)
                      : theme.primaryAccent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  isComplete
                      ? Icons.check_circle_rounded
                      : Icons.cloud_upload_outlined,
                  size: 20,
                  color: isComplete ? theme.success : theme.primaryAccent,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: theme.textPrimary,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: TextStyle(fontSize: 12, color: theme.textSecondary),
                    ),
                  ],
                ),
              ),
              if (canClose)
                IconButton(
                  icon: Icon(Icons.close_rounded, size: 20, color: theme.textSecondary),
                  onPressed: onClose,
                ),
            ],
          ),
        ],
      ),
    );
  }
}
