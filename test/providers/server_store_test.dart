import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shell_lite/models/auth_method.dart';
import 'package:shell_lite/models/server_profile.dart';
import 'package:shell_lite/providers/server_store.dart';
import 'package:shell_lite/services/storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ServerStore', () {
    late StorageService storage;
    late ServerStore store;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      storage = StorageService(prefs: prefs);
      store = ServerStore(storageService: storage);
    });

    test('Add, retrieve credential, and delete profile', () async {
      await store.load();
      expect(store.isEmpty, isTrue);

      final profile = ServerProfile(
        displayName: 'Test Node',
        host: '10.0.0.5',
        username: 'dev',
        authMethod: const PasswordAuth(credentialTag: 'tag-node'),
      );

      await store.addProfile(profile, credential: 'node_password');
      expect(store.profiles.length, 1);
      expect(store.profiles.first.displayName, 'Test Node');

      final cred = await store.getCredential(profile);
      expect(cred, 'node_password');

      await store.deleteProfile(profile.id);
      expect(store.isEmpty, isTrue);

      final deletedCred = await store.getCredential(profile);
      expect(deletedCred, isNull);
    });

    test('Update profile modifications', () async {
      await store.load();

      final profile = ServerProfile(
        displayName: 'Original',
        host: '10.0.0.1',
        username: 'root',
        authMethod: const PasswordAuth(credentialTag: 'tag-orig'),
      );

      await store.addProfile(profile, credential: 'pass1');

      final updated = profile.copyWith(displayName: 'Updated Name', port: 2200);
      await store.updateProfile(updated, newCredential: 'pass2');

      expect(store.profiles.first.displayName, 'Updated Name');
      expect(store.profiles.first.port, 2200);

      final cred = await store.getCredential(updated);
      expect(cred, 'pass2');
    });

    test('Add, retrieve key passphrase, update passphrase, and delete profile', () async {
      await store.load();

      final profile = ServerProfile(
        displayName: 'Protected SSH Node',
        host: '10.0.0.20',
        username: 'ubuntu',
        authMethod: const SSHKeyAuth(
          privateKeyTag: 'cred_node_ssh',
          passphraseTag: 'key_pass_node_ssh',
        ),
      );

      await store.addProfile(
        profile,
        credential: '-----BEGIN OPENSSH PRIVATE KEY-----...',
        keyPassphrase: 'mypassphrase123',
      );

      expect(store.profiles.length, 1);
      final savedKey = await store.getCredential(profile);
      final savedPass = await store.getKeyPassphrase(profile);
      expect(savedKey, '-----BEGIN OPENSSH PRIVATE KEY-----...');
      expect(savedPass, 'mypassphrase123');

      // Update passphrase
      await store.updateProfile(
        profile,
        newKeyPassphrase: 'newpassphrase456',
      );
      final updatedPass = await store.getKeyPassphrase(profile);
      expect(updatedPass, 'newpassphrase456');

      // Delete profile and ensure both key and passphrase credentials are deleted
      await store.deleteProfile(profile.id);
      expect(store.isEmpty, isTrue);
      expect(await store.getCredential(profile), isNull);
      expect(await store.getKeyPassphrase(profile), isNull);
    });
  });
}
