import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';
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

    final count = fileList.length;
    final items = <FileTransferItem>[];
    var loaded = 0;

    for (var i = 0; i < count; i++) {
      final file = fileList.item(i);
      if (file == null) continue;

      final reader = web.FileReader();
      reader.onloadend = ((web.ProgressEvent e) {
        final result = reader.result;
        Uint8List? bytes;
        if (result != null && result.isA<JSArrayBuffer>()) {
          bytes = (result as JSArrayBuffer).toDart.asUint8List();
        }
        items.add(FileTransferItem(
          name: file.name,
          size: file.size,
          bytes: bytes,
        ));
        loaded++;
        if (loaded == count && !completer.isCompleted) {
          input.remove();
          completer.complete(items);
        }
      }.toJS);

      reader.onerror = ((web.Event e) {
        loaded++;
        if (loaded == count && !completer.isCompleted) {
          input.remove();
          completer.complete(items);
        }
      }.toJS);

      reader.readAsArrayBuffer(file);
    }
  }.toJS);

  input.click();
  return completer.future;
}
