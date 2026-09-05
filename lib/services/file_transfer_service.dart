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

  /// Yields binary data chunks for upload without loading entire local files into RAM.
  Stream<Uint8List> openChunkStream({int chunkSize = 32 * 1024}) async* {
    if (bytes != null) {
      final data = bytes!;
      final total = data.length;
      if (total == 0) {
        yield Uint8List(0);
        return;
      }
      var offset = 0;
      while (offset < total) {
        final length = min(total - offset, chunkSize);
        yield data.sublist(offset, offset + length);
        offset += length;
      }
    } else if (!kIsWeb && localPath != null) {
      final file = File(localPath!);
      final raf = await file.open(mode: FileMode.read);
      try {
        final total = await file.length();
        if (total == 0) {
          yield Uint8List(0);
          return;
        }
        while (true) {
          final chunk = await raf.read(chunkSize);
          if (chunk.isEmpty) break;
          yield chunk;
        }
      } finally {
        await raf.close();
      }
    } else if (readStream != null) {
      await for (final rawChunk in readStream!) {
        final chunk = rawChunk is Uint8List ? rawChunk : Uint8List.fromList(rawChunk);
        if (chunk.isNotEmpty) {
          yield chunk;
        }
      }
    } else {
      throw Exception('No valid data source for $name');
    }
  }
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
      var bytesSent = 0;
      final total = item.size;

      await for (final chunk in item.openChunkStream(chunkSize: maxChunkSize)) {
        if (isCancelled?.call() == true) {
          session.close();
          try {
            await client.execute("rm -f '$escapedPath'");
          } catch (_) {}
          throw Exception('Upload cancelled');
        }

        session.stdin.add(chunk);
        bytesSent += chunk.length;
        onProgress?.call(bytesSent, total > 0 ? total : bytesSent);
        await Future.delayed(Duration.zero);
      }

      if (total > 0 && bytesSent < total) {
        onProgress?.call(total, total);
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
        var bytesSent = 0;
        final total = item.size;

        await for (final chunk in item.openChunkStream(chunkSize: maxChunkSize)) {
          if (isCancelled?.call() == true) {
            throw Exception('Upload cancelled');
          }

          await remoteFile.writeBytes(chunk, offset: bytesSent);
          bytesSent += chunk.length;
          onProgress?.call(bytesSent, total > 0 ? total : bytesSent);
        }

        if (total > 0 && bytesSent < total) {
          onProgress?.call(total, total);
        }
      } finally {
        await remoteFile.close();
      }
    } finally {
      await sftp.close();
    }
  }
}
