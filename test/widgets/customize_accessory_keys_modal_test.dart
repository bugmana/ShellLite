import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shell_lite/config/app_config.dart';
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

  testWidgets('CustomizeAccessoryKeysModal renders sticky modifiers and toggles them', (tester) async {
    await tester.pumpWidget(createTestWidget());
    await tester.pumpAndSettle();

    expect(find.text('STICKY MODIFIERS'), findsOneWidget);
    expect(find.text('Ctrl Sticky Modifier'), findsOneWidget);
    expect(find.text('Alt / Meta Sticky Modifier'), findsOneWidget);

    expect(settingsStore.ctrlModifierEnabled, isTrue);
    expect(settingsStore.altModifierEnabled, isTrue);

    // Toggle Ctrl switch (first switch in modal)
    final ctrlSwitch = find.byType(Switch).first;
    await tester.tap(ctrlSwitch);
    await tester.pumpAndSettle();
    expect(settingsStore.ctrlModifierEnabled, isFalse);

    // Toggle Alt switch (second switch in modal)
    final altSwitch = find.byType(Switch).at(1);
    await tester.tap(altSwitch);
    await tester.pumpAndSettle();
    expect(settingsStore.altModifierEnabled, isFalse);
  });

  testWidgets('CustomizeAccessoryKeysModal renders key list and toggle switches', (tester) async {
    await tester.pumpWidget(createTestWidget());
    await tester.pumpAndSettle();

    expect(find.text('Terminal Keys & Shortcuts'), findsOneWidget);
    expect(find.text('Tab'), findsOneWidget);
    expect(find.text('⇧Tab'), findsOneWidget);

    // Toggle the first switch in ReorderableListView
    final firstKeySwitch = find.descendant(
      of: find.byType(ReorderableListView),
      matching: find.byType(Switch),
    ).first;
    await tester.tap(firstKeySwitch);
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
    final listScrollable = find.descendant(
      of: find.byType(ReorderableListView),
      matching: find.byType(Scrollable),
    );
    await tester.scrollUntilVisible(find.text('git'), 200, scrollable: listScrollable);
    expect(find.text('git'), findsOneWidget);
  });

  testWidgets('CustomizeAccessoryKeysModal deletes custom key', (tester) async {
    await settingsStore.addCustomAccessoryKey(
      label: 'test_del',
      sequence: 'echo del\n',
    );

    await tester.pumpWidget(createTestWidget());
    await tester.pumpAndSettle();

    final listScrollable = find.descendant(
      of: find.byType(ReorderableListView),
      matching: find.byType(Scrollable),
    );
    final delText = find.text('test_del');
    await tester.scrollUntilVisible(delText, 100, scrollable: listScrollable);
    await tester.drag(listScrollable, const Offset(0, -80));
    await tester.pumpAndSettle();
    expect(delText, findsOneWidget);

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
    expect(find.text('Reset Terminal Keys?'), findsOneWidget);

    // Tap Reset Layout button
    final confirmResetButton = find.widgetWithText(ElevatedButton, 'Reset Layout');
    await tester.tap(confirmResetButton);
    await tester.pumpAndSettle();

    // Verify custom key is gone and default length restored
    expect(settingsStore.configuredAccessoryKeys.length, AccessoryBarConfig.defaultKeys.length);
    expect(settingsStore.configuredAccessoryKeys.any((k) => k.label == 'cust_reset'), isFalse);
  });

  testWidgets('CustomizeAccessoryKeysModal renders ReorderableListView with drag handles and reorders items', (tester) async {
    await tester.pumpWidget(createTestWidget());
    await tester.pumpAndSettle();

    // Verify ReorderableListView is present
    expect(find.byType(ReorderableListView), findsOneWidget);

    // Verify drag handle icon is present
    final dragHandles = find.byIcon(Icons.drag_handle_rounded);
    expect(dragHandles, findsWidgets);

    final initialFirstKey = settingsStore.configuredAccessoryKeys[0].label;
    final initialSecondKey = settingsStore.configuredAccessoryKeys[1].label;

    // Trigger reorder item 0 to position 2
    await settingsStore.reorderAccessoryKeys(0, 2);
    await tester.pumpAndSettle();

    // Verify positions swapped
    expect(settingsStore.configuredAccessoryKeys[0].label, initialSecondKey);
    expect(settingsStore.configuredAccessoryKeys[1].label, initialFirstKey);
  });

  testWidgets('AddCustomKeyDialog fills form from Quick Presets (Extended Keys) and adds key', (tester) async {
    await tester.pumpWidget(createTestWidget());
    await tester.pumpAndSettle();

    // Tap Add Key button in header
    final addButton = find.byIcon(Icons.add_rounded);
    await tester.tap(addButton);
    await tester.pumpAndSettle();

    // Verify quick preset chips exist
    expect(find.text('Quick Presets (Extended Keys):'), findsOneWidget);
    expect(find.text('F5'), findsOneWidget);

    // Tap F5 preset
    await tester.tap(find.text('F5'));
    await tester.pump();

    // Tap Add Key submit button
    final submitButton = find.widgetWithText(ElevatedButton, 'Add Key');
    await tester.tap(submitButton);
    await tester.pumpAndSettle();

    // Verify modal and store have F5 key with sequence '\x1B[15~'
    final f5Key = settingsStore.configuredAccessoryKeys.firstWhere((k) => k.label == 'F5');
    expect(f5Key.sequence, '\x1B[15~');
    expect(f5Key.description, 'Copy / Refresh');
  });

  testWidgets('CustomizeAccessoryKeysModal renders unified tabs and adds extended keys on tap', (tester) async {
    await tester.pumpWidget(createTestWidget());
    await tester.pumpAndSettle();

    // Verify all 4 unified tabs exist
    expect(find.text('Key Bar Layout'), findsOneWidget);
    expect(find.text('Function (F1–F12)'), findsOneWidget);
    expect(find.text('Navigation'), findsOneWidget);
    expect(find.text('Control Keys'), findsOneWidget);

    // Switch to Function (F1-F12) tab
    await tester.tap(find.text('Function (F1–F12)'));
    await tester.pumpAndSettle();

    expect(find.text('F1'), findsOneWidget);
    expect(find.text('F5'), findsOneWidget);

    // Tap F5 key to add it to Key Bar
    await tester.tap(find.text('F5'));
    await tester.pumpAndSettle();

    expect(settingsStore.configuredAccessoryKeys.any((k) => k.label == 'F5'), isTrue);

    // Switch to Navigation tab
    await tester.tap(find.text('Navigation'));
    await tester.pumpAndSettle();

    expect(find.text('Home'), findsOneWidget);
    expect(find.text('End'), findsOneWidget);

    // Switch to Control Keys tab
    await tester.tap(find.text('Control Keys'));
    await tester.pumpAndSettle();

    expect(find.text('^A'), findsOneWidget);
  });
}
