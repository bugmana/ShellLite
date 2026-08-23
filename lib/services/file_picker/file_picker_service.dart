import '../file_transfer_service.dart';
import 'file_picker_stub.dart'
    if (dart.library.js_interop) 'file_picker_web.dart'
    if (dart.library.io) 'file_picker_io.dart';

/// Cross-platform file picker service providing native file dialogs
/// across Android, iOS, macOS, Windows, Linux, and pure DOM file selection on Web.
class AppFilePicker {
  static Future<List<FileTransferItem>> pickFiles() {
    return platformPickFiles();
  }
}
