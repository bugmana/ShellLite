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

  group('SessionStore Auto-Reconnect (Immediate then 1-3 Backoff)', () {
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

    testWidgets('Initial drop reconnects immediately as soon as possible (0s delay)', (tester) async {
      final session = store.getOrCreateSession(profile);
      await tester.pumpAndSettle();

      session.wasConnected = true;
      session.connectionState = SSHConnectionState.disconnected;
      session.autoReconnectAttempts = 0;

      // Trigger initial auto-reconnect
      store.triggerAutoReconnect(session.id);

      // Attempt 1 should launch immediately with 0s delay
      expect(session.autoReconnectAttempts, equals(1));
      expect(session.connectionState, equals(SSHConnectionState.connecting));
      expect(session.autoReconnectCountdown, isNull);

      store.cancelAutoReconnect(session.id);
    });

    testWidgets('Subsequent failure starts 3-second backoff countdown', (tester) async {
      final session = store.getOrCreateSession(profile);
      await tester.pumpAndSettle();

      session.wasConnected = true;
      session.connectionState = SSHConnectionState.error;
      // Simulate that immediate attempt (attempt 1) already happened and failed
      session.autoReconnectAttempts = 1;

      // Trigger auto reconnect for attempt 2
      store.triggerAutoReconnect(session.id);

      // Now backoff applies
      expect(session.autoReconnectAttempts, equals(2));
      expect(session.autoReconnectCountdown, equals(3));

      // Advance by 1 second
      await tester.pump(const Duration(seconds: 1));
      expect(session.autoReconnectCountdown, equals(2));

      // Advance by 1 second
      await tester.pump(const Duration(seconds: 1));
      expect(session.autoReconnectCountdown, equals(1));

      // Advance by 1 second: countdown finishes, launches attempt 2, which on failure schedules attempt 3
      await tester.pump(const Duration(seconds: 1));
      expect(session.connectionState, equals(SSHConnectionState.error));
      expect(session.autoReconnectAttempts, equals(3));
      expect(session.autoReconnectCountdown, equals(3));

      store.cancelAutoReconnect(session.id);
    });

    testWidgets('Stops auto-reconnecting after max attempts (3)', (tester) async {
      final session = store.getOrCreateSession(profile);
      await tester.pumpAndSettle();

      session.wasConnected = true;
      session.connectionState = SSHConnectionState.error;
      session.autoReconnectAttempts = SSHConfig.maxAutoReconnectAttempts; // 3

      store.triggerAutoReconnect(session.id);

      // No new attempt scheduled
      expect(session.autoReconnectCountdown, isNull);
      await tester.pump(const Duration(seconds: 5));
      expect(session.connectionState, equals(SSHConnectionState.error));
    });

    testWidgets('Manual reconnect resets attempt count for future drops', (tester) async {
      final session = store.getOrCreateSession(profile);
      await tester.pumpAndSettle();

      session.wasConnected = true;
      session.connectionState = SSHConnectionState.disconnected;
      session.autoReconnectAttempts = 2;

      // User manually taps Reconnect
      unawaited(store.reconnectSession(session.id, isManual: true));

      expect(session.autoReconnectAttempts, equals(0));
      expect(session.connectionState, equals(SSHConnectionState.connecting));

      store.cancelAutoReconnect(session.id);
    });

    testWidgets('getOrCreateSession automatically reconnects and updates profile when opening a disconnected session', (tester) async {
      final session = store.getOrCreateSession(profile);
      await tester.pumpAndSettle();

      session.wasConnected = true;
      session.connectionState = SSHConnectionState.disconnected;

      // User edited profile (e.g. changed port and display name) and reopened from server list
      final updatedProfile = profile.copyWith(displayName: 'Updated Server Name', port: 2222);
      final reloadedSession = store.getOrCreateSession(updatedProfile);

      expect(reloadedSession.profile.displayName, equals('Updated Server Name'));
      expect(reloadedSession.profile.port, equals(2222));
      expect(reloadedSession.connectionState, equals(SSHConnectionState.connecting));

      store.cancelAutoReconnect(reloadedSession.id);
    });

    testWidgets('isSessionConnected accurately reflects live connection status', (tester) async {
      final session = store.getOrCreateSession(profile);
      await tester.pumpAndSettle();

      session.connectionState = SSHConnectionState.disconnected;
      expect(store.isSessionConnected(profile.id), isFalse);

      session.connectionState = SSHConnectionState.error;
      expect(store.isSessionConnected(profile.id), isFalse);

      session.connectionState = SSHConnectionState.connecting;
      expect(store.isSessionConnected(profile.id), isTrue);

      session.connectionState = SSHConnectionState.connected;
      expect(store.isSessionConnected(profile.id), isTrue);

      store.closeSession(profile.id);
      expect(store.isSessionConnected(profile.id), isFalse);
    });
  });
}
