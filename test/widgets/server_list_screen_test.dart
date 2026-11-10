import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shell_lite/providers/server_store.dart';
import 'package:shell_lite/screens/server_list_screen.dart';
import 'package:shell_lite/services/storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('ServerListScreen shows empty state when no servers configured',
      (tester) async {
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

    expect(find.text('No servers yet'), findsOneWidget);
    expect(find.text('Add server'), findsOneWidget);
    expect(find.byType(FloatingActionButton), findsNothing);
  });
}
