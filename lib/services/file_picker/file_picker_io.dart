import 'package:file_picker/file_picker.dart';
import '../file_transfer_service.dart';

Future<FileTransferItem?> platformPickFile() async {
  final file = await FilePicker.pickFile();
  if (file == null) return null;
  return FileTransferItem(
      name: file.name,
      size: await file.length(),
      localPath: file.path,
      readStream: file.readAsByteStream());
}
