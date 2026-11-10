import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:shell_lite/services/file_transfer_service.dart';

void main() {
  late Directory directory;
  setUp(() async =>
      directory = await Directory.systemTemp.createTemp('shelllite publish '));
  tearDown(() async => directory.delete(recursive: true));
  test('directory collisions preserve staging with either replacement choice',
      () async {
    for (final replace in [false, true]) {
      final source = File("${directory.path}/.upload's.part")
        ..writeAsStringSync('new contents');
      final target = Directory('${directory.path}/destination')..createSync();
      final result = await Process.run('sh', [
        '-c',
        FileTransferService.publishCommand(source.path, target.path,
            replace: replace)
      ]);
      expect(result.exitCode, isNot(0));
      expect(source.readAsStringSync(), 'new contents');
      expect(target.listSync(), isEmpty);
    }
  });
  test('quoted file targets respect both replacement choices', () async {
    for (final replace in [false, true]) {
      final source = File("${directory.path}/.upload's.part")
        ..writeAsStringSync('new contents');
      final target = File("${directory.path}/report's file.txt")
        ..writeAsStringSync('old contents');
      final result = await Process.run('sh', [
        '-c',
        FileTransferService.publishCommand(source.path, target.path,
            replace: replace)
      ]);
      expect(result.exitCode == 0, replace);
      expect(
          target.readAsStringSync(), replace ? 'new contents' : 'old contents');
      expect(source.existsSync(), !replace);
    }
  });
}
