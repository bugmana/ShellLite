import 'dart:async';
import 'package:shell_lite/services/file_transfer_service.dart';

class MemoryUploadDestination implements UploadDestination {
  final files = <String, List<int>>{};
  final removed = <String>[];
  final writes = <String>[];
  bool failWrite = false;
  bool failHome = false;
  void Function()? duringWrite;
  Completer<void>? block;
  Completer<void>? publishBlock;
  @override
  Future<String> home() async {
    if (failHome) throw StateError('home unavailable');
    return '/home/user';
  }

  @override
  Future<bool> exists(String path) async => files.containsKey(path);
  @override
  Future<void> write(String path, FileTransferItem item,
      void Function(int, int)? progress, bool Function()? cancelled) async {
    writes.add(path);
    files[path] = [];
    await for (final chunk in item.openChunkStream()) {
      files[path]!.addAll(chunk);
      progress?.call(files[path]!.length, item.size);
      duringWrite?.call();
      if (block != null) await block!.future;
      if (failWrite) throw StateError('Connection lost');
      if (cancelled?.call() == true) throw const UploadCancelled();
    }
  }

  @override
  Future<void> publish(String temporary, String path, bool replace) async {
    if (publishBlock != null) await publishBlock!.future;
    if (!replace && files.containsKey(path)) throw StateError('File exists');
    files[path] = files.remove(temporary)!;
  }

  @override
  Future<void> remove(String path) async {
    removed.add(path);
    files.remove(path);
  }
}
