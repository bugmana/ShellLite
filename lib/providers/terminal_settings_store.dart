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
  bool _isLoaded = false;

  TerminalSettingsStore({StorageService? storageService})
      : _storageService = storageService ?? StorageService();

  String get themeId => _themeId;
  double get fontSize => _fontSize;
  String get fontFamily => _fontFamily;
  bool get isLoaded => _isLoaded;

  TerminalThemePreset get activeThemePreset => TerminalThemePresets.getById(_themeId);
  TerminalTheme get activeTheme => activeThemePreset.theme;

  TerminalStyle get terminalStyle => TerminalStyle(
        fontSize: _fontSize,
        fontFamily: _fontFamily,
      );

  Future<void> load() async {
    _themeId = await _storageService.getTerminalThemeId();
    _fontSize = await _storageService.getTerminalFontSize();
    _fontFamily = await _storageService.getTerminalFontFamily();
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

  Future<void> resetDefaults() async {
    _themeId = 'obsidian';
    _fontSize = TerminalConfig.fontSize;
    _fontFamily = TerminalConfig.fontFamily;
    await _storageService.setTerminalThemeId(_themeId);
    await _storageService.setTerminalFontSize(_fontSize);
    await _storageService.setTerminalFontFamily(_fontFamily);
    notifyListeners();
  }
}
