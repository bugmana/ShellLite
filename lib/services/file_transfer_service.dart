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
  final double percentage; // 0.0 to 1.0
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

  double get progress => percentage;
}

class FileTransferService {
  /// Alias for backward compatibility
  static Future<String> resolveRemoteCurrentDirectory(SSHClient client) =>
      resolveCurrentDirectory(client);

  /// Format a byte count into a human-readable string (B, KB, MB, GB).
  static String formatBytes(int bytes) {
    if (bytes <= 0) return '0 B';
    const suffixes = ['B', 'KB', 'MB', 'GB', 'TB'];
    final i = (log(bytes) / log(1024)).floor();
    final clampedIndex = i.clamp(0, suffixes.length - 1);
    final value = bytes / pow(1024, clampedIndex);
    if (clampedIndex == 0) {
      return '$bytes B';
    }
    final formatted = value.toStringAsFixed(1);
    if (formatted.endsWith('.0') && value >= 10) {
      return '${value.toInt()} ${suffixes[clampedIndex]}';
    }
    return '$formatted ${suffixes[clampedIndex]}';
  }

  /// Proactively resolves the current remote directory for the given SSH session.
  static Future<String> resolveCurrentDirectory(SSHClient client) async {
    // 1. Try pwd via SSH exec first (fast, reliable, and avoids SFTP uint64 accessors in dart2js)
    try {
      final session = await client.execute('pwd');
      final output = await utf8.decodeStream(session.stdout);
      final trimmed = output.trim();
      if (trimmed.isNotEmpty && trimmed.startsWith('/')) {
        return trimmed;
      }
    } catch (_) {}

    // 2. Try SFTP absolute if exec is unavailable on native platforms
    if (!kIsWeb) {
      try {
        final sftp = await client.sftp();
        try {
          final absPath = await sftp.absolute('.');
          if (absPath.isNotEmpty && absPath.startsWith('/')) {
            return absPath;
          }
        } finally {
          await sftp.close();
        }
      } catch (_) {}
    }

    return '~';
  }

  /// Uploads a single file to [remoteDirectory] on the remote server.
  ///
  /// On Web, we stream through an SSH channel (`cat > file`) to prevent
  /// `dart2js` runtime errors with 64-bit integer accessors in SFTP packets.
  /// On native platforms, SFTP is used with automatic fallback.
  static Future<void> uploadFile({
    required SSHClient client,
    required String remoteDirectory,
    required FileTransferItem item,
    void Function(int bytesUploaded, int totalBytes)? onProgress,
    bool Function()? isCancelled,
  }) async {
    if (kIsWeb) {
      await _uploadViaExec(
        client: client,
        remoteDirectory: remoteDirectory,
        item: item,
        onProgress: onProgress,
        isCancelled: isCancelled,
      );
    } else {
      try {
        await _uploadViaSftp(
          client: client,
          remoteDirectory: remoteDirectory,
          item: item,
          onProgress: onProgress,
          isCancelled: isCancelled,
        );
      } catch (e) {
        if (e.toString().contains('Uint64') || e is UnsupportedError) {
          await _uploadViaExec(
            client: client,
            remoteDirectory: remoteDirectory,
            item: item,
            onProgress: onProgress,
            isCancelled: isCancelled,
          );
        } else {
          rethrow;
        }
      }
    }
  }

