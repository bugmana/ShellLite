import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/app_config.dart';
import '../models/server_profile.dart';

/// Exception thrown when secure storage operations fail (SEC-STORAGE-03).
class StorageException implements Exception {
  final String message;
  const StorageException(this.message);

  @override
  String toString() => 'StorageException: $message';
}

/// Handles persistence for ServerProfiles and encrypted credentials.
class StorageService {
  static const _profilesKey = StorageConfig.profilesKey;

  static const Duration storageTimeout = Duration(seconds: 10);

  static const FlutterSecureStorage _defaultSecureStorage = FlutterSecureStorage(
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
      synchronizable: false,
    ),
    aOptions: AndroidOptions(
      resetOnError: false,
      migrateOnAlgorithmChange: true,
      migrateWithBackup: true,
      keyCipherAlgorithm: KeyCipherAlgorithm.RSA_ECB_OAEPwithSHA_256andMGF1Padding,
      storageCipherAlgorithm: StorageCipherAlgorithm.AES_GCM_NoPadding,
    ),
  );

  static FlutterSecureStorage get defaultSecureStorage => _defaultSecureStorage;

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
  static const _knownHostPrefix = 'shell_lite_kh_';

  Future<void> saveCredential(String tag, String value) async {
    _inMemoryCredentials[tag] = value;
    if (kIsWeb) {
      // In web mode, NEVER write cleartext or base64 credentials to browser localStorage (SEC-STORAGE-01).
      // Web credentials are kept in ephemeral session memory only.
      // Proactively scrub any legacy credentials stored in localStorage under this tag.
      try {
        final prefs = await _sharedPrefs;
        await prefs.remove('$_webCredPrefix$tag');
      } catch (_) {}
      return;
    }
    try {
      await _secureStorage
          .write(key: tag, value: value)
          .timeout(storageTimeout);
    } catch (e) {
      debugPrint('StorageService.saveCredential error: $e');
      throw StorageException('Failed to securely persist credential: $e');
    }
  }

  Future<String?> retrieveCredential(String tag) async {
    if (_inMemoryCredentials.containsKey(tag)) {
      return _inMemoryCredentials[tag];
    }
    if (kIsWeb) {
      // In web mode, unencrypted credentials in localStorage are disallowed (SEC-STORAGE-01).
      // Only ephemeral in-memory session credentials are used.
      return null;
    }
    try {
      final val = await _secureStorage
          .read(key: tag)
          .timeout(storageTimeout);
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
          .timeout(storageTimeout);
    } catch (e) {
      debugPrint('StorageService.deleteCredential error: $e');
      throw StorageException('Failed to delete secure credential: $e');
    }
  }

  // ── Known Host Fingerprints (TOFU Host Key Verification - SEC-NET-01) ────────

  Future<String?> getKnownHostFingerprint(String host, int port) async {
    final key = '$_knownHostPrefix${host}_$port';
    if (_inMemoryCredentials.containsKey(key)) {
      return _inMemoryCredentials[key];
    }
    if (kIsWeb) {
      try {
        final prefs = await _sharedPrefs;
        final fp = prefs.getString(key);
        if (fp != null) {
          _inMemoryCredentials[key] = fp;
          return fp;
        }
      } catch (_) {}
      return null;
    }
    try {
      final fp = await _secureStorage.read(key: key).timeout(storageTimeout);
      if (fp != null) {
        _inMemoryCredentials[key] = fp;
        return fp;
      }
    } catch (_) {}
    return null;
  }

  Future<void> saveKnownHostFingerprint(String host, int port, String fingerprint) async {
    final key = '$_knownHostPrefix${host}_$port';
    _inMemoryCredentials[key] = fingerprint;
    if (kIsWeb) {
      try {
        final prefs = await _sharedPrefs;
        await prefs.setString(key, fingerprint);
      } catch (_) {}
      return;
    }
    try {
      await _secureStorage.write(key: key, value: fingerprint).timeout(storageTimeout);
    } catch (_) {}
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

  // ── Sticky Modifiers Setting ───────────────────────────────────────────────

  Future<bool> getCtrlModifierEnabled() async {
    try {
      final prefs = await _sharedPrefs;
      return prefs.getBool(StorageConfig.ctrlModifierEnabledKey) ?? true;
    } catch (_) {
      return true;
    }
  }

  Future<void> setCtrlModifierEnabled(bool enabled) async {
    try {
      final prefs = await _sharedPrefs;
      await prefs.setBool(StorageConfig.ctrlModifierEnabledKey, enabled);
    } catch (_) {}
  }

  Future<bool> getAltModifierEnabled() async {
    try {
      final prefs = await _sharedPrefs;
      return prefs.getBool(StorageConfig.altModifierEnabledKey) ?? true;
    } catch (_) {
      return true;
    }
  }

  Future<void> setAltModifierEnabled(bool enabled) async {
    try {
      final prefs = await _sharedPrefs;
      await prefs.setBool(StorageConfig.altModifierEnabledKey, enabled);
    } catch (_) {}
  }
}
