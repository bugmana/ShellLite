import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shell_lite/models/auth_method.dart';
import 'package:shell_lite/models/server_profile.dart';
import 'package:shell_lite/models/server_telemetry.dart';
import 'package:shell_lite/providers/server_store.dart';
import 'package:shell_lite/providers/telemetry_store.dart';
import 'package:shell_lite/screens/server_list_screen.dart';
import 'package:shell_lite/services/storage_service.dart';
import 'package:shell_lite/widgets/server_card.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('ServerListScreen shows empty state when no servers configured', (tester) async {
    final prefs = await SharedPreferences.getInstance();
    final storage = StorageService(prefs: prefs);
    final store = ServerStore(storageService: storage);
    await store.load();

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: store,
        child: const MaterialApp(home: ServerListScreen()),
      ),
    );

    expect(find.text('No Servers Configured'), findsOneWidget);
    expect(find.text('Add First Server'), findsOneWidget);
  });

  testWidgets('ServerCard renders displayName and connection details', (tester) async {
    final profile = ServerProfile(
      displayName: 'My Production Server',
      host: 'prod.example.com',
      username: 'admin',
      authMethod: const PasswordAuth(credentialTag: 'p-1'),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ServerCard(
            profile: profile,
            onTap: () {},
            onEdit: () {},
            onDelete: () {},
          ),
        ),
      ),
    );

    expect(find.text('My Production Server'), findsOneWidget);
    expect(find.text('admin@prod.example.com:22'), findsOneWidget);
    expect(find.text('Pass'), findsOneWidget);
  });

  testWidgets('ServerCard renders CPU, RAM, Disk, and Uptime metrics when telemetry is loaded', (tester) async {
    final profile = ServerProfile(
      displayName: 'Prod Node',
      host: 'node1.example.com',
      username: 'root',
      authMethod: const PasswordAuth(credentialTag: 'p-telemetry'),
    );

    final telemetry = ServerTelemetry.fromSSHOutput('''
 10:00:00 up 5 days, 1 user, load average: 0.12, 0.20, 0.15
---CPU---
%Cpu(s): 15.0 us, 5.0 sy, 0.0 ni, 80.0 id, 0.0 wa, 0.0 hi, 0.0 si, 0.0 st
---MEM---
               total        used        free      shared  buff/cache   available
Mem:          16.0Gi       4.0Gi      12.0Gi       100Mi       2.0Gi      11.0Gi
---DISK---
Filesystem      Size  Used Avail Use% Mounted on
/dev/sda1       100G   30G   70G  30% /
''');

    final telemetryStore = TelemetryStore();
    telemetryStore.setTelemetry(profile.id, telemetry);

    await tester.pumpWidget(
      ChangeNotifierProvider<TelemetryStore>.value(
        value: telemetryStore,
        child: MaterialApp(
          home: Scaffold(
            body: ServerCard(
              profile: profile,
              onTap: () {},
              onEdit: () {},
              onDelete: () {},
            ),
          ),
        ),
      ),
    );

    expect(find.text('Prod Node'), findsOneWidget);
    expect(find.text('CPU: 20.0%'), findsOneWidget);
    expect(find.text('RAM: 4.0Gi / 16.0Gi'), findsOneWidget);
    expect(find.text('Disk: 30G / 100G (30%)'), findsOneWidget);
    expect(find.text('5 days'), findsOneWidget);
  });

  testWidgets('ServerListScreen displays server count badge on add button', (tester) async {
    final prefs = await SharedPreferences.getInstance();
    final storage = StorageService(prefs: prefs);
    final store = ServerStore(storageService: storage);
    await store.load();
    await store.addProfile(
      ServerProfile(
        displayName: 'Test Server',
        host: '10.0.0.1',
        username: 'user',
        authMethod: const PasswordAuth(credentialTag: 'c1'),
      ),
      credential: 'pwd',
    );

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: store,
        child: const MaterialApp(home: ServerListScreen()),
      ),
    );

    expect(find.text('Add Server'), findsOneWidget);
    expect(find.text('(1/10)'), findsOneWidget);
  });

  test('ServerStore enforces maximum limit of 10 servers', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final storage = StorageService(prefs: prefs);
    final store = ServerStore(storageService: storage);
    await store.load();

    for (int i = 0; i < 10; i++) {
      await store.addProfile(
        ServerProfile(
          displayName: 'Server $i',
          host: '10.0.0.$i',
          username: 'user',
          authMethod: PasswordAuth(credentialTag: 'c-$i'),
        ),
        credential: 'pwd',
      );
    }

    expect(store.profiles.length, 10);
    expect(store.canAddServer, isFalse);

    expect(
      () => store.addProfile(
        ServerProfile(
          displayName: 'Server 11',
          host: '10.0.0.11',
          username: 'user',
          authMethod: const PasswordAuth(credentialTag: 'c-11'),
        ),
        credential: 'pwd',
      ),
      throwsA(isA<StateError>()),
    );
  });
}
