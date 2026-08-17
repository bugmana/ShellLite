import 'package:xterm/xterm.dart';
import '../theme/app_theme.dart';

/// Configuration for the ANSI terminal emulator.
class TerminalConfig {
  static const String fontFamily = 'monospace';
  static const double fontSize = 13.5;
  static const int maxScrollbackLines = 10000;
  static const int defaultWidth = 80;
  static const int defaultHeight = 24;

  static TerminalTheme get theme => AppTheme.terminalTheme;

  static const TerminalStyle textStyle = TerminalStyle(
    fontSize: fontSize,
    fontFamily: fontFamily,
  );
}

/// Server and Profile limits.
class ServerConfig {
  static const int maxServers = 10;
}

/// SSH Connection and Networking defaults.
class SSHConfig {
  static const int defaultPort = 22;
  static const Duration connectTimeout = Duration(seconds: 15);
  static const Duration keepAliveInterval = Duration(seconds: 30);
}

/// Storage keys and persistence constants.
class StorageConfig {
  static const String profilesKey = 'shell_lite_server_profiles_v1';
  static const String credentialPrefix = 'cred_';
  static const String hasSeenGestureTipKey = 'shell_lite_has_seen_gesture_tip_v1';
  static const String terminalThemeKey = 'shell_lite_terminal_theme_id_v1';
  static const String terminalFontSizeKey = 'shell_lite_terminal_font_size_v1';
  static const String terminalFontFamilyKey = 'shell_lite_terminal_font_family_v1';
  static const String snippetsKey = 'shell_lite_snippets_v1';

  static String buildCredentialTag(String profileId) => '$credentialPrefix$profileId';
}

/// Key shortcuts for the terminal keyboard accessory bar.
class TerminalKeyShortcut {
  final String label;
  final String sequence;

  const TerminalKeyShortcut({required this.label, required this.sequence});
}

class AccessoryBarConfig {
  static const double barHeight = 46.0;

  static const List<TerminalKeyShortcut> defaultKeys = [
    TerminalKeyShortcut(label: '⇥ Tab', sequence: '\t'),
    TerminalKeyShortcut(label: '^C', sequence: '\x03'),
    TerminalKeyShortcut(label: '^D', sequence: '\x04'),
    TerminalKeyShortcut(label: '↑', sequence: '\x1B[A'),
    TerminalKeyShortcut(label: '↓', sequence: '\x1B[B'),
    TerminalKeyShortcut(label: '←', sequence: '\x1B[D'),
    TerminalKeyShortcut(label: '→', sequence: '\x1B[C'),
    TerminalKeyShortcut(label: 'Esc', sequence: '\x1B'),
    TerminalKeyShortcut(label: '|', sequence: '|'),
    TerminalKeyShortcut(label: '~', sequence: '~'),
    TerminalKeyShortcut(label: '/', sequence: '/'),
    TerminalKeyShortcut(label: '-', sequence: '-'),
  ];
}
