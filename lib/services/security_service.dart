import 'package:flutter/foundation.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SecurityService {
  static const String _biometricEnabledKey = 'shell_lite_biometrics_enabled_v1';
  final LocalAuthentication _localAuth;
  final SharedPreferences? _prefs;

  SecurityService({
    LocalAuthentication? localAuth,
    SharedPreferences? prefs,
  })  : _localAuth = localAuth ?? LocalAuthentication(),
        _prefs = prefs;

  Future<SharedPreferences> get _sharedPrefs async =>
      _prefs ?? await SharedPreferences.getInstance();

  Future<bool> isBiometricsSupported() async {
    if (kIsWeb) return false;
    try {
      final isDeviceSupported = await _localAuth.isDeviceSupported();
      final canCheck = await _localAuth.canCheckBiometrics;
      return isDeviceSupported && canCheck;
    } catch (e) {
      debugPrint('SecurityService.isBiometricsSupported error: $e');
      return false;
    }
  }

  Future<bool> isBiometricEnabled() async {
    if (kIsWeb) return false;
    try {
      final prefs = await _sharedPrefs;
      return prefs.getBool(_biometricEnabledKey) ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<void> setBiometricEnabled(bool enabled) async {
    if (kIsWeb) return;
    try {
      final prefs = await _sharedPrefs;
      await prefs.setBool(_biometricEnabledKey, enabled);
    } catch (_) {}
  }

  Future<bool> authenticate({String reason = 'Authenticate to access ShellLite'}) async {
    if (kIsWeb) return true;
    try {
      return await _localAuth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: false,
        ),
      );
    } catch (e) {
      debugPrint('SecurityService.authenticate error: $e');
      return false;
    }
  }
}
