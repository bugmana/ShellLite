import 'package:flutter/material.dart';
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

  testWidgets('ServerListScreen shows empty state when no servers configured', (tester) async {
    SharedPreferences.setMockInitialValues({});
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
}
