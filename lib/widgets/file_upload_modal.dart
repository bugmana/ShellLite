import 'dart:math';
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

class CelebrationParticle {
  final double angle;
  final double speed;
  final double size;
  final Color color;
  final double rotationSpeed;

  const CelebrationParticle({
    required this.angle,
    required this.speed,
    required this.size,
    required this.color,
    required this.rotationSpeed,
  });
}

class CelebrationBurstPainter extends CustomPainter {
  final double progress;
  final List<CelebrationParticle> particles;

  CelebrationBurstPainter({
    required this.progress,
    required this.particles,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0.0 || progress >= 1.0) return;

    final center = Offset(size.width / 2, size.height / 2);
    final paint = Paint()..style = PaintingStyle.fill;

    for (final p in particles) {
      final distance = p.speed * Curves.easeOutCubic.transform(progress) * 95;
      final gravity = progress * progress * 45;
      final x = center.dx + cos(p.angle) * distance;
      final y = center.dy + sin(p.angle) * distance + gravity;
      final alpha = (1.0 - progress).clamp(0.0, 1.0);

      paint.color = p.color.withValues(alpha: alpha);

      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(p.rotationSpeed * progress * pi * 2);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset.zero, width: p.size, height: p.size * 0.55),
          const Radius.circular(2),
        ),
        paint,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant CelebrationBurstPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

class _FileUploadModalState extends State<FileUploadModal>
    with TickerProviderStateMixin {
  late final TextEditingController _dirController;
  bool _isLoadingDirectory = false;
  final List<FileTransferItem> _selectedFiles = [];

  bool _isUploading = false;
  bool _isCancelled = false;
  int _currentFileIndex = 0;
  int _currentFileUploadedBytes = 0;
  int _currentFileTotalBytes = 0;
  final List<String> _completedFiles = [];
  String? _errorMessage;
  bool _uploadComplete = false;

  late final AnimationController _successAnimController;
  late final Animation<double> _scaleAnimation;
  late final Animation<double> _fadeAnimation;
  late final Animation<double> _rippleAnimation;

  late final AnimationController _particleController;
  final List<CelebrationParticle> _particles = [];

  @override
  void initState() {
    super.initState();
    _dirController = TextEditingController(
      text: widget.initialDirectory?.trim().isNotEmpty == true
          ? widget.initialDirectory!.trim()
          : '',
    );

    if (_dirController.text.isEmpty) {
      _resolveRemoteDirectory();
    }

    _successAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _scaleAnimation = CurvedAnimation(
      parent: _successAnimController,
      curve: Curves.elasticOut,
    );

    _fadeAnimation = CurvedAnimation(
      parent: _successAnimController,
      curve: const Interval(0.0, 0.4, curve: Curves.easeIn),
    );

    _rippleAnimation = Tween<double>(begin: 0.8, end: 1.8).animate(
      CurvedAnimation(
        parent: _successAnimController,
        curve: const Interval(0.0, 0.8, curve: Curves.easeOutCubic),
      ),
    );

    _particleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );

    _generateCelebrationParticles();
  }

  void _generateCelebrationParticles() {
    final rng = Random(42);
    final colors = [
      const Color(0xFF3FB950), // Green
      const Color(0xFF38BDF8), // Cyan
      const Color(0xFFFBBF24), // Amber
      const Color(0xFFA855F7), // Purple
      const Color(0xFFF43F5E), // Coral
      const Color(0xFF22C55E), // Emerald
    ];

    for (int i = 0; i < 36; i++) {
      final angle = (i / 36) * 2 * pi + (rng.nextDouble() - 0.5) * 0.25;
      final speed = 0.5 + rng.nextDouble() * 0.8;
      final size = 6.0 + rng.nextDouble() * 6.0;
      final color = colors[rng.nextInt(colors.length)];
      final rotationSpeed = (rng.nextDouble() - 0.5) * 3.0;

      _particles.add(
        CelebrationParticle(
          angle: angle,
          speed: speed,
          size: size,
          color: color,
          rotationSpeed: rotationSpeed,
        ),
      );
    }
  }

  @override
  void dispose() {
    _dirController.dispose();
    _successAnimController.dispose();
    _particleController.dispose();
    super.dispose();
  }

  Future<void> _resolveRemoteDirectory() async {
    if (!mounted) return;
    setState(() {
      _isLoadingDirectory = true;
    });

    try {
      final client = widget.session.sshService.client;
      String path = '~';
      if (client != null && widget.session.sshService.isConnected) {
        path = await FileTransferService.resolveRemoteCurrentDirectory(client);
      }
      if (mounted) {
        setState(() {
          _dirController.text = path;
          _isLoadingDirectory = false;
        });
      }
    } catch (e) {
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
      _currentFileIndex = 0;
      _currentFileUploadedBytes = 0;
      _currentFileTotalBytes = _selectedFiles[0].size;
      _completedFiles.clear();
      _errorMessage = null;
      _uploadComplete = false;
    });

