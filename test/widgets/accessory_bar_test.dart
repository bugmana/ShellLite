import 'package:shell_lite/config/app_config.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shell_lite/widgets/keyboard_accessory_bar.dart';

void main() {
  testWidgets('only Paste and the keyboard toggle are pinned at narrow widths',
      (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
      body: KeyboardAccessoryBar(
          onKeyTap: (_) {}, onPaste: () {}, onToggleKeyboard: () {}),
    )));
    expect(find.byTooltip('More keys'), findsNothing);
    expect(find.byIcon(Icons.more_horiz), findsNothing);
    expect(find.byTooltip('Paste'), findsOneWidget);
    expect(find.byTooltip('Hide keyboard'), findsOneWidget);
    expect(
        tester.getRect(find.byTooltip('Paste')).right, lessThanOrEqualTo(320));
    expect(tester.getRect(find.byTooltip('Hide keyboard')).right,
        lessThanOrEqualTo(320));
    expect(tester.takeException(), isNull);
  });

  testWidgets('locked Alt stays visible and can be released from the key row',
      (tester) async {
    final sent = <String>[];
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: KeyboardAccessoryBar(onKeyTap: sent.add, keys: const [
      TerminalKeyShortcut(label: 'C', sequence: 'c')
    ]))));
    final alt = find.text('Alt');
    await tester.tap(alt);
    await tester.pump(const Duration(milliseconds: 40));
    await tester.tap(alt);
    await tester.pumpAndSettle();
    expect(find.text('Alt'), findsOneWidget);
    await tester.tap(find.text('C'));
    await tester.pumpAndSettle();
    expect(sent.last, '\x1bc');
    expect(find.text('Alt'), findsOneWidget);
    await tester.tap(find.text('Alt'));
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();
    expect(find.text('Alt'), findsOneWidget);
    await tester.tap(find.text('C'));
    await tester.pump();
    expect(sent.last, 'c');
  });
}
