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
    expect(find.text('ShellLite Obsidian'), findsWidgets);
    expect(find.text('Catppuccin Mocha'), findsOneWidget);
    expect(find.text('Dracula'), findsOneWidget);

    // Tap on Dracula theme preset
    await tester.tap(find.text('Dracula'));
    await tester.pump();

    expect(store.themeId, 'dracula');

    // Tap Reset
    await tester.tap(find.text('Reset'));
    await tester.pump();

    expect(store.themeId, 'obsidian');
  });
}
