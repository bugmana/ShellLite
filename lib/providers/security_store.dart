import 'package:flutter/foundation.dart';
import '../services/security_service.dart';

class SecurityStore extends ChangeNotifier {
  final SecurityService _securityService;

  bool _isBiometricsSupported = false;
  bool _isBiometricEnabled = false;
  bool _isAppUnlocked = true;

  SecurityStore({SecurityService? securityService})
      : _securityService = securityService ?? SecurityService();

  bool get isBiometricsSupported => _isBiometricsSupported;
  bool get isBiometricEnabled => _isBiometricEnabled;
  bool get isAppUnlocked => _isAppUnlocked;

  Future<void> load() async {
    _isBiometricsSupported = await _securityService.isBiometricsSupported();
    _isBiometricEnabled = await _securityService.isBiometricEnabled();
    if (_isBiometricEnabled) {
      _isAppUnlocked = false;
    } else {
      _isAppUnlocked = true;
    }
    notifyListeners();
  }

  Future<bool> unlockApp() async {
    if (!_isBiometricEnabled) {
      _isAppUnlocked = true;
      notifyListeners();
      return true;
    }

    final success = await _securityService.authenticate();
    if (success) {
      _isAppUnlocked = true;
      notifyListeners();
    }
    return success;
  }

  Future<void> setBiometricsEnabled(bool enabled) async {
    if (enabled) {
      final success = await _securityService.authenticate(
        reason: 'Authenticate to enable biometric protection',
      );
      if (!success) return;
    }

    _isBiometricEnabled = enabled;
    await _securityService.setBiometricEnabled(enabled);
    if (!enabled) {
      _isAppUnlocked = true;
    }
    notifyListeners();
  }

  void lockApp() {
    if (_isBiometricEnabled) {
      _isAppUnlocked = false;
      notifyListeners();
    }
  }
}
