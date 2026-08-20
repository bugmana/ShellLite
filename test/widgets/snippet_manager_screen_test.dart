import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shell_lite/providers/snippet_store.dart';
import 'package:shell_lite/screens/snippet_manager_screen.dart';
import 'package:shell_lite/services/storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late StorageService storage;
  late SnippetStore store;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    storage = StorageService();
    store = SnippetStore(storageService: storage);
    await store.load();
  });

  Widget createWidget() {
    return ChangeNotifierProvider<SnippetStore>.value(
      value: store,
      child: const MaterialApp(
        home: SnippetManagerScreen(),
      ),
    );
  }

  testWidgets('SnippetManagerScreen renders snippet list and count badge', (tester) async {
    // Delete snippets until 2 remain so Add button is visible on screen
    while (store.snippets.length > 2) {
      await store.deleteSnippet(store.snippets.last.id);
    }

    await tester.pumpWidget(createWidget());

    expect(find.text('Manage Snippets'), findsOneWidget);
    expect(find.text('Exit Vim (Force Quit)'), findsOneWidget);
    expect(find.text('Save & Exit Vim'), findsOneWidget);
    expect(find.text('Add Snippet'), findsOneWidget);
    expect(find.text('(2/10)'), findsOneWidget);
  });

  testWidgets('SnippetManagerScreen hides Add button when max 10 limit is reached', (tester) async {
    // Default already has 10 snippets
    await tester.pumpWidget(createWidget());

    expect(store.snippets.length, 10);
    expect(store.canAddSnippet, isFalse);
    expect(find.text('Add Snippet'), findsNothing);
  });
}
