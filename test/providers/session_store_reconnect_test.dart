import 'dart:async';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shell_lite/config/app_config.dart';
import 'package:shell_lite/models/auth_method.dart';
import 'package:shell_lite/models/server_profile.dart';
import 'package:shell_lite/providers/session_store.dart';
import 'package:shell_lite/services/ssh_service.dart';
import 'package:shell_lite/services/storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SessionStore Auto-Reconnect', () {
    late StorageService storage;
    late SessionStore store;
    late ServerProfile profile;

    setUp(() async {
      FlutterSecureStorage.setMockInitialValues({});
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      storage = StorageService(prefs: prefs);
      store = SessionStore(storageService: storage);

      profile = ServerProfile(
        id: 'test-profile-reconnect',
        displayName: 'Test Server',
        host: '127.0.0.1',
        port: 22,
        username: 'user',
        authMethod: const PasswordAuth(credentialTag: 'test-cred'),
      );
    });

    tearDown(() {
      store.closeSession(profile.id);
    });

    testWidgets('SessionStore initiates 3-second auto-reconnect countdown on connection loss', (tester) async {
      final session = store.getOrCreateSession(profile);
      // Let initial connection attempt settle
      await tester.pumpAndSettle();

      session.wasConnected = true;
      session.connectionState = SSHConnectionState.disconnected;

      // Trigger auto reconnect
      store.triggerAutoReconnect(session.id);
      expect(session.autoReconnectCountdown, equals(3));
      expect(session.autoReconnectAttempts, equals(1));

      // Advance by 1 second
      await tester.pump(const Duration(seconds: 1));
      expect(session.autoReconnectCountdown, equals(2));

      // Advance by 1 second
      await tester.pump(const Duration(seconds: 1));
      expect(session.autoReconnectCountdown, equals(1));

      // Advance by 1 second: countdown completes, reconnect attempt executes and on failure schedules attempt 2
      await tester.pump(const Duration(seconds: 1));
      expect(session.connectionState, equals(SSHConnectionState.error));
      expect(session.autoReconnectAttempts, equals(2));
      expect(session.autoReconnectCountdown, equals(3));

      // Clean up in-flight reconnect before teardown
      store.cancelAutoReconnect(session.id);
    });

    testWidgets('SessionStore cancels auto-reconnect timer when cancelAutoReconnect is called', (tester) async {
      final session = store.getOrCreateSession(profile);
      await tester.pumpAndSettle();

      session.wasConnected = true;
      session.connectionState = SSHConnectionState.disconnected;

      store.triggerAutoReconnect(session.id);
      expect(session.autoReconnectCountdown, equals(3));

      // Advance by 1 second
      await tester.pump(const Duration(seconds: 1));
      expect(session.autoReconnectCountdown, equals(2));

      // Cancel auto-reconnect
      store.cancelAutoReconnect(session.id);
      expect(session.autoReconnectCountdown, isNull);
      expect(session.autoReconnectCancelled, isTrue);

      // Advance further: should NOT trigger reconnect
      await tester.pump(const Duration(seconds: 5));
      expect(session.connectionState, equals(SSHConnectionState.disconnected));
    });

    testWidgets('SessionStore stops auto-reconnecting after max attempts reached', (tester) async {
      final session = store.getOrCreateSession(profile);
      await tester.pumpAndSettle();

      session.wasConnected = true;
      session.connectionState = SSHConnectionState.disconnected;

      // Exhaust all max attempts
      session.autoReconnectAttempts = SSHConfig.maxAutoReconnectAttempts;
      store.triggerAutoReconnect(session.id);

      expect(session.autoReconnectCountdown, isNull);
      await tester.pump(const Duration(seconds: 5));
      expect(session.connectionState, equals(SSHConnectionState.disconnected));
    });

    testWidgets('Tapping reconnectSession clears pending countdown and reconnects immediately', (tester) async {
      final session = store.getOrCreateSession(profile);
      await tester.pumpAndSettle();

      session.wasConnected = true;
      session.connectionState = SSHConnectionState.disconnected;

      store.triggerAutoReconnect(session.id);
      expect(session.autoReconnectCountdown, equals(3));

      // Launch manual reconnect (unawaited so we can observe connecting state)
      unawaited(store.reconnectSession(session.id));
      expect(session.autoReconnectCountdown, isNull);
      expect(session.connectionState, equals(SSHConnectionState.connecting));

      // Cancel before finish to clean up
      store.cancelAutoReconnect(session.id);
    });
  });
}
