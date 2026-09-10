import 'package:file_picker/file_picker.dart';
import '../file_transfer_service.dart';

Future<List<FileTransferItem>> platformPickFiles() async {
  final files = await FilePicker.pickFiles();
  if (files.isEmpty) {
    return [];
  }

  final items = <FileTransferItem>[];
  for (final f in files) {
    final size = f.lengthSync() ?? await f.length();
    items.add(
      FileTransferItem(
        name: f.name,
        size: size,
        localPath: f.path,
        readStream: f.readAsByteStream(),
      ),
    );
  }
  return items;
}
