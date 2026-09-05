import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shell_lite/providers/terminal_settings_store.dart';
import 'package:shell_lite/services/storage_service.dart';
import 'package:shell_lite/theme/terminal_theme_presets.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late StorageService storageService;
  late TerminalSettingsStore store;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    storageService = StorageService();
    store = TerminalSettingsStore(storageService: storageService);
  });

  test('TerminalSettingsStore initializes with defaults and loads', () async {
    await store.load();
    expect(store.themeId, 'obsidian');
    expect(store.fontSize, 13.5);
    expect(store.fontFamily, 'JetBrains Mono');
    expect(store.activeThemePreset.id, 'obsidian');
  });

  test('TerminalSettingsStore changes theme and persists', () async {
    await store.load();
    await store.setTheme('dracula');

    expect(store.themeId, 'dracula');
    expect(store.activeThemePreset.name, 'Dracula');

    final loadedId = await storageService.getTerminalThemeId();
    expect(loadedId, 'dracula');
  });

  test('TerminalSettingsStore changes font size within clamp limits', () async {
    await store.load();
    await store.setFontSize(16.0);
    expect(store.fontSize, 16.0);

    await store.setFontSize(40.0);
    expect(store.fontSize, 26.0);

    await store.setFontSize(5.0);
    expect(store.fontSize, 9.0);
  });

  test('TerminalSettingsStore resetDefaults restores initial settings', () async {
    await store.load();
    await store.setTheme('catppuccin');
    await store.setFontSize(18.0);

    await store.resetDefaults();
    expect(store.themeId, 'obsidian');
    expect(store.fontSize, 13.5);
  });

  test('TerminalSettingsStore reorders, toggles, adds custom keys and resets', () async {
    await store.load();
    expect(store.hapticFeedbackEnabled, isTrue);
    expect(store.accessoryKeys.first.label, 'Tab');

    // Toggle haptic feedback
    await store.setHapticFeedbackEnabled(false);
    expect(store.hapticFeedbackEnabled, isFalse);

    // Toggle key visibility
    final initialCount = store.accessoryKeys.length;
    await store.toggleAccessoryKeyVisibility(0); // disables 'Tab'
    expect(store.accessoryKeys.length, initialCount - 1);
    expect(store.accessoryKeys.first.label, '⇧Tab');

    // Add custom key
    await store.addCustomAccessoryKey(
      label: 'sudo',
      sequence: r'sudo \n',
      description: 'Run as superuser',
    );
    expect(store.configuredAccessoryKeys.last.label, 'sudo');
    expect(store.configuredAccessoryKeys.last.sequence, 'sudo \n');
    expect(store.configuredAccessoryKeys.last.isCustom, isTrue);

    // Reorder key
    final lastIdx = store.configuredAccessoryKeys.length - 1;
    await store.reorderAccessoryKeys(lastIdx, 0);
    expect(store.configuredAccessoryKeys.first.label, 'sudo');

    // Remove key
    await store.removeAccessoryKey(0);
    expect(store.configuredAccessoryKeys.first.label, 'Tab');

    // Reset to defaults
    await store.resetAccessoryKeysToDefault();
    expect(store.configuredAccessoryKeys.length, 7);
    expect(store.accessoryKeys.first.label, 'Tab');
  });

  test('TerminalThemePresets returns obsidian on unknown id', () {
    final preset = TerminalThemePresets.getById('non_existent');
    expect(preset.id, 'obsidian');
  });
}
