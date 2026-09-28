import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shell_lite/screens/terminal/terminal_connection_banner.dart';
import 'package:shell_lite/theme/app_theme.dart';
import 'package:shell_lite/theme/terminal_theme_presets.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final theme = AppTheme.buildTheme(TerminalThemePresets.obsidian).extension<AppThemeExtension>()!;

  Widget buildBanner({
    required bool wasConnected,
    required bool isConnecting,
    int? retryCountdown,
    int? retryAttempt,
    required VoidCallback onReconnect,
    VoidCallback? onCancel,
  }) {
    return MaterialApp(
      theme: AppTheme.buildTheme(TerminalThemePresets.obsidian),
      home: Scaffold(
        body: Stack(
          children: [
            TerminalConnectionBanner(
              wasConnected: wasConnected,
              isConnecting: isConnecting,
              retryCountdown: retryCountdown,
              retryAttempt: retryAttempt,
              onReconnect: onReconnect,
              onCancel: onCancel,
              theme: theme,
            ),
          ],
        ),
      ),
    );
  }

  testWidgets('TerminalConnectionBanner renders static message when not counting down', (tester) async {
    bool reconnected = false;
    await tester.pumpWidget(
      buildBanner(
        wasConnected: true,
        isConnecting: false,
        onReconnect: () => reconnected = true,
      ),
    );

    expect(find.text('Connection lost.'), findsOneWidget);
    expect(find.textContaining('Reconnecting in'), findsNothing);
    expect(find.text('Cancel'), findsNothing);
    expect(find.widgetWithText(ElevatedButton, 'Reconnect'), findsOneWidget);

    await tester.tap(find.widgetWithText(ElevatedButton, 'Reconnect'));
    expect(reconnected, isTrue);
  });

  testWidgets('TerminalConnectionBanner renders countdown and Cancel button during auto-reconnect', (tester) async {
    bool cancelled = false;
    bool reconnected = false;

    await tester.pumpWidget(
      buildBanner(
        wasConnected: true,
        isConnecting: false,
        retryCountdown: 3,
        retryAttempt: 1,
        onReconnect: () => reconnected = true,
        onCancel: () => cancelled = true,
      ),
    );

    expect(find.text('Connection lost.'), findsOneWidget);
    expect(find.text('Reconnecting in 3s...'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);
    expect(find.widgetWithText(ElevatedButton, 'Reconnect'), findsOneWidget);

    // Tap Cancel
    await tester.tap(find.text('Cancel'));
    expect(cancelled, isTrue);

    // Tap Reconnect directly
    await tester.tap(find.widgetWithText(ElevatedButton, 'Reconnect'));
    expect(reconnected, isTrue);
  });

  testWidgets('TerminalConnectionBanner shows spinner and Cancel button when connecting', (tester) async {
    bool cancelled = false;

    await tester.pumpWidget(
      buildBanner(
        wasConnected: true,
        isConnecting: true,
        onReconnect: () {},
        onCancel: () => cancelled = true,
      ),
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    expect(cancelled, isTrue);
  });
}
