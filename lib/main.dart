import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'providers/security_store.dart';
import 'providers/server_store.dart';
import 'providers/session_store.dart';
import 'providers/snippet_store.dart';
import 'providers/telemetry_store.dart';
import 'providers/terminal_settings_store.dart';
import 'screens/server_list_screen.dart';
import 'services/security_service.dart';
import 'services/storage_service.dart';
import 'theme/app_theme.dart';
import 'widgets/app_lock_screen.dart';

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

  final storageService = StorageService();
  final securityService = SecurityService();

  final store = ServerStore(storageService: storageService);
  final terminalSettings = TerminalSettingsStore(storageService: storageService);
  final snippetStore = SnippetStore(storageService: storageService);
  final telemetryStore = TelemetryStore(storageService: storageService);
  final sessionStore = SessionStore(storageService: storageService);
  final securityStore = SecurityStore(securityService: securityService);

  await store.load();
  await terminalSettings.load();
  await snippetStore.load();
  await securityStore.load();

  runApp(
    MultiProvider(
      providers: [
        Provider<StorageService>.value(value: storageService),
        ChangeNotifierProvider<ServerStore>.value(value: store),
        ChangeNotifierProvider<TerminalSettingsStore>.value(value: terminalSettings),
        ChangeNotifierProvider<SnippetStore>.value(value: snippetStore),
        ChangeNotifierProvider<TelemetryStore>.value(value: telemetryStore),
        ChangeNotifierProvider<SessionStore>.value(value: sessionStore),
        ChangeNotifierProvider<SecurityStore>.value(value: securityStore),
      ],
      child: const ShellLiteApp(),
    ),
  );
}

class ShellLiteApp extends StatelessWidget {
  const ShellLiteApp({super.key});

  @override
  Widget build(BuildContext context) {
    final security = context.watch<SecurityStore>();
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
      home: security.isBiometricEnabled && !security.isAppUnlocked
          ? const AppLockScreen()
          : const ServerListScreen(),
    );
  }
}
