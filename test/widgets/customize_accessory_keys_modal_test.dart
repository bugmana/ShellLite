import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shell_lite/providers/terminal_settings_store.dart';
import 'package:shell_lite/services/storage_service.dart';
import 'package:shell_lite/theme/app_theme.dart';
import 'package:shell_lite/theme/terminal_theme_presets.dart';
import 'package:shell_lite/widgets/customize_accessory_keys_modal.dart';

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
        home: const Scaffold(
          body: CustomizeAccessoryKeysModal(),
        ),
      ),
    );
  }

  testWidgets('CustomizeAccessoryKeysModal renders key list and toggle switches', (tester) async {
    await tester.pumpWidget(createTestWidget());
    await tester.pumpAndSettle();

    expect(find.text('Customize Accessory Keys'), findsOneWidget);
    expect(find.text('Tab'), findsOneWidget);
    expect(find.text('⇧Tab'), findsOneWidget);

    // Toggle the first switch
    final firstSwitch = find.byType(Switch).first;
    await tester.tap(firstSwitch);
    await tester.pumpAndSettle();

    // Verify first key is disabled in store
    expect(settingsStore.configuredAccessoryKeys.first.isEnabled, isFalse);
  });

  testWidgets('CustomizeAccessoryKeysModal adds a custom key via Add Dialog', (tester) async {
    await tester.pumpWidget(createTestWidget());
    await tester.pumpAndSettle();

    // Tap Add Key button in header
    final addButton = find.byIcon(Icons.add_rounded);
    expect(addButton, findsOneWidget);
    await tester.tap(addButton);
    await tester.pumpAndSettle();

    // Verify Add Custom Key dialog is open
    expect(find.text('Add Custom Key'), findsOneWidget);

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
    final submitButton = find.widgetWithText(ElevatedButton, 'Add Key');
    await tester.tap(submitButton);
    await tester.pumpAndSettle();

    // Verify modal now contains the new key in store and in list
    expect(settingsStore.configuredAccessoryKeys.any((k) => k.label == 'git'), isTrue);
    await tester.scrollUntilVisible(find.text('git'), 200, scrollable: find.byType(Scrollable));
    expect(find.text('git'), findsOneWidget);
  });

  testWidgets('CustomizeAccessoryKeysModal deletes custom key', (tester) async {
    await settingsStore.addCustomAccessoryKey(
      label: 'test_del',
      sequence: 'echo del\n',
    );

    await tester.pumpWidget(createTestWidget());
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(find.text('test_del'), 200, scrollable: find.byType(Scrollable));
    expect(find.text('test_del'), findsOneWidget);

    final deleteButton = find.byIcon(Icons.delete_outline_rounded);
    expect(deleteButton, findsOneWidget);
    await tester.tap(deleteButton);
    await tester.pumpAndSettle();

    expect(settingsStore.configuredAccessoryKeys.any((k) => k.label == 'test_del'), isFalse);
  });

  testWidgets('CustomizeAccessoryKeysModal resets to default layout with confirmation', (tester) async {
    await settingsStore.addCustomAccessoryKey(
      label: 'cust_reset',
      sequence: 'test',
    );

    await tester.pumpWidget(createTestWidget());
    await tester.pumpAndSettle();

    // Tap Reset Defaults button in header
    final resetButton = find.byIcon(Icons.restore_rounded);
    expect(resetButton, findsOneWidget);
    await tester.tap(resetButton);
    await tester.pumpAndSettle();

    // Confirmation dialog appears
    expect(find.text('Reset Accessory Keys?'), findsOneWidget);

    // Tap Reset Layout button
    final confirmResetButton = find.widgetWithText(ElevatedButton, 'Reset Layout');
    await tester.tap(confirmResetButton);
    await tester.pumpAndSettle();

    // Verify custom key is gone and default length restored
    expect(settingsStore.configuredAccessoryKeys.length, 13);
    expect(settingsStore.configuredAccessoryKeys.any((k) => k.label == 'cust_reset'), isFalse);
  });
}
