import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:shell_lite/services/file_transfer_service.dart';

void main() {
  group('FileTransferService formatBytes', () {
    test('formats zero and negative bytes', () {
      expect(FileTransferService.formatBytes(0), '0 B');
      expect(FileTransferService.formatBytes(-50), '0 B');
    });

    test('formats bytes under 1KB', () {
      expect(FileTransferService.formatBytes(1), '1 B');
      expect(FileTransferService.formatBytes(512), '512 B');
      expect(FileTransferService.formatBytes(1023), '1023 B');
    });

    test('formats kilobytes correctly', () {
      expect(FileTransferService.formatBytes(1024), '1.0 KB');
      expect(FileTransferService.formatBytes(1536), '1.5 KB');
      expect(FileTransferService.formatBytes(10240), '10 KB');
      expect(FileTransferService.formatBytes(500 * 1024), '500 KB');
    });

    test('formats megabytes correctly', () {
      expect(FileTransferService.formatBytes(1024 * 1024), '1.0 MB');
      expect(FileTransferService.formatBytes((2.5 * 1024 * 1024).round()), '2.5 MB');
      expect(FileTransferService.formatBytes(15 * 1024 * 1024), '15 MB');
    });

    test('formats gigabytes correctly', () {
      expect(FileTransferService.formatBytes(1024 * 1024 * 1024), '1.0 GB');
      expect(FileTransferService.formatBytes((3.7 * 1024 * 1024 * 1024).round()), '3.7 GB');
    });
  });

  group('FileTransferItem', () {
    test('creates item with bytes and provides formattedSize', () {
      final item = FileTransferItem(
        name: 'test_script.sh',
        size: 2048,
        bytes: Uint8List.fromList([1, 2, 3]),
      );

      expect(item.name, 'test_script.sh');
      expect(item.size, 2048);
      expect(item.formattedSize, '2.0 KB');
      expect(item.bytes, isNotNull);
    });

    test('creates item with localPath', () {
      const item = FileTransferItem(
        name: 'document.pdf',
        size: 10485760,
        localPath: '/tmp/document.pdf',
      );

      expect(item.name, 'document.pdf');
      expect(item.size, 10485760);
      expect(item.formattedSize, '10 MB');
      expect(item.localPath, '/tmp/document.pdf');
    });
  });

  group('FileUploadProgress', () {
    test('holds upload progress details', () {
      const progress = FileUploadProgress(
        fileName: 'package.tar.gz',
        bytesUploaded: 524288,
        totalBytes: 1048576,
        percentage: 0.5,
        isComplete: false,
      );

      expect(progress.fileName, 'package.tar.gz');
      expect(progress.bytesUploaded, 524288);
      expect(progress.totalBytes, 1048576);
      expect(progress.percentage, 0.5);
      expect(progress.isComplete, isFalse);
      expect(progress.error, isNull);
    });
  });
}
