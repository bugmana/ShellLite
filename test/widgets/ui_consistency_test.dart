import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shell_lite/screens/server_form/key_auth_section.dart';
import 'package:shell_lite/theme/app_theme.dart';
import 'package:shell_lite/theme/terminal_theme_presets.dart';

void main() {
  testWidgets('private-key controls fit a narrow screen with large text',
      (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = TextEditingController();
    final theme = AppTheme.buildTheme(TerminalThemePresets.obsidian);
    await tester.pumpWidget(MaterialApp(
        theme: theme,
        builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(2)),
            child: child!),
        home: Scaffold(
            body: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: KeyAuthSection(
                    keyController: controller,
                    isEditing: false,
                    hasStoredKey: false,
                    obscureKey: false,
                    onToggleObscureKey: () {},
                    onClearKey: () {},
                    onKeyChanged: (_) {},
                    theme: theme.extension<AppThemeExtension>()!)))));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Hide key'), findsOneWidget);
    expect(find.text('Clear key'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    controller.dispose();
  });
  test('primary filled buttons share app shape and text across themes', () {
    for (final preset in TerminalThemePresets.all) {
      final theme = AppTheme.buildTheme(preset);
      final filled = theme.filledButtonTheme.style!;
      final elevated = theme.elevatedButtonTheme.style!;
      expect(
          filled.minimumSize!.resolve({}), elevated.minimumSize!.resolve({}));
      expect(filled.shape!.resolve({}), elevated.shape!.resolve({}));
      expect(filled.textStyle!.resolve({}), elevated.textStyle!.resolve({}));
      expect(filled.foregroundColor!.resolve({}),
          elevated.foregroundColor!.resolve({}));
    }
  });
}
