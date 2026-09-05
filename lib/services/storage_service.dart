import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/app_config.dart';
import '../models/server_profile.dart';

/// Handles persistence for ServerProfiles and encrypted credentials.
class StorageService {
  static const _profilesKey = StorageConfig.profilesKey;

  static const FlutterSecureStorage _defaultSecureStorage = FlutterSecureStorage(
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
      synchronizable: false,
    ),
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
      resetOnError: true,
    ),
    mOptions: MacOsOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
    lOptions: LinuxOptions(),
  );

  final FlutterSecureStorage _secureStorage;
  final Map<String, String> _inMemoryCredentials = {};
  SharedPreferences? _prefs;

  StorageService({
    FlutterSecureStorage? secureStorage,
    SharedPreferences? prefs,
  })  : _secureStorage = secureStorage ?? _defaultSecureStorage,
        _prefs = prefs;

  Future<SharedPreferences> get _sharedPrefs async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }

  // ── Profile Metadata ────────────────────────────────────────────────────────

  Future<List<ServerProfile>> loadProfiles() async {
    try {
      final prefs = await _sharedPrefs;
      final rawJson = prefs.getString(_profilesKey);
      if (rawJson == null || rawJson.isEmpty) return [];

      final List<dynamic> list = json.decode(rawJson) as List<dynamic>;
      return list
          .map((item) => ServerProfile.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('StorageService.loadProfiles error: $e');
      return [];
    }
  }

  Future<void> saveProfiles(List<ServerProfile> profiles) async {
    try {
      final prefs = await _sharedPrefs;
      final rawJson = json.encode(profiles.map((p) => p.toJson()).toList());
      await prefs.setString(_profilesKey, rawJson);
    } catch (e) {
      debugPrint('StorageService.saveProfiles error: $e');
    }
  }

  // ── Secure Credentials (Passwords & Private Keys) ──────────────────────────

  static const _webCredPrefix = 'shell_lite_wc_';

  Future<void> saveCredential(String tag, String value) async {
    _inMemoryCredentials[tag] = value;
    if (kIsWeb) {
      try {
        final prefs = await _sharedPrefs;
        final encoded = base64Encode(utf8.encode(value));
        await prefs.setString('$_webCredPrefix$tag', encoded);
      } catch (e) {
        debugPrint('StorageService.saveCredential web error: $e');
      }
      return;
    }
    try {
      await _secureStorage
          .write(key: tag, value: value)
          .timeout(const Duration(milliseconds: 300));
    } catch (e) {
      debugPrint('StorageService.saveCredential secureStorage fallback to in-memory: $e');
    }
  }

  Future<String?> retrieveCredential(String tag) async {
    if (_inMemoryCredentials.containsKey(tag)) {
      return _inMemoryCredentials[tag];
    }
    if (kIsWeb) {
      try {
        final prefs = await _sharedPrefs;
        final raw = prefs.getString('$_webCredPrefix$tag');
        if (raw != null && raw.isNotEmpty) {
          final decoded = utf8.decode(base64Decode(raw));
          _inMemoryCredentials[tag] = decoded;
          return decoded;
        }
      } catch (e) {
        debugPrint('StorageService.retrieveCredential web error: $e');
      }
      return null;
    }
    try {
      final val = await _secureStorage
          .read(key: tag)
          .timeout(const Duration(milliseconds: 300));
      if (val != null) {
        _inMemoryCredentials[tag] = val;
        return val;
      }
    } catch (e) {
      debugPrint('StorageService.retrieveCredential error: $e');
    }
    return _inMemoryCredentials[tag];
  }

  Future<void> deleteCredential(String tag) async {
    _inMemoryCredentials.remove(tag);
    if (kIsWeb) {
      try {
        final prefs = await _sharedPrefs;
        await prefs.remove('$_webCredPrefix$tag');
      } catch (_) {}
      return;
    }
    try {
      await _secureStorage
          .delete(key: tag)
          .timeout(const Duration(milliseconds: 300));
    } catch (e) {
      debugPrint('StorageService.deleteCredential error: $e');
    }
  }

  // ── Terminal Preferences ───────────────────────────────────────────────────

  Future<String> getTerminalThemeId() async {
    try {
      final prefs = await _sharedPrefs;
      return prefs.getString(StorageConfig.terminalThemeKey) ?? 'obsidian';
    } catch (_) {
      return 'obsidian';
    }
  }

  Future<void> setTerminalThemeId(String themeId) async {
    try {
      final prefs = await _sharedPrefs;
      await prefs.setString(StorageConfig.terminalThemeKey, themeId);
    } catch (_) {}
  }

  Future<double> getTerminalFontSize() async {
    try {
      final prefs = await _sharedPrefs;
      return prefs.getDouble(StorageConfig.terminalFontSizeKey) ?? TerminalConfig.fontSize;
    } catch (_) {
      return TerminalConfig.fontSize;
    }
  }

  Future<void> setTerminalFontSize(double fontSize) async {
    try {
      final prefs = await _sharedPrefs;
      await prefs.setDouble(StorageConfig.terminalFontSizeKey, fontSize);
    } catch (_) {}
  }

  Future<String> getTerminalFontFamily() async {
    try {
      final prefs = await _sharedPrefs;
      return prefs.getString(StorageConfig.terminalFontFamilyKey) ?? TerminalConfig.fontFamily;
    } catch (_) {
      return TerminalConfig.fontFamily;
    }
  }

  Future<void> setTerminalFontFamily(String fontFamily) async {
    try {
      final prefs = await _sharedPrefs;
      await prefs.setString(StorageConfig.terminalFontFamilyKey, fontFamily);
    } catch (_) {}
  }

  // ── Accessory Bar Keys Persistence ─────────────────────────────────────────

  Future<List<AccessoryKeyItem>> loadAccessoryKeys() async {
    try {
      final prefs = await _sharedPrefs;
      final raw = prefs.getString(StorageConfig.accessoryKeysKey);
      if (raw == null || raw.isEmpty) {
        return AccessoryBarConfig.initialConfiguredKeys;
      }
      final List decoded = jsonDecode(raw);
      return decoded.map((e) => AccessoryKeyItem.fromJson(e as Map<String, dynamic>)).toList();
    } catch (e) {
      debugPrint('StorageService.loadAccessoryKeys error: $e');
      return AccessoryBarConfig.initialConfiguredKeys;
    }
  }

  Future<void> saveAccessoryKeys(List<AccessoryKeyItem> keys) async {
    try {
      final prefs = await _sharedPrefs;
      final raw = jsonEncode(keys.map((k) => k.toJson()).toList());
      await prefs.setString(StorageConfig.accessoryKeysKey, raw);
    } catch (e) {
      debugPrint('StorageService.saveAccessoryKeys error: $e');
    }
  }

  // ── Haptic Feedback Setting ────────────────────────────────────────────────

  Future<bool> getHapticFeedbackEnabled() async {
    try {
      final prefs = await _sharedPrefs;
      return prefs.getBool(StorageConfig.hapticFeedbackKey) ?? true;
    } catch (_) {
      return true;
    }
  }

  Future<void> setHapticFeedbackEnabled(bool enabled) async {
    try {
      final prefs = await _sharedPrefs;
      await prefs.setBool(StorageConfig.hapticFeedbackKey, enabled);
    } catch (_) {}
  }
}
