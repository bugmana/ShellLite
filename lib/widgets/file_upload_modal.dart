import 'package:flutter/material.dart';
import '../providers/session_store.dart';
import '../services/file_picker/file_picker_service.dart';
import '../services/file_transfer_service.dart';
import '../theme/app_theme.dart';

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
                _buildHeader(theme),
                const Divider(height: 1),
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (!_uploadComplete) ...[
                          _buildDirectorySection(theme),
                          const SizedBox(height: 16),
                        ],
                        if (_uploadComplete)
                          _buildCompleteView(theme)
                        else if (_isUploading)
                          _buildProgressView(theme)
                        else ...[
                          _buildFilePickerSection(theme),
                          if (_selectedFiles.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            _buildFileList(theme),
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

  Widget _buildHeader(AppThemeExtension theme) {
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
                  color: _uploadComplete
                      ? theme.success.withValues(alpha: 0.18)
                      : theme.primaryAccent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  _uploadComplete
                      ? Icons.check_circle_rounded
                      : Icons.cloud_upload_outlined,
                  size: 20,
                  color: _uploadComplete ? theme.success : theme.primaryAccent,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _uploadComplete ? 'Upload Successful' : 'Upload Files to Server',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: theme.textPrimary,
                      ),
                    ),
                    Text(
                      _uploadComplete
                          ? '${_completedFiles.length} file(s) transferred'
                          : '${widget.session.profile.displayName} (${widget.session.profile.username}@${widget.session.profile.host})',
                      style: TextStyle(fontSize: 12, color: theme.textSecondary),
                    ),
                  ],
                ),
              ),
              if (!_isUploading)
                IconButton(
                  icon: Icon(Icons.close_rounded, size: 20, color: theme.textSecondary),
                  onPressed: () => Navigator.of(context).pop(),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDirectorySection(AppThemeExtension theme) {
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
            if (_isLoadingDirectory)
              const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else
              GestureToRefresh(
                onTap: _initDirectory,
                theme: theme,
              ),
          ],
        ),
        const SizedBox(height: 6),
        TextField(
          controller: _dirController,
          enabled: !_isUploading,
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
            _buildQuickChip('.', 'Current', theme),
            _buildQuickChip('~', '~ (Home)', theme),
            _buildQuickChip('/tmp', '/tmp', theme),
            _buildQuickChip('/var/www', '/var/www', theme),
          ],
        ),
      ],
    );
  }

  Widget _buildQuickChip(String path, String label, AppThemeExtension theme) {
    return ActionChip(
      label: Text(label, style: const TextStyle(fontSize: 11)),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      backgroundColor: theme.cardSurface,
      side: BorderSide(color: theme.border),
      onPressed: _isUploading
          ? null
          : () {
              setState(() {
                _dirController.text = path;
              });
            },
    );
  }

  Widget _buildFilePickerSection(AppThemeExtension theme) {
    return InkWell(
      onTap: _pickFiles,
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

  Widget _buildFileList(AppThemeExtension theme) {
    return Container(
      decoration: BoxDecoration(
        color: theme.cardSurface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.border),
      ),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: _selectedFiles.length,
        separatorBuilder: (_, __) => Divider(height: 1, color: theme.border),
        itemBuilder: (context, index) {
          final file = _selectedFiles[index];
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
              onPressed: () => _removeFile(index),
            ),
          );
        },
      ),
    );
  }

  Widget _buildProgressView(AppThemeExtension theme) {
    final currentFile = _selectedFiles[_currentFileIndex];
    final fileProgress = _currentFileTotalBytes > 0
        ? (_currentFileUploadedBytes / _currentFileTotalBytes).clamp(0.0, 1.0)
        : 0.0;
    final totalFiles = _selectedFiles.length;
    final overallProgress = (totalFiles > 0)
        ? ((_currentFileIndex + fileProgress) / totalFiles).clamp(0.0, 1.0)
        : 0.0;

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
                  'Uploading (${_currentFileIndex + 1}/$totalFiles): ${currentFile.name}',
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
                '${FileTransferService.formatBytes(_currentFileUploadedBytes)} of ${FileTransferService.formatBytes(_currentFileTotalBytes)}',
                style: TextStyle(fontSize: 11, color: theme.textSecondary),
              ),
              TextButton(
                onPressed: _cancelUpload,
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

  Widget _buildCompleteView(AppThemeExtension theme) {
    return GestureDetector(
      onTap: () => Navigator.of(context).maybePop(),
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
        decoration: BoxDecoration(
          color: theme.cardSurface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: theme.success.withValues(alpha: 0.5),
            width: 1.5,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: theme.success.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.check_circle_rounded,
                size: 36,
                color: theme.success,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Upload Complete',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: theme.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${_completedFiles.length} file(s) transferred to ${_dirController.text.trim()}',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: theme.textSecondary,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 6,
              runSpacing: 6,
              children: _completedFiles.map((name) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: theme.success.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: theme.success.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_rounded, size: 12, color: theme.success),
                      const SizedBox(width: 4),
                      Text(
                        name,
                        style: TextStyle(
                          fontSize: 11,
                          color: theme.textPrimary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).maybePop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.primaryAccent,
                  foregroundColor: AppTheme.computeOnPrimary(theme.primaryAccent),
                  minimumSize: const Size(0, 44),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text('Done', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
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
