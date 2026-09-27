import 'dart:async';
import 'package:flutter/material.dart';
import '../providers/session_store.dart';
import '../services/file_picker/file_picker_service.dart';
import '../services/file_transfer_service.dart';
import '../theme/app_theme.dart';
import 'file_upload/file_directory_section.dart';
import 'file_upload/file_picker_dropzone.dart';
import 'file_upload/file_upload_complete_view.dart';
import 'file_upload/file_upload_header.dart';
import 'file_upload/file_upload_progress_view.dart';
import 'file_upload/selected_file_list.dart';

export 'file_upload/file_directory_section.dart';
export 'file_upload/file_picker_dropzone.dart';
export 'file_upload/file_upload_complete_view.dart';
export 'file_upload/file_upload_header.dart';
export 'file_upload/file_upload_progress_view.dart';
export 'file_upload/selected_file_list.dart';

class FileUploadModal extends StatefulWidget {
  final OpenSession session;
  final String? initialDirectory;

  const FileUploadModal({
    super.key,
    required this.session,
    this.initialDirectory,
  });

  static Future<void> show(
    BuildContext context, {
    required OpenSession session,
    String? initialDirectory,
  }) {
    final theme = context.appTheme;
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: theme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
        side: BorderSide(color: theme.border, width: 1),
      ),
      builder: (_) => FileUploadModal(
        session: session,
        initialDirectory: initialDirectory,
      ),
    );
  }

  @override
  State<FileUploadModal> createState() => _FileUploadModalState();
}

class _FileUploadModalState extends State<FileUploadModal> {
  final TextEditingController _dirController = TextEditingController();
  final List<FileTransferItem> _selectedFiles = [];

  bool _isLoadingDirectory = false;
  bool _isUploading = false;
  bool _uploadComplete = false;
  bool _isCancelled = false;
  String? _errorMessage;

  int _currentFileIndex = 0;
  int _currentFileUploadedBytes = 0;
  int _currentFileTotalBytes = 0;
  final List<String> _completedFiles = [];

  @override
  void initState() {
    super.initState();
    _initDirectory();
  }

  @override
  void dispose() {
    _dirController.dispose();
    super.dispose();
  }

  Future<void> _initDirectory() async {
    if (widget.initialDirectory != null && widget.initialDirectory!.isNotEmpty) {
      _dirController.text = widget.initialDirectory!;
      return;
    }

    final client = widget.session.sshService.client;
    if (client == null || !widget.session.sshService.isConnected) {
      _dirController.text = '~';
      return;
    }

    setState(() {
      _isLoadingDirectory = true;
      _errorMessage = null;
    });

    try {
      final resolved = await FileTransferService.resolveCurrentDirectory(client);
      if (mounted) {
        setState(() {
          _dirController.text = resolved;
          _isLoadingDirectory = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          if (_dirController.text.isEmpty) {
            _dirController.text = '~';
          }
          _isLoadingDirectory = false;
        });
      }
    }
  }

  Future<void> _pickFiles() async {
    try {
      final items = await AppFilePicker.pickFiles();

      if (items.isNotEmpty && mounted) {
        setState(() {
          for (final item in items) {
            if (!_selectedFiles.any((f) => f.name == item.name)) {
              _selectedFiles.add(item);
            }
          }
          _errorMessage = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Error picking files: $e';
        });
      }
    }
  }

  void _removeFile(int index) {
    if (_isUploading) return;
    setState(() {
      _selectedFiles.removeAt(index);
    });
  }

