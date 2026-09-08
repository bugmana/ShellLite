import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'providers/server_store.dart';
import 'providers/session_store.dart';
import 'providers/telemetry_store.dart';
import 'providers/terminal_settings_store.dart';
import 'screens/privacy_policy_screen.dart';
import 'screens/server_list_screen.dart';
import 'services/storage_service.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  SystemChrome.setSystemUIOverlayStyle(
    SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: AppTheme.defaultExtension.background,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  final storageService = StorageService();

  final store = ServerStore(storageService: storageService);
  final terminalSettings = TerminalSettingsStore(storageService: storageService);
  final telemetryStore = TelemetryStore(storageService: storageService);
  final sessionStore = SessionStore(storageService: storageService);

  await Future.wait([
    store.load(),
    terminalSettings.load(),
  ]);

  runApp(
    MultiProvider(
      providers: [
        Provider<StorageService>.value(value: storageService),
        ChangeNotifierProvider<ServerStore>.value(value: store),
        ChangeNotifierProvider<TerminalSettingsStore>.value(value: terminalSettings),
        ChangeNotifierProvider<TelemetryStore>.value(value: telemetryStore),
        ChangeNotifierProvider<SessionStore>.value(value: sessionStore),
      ],
      child: const ShellLiteApp(),
    ),
  );
}

class ShellLiteApp extends StatelessWidget {
  const ShellLiteApp({super.key});

  @override
  Widget build(BuildContext context) {
    final terminalSettings = context.watch<TerminalSettingsStore>();
    final activePreset = terminalSettings.activeThemePreset;
    final themeData = AppTheme.buildTheme(activePreset);

    // Synchronize system navigation bar & status bar overlay styling with active preset
    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarColor: activePreset.palette.background,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
    );

    return MaterialApp(
      title: 'ShellLite',
      debugShowCheckedModeBanner: false,
      theme: themeData,
      routes: {
        '/privacy': (context) => const PrivacyPolicyScreen(),
      },
      home: const ServerListScreen(),
    );
  }
}
