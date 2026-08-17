import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shell_lite/providers/security_store.dart';
import 'package:shell_lite/services/security_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('SecurityStore initializes unlocked when biometrics disabled', () async {
    SharedPreferences.setMockInitialValues({});
    final store = SecurityStore(securityService: SecurityService());
    await store.load();

    expect(store.isBiometricEnabled, isFalse);
    expect(store.isAppUnlocked, isTrue);
  });

  test('SecurityStore lockApp locks when biometric enabled', () async {
    SharedPreferences.setMockInitialValues({'shell_lite_biometrics_enabled_v1': true});
    final store = SecurityStore(securityService: SecurityService());
    await store.load();

    expect(store.isBiometricEnabled, isTrue);
    expect(store.isAppUnlocked, isFalse);
  });
}