    try {
      for (int i = 0; i < _selectedFiles.length; i++) {
        if (_isCancelled) break;

        final item = _selectedFiles[i];
        if (mounted) {
          setState(() {
            _currentFileIndex = i;
            _currentFileTotalBytes = item.size;
            _currentFileUploadedBytes = 0;
          });
        }

        await FileTransferService.uploadFile(
          client: client,
          remoteDirectory: targetDir,
          item: item,
          isCancelled: () => _isCancelled,
          onProgress: (uploaded, total) {
            if (mounted && !_isCancelled) {
              setState(() {
                _currentFileUploadedBytes = uploaded;
                _currentFileTotalBytes = total;
              });
            }
          },
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

            _successAnimController.forward(from: 0.0);
            _particleController.forward(from: 0.0);

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

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SafeArea(
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.88,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SheetDragHandle(),
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
    );
  }

  Widget _buildHeader(AppThemeExtension theme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 8, 10, 12),
      child: Row(
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
                  : Icons.cloud_upload_rounded,
              color: _uploadComplete ? theme.success : theme.primaryAccent,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
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
                const SizedBox(height: 2),
                Text(
                  '${widget.session.profile.displayName} • ${widget.session.profile.username}@${widget.session.profile.host}',
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.textSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded, size: 20),
            tooltip: 'Close',
            onPressed: () => Navigator.of(context).pop(),
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
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: theme.textPrimary,
              ),
            ),
            if (!_isUploading)
              InkWell(
                onTap: _isLoadingDirectory ? null : _resolveRemoteDirectory,
                borderRadius: BorderRadius.circular(4),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  child: Row(
                    children: [
                      if (_isLoadingDirectory)
                        SizedBox(
                          width: 12,
                          height: 12,
                          child: CircularProgressIndicator(
                            strokeWidth: 1.5,
                            color: theme.secondaryAccent,
                          ),
                        )
                      else
                        Icon(
                          Icons.refresh_rounded,
                          size: 14,
                          color: theme.secondaryAccent,
                        ),
                      const SizedBox(width: 4),
                      Text(
                        'Re-detect',
                        style: TextStyle(
                          fontSize: 11,
                          color: theme.secondaryAccent,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
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
            prefixIcon: Icon(
              Icons.folder_open_rounded,
              color: theme.primaryAccent,
              size: 20,
            ),
            hintText: 'e.g. /home/user/project or ~',
            hintStyle: TextStyle(
              color: theme.textSecondary.withValues(alpha: 0.6),
              fontSize: 13,
            ),
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
        const SizedBox(height: 4),
        Text(
          'Target directory on the remote server where files will be uploaded.',
          style: TextStyle(
            fontSize: 11,
            color: theme.textSecondary.withValues(alpha: 0.8),
          ),
        ),
      ],
    );
  }

  Widget _buildFilePickerSection(AppThemeExtension theme) {
    if (_selectedFiles.isEmpty) {
      return Material(
        color: theme.cardSurface,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: _pickFiles,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: theme.primaryAccent.withValues(alpha: 0.4),
                width: 1.5,
              ),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.upload_file_rounded,
                  size: 36,
                  color: theme.primaryAccent,
                ),
                const SizedBox(height: 10),
                Text(
                  'Select Files to Upload',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: theme.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Tap to choose one or more files from your device',
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'Selected Files (${_selectedFiles.length})',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: theme.textPrimary,
          ),
        ),
        TextButton.icon(
          onPressed: _pickFiles,
          icon: Icon(Icons.add_rounded, size: 16, color: theme.primaryAccent),
          label: Text(
            'Add More',
            style: TextStyle(fontSize: 12, color: theme.primaryAccent),
          ),
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ),
      ],
    );
  }