  /// Streams binary file data directly into an SSH execution process (`cat > file`).
  static Future<void> _uploadViaExec({
    required SSHClient client,
    required String remoteDirectory,
    required FileTransferItem item,
    void Function(int bytesUploaded, int totalBytes)? onProgress,
    bool Function()? isCancelled,
  }) async {
    var targetDir = remoteDirectory.trim();
    if (targetDir.isEmpty || targetDir == '~') {
      targetDir = await resolveCurrentDirectory(client);
    }

    if (targetDir.length > 1 && targetDir.endsWith('/')) {
      targetDir = targetDir.substring(0, targetDir.length - 1);
    }

    final remotePath = targetDir == '/' ? '/${item.name}' : '$targetDir/${item.name}';
    final escapedPath = remotePath.replaceAll("'", "'\\''");

    if (isCancelled?.call() == true) {
      throw Exception('Upload cancelled');
    }

    final session = await client.execute("cat > '$escapedPath'");
    const maxChunkSize = 32 * 1024;

    try {
      if (item.bytes != null) {
        final data = item.bytes!;
        final total = data.length;
        var bytesSent = 0;

        if (total == 0) {
          session.stdin.add(Uint8List(0));
          onProgress?.call(0, 0);
        } else {
          while (bytesSent < total) {
            if (isCancelled?.call() == true) {
              session.close();
              try {
                await client.execute("rm -f '$escapedPath'");
              } catch (_) {}
              throw Exception('Upload cancelled');
            }
            final chunkSize = min(total - bytesSent, maxChunkSize);
            final chunk = data.sublist(bytesSent, bytesSent + chunkSize);
            session.stdin.add(chunk);
            bytesSent += chunkSize;
            onProgress?.call(bytesSent, total);
            // Micro-yield to allow UI and websocket processing
            await Future.delayed(Duration.zero);
          }
        }
      } else if (!kIsWeb && item.localPath != null) {
        final file = File(item.localPath!);
        final raf = await file.open(mode: FileMode.read);
        try {
          final total = await file.length();
          var bytesSent = 0;
          if (total == 0) {
            session.stdin.add(Uint8List(0));
            onProgress?.call(0, 0);
          } else {
            while (bytesSent < total) {
              if (isCancelled?.call() == true) {
                session.close();
                try {
                  await client.execute("rm -f '$escapedPath'");
                } catch (_) {}
                throw Exception('Upload cancelled');
              }
              final chunkSize = min(total - bytesSent, maxChunkSize);
              final chunk = await raf.read(chunkSize);
              if (chunk.isEmpty) break;
              session.stdin.add(chunk);
              bytesSent += chunk.length;
              onProgress?.call(bytesSent, total);
              await Future.delayed(Duration.zero);
            }
          }
        } finally {
          await raf.close();
        }
      } else if (item.readStream != null) {
        var bytesSent = 0;
        final total = item.size;
        await for (final rawChunk in item.readStream!) {
          if (isCancelled?.call() == true) {
            session.close();
            try {
              await client.execute("rm -f '$escapedPath'");
            } catch (_) {}
            throw Exception('Upload cancelled');
          }
          final chunk = rawChunk is Uint8List ? rawChunk : Uint8List.fromList(rawChunk);
          if (chunk.isNotEmpty) {
            session.stdin.add(chunk);
            bytesSent += chunk.length;
            onProgress?.call(bytesSent, total > 0 ? total : bytesSent);
            await Future.delayed(Duration.zero);
          }
        }
        if (total > 0 && bytesSent < total) {
          onProgress?.call(total, total);
        }
      } else {
        throw Exception('No valid data source for ${item.name}');
      }

      await session.stdin.close();
      await session.done;

      if (session.exitCode != null && session.exitCode != 0) {
        throw Exception('Upload failed on server with exit code ${session.exitCode}');
      }
    } catch (e) {
      session.close();
      rethrow;
    }
  }

  /// Uploads a single file using the SFTP protocol.
  static Future<void> _uploadViaSftp({
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
        try {
          targetDir = await sftp.absolute('.');
        } catch (_) {
          targetDir = '.';
        }
      }

      if (targetDir.length > 1 && targetDir.endsWith('/')) {
        targetDir = targetDir.substring(0, targetDir.length - 1);
      }

      final remotePath = targetDir == '/' ? '/${item.name}' : '$targetDir/${item.name}';

      final remoteFile = await sftp.open(
        remotePath,
        mode: SftpFileOpenMode.create | SftpFileOpenMode.write | SftpFileOpenMode.truncate,
      );

      try {
        const maxChunkSize = 32 * 1024;

        if (item.bytes != null) {
          final data = item.bytes!;
          final total = data.length;
          var bytesSent = 0;

          if (total == 0) {
            await remoteFile.writeBytes(Uint8List(0), offset: 0);
            onProgress?.call(0, 0);
          } else {
            while (bytesSent < total) {
              if (isCancelled?.call() == true) {
                throw Exception('Upload cancelled');
              }
              final chunkSize = min(total - bytesSent, maxChunkSize);
              final chunk = data.sublist(bytesSent, bytesSent + chunkSize);
              await remoteFile.writeBytes(chunk, offset: bytesSent);
              bytesSent += chunkSize;
              onProgress?.call(bytesSent, total);
            }
          }
        } else if (!kIsWeb && item.localPath != null) {
          final file = File(item.localPath!);
          final raf = await file.open(mode: FileMode.read);
          try {
            final total = await file.length();
            var bytesSent = 0;
            if (total == 0) {
              await remoteFile.writeBytes(Uint8List(0), offset: 0);
              onProgress?.call(0, 0);
            } else {
              while (bytesSent < total) {
                if (isCancelled?.call() == true) {
                  throw Exception('Upload cancelled');
                }
                final chunkSize = min(total - bytesSent, maxChunkSize);
                final chunk = await raf.read(chunkSize);
                if (chunk.isEmpty) break;
                await remoteFile.writeBytes(chunk, offset: bytesSent);
                bytesSent += chunk.length;
                onProgress?.call(bytesSent, total);
              }
            }
          } finally {
            await raf.close();
          }
        } else if (item.readStream != null) {
          var bytesSent = 0;
          final total = item.size;
          await for (final rawChunk in item.readStream!) {
            if (isCancelled?.call() == true) {
              throw Exception('Upload cancelled');
            }
            final chunk = rawChunk is Uint8List ? rawChunk : Uint8List.fromList(rawChunk);
            if (chunk.isNotEmpty) {
              await remoteFile.writeBytes(chunk, offset: bytesSent);
              bytesSent += chunk.length;
              onProgress?.call(bytesSent, total > 0 ? total : bytesSent);
            }
          }
          if (total > 0 && bytesSent < total) {
            onProgress?.call(total, total);
          }
        } else {
          throw Exception('No valid data source for ${item.name}');
        }
      } finally {
        await remoteFile.close();
      }
    } finally {
      await sftp.close();
    }
  }
}
