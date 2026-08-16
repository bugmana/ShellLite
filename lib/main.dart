import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'providers/server_store.dart';
import 'screens/server_list_screen.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Dark status bar and navigation bar styling
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: AppTheme.background,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  final store = ServerStore();
  await store.load();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: store),
      ],
      child: const ShellLiteApp(),
    ),
  );
}

class ShellLiteApp extends StatelessWidget {
  const ShellLiteApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ShellLite',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: const ServerListScreen(),
    );
  }
}
