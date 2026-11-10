import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:shell_lite/services/file_transfer_service.dart';
import '../support/upload_destination.dart';

void main() {
  FileTransferItem file([int size = 3]) =>
      FileTransferItem(name: 'file.txt', size: size, bytes: Uint8List(size));
  test('resolves home forms and rejects relative paths', () async {
    Future<String> home() async => '/home/user';
    expect(
        await FileTransferService.resolveDestination('~', home), '/home/user');
    expect(await FileTransferService.resolveDestination('~/files', home),
        '/home/user/files');
    expect(await FileTransferService.resolveDestination('/tmp', home), '/tmp');
    await expectLater(FileTransferService.resolveDestination('files', home),
        throwsFormatException);
    await expectLater(
        FileTransferService.resolveDestination('/tmp\x00bad', home),
        throwsFormatException);
  });
  test('zero-byte upload uses staging then commits at root', () async {
    final remote = MemoryUploadDestination();
    await FileTransferService.uploadTo(
        destination: remote, remoteDirectory: '/', item: file(0));
    expect(remote.files, {'/file.txt': []});
    expect(remote.writes.single, startsWith('/.shelllite-'));
    expect(remote.removed.single, isNot('/file.txt'));
  });

  test('transfer error preserves old destination and removes only staging',
      () async {
    final remote = MemoryUploadDestination()
      ..files['/tmp/file.txt'] = [9]
      ..failWrite = true;
    await expectLater(
        FileTransferService.uploadTo(
            destination: remote,
            remoteDirectory: '/tmp',
            item: file(),
            confirmReplace: (_) async => true),
        throwsStateError);
    expect(remote.files, {
      '/tmp/file.txt': [9]
    });
    expect(remote.removed.single, remote.writes.single);
  });
  test('new conflict during transfer also requires confirmation', () async {
    final remote = MemoryUploadDestination();
    remote.duringWrite = () => remote.files['/tmp/file.txt'] = [9];
    var asked = false;
    await expectLater(
        FileTransferService.uploadTo(
            destination: remote,
            remoteDirectory: '/tmp',
            item: file(),
            confirmReplace: (_) async {
              asked = true;
              return false;
            }),
        throwsA(isA<UploadCancelled>()));
    expect(asked, isTrue);
    expect(remote.files, {
      '/tmp/file.txt': [9]
    });
  });
  test('cancellation preserves old file even after approving replacement',
      () async {
    final remote = MemoryUploadDestination()..files['/tmp/file.txt'] = [9];
    var cancelled = false;
    remote.duringWrite = () => cancelled = true;
    await expectLater(
        FileTransferService.uploadTo(
            destination: remote,
            remoteDirectory: '/tmp',
            item: file(),
            confirmReplace: (_) async => true,
            isCancelled: () => cancelled),
        throwsA(isA<UploadCancelled>()));
    expect(remote.files, {
      '/tmp/file.txt': [9]
    });
  });
}
