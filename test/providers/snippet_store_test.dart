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

  test('SnippetStore loads curated default snippets when empty', () async {
    await store.load();
    expect(store.snippets.length, 10);
    expect(store.snippets.any((s) => s.title == 'Exit Vim (Force Quit)'), isTrue);
    expect(store.snippets.any((s) => s.title == 'Save & Exit Vim'), isTrue);
    expect(store.snippets.any((s) => s.title == 'System Monitor (htop)'), isTrue);
    expect(store.snippets.any((s) => s.title == 'Disk Space (df -h)'), isTrue);
    expect(store.snippets.any((s) => s.title == 'Memory Usage (free -h)'), isTrue);
  });

  test('SnippetStore adds, updates, and deletes snippet', () async {
    await store.load();

    // Delete one default snippet so there's room to add
    await store.deleteSnippet(store.snippets.first.id);
    expect(store.canAddSnippet, isTrue);

    const newSnippet = Snippet(
      id: 'custom_1',
      title: 'Custom Test',
      command: 'echo test\n',
    );

    await store.addSnippet(newSnippet);
    expect(store.snippets.any((s) => s.id == 'custom_1'), isTrue);

    final updated = newSnippet.copyWith(title: 'Updated Custom Test');
    await store.updateSnippet(updated);
    expect(store.snippets.firstWhere((s) => s.id == 'custom_1').title, 'Updated Custom Test');

    await store.deleteSnippet('custom_1');
    expect(store.snippets.any((s) => s.id == 'custom_1'), isFalse);
  });

  test('SnippetStore enforces maximum limit of 10 snippets', () async {
    await store.load();
    // Default already has 10 snippets
    expect(store.snippets.length, 10);
    expect(store.canAddSnippet, isFalse);

    expect(
      () => store.addSnippet(
        const Snippet(
          id: 'overflow',
          title: 'Overflow',
          command: 'echo overflow\n',
        ),
      ),
      throwsStateError,
    );
  });

  test('SnippetStore resetToDefaults restores defaults', () async {
    await store.load();
    await store.deleteSnippet(store.snippets.first.id);
    expect(store.snippets.length, 9);
    await store.resetToDefaults();

    expect(store.snippets.length, DefaultSnippets.defaults.length);
    expect(store.snippets.length, 10);
  });
}
