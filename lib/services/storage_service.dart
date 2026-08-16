import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/server_profile.dart';

/// Handles persistence for ServerProfiles and encrypted credentials.
class StorageService {
  static const _profilesKey = 'shell_lite_server_profiles_v1';

  final FlutterSecureStorage _secureStorage;
  final Map<String, String> _inMemoryCredentials = {};
  SharedPreferences? _prefs;

  StorageService({
    FlutterSecureStorage? secureStorage,
    SharedPreferences? prefs,
  })  : _secureStorage = secureStorage ?? const FlutterSecureStorage(),
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

  Future<void> saveCredential(String tag, String value) async {
    _inMemoryCredentials[tag] = value;
    try {
      await _secureStorage.write(key: tag, value: value);
    } catch (e) {
      debugPrint('StorageService.saveCredential secureStorage fallback to in-memory: $e');
    }
  }

  Future<String?> retrieveCredential(String tag) async {
    try {
      final val = await _secureStorage.read(key: tag);
      if (val != null) return val;
    } catch (e) {
      debugPrint('StorageService.retrieveCredential error: $e');
    }
    return _inMemoryCredentials[tag];
  }

  Future<void> deleteCredential(String tag) async {
    _inMemoryCredentials.remove(tag);
    try {
      await _secureStorage.delete(key: tag);
    } catch (e) {
      debugPrint('StorageService.deleteCredential error: $e');
    }
  }
}
