import 'package:xterm/xterm.dart';
import '../theme/app_theme.dart';

/// Configuration for the ANSI terminal emulator.
class TerminalConfig {
  static const String fontFamily = 'JetBrains Mono';
  static const List<String> fontFamilyFallback = [
    'JetBrains Mono',
    'Roboto Mono',
    'Fira Code',
    'Cascadia Code',
    'Menlo',
    'Monaco',
    'Consolas',
    'Liberation Mono',
    'Courier New',
    'monospace',
  ];
  static const double fontSize = 13.5;
  static const int maxScrollbackLines = 10000;
  static const int defaultWidth = 80;
  static const int defaultHeight = 24;

  static TerminalTheme get theme => AppTheme.terminalTheme;

  static const TerminalStyle textStyle = TerminalStyle(
    fontSize: fontSize,
    fontFamily: fontFamily,
    fontFamilyFallback: fontFamilyFallback,
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
  static const String keyPassphrasePrefix = 'key_pass_';
  static const String hasSeenGestureTipKey = 'shell_lite_has_seen_gesture_tip_v1';
  static const String terminalThemeKey = 'shell_lite_terminal_theme_id_v1';
  static const String terminalFontSizeKey = 'shell_lite_terminal_font_size_v1';
  static const String terminalFontFamilyKey = 'shell_lite_terminal_font_family_v1';
  static const String accessoryKeysKey = 'shell_lite_accessory_keys_v1';
  static const String hapticFeedbackKey = 'shell_lite_haptic_feedback_v1';

  static String buildCredentialTag(String profileId) => '$credentialPrefix$profileId';
  static String buildKeyPassphraseTag(String profileId) => '$keyPassphrasePrefix$profileId';
}

/// Helper to decode escape codes from user input into terminal sequences.
String parseKeySequence(String raw) {
  var result = raw;
  result = result.replaceAll(r'\e', '\x1B');
  result = result.replaceAll(r'\x1b', '\x1B');
  result = result.replaceAll(r'\x1B', '\x1B');
  result = result.replaceAll(r'\t', '\t');
  result = result.replaceAll(r'\n', '\n');
  result = result.replaceAll(r'\r', '\r');

  // Translate ^A to ^Z
  for (int i = 1; i <= 26; i++) {
    final letter = String.fromCharCode(64 + i);
    final ctrlChar = String.fromCharCode(i);
    result = result.replaceAll('^$letter', ctrlChar);
  }
  result = result.replaceAll(r'^]', '\x1D');
  result = result.replaceAll(r'^^', '\x1E');
  result = result.replaceAll(r'^_', '\x1F');
  result = result.replaceAll(r'^?', '\x7F');
  result = result.replaceAll(r'^[', '\x1B');
  result = result.replaceAll(r'^\', '\x1C');

  return result;
}

/// Key shortcuts for the terminal keyboard accessory bar.
class TerminalKeyShortcut {
  final String label;
  final String sequence;
  final String? description;

  const TerminalKeyShortcut({
    required this.label,
    required this.sequence,
    this.description,
  });
}

/// Configurable item in the keyboard accessory bar.
class AccessoryKeyItem {
  final String id;
  final String label;
  final String sequence;
  final String? description;
  final bool isEnabled;
  final bool isCustom;

  const AccessoryKeyItem({
    required this.id,
    required this.label,
    required this.sequence,
    this.description,
    this.isEnabled = true,
    this.isCustom = false,
  });

  TerminalKeyShortcut toShortcut() => TerminalKeyShortcut(
        label: label,
        sequence: sequence,
        description: description,
      );

  AccessoryKeyItem copyWith({
    String? id,
    String? label,
    String? sequence,
    String? description,
    bool? isEnabled,
    bool? isCustom,
  }) {
    return AccessoryKeyItem(
      id: id ?? this.id,
      label: label ?? this.label,
      sequence: sequence ?? this.sequence,
      description: description ?? this.description,
      isEnabled: isEnabled ?? this.isEnabled,
      isCustom: isCustom ?? this.isCustom,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'label': label,
        'sequence': sequence,
        'description': description,
        'isEnabled': isEnabled,
        'isCustom': isCustom,
      };

  factory AccessoryKeyItem.fromJson(Map<String, dynamic> json) {
    return AccessoryKeyItem(
      id: json['id'] as String? ?? json['label'] as String,
      label: json['label'] as String,
      sequence: json['sequence'] as String,
      description: json['description'] as String?,
      isEnabled: json['isEnabled'] as bool? ?? true,
      isCustom: json['isCustom'] as bool? ?? false,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AccessoryKeyItem &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          label == other.label &&
          sequence == other.sequence &&
          isEnabled == other.isEnabled &&
          isCustom == other.isCustom;

  @override
  int get hashCode => Object.hash(id, label, sequence, isEnabled, isCustom);
}

class AccessoryBarConfig {
  static const double barHeight = 46.0;

  static const List<TerminalKeyShortcut> defaultKeys = [
    TerminalKeyShortcut(label: 'Tab', sequence: '\t'),
    TerminalKeyShortcut(label: '⇧Tab', sequence: '\x1B[Z'),
    TerminalKeyShortcut(label: '↑', sequence: '\x1B[A'),
    TerminalKeyShortcut(label: '↓', sequence: '\x1B[B'),
    TerminalKeyShortcut(label: '←', sequence: '\x1B[D'),
    TerminalKeyShortcut(label: '→', sequence: '\x1B[C'),
    TerminalKeyShortcut(label: 'Esc', sequence: '\x1B'),
    TerminalKeyShortcut(label: '^C', sequence: '\x03'),
    TerminalKeyShortcut(label: '^D', sequence: '\x04'),
    TerminalKeyShortcut(label: '|', sequence: '|'),
    TerminalKeyShortcut(label: '~', sequence: '~'),
    TerminalKeyShortcut(label: '/', sequence: '/'),
    TerminalKeyShortcut(label: '-', sequence: '-'),
  ];

  static List<AccessoryKeyItem> get initialConfiguredKeys => defaultKeys
      .asMap()
      .entries
      .map(
        (e) => AccessoryKeyItem(
          id: 'def_${e.key}_${e.value.label}',
          label: e.value.label,
          sequence: e.value.sequence,
          description: e.value.description,
          isEnabled: true,
          isCustom: false,
        ),
      )
      .toList();

  static const List<TerminalKeyShortcut> controlKeys = [
    TerminalKeyShortcut(label: '^A', sequence: '\x01', description: 'Start of line'),
    TerminalKeyShortcut(label: '^E', sequence: '\x05', description: 'End of line'),
    TerminalKeyShortcut(label: '^U', sequence: '\x15', description: 'Clear line before cursor'),
    TerminalKeyShortcut(label: '^K', sequence: '\x0B', description: 'Clear line after cursor'),
    TerminalKeyShortcut(label: '^W', sequence: '\x17', description: 'Delete word backward'),
    TerminalKeyShortcut(label: '^R', sequence: '\x12', description: 'History reverse search'),
    TerminalKeyShortcut(label: '^L', sequence: '\x0C', description: 'Clear screen'),
    TerminalKeyShortcut(label: '^Z', sequence: '\x1A', description: 'Suspend process (SIGTSTP)'),
    TerminalKeyShortcut(label: '^C', sequence: '\x03', description: 'Interrupt process (SIGINT)'),
    TerminalKeyShortcut(label: '^D', sequence: '\x04', description: 'EOF / Exit shell'),
    TerminalKeyShortcut(label: '^B', sequence: '\x02', description: 'Cursor back / tmux prefix'),
    TerminalKeyShortcut(label: '^F', sequence: '\x06', description: 'Cursor forward'),
    TerminalKeyShortcut(label: '^P', sequence: '\x10', description: 'Previous command'),
    TerminalKeyShortcut(label: '^N', sequence: '\x0E', description: 'Next command'),
    TerminalKeyShortcut(label: '^\\', sequence: '\x1C', description: 'Quit process (SIGQUIT)'),
  ];

  static const List<TerminalKeyShortcut> navigationKeys = [
    TerminalKeyShortcut(label: 'Home', sequence: '\x1B[H', description: 'Cursor to start of line'),
    TerminalKeyShortcut(label: 'End', sequence: '\x1B[F', description: 'Cursor to end of line'),
    TerminalKeyShortcut(label: 'PgUp', sequence: '\x1B[5~', description: 'Page Up'),
    TerminalKeyShortcut(label: 'PgDn', sequence: '\x1B[6~', description: 'Page Down'),
    TerminalKeyShortcut(label: 'Insert', sequence: '\x1B[2~', description: 'Insert toggle'),
    TerminalKeyShortcut(label: 'Delete', sequence: '\x1B[3~', description: 'Forward delete'),
    TerminalKeyShortcut(label: 'Tab', sequence: '\t', description: 'Forward tab'),
    TerminalKeyShortcut(label: '⇧Tab', sequence: '\x1B[Z', description: 'Back tab / Reverse navigation'),
    TerminalKeyShortcut(label: 'Esc', sequence: '\x1B', description: 'Escape key'),
  ];

  static const List<TerminalKeyShortcut> functionKeys = [
    TerminalKeyShortcut(label: 'F1', sequence: '\x1BOP', description: 'Help / Menu'),
    TerminalKeyShortcut(label: 'F2', sequence: '\x1BOQ', description: 'Menu / User menu'),
    TerminalKeyShortcut(label: 'F3', sequence: '\x1BOR', description: 'View file'),
    TerminalKeyShortcut(label: 'F4', sequence: '\x1BOS', description: 'Edit file'),
    TerminalKeyShortcut(label: 'F5', sequence: '\x1B[15~', description: 'Copy / Refresh'),
    TerminalKeyShortcut(label: 'F6', sequence: '\x1B[17~', description: 'Move / Ren'),
    TerminalKeyShortcut(label: 'F7', sequence: '\x1B[18~', description: 'Mkdir / Search'),
    TerminalKeyShortcut(label: 'F8', sequence: '\x1B[19~', description: 'Delete file'),
    TerminalKeyShortcut(label: 'F9', sequence: '\x1B[20~', description: 'Pull-down menu'),
    TerminalKeyShortcut(label: 'F10', sequence: '\x1B[21~', description: 'Quit / Exit'),
    TerminalKeyShortcut(label: 'F11', sequence: '\x1B[23~', description: 'Full screen / Function 11'),
    TerminalKeyShortcut(label: 'F12', sequence: '\x1B[24~', description: 'Function 12'),
  ];
}
