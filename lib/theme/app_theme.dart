import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:xterm/xterm.dart';
import 'terminal_theme_presets.dart';

@immutable
class AppThemeExtension extends ThemeExtension<AppThemeExtension> {
  final AppThemePalette palette;

  const AppThemeExtension({required this.palette});

  Color get background => palette.background;
  Color get surface => palette.surface;
  Color get cardSurface => palette.cardSurface;
  Color get cardSurfaceHover => palette.cardSurfaceHover;
  Color get border => palette.border;
  Color get primaryAccent => palette.primaryAccent;
  Color get secondaryAccent => palette.secondaryAccent;
  Color get textPrimary => palette.textPrimary;
  Color get textSecondary => palette.textSecondary;
  Color get textMuted => palette.textMuted;
  Color get error => palette.error;
  Color get warning => palette.warning;
  Color get success => palette.success;

  @override
  AppThemeExtension copyWith({AppThemePalette? palette}) {
    return AppThemeExtension(palette: palette ?? this.palette);
  }

  @override
  AppThemeExtension lerp(ThemeExtension<AppThemeExtension>? other, double t) {
    if (other is! AppThemeExtension) return this;
    return AppThemeExtension(
      palette: AppThemePalette(
        background: Color.lerp(palette.background, other.palette.background, t) ?? palette.background,
        surface: Color.lerp(palette.surface, other.palette.surface, t) ?? palette.surface,
        cardSurface: Color.lerp(palette.cardSurface, other.palette.cardSurface, t) ?? palette.cardSurface,
        cardSurfaceHover: Color.lerp(palette.cardSurfaceHover, other.palette.cardSurfaceHover, t) ?? palette.cardSurfaceHover,
        border: Color.lerp(palette.border, other.palette.border, t) ?? palette.border,
        primaryAccent: Color.lerp(palette.primaryAccent, other.palette.primaryAccent, t) ?? palette.primaryAccent,
        secondaryAccent: Color.lerp(palette.secondaryAccent, other.palette.secondaryAccent, t) ?? palette.secondaryAccent,
        textPrimary: Color.lerp(palette.textPrimary, other.palette.textPrimary, t) ?? palette.textPrimary,
        textSecondary: Color.lerp(palette.textSecondary, other.palette.textSecondary, t) ?? palette.textSecondary,
        textMuted: Color.lerp(palette.textMuted, other.palette.textMuted, t) ?? palette.textMuted,
        error: Color.lerp(palette.error, other.palette.error, t) ?? palette.error,
        warning: Color.lerp(palette.warning, other.palette.warning, t) ?? palette.warning,
        success: Color.lerp(palette.success, other.palette.success, t) ?? palette.success,
      ),
    );
  }
}

extension AppThemeContextExtension on BuildContext {
  AppThemeExtension get appTheme {
    return Theme.of(this).extension<AppThemeExtension>() ?? AppTheme.defaultExtension;
  }

  T? maybeWatch<T>() {
    try {
      return Provider.of<T>(this, listen: true);
    } catch (_) {
      return null;
    }
  }

  T? maybeRead<T>() {
    try {
      return Provider.of<T>(this, listen: false);
    } catch (_) {
      return null;
    }
  }
}

abstract final class AppSpacing {
  static const double xxs = 2.0;
  static const double xs  = 4.0;
  static const double sm  = 8.0;
  static const double md  = 12.0;
  static const double lg  = 16.0;
  static const double xl  = 24.0;
  static const double xxl = 32.0;
}

abstract final class AppRadius {
  static const double sm = 6.0;
  static const double md = 10.0;
  static const double lg = 14.0;
  static const double xl = 18.0;
}

abstract final class AppTouchTarget {
  static const double min = 44.0;         // Apple HIG minimum (44pt)
  static const double recommended = 48.0; // Material 3 standard (48dp)
}

class AppTheme {
  static final AppThemeExtension defaultExtension = AppThemeExtension(
    palette: TerminalThemePresets.obsidian.palette,
  );

  static TerminalTheme get terminalTheme => TerminalThemePresets.obsidian.theme;

  /// Computes foreground color guaranteeing WCAG AA (>= 4.5:1) against primaryAccent.
  /// (1.05) / (L + 0.05) < 4.5  =>  L > 0.1833
  static Color computeOnPrimary(Color primaryAccent) {
    final lum = primaryAccent.computeLuminance();
    return lum > 0.1833 ? const Color(0xFF0B0F14) : Colors.white;
  }

