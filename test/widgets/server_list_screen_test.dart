import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shell_lite/models/auth_method.dart';
import 'package:shell_lite/models/server_profile.dart';
import 'package:shell_lite/providers/server_store.dart';
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
