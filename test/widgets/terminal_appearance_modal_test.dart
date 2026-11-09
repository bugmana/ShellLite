import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shell_lite/providers/terminal_settings_store.dart';
import 'package:shell_lite/services/storage_service.dart';
import 'package:shell_lite/widgets/terminal_appearance_modal.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('TerminalAppearanceModal renders themes and font size controls',
      (tester) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    SharedPreferences.setMockInitialValues({});
    final storage = StorageService();
    final store = TerminalSettingsStore(storageService: storage);
    await store.load();

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: store,
        child: const MaterialApp(
          home: Scaffold(
            body: TerminalAppearanceModal(),
          ),
        ),
      ),
    );

    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('Theme'), findsOneWidget);
    expect(find.text('Text size'), findsOneWidget);
    expect(find.byType(Slider), findsNothing);
    final semantics = tester.ensureSemantics();
    try {
      expect(tester.getSemantics(find.text('13.5 pt')).label,
          'Text size 13.5 points');
      expect(
          tester.getSemantics(find.byType(Switch).first).label, 'Show key row');
      expect(tester.getSemantics(find.byType(Switch).last).label, 'Haptics');
    } finally {
      semantics.dispose();
    }
    expect(find.textContaining('Obsidian'), findsWidgets);
    expect(find.text('Catppuccin Mocha'), findsOneWidget);
    expect(find.text('Dracula'), findsOneWidget);

    expect(find.text('Haptics'), findsOneWidget);
    expect(find.text('About'), findsOneWidget);
    expect(find.text('Privacy'), findsOneWidget);
    expect(find.text('Keyboard'), findsOneWidget);
    expect(find.text('Keys'), findsOneWidget);
    expect(find.text('Choose keys and shortcuts'), findsOneWidget);
    expect(find.text('Show key row'), findsOneWidget);

    // Tap on Dracula theme preset
    await tester.tap(find.text('Dracula'));
    await tester.pump();

    expect(store.themeId, 'dracula');

    // Toggle Haptics switch
    final hapticFinder = find
        .ancestor(of: find.text('Haptics'), matching: find.byType(Container))
        .first;
    final hapticSwitch =
        find.descendant(of: hapticFinder, matching: find.byType(Switch));
    expect(store.hapticFeedbackEnabled, isTrue);
    await tester.tap(hapticSwitch);
    await tester.pump();
    expect(store.hapticFeedbackEnabled, isFalse);

    // Tap Reset
    await tester.tap(find.text('Reset settings'));
    await tester.pump();

    expect(store.themeId, 'obsidian');
    expect(store.hapticFeedbackEnabled, isTrue);
  });

  testWidgets(
      'TerminalAppearanceModal opens CustomizeAccessoryKeysModal when tapped',
      (tester) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    SharedPreferences.setMockInitialValues({});
    final storage = StorageService();
    final store = TerminalSettingsStore(storageService: storage);
    await store.load();

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: store,
        child: const MaterialApp(
          home: Scaffold(
            body: TerminalAppearanceModal(),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Keys'));
    await tester.pumpAndSettle();

    expect(find.text('Modifiers'), findsOneWidget);
    expect(find.text('Shortcuts'), findsOneWidget);
  });
}
