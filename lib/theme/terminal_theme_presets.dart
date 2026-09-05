import 'package:flutter/material.dart';
import 'package:xterm/xterm.dart';

class AppThemePalette {
  final Color background;
  final Color surface;
  final Color cardSurface;
  final Color cardSurfaceHover;
  final Color border;
  final Color primaryAccent;
  final Color secondaryAccent;
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;
  final Color error;
  final Color warning;
  final Color success;

  const AppThemePalette({
    required this.background,
    required this.surface,
    required this.cardSurface,
    required this.cardSurfaceHover,
    required this.border,
    required this.primaryAccent,
    required this.secondaryAccent,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.error,
    required this.warning,
    required this.success,
  });
}

class TerminalThemePreset {
  final String id;
  final String name;
  final String description;
  final TerminalTheme theme;
  final List<Color> previewPalette;
  final AppThemePalette palette;

  const TerminalThemePreset({
    required this.id,
    required this.name,
    required this.description,
    required this.theme,
    required this.previewPalette,
    required this.palette,
  });
}

class TerminalThemePresets {
  static const obsidian = TerminalThemePreset(
    id: 'obsidian',
    name: 'ShellLite Obsidian',
    description: 'Deep black with emerald terminal green accents',
    theme: TerminalTheme(
      cursor: Color(0xFF3FB950),
      selection: Color(0x7758A6FF),
      foreground: Color(0xFFF0F6FC),
      background: Color(0xFF0B0F14),
      black: Color(0xFF30363D),
      red: Color(0xFFF85149),
      green: Color(0xFF3FB950),
      yellow: Color(0xFFD29922),
      blue: Color(0xFF58A6FF),
      magenta: Color(0xFFBC8CFF),
      cyan: Color(0xFF39C5CF),
      white: Color(0xFFD0D7DE),
      brightBlack: Color(0xFF6E7681),
      brightRed: Color(0xFFFFA198),
      brightGreen: Color(0xFF56D364),
      brightYellow: Color(0xFFE3B341),
      brightBlue: Color(0xFF79C0FF),
      brightMagenta: Color(0xFFD2A8FF),
      brightCyan: Color(0xFF56D4DD),
      brightWhite: Color(0xFFFFFFFF),
      searchHitBackground: Color(0x66D29922),
      searchHitBackgroundCurrent: Color(0xFF2EA043),
      searchHitForeground: Color(0xFFFFFFFF),
    ),
    previewPalette: [
      Color(0xFF0B0F14),
      Color(0xFF3FB950),
      Color(0xFF58A6FF),
      Color(0xFFF85149),
      Color(0xFFF0F6FC),
    ],
    palette: AppThemePalette(
      background: Color(0xFF0B0F14),
      surface: Color(0xFF161B22),
      cardSurface: Color(0xFF1F242C),
      cardSurfaceHover: Color(0xFF282F3A),
      border: Color(0xFF30363D),
      primaryAccent: Color(0xFF3FB950),
      secondaryAccent: Color(0xFF58A6FF),
      textPrimary: Color(0xFFF0F6FC),
      textSecondary: Color(0xFF8B949E),
      textMuted: Color(0xFF6E7681),
      error: Color(0xFFF85149),
      warning: Color(0xFFD29922),
      success: Color(0xFF3FB950),
    ),
  );

  static const catppuccinMocha = TerminalThemePreset(
    id: 'catppuccin',
    name: 'Catppuccin Mocha',
    description: 'Soothing pastel dark theme with soft hues',
    theme: TerminalTheme(
      cursor: Color(0xFFF5E0DC),
      selection: Color(0x7789B4FA),
      foreground: Color(0xFFCDD6F4),
      background: Color(0xFF1E1E2E),
      black: Color(0xFF45475A),
      red: Color(0xFFF38BA8),
      green: Color(0xFFA6E3A1),
      yellow: Color(0xFFF9E2AF),
      blue: Color(0xFF89B4FA),
      magenta: Color(0xFFF5C2E7),
      cyan: Color(0xFF94E2D5),
      white: Color(0xFFBAC2DE),
      brightBlack: Color(0xFF585B70),
      brightRed: Color(0xFFF38BA8),
      brightGreen: Color(0xFFA6E3A1),
      brightYellow: Color(0xFFF9E2AF),
      brightBlue: Color(0xFF89B4FA),
      brightMagenta: Color(0xFFF5C2E7),
      brightCyan: Color(0xFF94E2D5),
      brightWhite: Color(0xFFA6ADC8),
      searchHitBackground: Color(0x66F9E2AF),
      searchHitBackgroundCurrent: Color(0xFFA6E3A1),
      searchHitForeground: Color(0xFF1E1E2E),
    ),
    previewPalette: [
      Color(0xFF1E1E2E),
      Color(0xFFA6E3A1),
      Color(0xFF89B4FA),
      Color(0xFFF38BA8),
      Color(0xFFCDD6F4),
    ],
    palette: AppThemePalette(
      background: Color(0xFF1E1E2E),
      surface: Color(0xFF181825),
      cardSurface: Color(0xFF313244),
      cardSurfaceHover: Color(0xFF45475A),
      border: Color(0xFF45475A),
      primaryAccent: Color(0xFFA6E3A1),
      secondaryAccent: Color(0xFF89B4FA),
      textPrimary: Color(0xFFCDD6F4),
      textSecondary: Color(0xFFA6ADC8),
      textMuted: Color(0xFF6C7086),
      error: Color(0xFFF38BA8),
      warning: Color(0xFFF9E2AF),
      success: Color(0xFFA6E3A1),
    ),
  );