  Future<void> _startUpload() async {
    if (_selectedFiles.isEmpty || _isUploading) return;

    final client = widget.session.sshService.client;
    if (client == null || !widget.session.sshService.isConnected) {
      setState(() {
        _errorMessage = 'SSH session is not connected.';
      });
      return;
    }

    final targetDir = _dirController.text.trim().isNotEmpty
        ? _dirController.text.trim()
        : '~';

    setState(() {
      _isUploading = true;
      _isCancelled = false;
      _errorMessage = null;
      _uploadComplete = false;
      _completedFiles.clear();
      _currentFileIndex = 0;
      _currentFileUploadedBytes = 0;
      _currentFileTotalBytes = _selectedFiles.first.size;
    });

    try {
      for (var i = 0; i < _selectedFiles.length; i++) {
        if (_isCancelled) break;

        final item = _selectedFiles[i];

        setState(() {
          _currentFileIndex = i;
          _currentFileTotalBytes = item.size;
          _currentFileUploadedBytes = 0;
        });

        await FileTransferService.uploadFile(
          client: client,
          remoteDirectory: targetDir,
          item: item,
          onProgress: (uploaded, total) {
            if (mounted && !_isCancelled) {
              setState(() {
                _currentFileUploadedBytes = uploaded;
                _currentFileTotalBytes = total;
              });
            }
          },
          isCancelled: () => _isCancelled,
        );

        if (!_isCancelled) {
          _completedFiles.add(item.name);
        }
      }

      if (mounted) {
        if (_isCancelled) {
          setState(() {
            _isUploading = false;
            _errorMessage = 'Upload cancelled by user.';
          });
        } else {
          // Snap progress to 100% smoothly before celebratory switch
          setState(() {
            _currentFileUploadedBytes = _currentFileTotalBytes;
          });
          await Future.delayed(const Duration(milliseconds: 150));

          if (mounted) {
            setState(() {
              _isUploading = false;
              _uploadComplete = true;
            });

            // Auto-dismiss after 1500ms unless accessibility navigation is active
            final isAccessible = MediaQuery.accessibleNavigationOf(context);
            if (!isAccessible) {
              Future.delayed(const Duration(milliseconds: 1500), () {
                if (mounted && _uploadComplete) {
                  Navigator.of(context).maybePop();
                }
              });
            }

            // Print success message in the terminal scrollback
            final count = _completedFiles.length;
            final dirDisplay = targetDir == '.' ? 'current directory' : targetDir;
            final names = _completedFiles.join(', ');
            widget.session.terminal.write(
              '\r\n\x1b[38;2;63;185;80m✔ Uploaded $count file(s) to $dirDisplay: $names\x1b[0m\r\n',
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isUploading = false;
          _errorMessage = 'Upload failed: $e';
        });
      }
    }
  }

  void _cancelUpload() {
    setState(() {
      _isCancelled = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.appTheme;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    final currentFile = _selectedFiles.isNotEmpty ? _selectedFiles[_currentFileIndex] : null;
    final fileProgress = (_currentFileTotalBytes > 0)
        ? (_currentFileUploadedBytes / _currentFileTotalBytes).clamp(0.0, 1.0)
        : 0.0;
    final totalFiles = _selectedFiles.length;
    final overallProgress = (totalFiles > 0)
        ? ((_currentFileIndex + fileProgress) / totalFiles).clamp(0.0, 1.0)
        : 0.0;

    return PopScope(
      canPop: !_isUploading,
      child: Padding(
        padding: EdgeInsets.only(bottom: bottomInset),
        child: SafeArea(
          child: Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.65,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                FileUploadHeader(
                  title: _uploadComplete ? 'Upload Successful' : 'Upload Files to Server',
                  subtitle: _uploadComplete
                      ? '${_completedFiles.length} file(s) transferred'
                      : '${widget.session.profile.displayName} (${widget.session.profile.username}@${widget.session.profile.host})',
                  isComplete: _uploadComplete,
                  canClose: !_isUploading,
                  onClose: () => Navigator.of(context).pop(),
                  theme: theme,
                ),
                const Divider(height: 1),
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (!_uploadComplete) ...[
                          FileDirectorySection(
                            controller: _dirController,
                            isLoading: _isLoadingDirectory,
                            isUploading: _isUploading,
                            onRefresh: _initDirectory,
                            onQuickSelect: (path) => setState(() => _dirController.text = path),
                            theme: theme,
                          ),
                          const SizedBox(height: 16),
                        ],
                        if (_uploadComplete)
                          FileUploadCompleteView(
                            destinationDir: _dirController.text.trim(),
                            completedFiles: _completedFiles,
                            onDone: () => Navigator.of(context).maybePop(),
                            theme: theme,
                          )
                        else if (_isUploading && currentFile != null)
                          FileUploadProgressView(
                            fileName: currentFile.name,
                            fileIndex: _currentFileIndex,
                            totalFiles: totalFiles,
                            uploadedBytes: _currentFileUploadedBytes,
                            totalBytes: _currentFileTotalBytes,
                            overallProgress: overallProgress,
                            onCancel: _cancelUpload,
                            theme: theme,
                          )
                        else ...[
                          FilePickerDropzone(
                            onTap: _pickFiles,
                            theme: theme,
                          ),
                          if (_selectedFiles.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            SelectedFileList(
                              files: _selectedFiles,
                              isUploading: _isUploading,
                              onRemove: _removeFile,
                              theme: theme,
                            ),
                          ],
                          if (_errorMessage != null) ...[
                            const SizedBox(height: 12),
                            _buildErrorBanner(theme),
                          ],
                          const SizedBox(height: 20),
                          _buildActionButtons(theme),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildErrorBanner(AppThemeExtension theme) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: theme.error.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.error.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline_rounded, color: theme.error, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _errorMessage ?? '',
              style: TextStyle(color: theme.error, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(AppThemeExtension theme) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: () => Navigator.of(context).pop(),
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: theme.border),
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(
              'Cancel',
              style: TextStyle(color: theme.textSecondary),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 2,
          child: ElevatedButton.icon(
            onPressed: _selectedFiles.isEmpty ? null : _startUpload,
            icon: const Icon(Icons.cloud_upload_rounded, size: 18),
            label: Text(
              _selectedFiles.isEmpty
                  ? 'Upload'
                  : 'Upload (${_selectedFiles.length})',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.primaryAccent,
              foregroundColor: AppTheme.computeOnPrimary(theme.primaryAccent),
              disabledBackgroundColor: theme.border,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
