import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:dartssh2/dartssh2.dart';
import 'package:flutter/foundation.dart';

/// Encapsulates a selected local file for cross-platform upload (Mobile, Desktop, Web).
class FileTransferItem {
  final String name;
  final int size;
  final String? localPath;
  final Uint8List? bytes;
  final Stream<List<int>>? readStream;

  const FileTransferItem({
    required this.name,
    required this.size,
    this.localPath,
    this.bytes,
    this.readStream,
  });

  String get formattedSize => FileTransferService.formatBytes(size);
}

/// Status and progress information for an active file upload.
class FileUploadProgress {
  final String fileName;
  final int bytesUploaded;
  final int totalBytes;
  final double percentage;
  final bool isComplete;
  final String? error;

  const FileUploadProgress({
    required this.fileName,
    required this.bytesUploaded,
    required this.totalBytes,
    required this.percentage,
    this.isComplete = false,
    this.error,
  });
}

/// Service handling SFTP file uploads and remote current directory resolution.
class FileTransferService {
  /// Formats byte count into human-readable strings (e.g. 1.2 MB, 450 KB).
  static String formatBytes(int bytes) {
    if (bytes <= 0) return '0 B';
    const suffixes = ['B', 'KB', 'MB', 'GB', 'TB'];
    final i = (log(bytes) / log(1024)).floor();
    final index = min(i, suffixes.length - 1);
    final value = bytes / pow(1024, index);
    if (index == 0) {
      return '$bytes B';
    }
    return '${value.toStringAsFixed(value < 10 ? 1 : 0)} ${suffixes[index]}';
  }

  /// Attempts to resolve the current remote directory of the active SSH shell.
  ///
  /// Uses a multi-tiered fallback hierarchy:
  /// 1. Tmux active pane path (if tmux session is active)
  /// 2. Active PTS shell process `/proc/<pid>/cwd` or `pwdx`
  /// 3. SFTP canonicalized home directory
  /// 4. Fallback to '~'
  static Future<String> resolveRemoteCurrentDirectory(SSHClient client) async {
    try {
      const probeCmd =
          'if command -v tmux >/dev/null 2>&1 && tmux display-message -p -F "#{pane_current_path}" 2>/dev/null; then '
          'exit 0; '
          'fi; '
          'PTS_PID=\$((ps -o pid,tty,cmd -u "\$USER" 2>/dev/null || ps -ef 2>/dev/null) | grep -E "pts/|pts\\b" | grep -E "bash|zsh|sh|fish|ash" | grep -v "grep" | tail -n 1 | awk \'{print \$1}\'); '
          'if [ -n "\$PTS_PID" ] && [ -e "/proc/\$PTS_PID/cwd" ]; then '
          'readlink -f "/proc/\$PTS_PID/cwd" 2>/dev/null && exit 0; '
          'fi; '
          'if [ -n "\$PTS_PID" ] && command -v pwdx >/dev/null 2>&1; then '
          'pwdx "\$PTS_PID" 2>/dev/null | awk \'{print \$2}\' && exit 0; '
          'fi; '
          'pwd';

      final outputBytes = await client.run(probeCmd).timeout(
            const Duration(seconds: 3),
            onTimeout: () => Uint8List(0),
          );

      if (outputBytes.isNotEmpty) {
        final lines = utf8.decode(outputBytes).split('\n');
        for (final line in lines) {
          final trimmed = line.trim();
          if (trimmed.isNotEmpty && trimmed.startsWith('/')) {
            return trimmed;
          }
        }
      }
    } catch (e) {
      debugPrint('FileTransferService: CWD probe exec failed ($e), falling back to SFTP');
    }

    // Fallback: SFTP canonical real path of home / root
    try {
      final sftp = await client.sftp().timeout(const Duration(seconds: 3));
      try {
        final canonical = await sftp.absolute('.').timeout(const Duration(seconds: 2));
        if (canonical.isNotEmpty) {
          return canonical;
        }
      } finally {
        await sftp.close();
      }
    } catch (e) {
      debugPrint('FileTransferService: SFTP canonicalize failed: $e');
    }

    return '~';
  }

  /// Uploads a single file to [remoteDirectory] on the remote server via SFTP.
  static Future<void> uploadFile({
    required SSHClient client,
    required String remoteDirectory,
    required FileTransferItem item,
    void Function(int bytesUploaded, int totalBytes)? onProgress,
    bool Function()? isCancelled,
  }) async {
    final sftp = await client.sftp();
    try {
      if (isCancelled?.call() == true) {
        throw Exception('Upload cancelled');
      }

      var targetDir = remoteDirectory.trim();
      if (targetDir.isEmpty || targetDir == '~') {
        // Resolve ~ to absolute home if possible
        try {
          targetDir = await sftp.absolute('.');
        } catch (_) {
          targetDir = '.';
        }
      }

      // Ensure no trailing slash unless root
      if (targetDir.length > 1 && targetDir.endsWith('/')) {
        targetDir = targetDir.substring(0, targetDir.length - 1);
      }

      final remotePath = targetDir == '/' ? '/${item.name}' : '$targetDir/${item.name}';

      final remoteFile = await sftp.open(
        remotePath,
        mode: SftpFileOpenMode.create | SftpFileOpenMode.write | SftpFileOpenMode.truncate,
      );

      try {
        Stream<Uint8List> dataStream;
        if (item.bytes != null) {
          dataStream = Stream.value(item.bytes!);
        } else if (item.localPath != null) {
          dataStream = File(item.localPath!).openRead().map(Uint8List.fromList);
        } else if (item.readStream != null) {
          dataStream = item.readStream!.map(Uint8List.fromList);
        } else {
          throw Exception('No valid data source for ${item.name}');
        }

        var totalSent = 0;
        final writer = remoteFile.write(
          dataStream,
          onProgress: (bytesWritten) {
            if (isCancelled?.call() == true) {
              throw Exception('Upload cancelled');
            }
            totalSent = bytesWritten;
            onProgress?.call(bytesWritten, item.size);
          },
        );

        await writer.done;
        // Ensure 100% callback if completed
        if (item.size > 0 && totalSent < item.size) {
          onProgress?.call(item.size, item.size);
        }
      } finally {
        await remoteFile.close();
      }
    } finally {
      await sftp.close();
    }
  }
}