  static ThemeData buildTheme(TerminalThemePreset preset) {
    final p = preset.palette;
    final onPrimary = computeOnPrimary(p.primaryAccent);

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: p.background,
      primaryColor: p.primaryAccent,
      canvasColor: p.background,
      colorScheme: ColorScheme.dark(
        primary: p.primaryAccent,
        secondary: p.secondaryAccent,
        surface: p.surface,
        error: p.error,
        onPrimary: onPrimary,
        onSecondary: Colors.white,
        onSurface: p.textPrimary,
        onError: Colors.white,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: p.surface,
        elevation: 0,
        centerTitle: true,
        scrolledUnderElevation: 0,
        titleTextStyle: TextStyle(
          color: p.textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.2,
        ),
        iconTheme: IconThemeData(color: p.textPrimary),
      ),
      cardTheme: CardThemeData(
        color: p.cardSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          side: BorderSide(color: p.border, width: 1),
          borderRadius: BorderRadius.circular(12),
        ),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: p.surface,
        elevation: 6,
        shape: RoundedRectangleBorder(
          side: BorderSide(color: p.border, width: 1),
          borderRadius: BorderRadius.circular(16),
        ),
        titleTextStyle: TextStyle(
          color: p.textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
        contentTextStyle: TextStyle(
          color: p.textSecondary,
          fontSize: 14,
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: p.surface,
        modalBackgroundColor: p.surface,
        elevation: 8,
        shape: RoundedRectangleBorder(
          side: BorderSide(color: p.border, width: 1),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: p.surface,
        elevation: 6,
        shape: RoundedRectangleBorder(
          side: BorderSide(color: p.border, width: 1),
          borderRadius: BorderRadius.circular(10),
        ),
        textStyle: TextStyle(color: p.textPrimary, fontSize: 13),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: p.cardSurface,
        contentTextStyle: TextStyle(color: p.textPrimary, fontSize: 13),
        shape: RoundedRectangleBorder(
          side: BorderSide(color: p.border, width: 1),
          borderRadius: BorderRadius.circular(8),
        ),
        behavior: SnackBarBehavior.floating,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: p.cardSurface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        hintStyle: TextStyle(color: p.textSecondary, fontSize: 14),
        labelStyle: TextStyle(color: p.textSecondary, fontSize: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: p.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: p.border),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: p.border.withValues(alpha: 0.4)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: p.primaryAccent, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: p.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: p.error, width: 1.5),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: p.primaryAccent,
          foregroundColor: onPrimary,
          minimumSize: const Size(0, AppTouchTarget.min),
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
      textTheme: TextTheme(
        headlineMedium: TextStyle(color: p.textPrimary, fontWeight: FontWeight.bold),
        titleLarge: TextStyle(color: p.textPrimary, fontWeight: FontWeight.w600, fontSize: 18),
        titleMedium: TextStyle(color: p.textPrimary, fontWeight: FontWeight.w600, fontSize: 15),
        bodyLarge: TextStyle(color: p.textPrimary, fontSize: 14),
        bodyMedium: TextStyle(color: p.textSecondary, fontSize: 13),
        bodySmall: TextStyle(color: p.textMuted, fontSize: 11),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: p.textPrimary,
          side: BorderSide(color: p.border),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: p.primaryAccent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: p.primaryAccent,
        inactiveTrackColor: p.border,
        thumbColor: p.primaryAccent,
        overlayColor: p.primaryAccent.withValues(alpha: 0.18),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return p.primaryAccent;
          return p.textSecondary;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return p.primaryAccent.withValues(alpha: 0.4);
          return p.cardSurface;
        }),
        trackOutlineColor: WidgetStateProperty.all(p.border),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: p.cardSurface,
        selectedColor: p.primaryAccent,
        disabledColor: p.cardSurface,
        labelStyle: TextStyle(color: p.textPrimary, fontSize: 12),
        secondaryLabelStyle: const TextStyle(color: Colors.white, fontSize: 12),
        side: BorderSide(color: p.border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      extensions: [
        AppThemeExtension(palette: p),
      ],
    );
  }
}

/// Standardized top grab handle for bottom sheet modals across the app.
class SheetDragHandle extends StatelessWidget {
  const SheetDragHandle({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = context.appTheme;
    return Center(
      child: Container(
        width: 36,
        height: 4,
        margin: const EdgeInsets.only(top: 8, bottom: 6),
        decoration: BoxDecoration(
          color: theme.textSecondary.withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}

