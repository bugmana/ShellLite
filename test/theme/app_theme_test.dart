import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shell_lite/theme/app_theme.dart';
import 'package:shell_lite/theme/terminal_theme_presets.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AppTheme & TerminalThemePresets', () {
    test('All presets define a valid AppThemePalette with matching background', () {
      expect(TerminalThemePresets.all.length, 6);

      for (final preset in TerminalThemePresets.all) {
        final palette = preset.palette;
        expect(preset.id.isNotEmpty, isTrue);
        expect(preset.name.isNotEmpty, isTrue);
        expect(palette.background, equals(preset.theme.background));
        expect(palette.primaryAccent, isNotNull);
        expect(palette.secondaryAccent, isNotNull);
        expect(palette.surface, isNotNull);
        expect(palette.cardSurface, isNotNull);
        expect(palette.border, isNotNull);
        expect(palette.textPrimary, isNotNull);
        expect(palette.textSecondary, isNotNull);
        expect(palette.textMuted, isNotNull);
        expect(palette.error, isNotNull);
        expect(palette.warning, isNotNull);
        expect(palette.success, isNotNull);
      }
    });

    test('AppTheme.buildTheme builds a comprehensive ThemeData for every preset', () {
      for (final preset in TerminalThemePresets.all) {
        final theme = AppTheme.buildTheme(preset);

        expect(theme.brightness, Brightness.dark);
        expect(theme.scaffoldBackgroundColor, preset.palette.background);
        expect(theme.colorScheme.primary, preset.palette.primaryAccent);
        expect(theme.colorScheme.surface, preset.palette.surface);
        expect(theme.colorScheme.error, preset.palette.error);
        expect(theme.appBarTheme.backgroundColor, preset.palette.surface);
        expect(theme.cardTheme.color, preset.palette.cardSurface);

        final ext = theme.extension<AppThemeExtension>();
        expect(ext, isNotNull);
        expect(ext!.background, preset.palette.background);
        expect(ext.primaryAccent, preset.palette.primaryAccent);
        expect(ext.surface, preset.palette.surface);
      }
    });

    test('AppThemeExtension copyWith and lerp operate correctly', () {
      final defaultExt = AppTheme.defaultExtension;
      final copied = defaultExt.copyWith();
      expect(copied.palette.background, defaultExt.palette.background);

      final nordPreset = TerminalThemePresets.all.firstWhere((p) => p.id == 'nord');
      final nordExt = AppThemeExtension(palette: nordPreset.palette);

      final lerped = defaultExt.lerp(nordExt, 0.5);
      expect(lerped.palette.background, isNotNull);

      // lerp with non-AppThemeExtension returns this
      final lerpSame = defaultExt.lerp(null, 0.5);
      expect(identical(lerpSame, defaultExt), isTrue);
    });

    testWidgets('BuildContext.appTheme extension retrieves extension from ThemeData', (tester) async {
      final draculaPreset = TerminalThemePresets.all.firstWhere((p) => p.id == 'dracula');
      final themeData = AppTheme.buildTheme(draculaPreset);

      Color? retrievedBg;
      Color? retrievedAccent;

      await tester.pumpWidget(
        MaterialApp(
          theme: themeData,
          home: Builder(
            builder: (context) {
              final appTheme = context.appTheme;
              retrievedBg = appTheme.background;
              retrievedAccent = appTheme.primaryAccent;
              return const SizedBox();
            },
          ),
        ),
      );

      expect(retrievedBg, draculaPreset.palette.background);
      expect(retrievedAccent, draculaPreset.palette.primaryAccent);
    });

    testWidgets('BuildContext.appTheme falls back to defaultExtension if none registered', (tester) async {
      Color? retrievedBg;

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: Builder(
            builder: (context) {
              retrievedBg = context.appTheme.background;
              return const SizedBox();
            },
          ),
        ),
      );

      expect(retrievedBg, AppTheme.defaultExtension.background);
    });
  });
}
