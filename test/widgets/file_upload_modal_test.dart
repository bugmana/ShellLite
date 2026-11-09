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
  });
  for (final replace in [false, true]) {
    testWidgets('replacement confirmation replace=$replace', (tester) async {
      destination.files['/home/user/hello.txt'] = [9];
      await tester.pumpWidget(build());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Upload'));
      await tester.pumpAndSettle();
      expect(find.text('Replace “hello.txt”?'), findsOneWidget);
      await tester.tap(find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text(replace ? 'Replace' : 'Cancel')));
      await tester.pumpAndSettle();
      expect(
          destination.files['/home/user/hello.txt'], replace ? [1, 2, 3] : [9]);
    });
  }
  testWidgets('picker cancellation opens no sheet', (tester) async {
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: Builder(
                builder: (context) => TextButton(
                    onPressed: () => FileUploadModal.show(context,
                        session: session, pickFile: () async => null),
                    child: const Text('Choose'))))));
    await tester.tap(find.text('Choose'));
    await tester.pumpAndSettle();
    expect(find.byType(FileUploadModal), findsNothing);
  });
  testWidgets('can choose another file', (tester) async {
    await tester.pumpWidget(build(
        picker: () async =>
            FileTransferItem(name: 'other.txt', size: 0, bytes: Uint8List(0))));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Choose another file'));
    await tester.pumpAndSettle();
    expect(find.text('other.txt'), findsOneWidget);
    expect(find.text('hello.txt'), findsNothing);
  });
  testWidgets(
      'home failure permits explicit folder and failed transfer retains controls',
      (tester) async {
    destination.failHome = true;
    destination.failWrite = true;
    await tester.pumpWidget(build());
    await tester.pumpAndSettle();
    expect(find.textContaining('Could not find the home'), findsOneWidget);
    await tester.enterText(find.byType(TextField), '/tmp');
    await tester.tap(find.text('Upload'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Upload failed.'), findsOneWidget);
    expect(destination.files, isEmpty);
    expect(find.text('Choose another file'), findsOneWidget);
  });
  testWidgets('Cancel stops staged upload without changing existing file',
      (tester) async {
    destination.files['/home/user/hello.txt'] = [9];
    destination.block = Completer<void>();
    await tester.pumpWidget(build());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Upload'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Replace'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.descendant(of: find.byType(FileUploadModal), matching: find.text('Cancel')));
    await tester.pump();
    destination.block!.complete();
    await tester.pumpAndSettle();
    expect(find.text('Upload cancelled'), findsOneWidget);
    expect(destination.files, {
      '/home/user/hello.txt': [9]
    });
  });
}
