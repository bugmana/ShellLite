import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shell_lite/widgets/terminal_search_bar.dart';
import 'package:xterm/xterm.dart';

void main() {
  testWidgets('TerminalSearchBar searches terminal buffer and navigates matches', (tester) async {
    final terminal = Terminal();
    final controller = TerminalController();
    bool closed = false;

    terminal.write('line one with apple\r\nline two with banana\r\nline three with apple\r\n');

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TerminalSearchBar(
            terminal: terminal,
            controller: controller,
            onClose: () => closed = true,
          ),
        ),
      ),
    );

    expect(find.byType(TextField), findsOneWidget);

    // Search for 'apple'
    await tester.enterText(find.byType(TextField), 'apple');
    await tester.pump();

    expect(find.text('1 of 2'), findsOneWidget);

    // Tap next match
    await tester.tap(find.byTooltip('Next match'));
    await tester.pump();
    expect(find.text('2 of 2'), findsOneWidget);

    // Tap previous match
    await tester.tap(find.byTooltip('Previous match'));
    await tester.pump();
    expect(find.text('1 of 2'), findsOneWidget);

    // Tap close
    await tester.tap(find.byTooltip('Close search'));
    await tester.pump();
    expect(closed, isTrue);
  });
}
