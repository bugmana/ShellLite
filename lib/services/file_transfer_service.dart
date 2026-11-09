import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:dartssh2/dartssh2.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

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
        final chunk =
            rawChunk is Uint8List ? rawChunk : Uint8List.fromList(rawChunk);
        if (chunk.isNotEmpty) {
          yield chunk;
        }
      }
    } else {
      throw Exception('No valid data source for $name');
    }
  }
}

class FileTransferService {
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

  static Future<String> resolveHomeDirectory(SSHClient client) async {
    try {
      final session = await client.execute(r'''printf '%s\n' "$HOME"''');
      final errors = session.stderr.drain<void>();
      final output = (await utf8.decodeStream(session.stdout)).trim();
      await errors;
      await session.done;
      if (session.exitCode == 0 && output.startsWith('/')) return output;
    } catch (_) {/* SFTP-only servers may not allow exec. */}
    if (!kIsWeb) {
      final sftp = await client.sftp();
      try {
        return await sftp.absolute('.');
      } finally {
        await sftp.close();
      }
    }
    throw StateError(
        'Could not find the home directory. Enter an absolute path.');
  }

  static Future<String> resolveDestination(
      String input, Future<String> Function() home) async {
    final value = input.trim();
    if (value.contains('\x00')) {
      throw const FormatException('Invalid destination folder');
    }
    if (value.isEmpty || value == '~') return home();
    if (value.startsWith('~/')) return '${await home()}/${value.substring(2)}';
    if (!value.startsWith('/')) {
      throw const FormatException('Enter an absolute path or ~/folder');
    }
    return value;
  }

  static Future<void> uploadFile({
    required SSHClient client,
    required String remoteDirectory,
    required FileTransferItem item,
    void Function(int, int)? onProgress,
    bool Function()? isCancelled,
    Future<bool> Function(String)? confirmReplace,
    VoidCallback? onFinalizing,
  }) =>
      uploadTo(
          destination: _SshUploadDestination(client),
          remoteDirectory: remoteDirectory,
          item: item,
          onProgress: onProgress,
          isCancelled: isCancelled,
          confirmReplace: confirmReplace,
          onFinalizing: onFinalizing);

  static Future<void> uploadTo({
    required UploadDestination destination,
    required String remoteDirectory,
    required FileTransferItem item,
    void Function(int, int)? onProgress,
    bool Function()? isCancelled,
    Future<bool> Function(String)? confirmReplace,
    VoidCallback? onFinalizing,
  }) async {
    final directory =
        await resolveDestination(remoteDirectory, destination.home);
    final prefix = directory.endsWith('/') ? directory : '$directory/';
    final path = '$prefix${sanitizeFileName(item.name)}';
    final temporary = '$prefix.shelllite-${const Uuid().v4()}.part';
    var confirmed = false;
    void checkCancelled() {
      if (isCancelled?.call() == true) throw const UploadCancelled();
    }

    checkCancelled();
    if (await destination.exists(path)) {
      confirmed = await confirmReplace?.call(path) ?? false;
      if (!confirmed) throw const UploadCancelled();
    }
    checkCancelled();
    try {
      await destination.write(temporary, item, onProgress, isCancelled);
      checkCancelled();
      if (!confirmed && await destination.exists(path)) {
        confirmed = await confirmReplace?.call(path) ?? false;
        if (!confirmed) throw const UploadCancelled();
      }
      checkCancelled();
      onFinalizing?.call();
      await destination.publish(temporary, path, confirmed);
    } finally {
      // Only the staging path belongs to this upload. Never delete the target.
      try {
        await destination.remove(temporary);
      } catch (_) {/* Best effort after disconnect. */}
    }
  }

  static String quoteRemotePath(String path) =>
      "'${path.replaceAll("'", "'\\''")}'";

  // The directory guard avoids mv/ln treating the target as a container.
  // Use POSIX utility options so BSD and Linux SSH servers both work.
  @visibleForTesting
  static String publishCommand(String temporary, String path,
          {required bool replace}) =>
      'if test -d ${quoteRemotePath(path)}; then exit 2; fi; '
      '${replace ? 'mv -f' : 'ln'} ${quoteRemotePath(temporary)} ${quoteRemotePath(path)}';

  /// Sanitizes a filename to protect against path traversal attacks (SEC-INJECT-01).
  /// Strips directory paths (POSIX and Windows separators), null bytes, and traversal tokens ('..').
  static String sanitizeFileName(String fileName) {
    var name = fileName.split('/').last.split(r'\').last.trim();
    name = name.replaceAll('\x00', '').replaceAll('..', '');
    if (name.isEmpty || name == '.' || name == '..') {
      return 'upload_${DateTime.now().millisecondsSinceEpoch}';
    }
    return name;
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
      targetDir = await resolveHomeDirectory(client);
    }

    if (targetDir.length > 1 && targetDir.endsWith('/')) {
      targetDir = targetDir.substring(0, targetDir.length - 1);
    }

    final safeName = sanitizeFileName(item.name);
    final remotePath = targetDir == '/' ? '/$safeName' : '$targetDir/$safeName';
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
        throw StateError(
            'The file could not be read completely. Choose it again.');
      }

