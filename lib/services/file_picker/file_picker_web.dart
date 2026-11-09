import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';
import 'package:web/web.dart' as web;
import '../file_transfer_service.dart';

Future<FileTransferItem?> platformPickFile() {
  final result = Completer<FileTransferItem?>();
  final input = web.HTMLInputElement()
    ..type = 'file'
    ..multiple = false;
  input.style.display = 'none';
  void finish(FileTransferItem? item) {
    input.remove();
    if (!result.isCompleted) result.complete(item);
  }

  input.oncancel = ((web.Event _) => finish(null)).toJS;
  input.onchange = ((web.Event _) {
    () async {
      try {
        final file = input.files?.item(0);
        if (file == null) {
          finish(null);
          return;
        }
        final buffer = await file.arrayBuffer().toDart;
        finish(FileTransferItem(
            name: file.name,
            size: file.size,
            bytes: Uint8List.fromList(buffer.toDart.asUint8List())));
      } catch (error, stack) {
        input.remove();
        if (!result.isCompleted) result.completeError(error, stack);
      }
    }();
  }).toJS;
  web.document.body?.appendChild(input);
  input.click();
  return result.future;
}
