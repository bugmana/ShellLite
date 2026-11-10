import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shell_lite/models/auth_method.dart';
import 'package:shell_lite/models/server_profile.dart';
import 'package:shell_lite/providers/session_store.dart';
import 'package:shell_lite/services/file_transfer_service.dart';
import 'package:shell_lite/services/ssh_service.dart';
import 'package:shell_lite/widgets/file_upload_modal.dart';
import 'package:xterm/xterm.dart';
import '../support/upload_destination.dart';

void main() {
  late OpenSession session;
  late MemoryUploadDestination destination;
  late FileTransferItem item;
  setUp(() {
    session = OpenSession(
        id: 'test',
        profile: ServerProfile(
            displayName: 'Server',
            host: 'host',
            username: 'user',
            authMethod: const PasswordAuth(credentialTag: 'cred')),
        terminal: Terminal(),
        controller: TerminalController(),
        sshService: SSHService());
    destination = MemoryUploadDestination();
    item = FileTransferItem(
        name: 'hello.txt', size: 3, bytes: Uint8List.fromList([1, 2, 3]));
  });
  Widget build({Future<FileTransferItem?> Function()? picker}) => MaterialApp(
      home: Scaffold(
          body: FileUploadModal(
              session: session,
              item: item,
              destination: destination,
              pickFile: picker ?? () async => null)));

  testWidgets('shows one file, home folder and completion until Done',
      (tester) async {
    final semantics = tester.ensureSemantics();
    try {
      await tester.pumpWidget(build());
      await tester.pumpAndSettle();
      expect(find.text('hello.txt'), findsOneWidget);
      expect(find.text('/home/user'), findsOneWidget);
      await tester.tap(find.text('Upload'));
      await tester.pumpAndSettle();
      expect(destination.files['/home/user/hello.txt'], [1, 2, 3]);
      expect(find.text('Upload complete'), findsOneWidget);
      await tester.pump(const Duration(seconds: 3));
      expect(find.text('Done'), findsOneWidget);
      expect(session.terminal.buffer.getText(), isNot(contains('Uploaded')));
      final status = tester
          .getSemantics(find.byKey(const Key('upload_status')))
          .getSemanticsData();
      expect(status.flagsCollection.isLiveRegion, isTrue);
      expect(status.label, 'Upload complete');
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('finishing upload cannot accept a cancellation it cannot honor',
      (tester) async {
    destination.publishBlock = Completer<void>();
    await tester.pumpWidget(build());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Upload'));
    await tester.pump();
    expect(find.text('Finishing upload…'), findsOneWidget);
    final finishButton =
        tester.widget<TextButton>(find.widgetWithText(TextButton, 'Cancel'));
    expect(finishButton.onPressed, isNull);
    destination.publishBlock!.complete();
    await tester.pumpAndSettle();
    expect(find.text('Upload complete'), findsOneWidget);
  });
}
