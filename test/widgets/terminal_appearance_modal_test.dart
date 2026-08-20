import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shell_lite/providers/terminal_settings_store.dart';
import 'package:shell_lite/services/storage_service.dart';
import 'package:shell_lite/widgets/terminal_appearance_modal.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('TerminalAppearanceModal renders themes and font size controls', (tester) async {
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

    expect(find.text('Terminal Appearance'), findsOneWidget);
    expect(find.text('COLOR SCHEME'), findsOneWidget);
    expect(find.text('FONT SIZE'), findsOneWidget);
    expect(find.textContaining('Obsidian'), findsWidgets);
    expect(find.text('Catppuccin Mocha'), findsOneWidget);
    expect(find.text('Dracula'), findsOneWidget);

    expect(find.text('Haptic Feedback'), findsOneWidget);
    expect(find.text('Customize Accessory Keys'), findsOneWidget);

    // Tap on Dracula theme preset
    await tester.tap(find.text('Dracula'));
    await tester.pump();

    expect(store.themeId, 'dracula');

    // Toggle Haptic Feedback switch
    final hapticSwitch = find.byType(Switch).first;
    expect(store.hapticFeedbackEnabled, isTrue);
    await tester.tap(hapticSwitch);
    await tester.pump();
    expect(store.hapticFeedbackEnabled, isFalse);

    // Tap Reset
    await tester.tap(find.text('Reset'));
    await tester.pump();

    expect(store.themeId, 'obsidian');
    expect(store.hapticFeedbackEnabled, isTrue);
  });
}