  Widget _buildFileList(AppThemeExtension theme) {
    return Container(
      decoration: BoxDecoration(
        color: theme.cardSurface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: theme.border),
      ),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: _selectedFiles.length,
        separatorBuilder: (_, __) => Divider(height: 1, color: theme.border),
        itemBuilder: (context, index) {
          final file = _selectedFiles[index];
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                Icon(
                  Icons.insert_drive_file_outlined,
                  size: 20,
                  color: theme.secondaryAccent,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        file.name,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: theme.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        file.formattedSize,
                        style: TextStyle(
                          fontSize: 11,
                          color: theme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(
                    Icons.close_rounded,
                    size: 18,
                    color: theme.textSecondary,
                  ),
                  tooltip: 'Remove',
                  onPressed: () => _removeFile(index),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildProgressView(AppThemeExtension theme) {
    final currentFile = _selectedFiles.isNotEmpty && _currentFileIndex < _selectedFiles.length
        ? _selectedFiles[_currentFileIndex]
        : null;

    final progress = _currentFileTotalBytes > 0
        ? (_currentFileUploadedBytes / _currentFileTotalBytes).clamp(0.0, 1.0)
        : 0.0;

    final isAlmostDone = progress >= 0.99;
    final progressColor = isAlmostDone ? theme.success : theme.primaryAccent;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardSurface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isAlmostDone
              ? theme.success.withValues(alpha: 0.5)
              : theme.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Uploading file ${_currentFileIndex + 1} of ${_selectedFiles.length}...',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: theme.textPrimary,
                ),
              ),
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 200),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: progressColor,
                  fontFamily: 'monospace',
                ),
                child: Text('${(progress * 100).toInt()}%'),
              ),
            ],
          ),
          if (currentFile != null) ...[
            const SizedBox(height: 4),
            Text(
              currentFile.name,
              style: TextStyle(
                fontSize: 12,
                color: theme.textSecondary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0.0, end: progress),
              duration: const Duration(milliseconds: 150),
              curve: Curves.easeOut,
              builder: (context, animValue, _) {
                return LinearProgressIndicator(
                  value: animValue,
                  backgroundColor: theme.surface,
                  valueColor: AlwaysStoppedAnimation<Color>(progressColor),
                  minHeight: 8,
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${FileTransferService.formatBytes(_currentFileUploadedBytes)} / ${FileTransferService.formatBytes(_currentFileTotalBytes)}',
                style: TextStyle(
                  fontSize: 11,
                  color: theme.textSecondary,
                  fontFamily: 'monospace',
                ),
              ),
              Text(
                'Total files: ${_selectedFiles.length}',
                style: TextStyle(
                  fontSize: 11,
                  color: theme.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Center(
            child: OutlinedButton.icon(
              onPressed: _cancelUpload,
              icon: Icon(Icons.cancel_outlined, size: 16, color: theme.error),
              label: Text(
                'Cancel Upload',
                style: TextStyle(color: theme.error, fontSize: 13),
              ),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: theme.error.withValues(alpha: 0.5)),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompleteView(AppThemeExtension theme) {
    return AnimatedBuilder(
      animation: Listenable.merge([_successAnimController, _particleController]),
      builder: (context, child) {
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
          decoration: BoxDecoration(
            color: theme.cardSurface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: theme.success.withValues(alpha: 0.6),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: theme.success.withValues(alpha: 0.15),
                blurRadius: 20,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Column(
            children: [
              // Celebratory Particle Burst + Expanding Ripples + Bouncing Checkmark
              SizedBox(
                height: 110,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Confetti Particles
                    CustomPaint(
                      size: const Size(220, 110),
                      painter: CelebrationBurstPainter(
                        progress: _particleController.value,
                        particles: _particles,
                      ),
                    ),
                    // Outer Ripple
                    Transform.scale(
                      scale: _rippleAnimation.value,
                      child: Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: theme.success.withValues(
                              alpha: (0.7 * (1.0 - _successAnimController.value)).clamp(0.0, 0.7),
                            ),
                            width: 2,
                          ),
                        ),
                      ),
                    ),
                    // Inner Soft Glow
                    Transform.scale(
                      scale: 1.0 + (_rippleAnimation.value - 1.0) * 0.5,
                      child: Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: theme.success.withValues(
                            alpha: (0.25 * (1.0 - _successAnimController.value)).clamp(0.0, 0.25),
                          ),
                        ),
                      ),
                    ),
                    // Bouncing Checkmark Icon Badge
                    ScaleTransition(
                      scale: _scaleAnimation,
                      child: Container(
                        width: 68,
                        height: 68,
                        decoration: BoxDecoration(
                          color: theme.success.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: theme.success,
                            width: 2.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: theme.success.withValues(alpha: 0.35),
                              blurRadius: 18,
                              spreadRadius: 3,
                            ),
                          ],
                        ),
                        child: Icon(
                          Icons.check_rounded,
                          color: theme.success,
                          size: 40,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              FadeTransition(
                opacity: _fadeAnimation,
                child: Text(
                  'Upload Complete!',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: theme.textPrimary,
                    letterSpacing: -0.2,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              // Pill info badge
              FadeTransition(
                opacity: _fadeAnimation,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: theme.surface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: theme.border),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.folder_rounded, size: 14, color: theme.secondaryAccent),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          _dirController.text.trim(),
                          style: TextStyle(
                            fontSize: 12,
                            color: theme.textSecondary,
                            fontFamily: 'monospace',
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // File chips summary
              FadeTransition(
                opacity: _fadeAnimation,
                child: Wrap(
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
                          Icon(Icons.check_circle_outline_rounded, size: 12, color: theme.success),
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
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.done_all_rounded, size: 18),
                  label: const Text(
                    'Done',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.primaryAccent,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
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
              foregroundColor: Colors.black,
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
