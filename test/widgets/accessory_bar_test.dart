import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shell_lite/widgets/keyboard_accessory_bar.dart';

void main() {
  testWidgets('KeyboardAccessoryBar renders default keys with Tab on far left and triggers callbacks', (tester) async {
    String? tappedSequence;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: KeyboardAccessoryBar(
            onKeyTap: (seq) => tappedSequence = seq,
          ),
        ),
      ),
    );

    expect(find.text('Tab'), findsOneWidget);
    expect(find.text('⇧Tab'), findsOneWidget);
    expect(find.text('↑'), findsOneWidget);
    expect(find.text('↓'), findsOneWidget);
    expect(find.text('←'), findsOneWidget);
    expect(find.text('→'), findsOneWidget);
    expect(find.text('Esc'), findsOneWidget);
    expect(find.text('^C'), findsOneWidget);
    expect(find.text('^D'), findsOneWidget);

    await tester.tap(find.text('Tab'));
    await tester.pump();
    expect(tappedSequence, '\t');

    await tester.tap(find.text('⇧Tab'));
    await tester.pump();
    expect(tappedSequence, '\x1B[Z');

    await tester.tap(find.text('↑'));
    await tester.pump();
    expect(tappedSequence, '\x1B[A');

    await tester.tap(find.text('^C'));
    await tester.pump();
    expect(tappedSequence, '\x03');
  });

  testWidgets('KeyboardAccessoryBar opens ExtendedKeysSheet modal and triggers key callback', (tester) async {
    String? tappedSequence;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: KeyboardAccessoryBar(
            onKeyTap: (seq) => tappedSequence = seq,
          ),
        ),
      ),
    );

    // Tap Extended Keys button
    final extButton = find.byIcon(Icons.keyboard_double_arrow_up_rounded);
    expect(extButton, findsOneWidget);
    await tester.tap(extButton);
    await tester.pumpAndSettle();

    // Verify modal is open
    expect(find.text('Extended Keys & Shortcuts'), findsOneWidget);
    expect(find.text('Control Keys'), findsOneWidget);
    expect(find.text('Navigation'), findsOneWidget);
    expect(find.text('Function (F1-F12)'), findsOneWidget);

    // Tap ^A in Control Keys tab
    expect(find.text('^A'), findsOneWidget);
    await tester.tap(find.text('^A'));
    await tester.pumpAndSettle();

    // Key sequence sent and modal dismissed
    expect(tappedSequence, '\x01');
    expect(find.text('Extended Keys & Shortcuts'), findsNothing);
  });

  testWidgets('KeyboardAccessoryBar renders pinned extended keys button and no snippet button', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: KeyboardAccessoryBar(
            onKeyTap: (_) {},
          ),
        ),
      ),
    );

    expect(find.byIcon(Icons.keyboard_double_arrow_up_rounded), findsOneWidget);
    expect(find.byIcon(Icons.bolt_rounded), findsNothing);
  });

  testWidgets('KeyboardAccessoryBar and buttons have canRequestFocus disabled to prevent dropping virtual keyboard', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: KeyboardAccessoryBar(
            onKeyTap: (_) {},
          ),
        ),
      ),
    );

    // Verify Focus wrapper has canRequestFocus false
    final focusWidgets = tester.widgetList<Focus>(find.byType(Focus));
    final nonFocusable = focusWidgets.where((f) => !f.canRequestFocus && !f.descendantsAreFocusable);
    expect(nonFocusable.isNotEmpty, isTrue);

    // Verify InkWells in accessory bar have canRequestFocus false
    final inkWells = tester.widgetList<InkWell>(find.byType(InkWell));
    expect(inkWells.isNotEmpty, isTrue);
    for (final inkWell in inkWells) {
      expect(inkWell.canRequestFocus, isFalse);
    }
  });

  testWidgets('KeyboardAccessoryBar renders close keyboard button on far right when onCloseKeyboard provided', (tester) async {
    bool closeKeyboardCalled = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: KeyboardAccessoryBar(
            onKeyTap: (_) {},
            onCloseKeyboard: () => closeKeyboardCalled = true,
          ),
        ),
      ),
    );

    final hideKeyboardButton = find.byIcon(Icons.keyboard_hide_rounded);
    expect(hideKeyboardButton, findsOneWidget);

    await tester.tap(hideKeyboardButton);
    await tester.pump();
    expect(closeKeyboardCalled, isTrue);
  });
}
