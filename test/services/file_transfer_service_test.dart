import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:shell_lite/services/file_transfer_service.dart';

void main() {
  test(
      'file sources preserve bytes and chunk boundaries, including empty files',
      () async {
    final data = Uint8List.fromList(List.generate(100, (i) => i));
    final bytes =
        FileTransferItem(name: 'bytes', size: data.length, bytes: data);
    final chunks = await bytes.openChunkStream(chunkSize: 40).toList();
    expect(chunks.map((chunk) => chunk.length), [40, 40, 20]);
    expect(chunks.expand((chunk) => chunk), data);
    final streamed = FileTransferItem(
        name: 'stream',
        size: 5,
        readStream: Stream.fromIterable([
          [1, 2],
          [3, 4, 5]
        ]));
    expect(await streamed.openChunkStream().toList(), [
      [1, 2],
      [3, 4, 5]
    ]);
    final empty = FileTransferItem(name: 'empty', size: 0, bytes: Uint8List(0));
    expect(await empty.openChunkStream().toList(), [isEmpty]);
  });

  test('upload names cannot retain paths, traversal, or null bytes', () {
    for (final entry in {
      'document.pdf': 'document.pdf',
      '/etc/shadow': 'shadow',
      '../../root/.ssh/authorized_keys': 'authorized_keys',
      r'C:\Windows\System32\cmd.exe': 'cmd.exe',
      r'..\..\Windows\cmd.exe': 'cmd.exe',
      '..test..file..\x00.sh': 'testfile.sh',
    }.entries) {
      expect(FileTransferService.sanitizeFileName(entry.key), entry.value);
    }
    for (final name in ['', '..']) {
      expect(FileTransferService.sanitizeFileName(name), startsWith('upload_'));
    }
  });
}
