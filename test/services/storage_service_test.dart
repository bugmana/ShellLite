import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shell_lite/services/storage_service.dart';

/// Test double simulating FlutterSecureStorage with backing storage and fault injection.
class FakeFlutterSecureStorage extends FlutterSecureStorage {
  final Map<String, String> data;
  bool shouldThrowOnRead;
  bool shouldThrowOnWrite;

  FakeFlutterSecureStorage({
    Map<String, String>? initialData,
    this.shouldThrowOnRead = false,
    this.shouldThrowOnWrite = false,
  }) : data = initialData ?? {};

  @override
  Future<void> write({
    required String key,
    required String? value,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    if (shouldThrowOnWrite) {
      throw Exception('Simulated KeyStore write failure');
    }
    if (value == null) {
      data.remove(key);
    } else {
      data[key] = value;
    }
  }

  @override
  Future<String?> read({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    if (shouldThrowOnRead) {
      throw Exception('Simulated KeyStore read failure');
    }
    return data[key];
  }

  @override
  Future<void> delete({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    data.remove(key);
  }

  @override
  Future<void> deleteAll({
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    data.clear();
  }

  @override
  Future<bool> containsKey({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    return data.containsKey(key);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('StorageService', () {
    late SharedPreferences prefs;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
    });

    test(
        'Throws StorageException on secure storage write failure (SEC-STORAGE-03)',
        () async {
      final faultStorage = FakeFlutterSecureStorage(
        shouldThrowOnWrite: true,
      );
      final service = StorageService(secureStorage: faultStorage, prefs: prefs);

      expect(
        () => service.saveCredential('failing_key', 'val'),
        throwsA(isA<StorageException>()),
      );
    });

    test(
        'Cross-instance persistence ensures credentials persist across app restarts',
        () async {
      final backingStore = <String, String>{};
      final fakeStorage1 = FakeFlutterSecureStorage(initialData: backingStore);
      final service1 =
          StorageService(secureStorage: fakeStorage1, prefs: prefs);

      // Save an SSH key credential in the first app session
      const keyTag = 'cred_test_profile_id';
      const keyData =
          '-----BEGIN OPENSSH PRIVATE KEY-----\nMOCK_KEY_DATA\n-----END OPENSSH PRIVATE KEY-----';
      await service1.saveCredential(keyTag, keyData);

      expect(backingStore[keyTag], keyData,
          reason: 'Must write through to secure storage');

      // Simulate a cold app restart: fresh StorageService instance with empty in-memory cache
      final fakeStorage2 = FakeFlutterSecureStorage(initialData: backingStore);
      final service2 =
          StorageService(secureStorage: fakeStorage2, prefs: prefs);

      final retrieved = await service2.retrieveCredential(keyTag);
      expect(retrieved, keyData,
          reason:
              'Fresh service instance must retrieve persisted key from secure storage');
    });

    test(
        'Graceful error handling on secure storage read failure without wiping other keys',
        () async {
      final backingStore = <String, String>{
        'safe_key': 'safe_value',
        'failing_key': 'corrupt_data',
      };
      final faultStorage = FakeFlutterSecureStorage(
        initialData: backingStore,
        shouldThrowOnRead: true,
      );
      final service = StorageService(secureStorage: faultStorage, prefs: prefs);

      final result = await service.retrieveCredential('failing_key');
      expect(result, isNull);

      // Existing data must remain intact and not wiped
      expect(backingStore['safe_key'], 'safe_value',
          reason: 'Read failures must not wipe other keys in storage');
    });
  });
}
