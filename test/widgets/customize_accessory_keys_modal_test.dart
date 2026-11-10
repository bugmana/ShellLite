import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shell_lite/providers/terminal_settings_store.dart';
import 'package:shell_lite/services/storage_service.dart';
import 'package:shell_lite/theme/app_theme.dart';
import 'package:shell_lite/theme/terminal_theme_presets.dart';
import 'package:shell_lite/screens/terminal_keys_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late StorageService storageService;
  late TerminalSettingsStore settingsStore;

  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    storageService = StorageService(prefs: prefs);
    settingsStore = TerminalSettingsStore(storageService: storageService);
    await settingsStore.load();
  });

  Widget createTestWidget() {
    return ChangeNotifierProvider<TerminalSettingsStore>.value(
      value: settingsStore,
      child: MaterialApp(
        theme: AppTheme.buildTheme(TerminalThemePresets.obsidian),
        home: const TerminalKeysScreen(),
      ),
    );
  }

  testWidgets('shortcut feedback replaces older messages and stays on Keys',
      (tester) async {
    await tester.pumpWidget(ChangeNotifierProvider.value(
      value: settingsStore,
      child: MaterialApp(home: Builder(builder: (context) {
        return Scaffold(
            body: TextButton(
          onPressed: () => TerminalKeysScreen.open(context),
          child: const Text('Open keys'),
        ));
      })),
    ));
    await tester.tap(find.text('Open keys'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Function (F1–F12)'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('F1'));
    await tester.pump(const Duration(milliseconds: 250));
    await tester.tap(find.text('F2'));
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.text('Added "F2" to key row'), findsOneWidget);
    expect(find.text('Added "F1" to key row'), findsNothing);
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 2));
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('CustomizeAccessoryKeysModal adds a custom key via Add Dialog',
      (tester) async {
    await tester.pumpWidget(createTestWidget());
    await tester.pumpAndSettle();

    // Tap Add Key button in header
    final addButton = find.byIcon(Icons.add_rounded);
    expect(addButton, findsOneWidget);
    await tester.tap(addButton);
    await tester.pumpAndSettle();

    // Verify Add Custom Key dialog is open
    expect(find.text('New shortcut'), findsOneWidget);

    // Enter label and sequence
    final textFields = find.byType(TextFormField);
    await tester.enterText(textFields.at(0), 'git');
    await tester.enterText(textFields.at(1), 'git status');

    // Tap quick insert chip for Enter (\n)
    final enterChip = find.text(r'\n (Enter)');
    expect(enterChip, findsOneWidget);
    await tester.tap(enterChip);
    await tester.pump();

    // Tap Add Key submit button
    final submitButton = find.widgetWithText(ElevatedButton, 'Add shortcut');
    await tester.tap(submitButton);
    await tester.pumpAndSettle();

    // Verify modal now contains the new key in store and in list
    expect(settingsStore.configuredAccessoryKeys.any((k) => k.label == 'git'),
        isTrue);
    final listScrollable = find.descendant(
      of: find.byType(ReorderableListView),
      matching: find.byType(Scrollable),
    );
    await tester.scrollUntilVisible(find.text('git'), 200,
        scrollable: listScrollable);
    expect(find.text('git'), findsOneWidget);
  });
}
