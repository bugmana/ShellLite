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
              theme: theme,
            ),
          ],
        ),
      ),
    );
  }

  testWidgets('TerminalConnectionBanner renders static message and single Reconnect button without Cancel', (tester) async {
    bool reconnected = false;
    await tester.pumpWidget(
      buildBanner(
        wasConnected: true,
        isConnecting: false,
        onReconnect: () => reconnected = true,
      ),
    );

    expect(find.text('Connection lost.'), findsOneWidget);
    expect(find.textContaining('Retrying in'), findsNothing);
    expect(find.text('Cancel'), findsNothing);
    expect(find.widgetWithText(ElevatedButton, 'Reconnect'), findsOneWidget);

    await tester.tap(find.widgetWithText(ElevatedButton, 'Reconnect'));
    expect(reconnected, isTrue);
  });

  testWidgets('TerminalConnectionBanner renders countdown and single Reconnect button during auto-reconnect', (tester) async {
    bool reconnected = false;

    await tester.pumpWidget(
      buildBanner(
        wasConnected: true,
        isConnecting: false,
        retryCountdown: 3,
        retryAttempt: 2,
        onReconnect: () => reconnected = true,
      ),
    );

    expect(find.text('Connection lost.'), findsOneWidget);
    expect(find.text('Retrying in 3s...'), findsOneWidget);
    expect(find.text('Cancel'), findsNothing);
    expect(find.widgetWithText(ElevatedButton, 'Reconnect'), findsOneWidget);

    // Tap Reconnect directly
    await tester.tap(find.widgetWithText(ElevatedButton, 'Reconnect'));
    expect(reconnected, isTrue);
  });

  testWidgets('TerminalConnectionBanner shows spinner on Reconnect button and no extra buttons when connecting', (tester) async {
    await tester.pumpWidget(
      buildBanner(
        wasConnected: true,
        isConnecting: true,
        onReconnect: () {},
      ),
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Cancel'), findsNothing);
    final button = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
    expect(button.onPressed, isNull);
  });
}
