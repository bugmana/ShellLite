import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shell_lite/widgets/keyboard_accessory_bar.dart';

void main() {
  testWidgets('KeyboardAccessoryBar renders all default keys and triggers callbacks', (tester) async {
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

    expect(find.text('⇥ Tab'), findsOneWidget);
    expect(find.text('^C'), findsOneWidget);
    expect(find.text('^D'), findsOneWidget);
    expect(find.text('Esc'), findsOneWidget);

    await tester.tap(find.text('^C'));
    await tester.pump();

    expect(tappedSequence, '\x03');
  });
}
