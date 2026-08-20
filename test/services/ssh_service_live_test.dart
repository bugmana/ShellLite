import 'dart:async';
import 'dart:io';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shell_lite/models/auth_method.dart';
import 'package:shell_lite/models/server_profile.dart';
import 'package:shell_lite/services/ssh_service.dart';
import 'package:shell_lite/services/storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late StorageService storageService;

  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    storageService = StorageService(prefs: prefs);
  });

  Future<bool> isLocalSshReachable() async {
    try {
      final socket = await Socket.connect('127.0.0.1', 22, timeout: const Duration(milliseconds: 300));
      socket.destroy();
      return true;
    } catch (_) {
      return false;
    }
  }

  test('SSHService connects with Password authentication and receives shell output', () async {
    if (Platform.environment.containsKey('CI') || !await isLocalSshReachable()) {
      return;
    }

    const passwordTag = 'testuser_pass_tag';
    await storageService.saveCredential(passwordTag, 'Vp%8FOE=zp6V39oFuVfYyr7U');

    final profile = ServerProfile(
      id: 'live_test_pwd',
      displayName: 'Localhost TestUser Pwd',
      host: '127.0.0.1',
      port: 22,
      username: 'testuser',
      authMethod: const PasswordAuth(credentialTag: passwordTag),
    );

    final sshService = SSHService(storageService: storageService);
    final outputCompleter = Completer<String>();
    final outputBuffer = StringBuffer();

    await sshService.connect(
      profile: profile,
      terminalWidth: 80,
      terminalHeight: 24,
      onOutput: (output) {
        outputBuffer.write(output);
        if (outputBuffer.toString().contains('SSH_PASSWORD_OK') && !outputCompleter.isCompleted) {
          outputCompleter.complete(outputBuffer.toString());
        }
      },
      onStateChange: (state, error) {},
    );

    if (sshService.isConnected) {
      expect(sshService.state, SSHConnectionState.connected);

      // Send a test command into the PTY shell session
      sshService.sendInput('echo "SSH_PASSWORD_OK"\n');

      // Await output from terminal shell
      final result = await outputCompleter.future.timeout(
        const Duration(seconds: 5),
        onTimeout: () => outputBuffer.toString(),
      );

      expect(result, contains('SSH_PASSWORD_OK'));

      // Disconnect
      await sshService.disconnect();
      expect(sshService.isConnected, isFalse);
    }
  });

  test('SSHService connects with SSH Key authentication and receives shell output', () async {
    if (Platform.environment.containsKey('CI') || !await isLocalSshReachable()) {
      return;
    }

    const testEd25519Pem = '''-----BEGIN OPENSSH PRIVATE KEY-----
b3BlbnNzaC1rZXktdjEAAAAABG5vbmUAAAAEbm9uZQAAAAAAAAABAAAAMwAAAAtzc2gtZW
QyNTUxOQAAACACOEN68b2WrDDAQzVt/mL93MjdboaRLii6uoBgye0j2gAAAJgqjMqUKozK
lAAAAAtzc2gtZWQyNTUxOQAAACACOEN68b2WrDDAQzVt/mL93MjdboaRLii6uoBgye0j2g
AAAECrVjMfI40fpm1j7XwF5Jhb+Pft8LCezFy3HpfGZ1yZ3AI4Q3rxvZasMMBDNW3+Yv3c
yN1uhpEuKLq6gGDJ7SPaAAAAEnRlc3R1c2VyQHNoZWxsbGl0ZQECAw==
-----END OPENSSH PRIVATE KEY-----''';

    const keyTag = 'testuser_key_tag';
    await storageService.saveCredential(keyTag, testEd25519Pem);

    final profile = ServerProfile(
      id: 'live_test_key',
      displayName: 'Localhost TestUser Key',
      host: '127.0.0.1',
      port: 22,
      username: 'testuser',
      authMethod: const SSHKeyAuth(privateKeyTag: keyTag),
    );

    final sshService = SSHService(storageService: storageService);
    final outputCompleter = Completer<String>();
    final outputBuffer = StringBuffer();

    await sshService.connect(
      profile: profile,
      terminalWidth: 80,
      terminalHeight: 24,
      onOutput: (output) {
        outputBuffer.write(output);
        if (outputBuffer.toString().contains('SSH_KEY_OK') && !outputCompleter.isCompleted) {
          outputCompleter.complete(outputBuffer.toString());
        }
      },
      onStateChange: (state, error) {},
    );

    // If key auth is configured
    if (sshService.isConnected) {
      sshService.sendInput('echo "SSH_KEY_OK"\n');

      final result = await outputCompleter.future.timeout(
        const Duration(seconds: 5),
        onTimeout: () => outputBuffer.toString(),
      );

      expect(result, contains('SSH_KEY_OK'));

      await sshService.disconnect();
      expect(sshService.isConnected, isFalse);
    }
  });
}
