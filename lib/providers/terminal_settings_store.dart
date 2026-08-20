import 'package:flutter/foundation.dart';
import 'package:xterm/xterm.dart';
import '../config/app_config.dart';
import '../services/storage_service.dart';
import '../theme/terminal_theme_presets.dart';

class TerminalSettingsStore extends ChangeNotifier {
  final StorageService _storageService;

  String _themeId = 'obsidian';
  double _fontSize = TerminalConfig.fontSize;
  String _fontFamily = TerminalConfig.fontFamily;
  List<AccessoryKeyItem> _configuredAccessoryKeys = AccessoryBarConfig.initialConfiguredKeys;
  bool _hapticFeedbackEnabled = true;
  bool _isLoaded = false;

  TerminalSettingsStore({StorageService? storageService})
      : _storageService = storageService ?? StorageService();

  String get themeId => _themeId;
  double get fontSize => _fontSize;
  String get fontFamily => _fontFamily;
  List<AccessoryKeyItem> get configuredAccessoryKeys => List.unmodifiable(_configuredAccessoryKeys);
  List<TerminalKeyShortcut> get accessoryKeys =>
      _configuredAccessoryKeys.where((k) => k.isEnabled).map((k) => k.toShortcut()).toList();
  bool get hapticFeedbackEnabled => _hapticFeedbackEnabled;
  bool get isLoaded => _isLoaded;

  TerminalThemePreset get activeThemePreset => TerminalThemePresets.getById(_themeId);
  TerminalTheme get activeTheme => activeThemePreset.theme;

  TerminalStyle get terminalStyle => TerminalStyle(
        fontSize: _fontSize,
        fontFamily: _fontFamily,
        fontFamilyFallback: TerminalConfig.fontFamilyFallback,
      );

  Future<void> load() async {
    _themeId = await _storageService.getTerminalThemeId();
    _fontSize = await _storageService.getTerminalFontSize();
    _fontFamily = await _storageService.getTerminalFontFamily();
    _configuredAccessoryKeys = await _storageService.loadAccessoryKeys();
    _hapticFeedbackEnabled = await _storageService.getHapticFeedbackEnabled();
    _isLoaded = true;
    notifyListeners();
  }

  Future<void> setTheme(String themeId) async {
    _themeId = themeId;
    await _storageService.setTerminalThemeId(themeId);
    notifyListeners();
  }

  Future<void> setFontSize(double size) async {
    _fontSize = size.clamp(9.0, 26.0);
    await _storageService.setTerminalFontSize(_fontSize);
    notifyListeners();
  }

  Future<void> setFontFamily(String family) async {
    _fontFamily = family;
    await _storageService.setTerminalFontFamily(family);
    notifyListeners();
  }

  Future<void> setHapticFeedbackEnabled(bool enabled) async {
    _hapticFeedbackEnabled = enabled;
    await _storageService.setHapticFeedbackEnabled(enabled);
    notifyListeners();
  }

  Future<void> reorderAccessoryKeys(int oldIndex, int newIndex) async {
    if (oldIndex < 0 || oldIndex >= _configuredAccessoryKeys.length) return;
    if (newIndex < 0 || newIndex > _configuredAccessoryKeys.length) return;

    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    final item = _configuredAccessoryKeys.removeAt(oldIndex);
    _configuredAccessoryKeys.insert(newIndex, item);
    await _storageService.saveAccessoryKeys(_configuredAccessoryKeys);
    notifyListeners();
  }

  Future<void> toggleAccessoryKeyVisibility(int index) async {
    if (index < 0 || index >= _configuredAccessoryKeys.length) return;
    final item = _configuredAccessoryKeys[index];
    _configuredAccessoryKeys[index] = item.copyWith(isEnabled: !item.isEnabled);
    await _storageService.saveAccessoryKeys(_configuredAccessoryKeys);
    notifyListeners();
  }

  Future<void> addCustomAccessoryKey({
    required String label,
    required String sequence,
    String? description,
  }) async {
    final parsedSequence = parseKeySequence(sequence);
    final item = AccessoryKeyItem(
      id: 'cust_${DateTime.now().microsecondsSinceEpoch}',
      label: label.trim(),
      sequence: parsedSequence,
      description: description?.trim().isNotEmpty == true ? description!.trim() : null,
      isEnabled: true,
      isCustom: true,
    );
    _configuredAccessoryKeys.add(item);
    await _storageService.saveAccessoryKeys(_configuredAccessoryKeys);
    notifyListeners();
  }

  Future<void> removeAccessoryKey(int index) async {
    if (index < 0 || index >= _configuredAccessoryKeys.length) return;
    _configuredAccessoryKeys.removeAt(index);
    await _storageService.saveAccessoryKeys(_configuredAccessoryKeys);
    notifyListeners();
  }

  Future<void> resetAccessoryKeysToDefault() async {
    _configuredAccessoryKeys = List.from(AccessoryBarConfig.initialConfiguredKeys);
    await _storageService.saveAccessoryKeys(_configuredAccessoryKeys);
    notifyListeners();
  }

  Future<void> resetDefaults() async {
    _themeId = 'obsidian';
    _fontSize = TerminalConfig.fontSize;
    _fontFamily = TerminalConfig.fontFamily;
    _hapticFeedbackEnabled = true;
    _configuredAccessoryKeys = List.from(AccessoryBarConfig.initialConfiguredKeys);
    await _storageService.setTerminalThemeId(_themeId);
    await _storageService.setTerminalFontSize(_fontSize);
    await _storageService.setTerminalFontFamily(_fontFamily);
    await _storageService.setHapticFeedbackEnabled(_hapticFeedbackEnabled);
    await _storageService.saveAccessoryKeys(_configuredAccessoryKeys);
    notifyListeners();
  }
}
