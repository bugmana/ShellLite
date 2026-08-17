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
    expect(store.fontFamily, 'monospace');
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

  test('TerminalThemePresets returns obsidian on unknown id', () {
    final preset = TerminalThemePresets.getById('non_existent');
    expect(preset.id, 'obsidian');
  });
}
