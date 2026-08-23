import 'dart:async';
import 'dart:js_interop';
import 'package:web/web.dart' as web;
import '../file_transfer_service.dart';

Future<List<FileTransferItem>> platformPickFiles() async {
  final completer = Completer<List<FileTransferItem>>();
  final input = web.document.createElement('input') as web.HTMLInputElement;
  input.type = 'file';
  input.multiple = true;
  input.style.display = 'none';

  web.document.body?.appendChild(input);

  input.onchange = ((web.Event event) {
    final fileList = input.files;
    if (fileList == null || fileList.length == 0) {
      input.remove();
      if (!completer.isCompleted) {
        completer.complete([]);
      }
      return;
    }

    () async {
      try {
        final count = fileList.length;
        final items = <FileTransferItem>[];

        for (var i = 0; i < count; i++) {
          final file = fileList.item(i);
          if (file == null) continue;

          // Directly read binary ArrayBuffer from the browser File/Blob Promise
          final jsBuffer = await file.arrayBuffer().toDart;
          final bytes = jsBuffer.toDart.asUint8List();

          items.add(FileTransferItem(
            name: file.name,
            size: file.size,
            bytes: bytes,
          ));
        }

        input.remove();
        if (!completer.isCompleted) {
          completer.complete(items);
        }
      } catch (e) {
        input.remove();
        if (!completer.isCompleted) {
          completer.completeError(e);
        }
      }
    }();
  }.toJS);

  input.click();
  return completer.future;
}
