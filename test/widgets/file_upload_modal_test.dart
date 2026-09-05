import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shell_lite/models/auth_method.dart';
import 'package:shell_lite/models/server_profile.dart';
import 'package:shell_lite/providers/session_store.dart';
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

  testWidgets('FileUploadModal renders header, initial directory and file selection prompt', (tester) async {
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

  testWidgets('FileUploadModal uses PopScope to protect against accidental navigation during upload', (tester) async {
    await tester.pumpWidget(createTestWidget(initialDirectory: '/tmp'));
    await tester.pumpAndSettle();

    final popScopeFinder = find.byType(PopScope);
    expect(popScopeFinder, findsOneWidget);
    final popScope = tester.widget<PopScope>(popScopeFinder);
    // When not uploading, canPop is true
    expect(popScope.canPop, isTrue);

    // Close button is present when not uploading
    expect(find.byIcon(Icons.close_rounded), findsOneWidget);
  });
}
