import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shell_lite/providers/snippet_store.dart';
import 'package:shell_lite/services/storage_service.dart';
import 'package:shell_lite/widgets/snippet_runner_sheet.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('SnippetRunnerSheet renders snippet list and executes tap', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final storage = StorageService();
    final store = SnippetStore(storageService: storage);
    await store.load();

    String executedCmd = '';

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: store,
        child: MaterialApp(
          home: Scaffold(
            body: SnippetRunnerSheet(
              onExecute: (cmd) => executedCmd = cmd,
            ),
          ),
        ),
      ),
    );

    expect(find.text('Command Snippets'), findsOneWidget);
    expect(find.text('Exit Vim (Force Quit)'), findsOneWidget);
    expect(find.text('Save & Exit Vim'), findsOneWidget);

    // Tap on Exit Vim (Force Quit)
    await tester.tap(find.text('Exit Vim (Force Quit)'));
    await tester.pumpAndSettle();

    expect(executedCmd, '\x1B:q!\n');
  });
}
