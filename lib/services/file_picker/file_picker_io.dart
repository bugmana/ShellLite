import 'package:file_picker/file_picker.dart';
import '../file_transfer_service.dart';

Future<List<FileTransferItem>> platformPickFiles() async {
  final result = await FilePicker.pickFiles(
    allowMultiple: true,
    withReadStream: true,
  );

  if (result == null || result.files.isEmpty) {
    return [];
  }

  return result.files
      .map(
        (f) => FileTransferItem(
          name: f.name,
          size: f.size,
          localPath: f.path,
          bytes: f.bytes,
          readStream: f.readStream,
        ),
      )
      .toList();
}
