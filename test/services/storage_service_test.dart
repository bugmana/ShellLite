import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shell_lite/models/auth_method.dart';
import 'package:shell_lite/models/server_profile.dart';
import 'package:shell_lite/services/storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('StorageService', () {
    late StorageService storage;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      storage = StorageService(prefs: prefs);
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
  });
}