  static const dracula = TerminalThemePreset(
    id: 'dracula',
    name: 'Dracula',
    description: 'Vibrant dark theme with high contrast purples & pinks',
    theme: TerminalTheme(
      cursor: Color(0xFFF8F8F2),
      selection: Color(0x77BD93F9),
      foreground: Color(0xFFF8F8F2),
      background: Color(0xFF282A36),
      black: Color(0xFF21222C),
      red: Color(0xFFFF5555),
      green: Color(0xFF50FA7B),
      yellow: Color(0xFFF1FA8C),
      blue: Color(0xFFBD93F9),
      magenta: Color(0xFFFF79C6),
      cyan: Color(0xFF8BE9FD),
      white: Color(0xFFF8F8F2),
      brightBlack: Color(0xFF6272A4),
      brightRed: Color(0xFFFF6E6E),
      brightGreen: Color(0xFF69FF94),
      brightYellow: Color(0xFFFFFFA5),
      brightBlue: Color(0xFFD6ACFF),
      brightMagenta: Color(0xFFFF92DF),
      brightCyan: Color(0xFFA4FFFF),
      brightWhite: Color(0xFFFFFFFF),
      searchHitBackground: Color(0x66F1FA8C),
      searchHitBackgroundCurrent: Color(0xFF50FA7B),
      searchHitForeground: Color(0xFF282A36),
    ),
    previewPalette: [
      Color(0xFF282A36),
      Color(0xFF50FA7B),
      Color(0xFFBD93F9),
      Color(0xFFFF79C6),
      Color(0xFFF8F8F2),
    ],
    palette: AppThemePalette(
      background: Color(0xFF282A36),
      surface: Color(0xFF21222C),
      cardSurface: Color(0xFF343746),
      cardSurfaceHover: Color(0xFF44475A),
      border: Color(0xFF44475A),
      primaryAccent: Color(0xFF50FA7B),
      secondaryAccent: Color(0xFFBD93F9),
      textPrimary: Color(0xFFF8F8F2),
      textSecondary: Color(0xFF6272A4),
      textMuted: Color(0xFF4E5A7E),
      error: Color(0xFFFF5555),
      warning: Color(0xFFF1FA8C),
      success: Color(0xFF50FA7B),
    ),
  );

  static const nord = TerminalThemePreset(
    id: 'nord',
    name: 'Nord',
    description: 'Arctic, north-bluish clean color palette',
    theme: TerminalTheme(
      cursor: Color(0xFFD8DEE9),
      selection: Color(0x7788C0D0),
      foreground: Color(0xFFD8DEE9),
      background: Color(0xFF2E3440),
      black: Color(0xFF3B4252),
      red: Color(0xFFBF616A),
      green: Color(0xFFA3BE8C),
      yellow: Color(0xFFEBCB8B),
      blue: Color(0xFF81A1C1),
      magenta: Color(0xFFB48EAD),
      cyan: Color(0xFF88C0D0),
      white: Color(0xFFE5E9F0),
      brightBlack: Color(0xFF4C566A),
      brightRed: Color(0xFFBF616A),
      brightGreen: Color(0xFFA3BE8C),
      brightYellow: Color(0xFFEBCB8B),
      brightBlue: Color(0xFF81A1C1),
      brightMagenta: Color(0xFFB48EAD),
      brightCyan: Color(0xFF8FBCBB),
      brightWhite: Color(0xFFECEFF4),
      searchHitBackground: Color(0x66EBCB8B),
      searchHitBackgroundCurrent: Color(0xFFA3BE8C),
      searchHitForeground: Color(0xFF2E3440),
    ),
    previewPalette: [
      Color(0xFF2E3440),
      Color(0xFFA3BE8C),
      Color(0xFF88C0D0),
      Color(0xFFBF616A),
      Color(0xFFD8DEE9),
    ],
    palette: AppThemePalette(
      background: Color(0xFF2E3440),
      surface: Color(0xFF242933),
      cardSurface: Color(0xFF3B4252),
      cardSurfaceHover: Color(0xFF434C5E),
      border: Color(0xFF4C566A),
      primaryAccent: Color(0xFFA3BE8C),
      secondaryAccent: Color(0xFF88C0D0),
      textPrimary: Color(0xFFECEFF4),
      textSecondary: Color(0xFFD8DEE9),
      textMuted: Color(0xFF9AA7B9),
      error: Color(0xFFBF616A),
      warning: Color(0xFFEBCB8B),
      success: Color(0xFFA3BE8C),
    ),
  );

