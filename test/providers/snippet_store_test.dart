import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shell_lite/models/snippet.dart';
import 'package:shell_lite/providers/snippet_store.dart';
import 'package:shell_lite/services/storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late StorageService storage;
  late SnippetStore store;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    storage = StorageService();
    store = SnippetStore(storageService: storage);
  });

  test('SnippetStore loads default snippets when empty', () async {
    await store.load();
    expect(store.snippets.isNotEmpty, isTrue);
    expect(store.categories.contains('All'), isTrue);
    expect(store.categories.contains('Monitoring'), isTrue);
  });

  test('SnippetStore adds, updates, and deletes snippet', () async {
    await store.load();

    const newSnippet = Snippet(
      id: 'custom_1',
      title: 'Custom Test',
      command: 'echo test\n',
      category: 'Custom',
    );

    await store.addSnippet(newSnippet);
    expect(store.snippets.any((s) => s.id == 'custom_1'), isTrue);

    final updated = newSnippet.copyWith(title: 'Updated Custom Test');
    await store.updateSnippet(updated);
    expect(store.snippets.firstWhere((s) => s.id == 'custom_1').title, 'Updated Custom Test');

    await store.deleteSnippet('custom_1');
    expect(store.snippets.any((s) => s.id == 'custom_1'), isFalse);
  });

  test('SnippetStore resetToDefaults restores defaults', () async {
    await store.load();
    await store.deleteSnippet(store.snippets.first.id);
    await store.resetToDefaults();

    expect(store.snippets.length, DefaultSnippets.defaults.length);
  });
}
