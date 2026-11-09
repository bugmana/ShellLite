import 'package:flutter/material.dart';
import '../providers/session_store.dart';
import '../services/file_picker/file_picker_service.dart';
import '../services/file_transfer_service.dart';

class FileUploadModal extends StatefulWidget {
  const FileUploadModal(
      {super.key,
      required this.session,
      required this.item,
      this.initialDirectory,
      this.destination,
      this.pickFile = AppFilePicker.pickFile});
  final OpenSession session;
  final FileTransferItem item;
  final String? initialDirectory;
  final UploadDestination? destination;
  final Future<FileTransferItem?> Function() pickFile;

  static Future<void> show(BuildContext context,
      {required OpenSession session,
      String? initialDirectory,
      Future<FileTransferItem?> Function() pickFile =
          AppFilePicker.pickFile}) async {
    try {
      final item = await pickFile();
      if (item == null || !context.mounted) return;
      await showModalBottomSheet<void>(
          context: context,
          isScrollControlled: true,
          isDismissible: false,
          enableDrag: false,
          builder: (_) => FileUploadModal(
              session: session,
              item: item,
              initialDirectory: initialDirectory,
              pickFile: pickFile));
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Could not choose a file. Try again.')));
      }
    }
  }

  @override
  State<FileUploadModal> createState() => _FileUploadModalState();
}

class _FileUploadModalState extends State<FileUploadModal> {
  late FileTransferItem _item;
  late final TextEditingController _folder;
  bool _busy = false,
      _cancelled = false,
      _complete = false,
      _finalizing = false;
  int _uploaded = 0;
  String? _error;
  @override
  void initState() {
    super.initState();
    _item = widget.item;
    _folder = TextEditingController(text: widget.initialDirectory ?? '~');
    if (widget.initialDirectory == null) _loadHome();
  }

  Future<void> _loadHome() async {
    try {
      final client = widget.session.sshService.client;
      final home = widget.destination != null
          ? await widget.destination!.home()
          : client != null
              ? await FileTransferService.resolveHomeDirectory(client)
              : throw StateError('Not connected');
      if (mounted && _folder.text == '~') setState(() => _folder.text = home);
    } catch (_) {
      if (mounted) {
        setState(() => _error =
            'Could not find the home directory. Enter an absolute path.');
      }
    }
  }

  @override
  void dispose() {
    _cancelled = true;
    _folder.dispose();
    super.dispose();
  }

  Future<bool> _confirmReplace(String path) async {
    if (!mounted || _cancelled) return false;
    return await showDialog<bool>(
            context: context,
            builder: (dialogContext) => AlertDialog(
                  title: Text(
                      'Replace “${FileTransferService.sanitizeFileName(_item.name)}”?'),
                  content: Text('A file already exists at $path.'),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(dialogContext, false),
                        child: const Text('Cancel')),
                    TextButton(
                        style: TextButton.styleFrom(
                            foregroundColor:
                                Theme.of(dialogContext).colorScheme.error),
                        onPressed: () => Navigator.pop(dialogContext, true),
                        child: const Text('Replace')),
                  ],
                )) ??
        false;
  }

  Future<void> _upload() async {
    if (_busy) return;
    final path = _folder.text.trim();
    if (!(path.startsWith('/') || path == '~' || path.startsWith('~/'))) {
      setState(() => _error = 'Enter an absolute path or ~/folder');
      return;
    }
    setState(() {
      _busy = true;
      _cancelled = false;
      _error = null;
      _uploaded = 0;
      _finalizing = false;
    });
    try {
      void progress(int sent, int total) {
        if (mounted && !_cancelled) setState(() => _uploaded = sent);
      }

      if (widget.destination != null) {
        await FileTransferService.uploadTo(
            destination: widget.destination!,
            remoteDirectory: path,
            item: _item,
            onProgress: progress,
            isCancelled: () => _cancelled,
            confirmReplace: _confirmReplace,
            onFinalizing: () {
              if (mounted) setState(() => _finalizing = true);
            });
      } else {
        final client = widget.session.sshService.client;
        if (client == null || !widget.session.sshService.isConnected) {
          throw StateError('Not connected');
        }
        await FileTransferService.uploadFile(
            client: client,
            remoteDirectory: path,
            item: _item,
            onProgress: progress,
            isCancelled: () => _cancelled,
            confirmReplace: _confirmReplace,
            onFinalizing: () {
              if (mounted) setState(() => _finalizing = true);
            });
      }
      if (mounted) {
        setState(() {
          _complete = true;
          _busy = false;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = _cancelled || error is UploadCancelled
              ? 'Upload cancelled'
              : 'Upload failed. ${error.toString().replaceFirst('Bad state: ', '')}';
        });
      }
    }
  }

  Future<void> _chooseAnother() async {
    try {
      final file = await widget.pickFile();
      if (file != null && mounted) {
        setState(() {
          _item = file;
          _error = null;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Could not choose a file. Try again.');
      }
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
      canPop: !_busy,
      child: SafeArea(
          child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
            20, 16, 20, MediaQuery.viewInsetsOf(context).bottom + 20),
        child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(children: [
                Expanded(
                    child: Semantics(
                        header: true,
                        child: Text('Upload file',
                            style: Theme.of(context).textTheme.titleLarge))),
                IconButton(
                    tooltip: 'Close',
                    onPressed: _busy ? null : () => Navigator.pop(context),
                    icon: const Icon(Icons.close))
              ]),
              Text(_item.name),
              Text(_item.formattedSize),
              const SizedBox(height: 16),
              Semantics(
                  key: const Key('upload_status'),
                  liveRegion: true,
                  container: true,
                  child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                          _error ??
                              (_complete
                                  ? 'Upload complete'
                                  : _finalizing
                                      ? 'Finishing upload…'
                                      : _busy
                                          ? 'Uploading…'
                                          : ''),
                          style: _error == null
                              ? null
                              : TextStyle(
                                  color:
                                      Theme.of(context).colorScheme.error)))),
              if (_complete) ...[
                Text('Destination: ${_folder.text}'),
                FilledButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Done')),
              ] else ...[
                TextField(
                    controller: _folder,
                    enabled: !_busy,
                    autocorrect: false,
                    decoration: const InputDecoration(
                        labelText: 'Destination folder',
                        helperText: '~ is your home directory')),
                if (_busy) ...[
                  const SizedBox(height: 16),
                  LinearProgressIndicator(
                      value: _item.size == 0
                          ? null
                          : (_uploaded / _item.size).clamp(0, 1)),
                  Text(
                      '${FileTransferService.formatBytes(_uploaded)} / ${_item.formattedSize}'),
                  TextButton(
                      onPressed: _cancelled || _finalizing
                          ? null
                          : () => setState(() => _cancelled = true),
                      child: Text(_cancelled ? 'Cancelling…' : 'Cancel')),
                ] else ...[
                  TextButton(
                      onPressed: _chooseAnother,
                      child: const Text('Choose another file')),
                  FilledButton(onPressed: _upload, child: const Text('Upload')),
                ],
              ],
            ]),
      )));
}