      await session.stdin.close();
      await session.done;

      if (session.exitCode != null && session.exitCode != 0) {
        throw Exception(
            'Upload failed on server with exit code ${session.exitCode}');
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

      final safeName = sanitizeFileName(item.name);
      final remotePath =
          targetDir == '/' ? '/$safeName' : '$targetDir/$safeName';

      final remoteFile = await sftp.open(
        remotePath,
        mode: SftpFileOpenMode.create |
            SftpFileOpenMode.write |
            SftpFileOpenMode.truncate,
      );

      try {
        const maxChunkSize = 32 * 1024;
        var bytesSent = 0;
        final total = item.size;

        await for (final chunk
            in item.openChunkStream(chunkSize: maxChunkSize)) {
          if (isCancelled?.call() == true) {
            throw Exception('Upload cancelled');
          }

          await remoteFile.writeBytes(chunk, offset: bytesSent);
          bytesSent += chunk.length;
          onProgress?.call(bytesSent, total > 0 ? total : bytesSent);
        }

        if (total > 0 && bytesSent < total) {
          throw StateError(
              'The file could not be read completely. Choose it again.');
        }
      } finally {
        await remoteFile.close();
      }
    } finally {
      await sftp.close();
    }
  }
}

class UploadCancelled implements Exception {
  const UploadCancelled();
  @override
  String toString() => 'Upload cancelled';
}

abstract class UploadDestination {
  Future<String> home();
  Future<bool> exists(String path);
  Future<void> write(String path, FileTransferItem item,
      void Function(int, int)? onProgress, bool Function()? isCancelled);
  Future<void> publish(String temporary, String path, bool replace);
  Future<void> remove(String path);
}

class _SshUploadDestination implements UploadDestination {
  _SshUploadDestination(this.client);
  final SSHClient client;
  String quote(String value) => "'${value.replaceAll("'", "'\\''")}'";
  Future<int?> command(String command) async {
    final session = await client.execute(command);
    final output = session.stdout.drain<void>();
    final errors = session.stderr.drain<void>();
    await Future.wait([output, errors]);
    await session.done;
    return session.exitCode;
  }

  @override
  Future<String> home() => FileTransferService.resolveHomeDirectory(client);
  @override
  Future<bool> exists(String path) async {
    if (!kIsWeb) {
      final sftp = await client.sftp();
      try {
        final attrs = await sftp.stat(path, followLink: false);
        if (attrs.isDirectory) {
          throw StateError(
              'A folder already exists at the destination. Choose another folder.');
        }
        return true;
      } on SftpStatusError catch (error) {
        if (error.code == 2) return false;
        rethrow;
      } finally {
        await sftp.close();
      }
    }
    final code = await command(
        'if test -d ${quote(path)}; then exit 2; elif test -e ${quote(path)} || test -L ${quote(path)}; then exit 0; else exit 1; fi');
    if (code == 0) return true;
    if (code == 1) return false;
    if (code == 2) {
      throw StateError(
          'A folder already exists at the destination. Choose another folder.');
    }
    throw StateError('Could not check destination');
  }

  @override
  Future<void> write(String path, FileTransferItem item,
      void Function(int, int)? onProgress, bool Function()? isCancelled) async {
    final slash = path.lastIndexOf('/');
    final staged = FileTransferItem(
        name: path.substring(slash + 1),
        size: item.size,
        bytes: item.bytes,
        localPath: item.localPath,
        readStream: item.readStream);
    Future<void> viaExec() => FileTransferService._uploadViaExec(
        client: client,
        remoteDirectory: slash == 0 ? '/' : path.substring(0, slash),
        item: staged,
        onProgress: onProgress,
        isCancelled: isCancelled);
    if (kIsWeb) {
      await viaExec();
      return;
    }
    try {
      await FileTransferService._uploadViaSftp(
          client: client,
          remoteDirectory: slash == 0 ? '/' : path.substring(0, slash),
          item: staged,
          onProgress: onProgress,
          isCancelled: isCancelled);
    } catch (error) {
      if ((error is UnsupportedError || error.toString().contains('Uint64')) &&
          (item.bytes != null || item.localPath != null)) {
        await viaExec();
      } else {
        rethrow;
      }
    }
  }

  @override
  Future<void> publish(String temporary, String path, bool replace) async {
    if (!kIsWeb) {
      final sftp = await client.sftp();
      try {
        if (!replace && await exists(path)) {
          throw StateError('Destination changed. Try again.');
        }
        await sftp.rename(temporary, path);
      } finally {
        await sftp.close();
      }
    } else {
      final action =
          FileTransferService.publishCommand(temporary, path, replace: replace);
      if (await command(action) != 0) {
        throw StateError('Could not finish upload. Check the destination.');
      }
    }
  }

  @override
  Future<void> remove(String path) async {
    if (!kIsWeb) {
      final sftp = await client.sftp();
      try {
        await sftp.remove(path);
      } finally {
        await sftp.close();
      }
    } else {
      await command('rm -f -- ${quote(path)}');
    }
  }
}
