import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shell_lite/models/auth_method.dart';
import 'package:shell_lite/models/server_profile.dart';
import 'package:shell_lite/services/storage_service.dart';

/// Test double simulating FlutterSecureStorage with backing storage, latency, and fault injection.
class FakeFlutterSecureStorage extends FlutterSecureStorage {
  final Map<String, String> data;
  Duration simulatedDelay;
  bool shouldThrowOnRead;
  bool shouldThrowOnWrite;

  FakeFlutterSecureStorage({
    Map<String, String>? initialData,
    this.simulatedDelay = Duration.zero,
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
    if (simulatedDelay > Duration.zero) {
      await Future.delayed(simulatedDelay);
    }
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
    if (simulatedDelay > Duration.zero) {
      await Future.delayed(simulatedDelay);
    }
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
    if (simulatedDelay > Duration.zero) {
      await Future.delayed(simulatedDelay);
    }
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
    late StorageService storage;
    late SharedPreferences prefs;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      storage = StorageService(secureStorage: FakeFlutterSecureStorage(), prefs: prefs);
    });

    test('Save and retrieve credential', () async {
      await storage.saveCredential('tag-test', 's3cr3t_pass');
      final result = await storage.retrieveCredential('tag-test');
      expect(result, 's3cr3t_pass');
    });

    test('Overwrite credential', () async {
      await storage.saveCredential('tag-ow', 'first');
      await storage.saveCredential('tag-ow', 'second');
      final result = await storage.retrieveCredential('tag-ow');
      expect(result, 'second');
    });

    test('Non-existent credential returns null', () async {
      final result = await storage.retrieveCredential('nonexistent');
      expect(result, isNull);
    });

    test('Delete credential removes it', () async {
      await storage.saveCredential('to-del', 'val');
      await storage.deleteCredential('to-del');
      final result = await storage.retrieveCredential('to-del');
      expect(result, isNull);
    });

    test('Delete is idempotent', () async {
      await storage.deleteCredential('never-existed');
      // Should not throw
    });

    test('Save and load profiles round-trip', () async {
      final p1 = ServerProfile(
        displayName: 'Alpha',
        host: '1.1.1.1',
        username: 'user1',
        authMethod: const PasswordAuth(credentialTag: 't1'),
      );
      final p2 = ServerProfile(
        displayName: 'Beta',
        host: '2.2.2.2',
        port: 2222,
        username: 'user2',
        authMethod: const SSHKeyAuth(privateKeyTag: 't2'),
        initialCommand: 'htop',
      );

      await storage.saveProfiles([p1, p2]);
      final loaded = await storage.loadProfiles();

      expect(loaded.length, 2);
      expect(loaded[0].displayName, 'Alpha');
      expect(loaded[1].displayName, 'Beta');
      expect(loaded[1].initialCommand, 'htop');
    });

    test('Default AndroidOptions adheres to security recommendations', () {
      final defaultStorage = StorageService.defaultSecureStorage;
      final androidMap = defaultStorage.aOptions.toMap();

      expect(androidMap['resetOnError'], 'false',
          reason: 'resetOnError must be false to prevent accidental storage wiping');
      expect(androidMap['migrateWithBackup'], 'true',
          reason: 'migrateWithBackup must be true for crash-resistant migration');
      expect(androidMap['keyCipherAlgorithm'], 'RSA_ECB_OAEPwithSHA_256andMGF1Padding',
          reason: 'Must use recommended RSA-OAEP key wrapping algorithm');
      expect(androidMap['storageCipherAlgorithm'], 'AES_GCM_NoPadding',
          reason: 'Must use recommended AES-GCM-256 authenticated encryption');
    });

    test('Cross-instance persistence ensures credentials persist across app restarts', () async {
      final backingStore = <String, String>{};
      final fakeStorage1 = FakeFlutterSecureStorage(initialData: backingStore);
      final service1 = StorageService(secureStorage: fakeStorage1, prefs: prefs);

      // Save an SSH key credential in the first app session
      const keyTag = 'cred_test_profile_id';
      const keyData = '-----BEGIN OPENSSH PRIVATE KEY-----\nMOCK_KEY_DATA\n-----END OPENSSH PRIVATE KEY-----';
      await service1.saveCredential(keyTag, keyData);

      expect(backingStore[keyTag], keyData, reason: 'Must write through to secure storage');

      // Simulate a cold app restart: fresh StorageService instance with empty in-memory cache
      final fakeStorage2 = FakeFlutterSecureStorage(initialData: backingStore);
      final service2 = StorageService(secureStorage: fakeStorage2, prefs: prefs);

      final retrieved = await service2.retrieveCredential(keyTag);
      expect(retrieved, keyData, reason: 'Fresh service instance must retrieve persisted key from secure storage');
    });

    test('Latency tolerance: operations exceeding 300ms succeed without dropping to RAM', () async {
      final backingStore = <String, String>{};
      // Simulate hardware KeyStore operations taking 400ms (previously exceeded 300ms timeout)
      final delayedStorage = FakeFlutterSecureStorage(
        initialData: backingStore,
        simulatedDelay: const Duration(milliseconds: 400),
      );
      final service = StorageService(secureStorage: delayedStorage, prefs: prefs);

      const keyTag = 'cred_delayed_test';
      const keyData = 'delayed_secret_key';

      await service.saveCredential(keyTag, keyData);

      // Ensure it was persisted to underlying secure storage, not dropped
      expect(backingStore[keyTag], keyData,
          reason: 'Operation taking >300ms must still be persisted to secure storage');

      // Fresh instance should also read without premature timeout
      final freshService = StorageService(secureStorage: delayedStorage, prefs: prefs);
      final retrieved = await freshService.retrieveCredential(keyTag);
      expect(retrieved, keyData);
    });

    test('Graceful error handling on secure storage read failure without wiping other keys', () async {
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
