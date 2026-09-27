import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shell_lite/models/auth_method.dart';
import 'package:shell_lite/models/server_profile.dart';
import 'package:shell_lite/providers/session_store.dart';
import 'package:shell_lite/services/file_transfer_service.dart';
import 'package:shell_lite/services/ssh_service.dart';
import 'package:shell_lite/theme/app_theme.dart';
import 'package:shell_lite/theme/terminal_theme_presets.dart';
import 'package:shell_lite/widgets/file_upload_modal.dart';
import 'package:xterm/xterm.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late OpenSession testSession;
  late ServerProfile testProfile;

  setUp(() {
    testProfile = ServerProfile(
      id: 'server-upload-test',
      displayName: 'Staging Server',
      host: '192.168.1.100',
      port: 2222,
      username: 'deploy',
      authMethod: const PasswordAuth(credentialTag: 'cred-123'),
    );

    testSession = OpenSession(
      id: testProfile.id,
      profile: testProfile,
      terminal: Terminal(),
      controller: TerminalController(),
      sshService: SSHService(),
    );
  });

  Widget createTestWidget({String? initialDirectory}) {
    return MaterialApp(
      theme: AppTheme.buildTheme(TerminalThemePresets.obsidian),
      home: Scaffold(
        body: FileUploadModal(
          session: testSession,
          initialDirectory: initialDirectory,
        ),
      ),
    );
  }

  Widget wrapWithTheme(Widget child) {
    return MaterialApp(
      theme: AppTheme.buildTheme(TerminalThemePresets.obsidian),
      home: Scaffold(
        body: Builder(
          builder: (context) => child,
        ),
      ),
    );
  }

  group('FileUploadModal Coordinator', () {
    testWidgets('renders header, initial directory and file selection prompt', (tester) async {
      await tester.pumpWidget(createTestWidget(initialDirectory: '/var/www/my-site'));
      await tester.pumpAndSettle();

      // Verify header title and server info
      expect(find.text('Upload Files to Server'), findsOneWidget);
      expect(find.textContaining('Staging Server'), findsOneWidget);
      expect(find.textContaining('deploy@192.168.1.100'), findsOneWidget);

      // Verify remote destination folder field
      expect(find.text('Remote Destination Folder'), findsOneWidget);
      expect(find.widgetWithText(TextField, '/var/www/my-site'), findsOneWidget);
      expect(find.text('Re-detect'), findsOneWidget);

      // Verify empty file picker prompt
      expect(find.text('Select Files to Upload'), findsOneWidget);
      expect(find.text('Tap to choose one or more files from your device'), findsOneWidget);

      // Verify bottom action buttons
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('Upload'), findsOneWidget);

      // Verify Upload button is disabled when no files are selected
      final uploadButton = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, 'Upload'),
      );
      expect(uploadButton.onPressed, isNull);
    });

    testWidgets('uses PopScope to protect against accidental navigation during upload', (tester) async {
      await tester.pumpWidget(createTestWidget(initialDirectory: '/tmp'));
      await tester.pumpAndSettle();

      final popScopeFinder = find.byType(PopScope);
      expect(popScopeFinder, findsOneWidget);
      final popScope = tester.widget<PopScope>(popScopeFinder);
      expect(popScope.canPop, isTrue);

      expect(find.byIcon(Icons.close_rounded), findsOneWidget);
    });
  });

  group('FileUploadHeader Widget', () {
    testWidgets('renders title, subtitle, close button and handles close callback', (tester) async {
      bool closed = false;

      await tester.pumpWidget(wrapWithTheme(
        Builder(
          builder: (context) => FileUploadHeader(
            title: 'Upload Files to Server',
            subtitle: 'My Server (root@10.0.0.1)',
            isComplete: false,
            canClose: true,
            onClose: () => closed = true,
            theme: context.appTheme,
          ),
        ),
      ));

      expect(find.text('Upload Files to Server'), findsOneWidget);
      expect(find.text('My Server (root@10.0.0.1)'), findsOneWidget);
      expect(find.byIcon(Icons.cloud_upload_outlined), findsOneWidget);
      expect(find.byIcon(Icons.close_rounded), findsOneWidget);

      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pump();
      expect(closed, isTrue);
    });

    testWidgets('hides close button when canClose is false during upload', (tester) async {
      await tester.pumpWidget(wrapWithTheme(
        Builder(
          builder: (context) => FileUploadHeader(
            title: 'Uploading...',
            subtitle: '1 file remaining',
            isComplete: false,
            canClose: false,
            onClose: () {},
            theme: context.appTheme,
          ),
        ),
      ));

      expect(find.byIcon(Icons.close_rounded), findsNothing);
    });

    testWidgets('renders celebratory check icon when isComplete is true', (tester) async {
      await tester.pumpWidget(wrapWithTheme(
        Builder(
          builder: (context) => FileUploadHeader(
            title: 'Upload Successful',
            subtitle: '2 file(s) transferred',
            isComplete: true,
            canClose: true,
            onClose: () {},
            theme: context.appTheme,
          ),
        ),
      ));

      expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
      expect(find.text('Upload Successful'), findsOneWidget);
    });
  });

  group('FileDirectorySection Widget', () {
    testWidgets('renders directory text field and quick selection chips', (tester) async {
      final controller = TextEditingController(text: '/home/deploy');
      String? selectedQuickPath;

      await tester.pumpWidget(wrapWithTheme(
        Builder(
          builder: (context) => FileDirectorySection(
            controller: controller,
            isLoading: false,
            isUploading: false,
            onRefresh: () {},
            onQuickSelect: (path) => selectedQuickPath = path,
            theme: context.appTheme,
          ),
        ),
      ));

      expect(find.text('Remote Destination Folder'), findsOneWidget);
      expect(find.widgetWithText(TextField, '/home/deploy'), findsOneWidget);
      expect(find.text('Current'), findsOneWidget);
      expect(find.text('~ (Home)'), findsOneWidget);
      expect(find.text('/tmp'), findsOneWidget);
      expect(find.text('/var/www'), findsOneWidget);

      await tester.tap(find.text('/var/www'));
      await tester.pump();
      expect(selectedQuickPath, '/var/www');
    });

    testWidgets('triggers onRefresh callback when Re-detect is tapped', (tester) async {
      final controller = TextEditingController(text: '~');
      bool refreshTapped = false;

      await tester.pumpWidget(wrapWithTheme(
        Builder(
          builder: (context) => FileDirectorySection(
            controller: controller,
            isLoading: false,
            isUploading: false,
            onRefresh: () => refreshTapped = true,
            onQuickSelect: (_) {},
            theme: context.appTheme,
          ),
        ),
      ));

      expect(find.text('Re-detect'), findsOneWidget);
      await tester.tap(find.text('Re-detect'));
      await tester.pump();
      expect(refreshTapped, isTrue);
    });

    testWidgets('shows loading spinner when isLoading is true', (tester) async {
      final controller = TextEditingController(text: '~');

      await tester.pumpWidget(wrapWithTheme(
        Builder(
          builder: (context) => FileDirectorySection(
            controller: controller,
            isLoading: true,
            isUploading: false,
            onRefresh: () {},
            onQuickSelect: (_) {},
            theme: context.appTheme,
          ),
        ),
      ));

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Re-detect'), findsNothing);
    });
  });

  group('FilePickerDropzone Widget', () {
    testWidgets('renders dropzone and triggers onTap on click', (tester) async {
      bool tapped = false;

      await tester.pumpWidget(wrapWithTheme(
        Builder(
          builder: (context) => FilePickerDropzone(
            onTap: () => tapped = true,
            theme: context.appTheme,
          ),
        ),
      ));

      expect(find.byIcon(Icons.file_upload_outlined), findsOneWidget);
      expect(find.text('Select Files to Upload'), findsOneWidget);
      expect(find.text('Tap to choose one or more files from your device'), findsOneWidget);

      await tester.tap(find.byType(FilePickerDropzone));
      await tester.pump();
      expect(tapped, isTrue);
    });
  });

  group('SelectedFileList Widget', () {
    testWidgets('renders selected file items with names and formatted sizes and allows removal', (tester) async {
      final files = [
        FileTransferItem(name: 'app.conf', size: 1024, bytes: Uint8List(1024)),
        FileTransferItem(name: 'data.tar.gz', size: 204800, bytes: Uint8List(204800)),
      ];
      int? removedIndex;

      await tester.pumpWidget(wrapWithTheme(
        Builder(
          builder: (context) => SelectedFileList(
            files: files,
            isUploading: false,
            onRemove: (idx) => removedIndex = idx,
            theme: context.appTheme,
          ),
        ),
      ));

      expect(find.text('app.conf'), findsOneWidget);
      expect(find.text('1.0 KB'), findsOneWidget);
      expect(find.text('data.tar.gz'), findsOneWidget);
      expect(find.text('200 KB'), findsOneWidget);
      expect(find.byIcon(Icons.close), findsNWidgets(2));

      await tester.tap(find.byIcon(Icons.close).first);
      await tester.pump();
      expect(removedIndex, 0);
    });

    testWidgets('disables removal while upload is active', (tester) async {
      final files = [
        FileTransferItem(name: 'backup.sql', size: 5000, bytes: Uint8List(5000)),
      ];
      int? removedIndex;

      await tester.pumpWidget(wrapWithTheme(
        Builder(
          builder: (context) => SelectedFileList(
            files: files,
            isUploading: true,
            onRemove: (idx) => removedIndex = idx,
            theme: context.appTheme,
          ),
        ),
      ));

      final closeButton = tester.widget<IconButton>(
        find.ancestor(of: find.byIcon(Icons.close), matching: find.byType(IconButton)),
      );
      expect(closeButton.onPressed, isNull);
      expect(removedIndex, isNull);
    });
  });

  group('FileUploadProgressView Widget', () {
    testWidgets('renders progress info, percentage and handles cancel', (tester) async {
      bool cancelled = false;

      await tester.pumpWidget(wrapWithTheme(
        Builder(
          builder: (context) => FileUploadProgressView(
            fileName: 'archive.zip',
            fileIndex: 1,
            totalFiles: 4,
            uploadedBytes: 524288,
            totalBytes: 1048576,
            overallProgress: 0.375,
            onCancel: () => cancelled = true,
            theme: context.appTheme,
          ),
        ),
      ));

      expect(find.text('Uploading (2/4): archive.zip'), findsOneWidget);
      expect(find.text('38%'), findsOneWidget);
      expect(find.text('512 KB of 1.0 MB'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);

      final indicator = tester.widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator));
      expect(indicator.value, 0.375);

      await tester.tap(find.text('Cancel'));
      await tester.pump();
      expect(cancelled, isTrue);
    });
  });

  group('FileUploadCompleteView Widget', () {
    testWidgets('renders celebratory badge, completed files chips and handles Done button', (tester) async {
      bool done = false;

      await tester.pumpWidget(wrapWithTheme(
        Builder(
          builder: (context) => FileUploadCompleteView(
            destinationDir: '/var/www/html',
            completedFiles: const ['index.html', 'style.css'],
            onDone: () => done = true,
            theme: context.appTheme,
          ),
        ),
      ));

      expect(find.text('Upload Complete'), findsOneWidget);
      expect(find.text('2 file(s) transferred to /var/www/html'), findsOneWidget);
      expect(find.text('index.html'), findsOneWidget);
      expect(find.text('style.css'), findsOneWidget);
      expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);

      await tester.tap(find.widgetWithText(ElevatedButton, 'Done'));
      await tester.pump();
      expect(done, isTrue);
    });
  });
}