  static const tokyoNight = TerminalThemePreset(
    id: 'tokyo_night',
    name: 'Tokyo Night',
    description: 'Clean dark theme inspired by Tokyo neon lights',
    theme: TerminalTheme(
      cursor: Color(0xFFC0CAF5),
      selection: Color(0x777AA2F7),
      foreground: Color(0xFFA9B1D6),
      background: Color(0xFF1A1B26),
      black: Color(0xFF32344A),
      red: Color(0xFFF7768E),
      green: Color(0xFF9ECE6A),
      yellow: Color(0xFFE0AF68),
      blue: Color(0xFF7AA2F7),
      magenta: Color(0xFFBB9AF7),
      cyan: Color(0xFF7DCFFF),
      white: Color(0xFFA9B1D6),
      brightBlack: Color(0xFF444B6A),
      brightRed: Color(0xFFFF7A93),
      brightGreen: Color(0xFFB9F27C),
      brightYellow: Color(0xFFFF9E3B),
      brightBlue: Color(0xFF7DA6FF),
      brightMagenta: Color(0xFFC0CAF5),
      brightCyan: Color(0xFF0DB9D7),
      brightWhite: Color(0xFFC0CAF5),
      searchHitBackground: Color(0x66E0AF68),
      searchHitBackgroundCurrent: Color(0xFF9ECE6A),
      searchHitForeground: Color(0xFF1A1B26),
    ),
    previewPalette: [
      Color(0xFF1A1B26),
      Color(0xFF9ECE6A),
      Color(0xFF7AA2F7),
      Color(0xFFF7768E),
      Color(0xFFA9B1D6),
    ],
    palette: AppThemePalette(
      background: Color(0xFF1A1B26),
      surface: Color(0xFF16161E),
      cardSurface: Color(0xFF24283B),
      cardSurfaceHover: Color(0xFF2F354D),
      border: Color(0xFF383E5A),
      primaryAccent: Color(0xFF9ECE6A),
      secondaryAccent: Color(0xFF7AA2F7),
      textPrimary: Color(0xFFC0CAF5),
      textSecondary: Color(0xFF7982A9),
      textMuted: Color(0xFF565F89),
      error: Color(0xFFF7768E),
      warning: Color(0xFFE0AF68),
      success: Color(0xFF9ECE6A),
    ),
  );

  static const solarizedDark = TerminalThemePreset(
    id: 'solarized_dark',
    name: 'Solarized Dark',
    description: 'Scientifically calibrated precision color palette',
    theme: TerminalTheme(
      cursor: Color(0xFF93A1A1),
      selection: Color(0x772AA198),
      foreground: Color(0xFF839496),
      background: Color(0xFF002B36),
      black: Color(0xFF073642),
      red: Color(0xFFDC322F),
      green: Color(0xFF859900),
      yellow: Color(0xFFB58900),
      blue: Color(0xFF268BD2),
      magenta: Color(0xFFD33682),
      cyan: Color(0xFF2AA198),
      white: Color(0xFFEEE8D5),
      brightBlack: Color(0xFF002B36),
      brightRed: Color(0xFFCB4B16),
      brightGreen: Color(0xFF586E75),
      brightYellow: Color(0xFF657B83),
      brightBlue: Color(0xFF839496),
      brightMagenta: Color(0xFF6C71C4),
      brightCyan: Color(0xFF93A1A1),
      brightWhite: Color(0xFFFDF6E3),
      searchHitBackground: Color(0x66B58900),
      searchHitBackgroundCurrent: Color(0xFF859900),
      searchHitForeground: Color(0xFF002B36),
    ),
    previewPalette: [
      Color(0xFF002B36),
      Color(0xFF859900),
      Color(0xFF268BD2),
      Color(0xFFDC322F),
      Color(0xFF839496),
    ],
    palette: AppThemePalette(
      background: Color(0xFF002B36),
      surface: Color(0xFF00212B),
      cardSurface: Color(0xFF073642),
      cardSurfaceHover: Color(0xFF0E4351),
      border: Color(0xFF0F4756),
      primaryAccent: Color(0xFF859900),
      secondaryAccent: Color(0xFF268BD2),
      textPrimary: Color(0xFFEEE8D5),
      textSecondary: Color(0xFF839496),
      textMuted: Color(0xFF657B83),
      error: Color(0xFFDC322F),
      warning: Color(0xFFB58900),
      success: Color(0xFF859900),
    ),
  );

  static const List<TerminalThemePreset> all = [
    obsidian,
    catppuccinMocha,
    dracula,
    nord,
    tokyoNight,
    solarizedDark,
  ];

  static TerminalThemePreset getById(String? id) {
    if (id == null) return obsidian;
    return all.firstWhere(
      (preset) => preset.id == id,
      orElse: () => obsidian,
    );
  }
}
