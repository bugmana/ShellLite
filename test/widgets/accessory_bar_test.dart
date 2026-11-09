import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shell_lite/widgets/keyboard_accessory_bar.dart';
import 'package:shell_lite/config/app_config.dart';

void main() {
  testWidgets(
      'KeyboardAccessoryBar renders default keys with Tab on far left and triggers callbacks',
      (tester) async {
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
    expect(find.text('⇧Tab'), findsNothing);
    expect(find.text('↑'), findsOneWidget);
    expect(find.text('↓'), findsOneWidget);
    expect(find.text('←'), findsOneWidget);
    expect(find.text('→'), findsOneWidget);
    expect(find.text('Esc'), findsOneWidget);

    await tester.tap(find.text('Tab'));
    await tester.pump();
    expect(tappedSequence, '\t');

    await tester.tap(find.text('↑'));
    await tester.pump();
    expect(tappedSequence, '\x1B[A');

    await tester.tap(find.text('Esc'));
    await tester.pump();
    expect(tappedSequence, '\x1B');
  });

  testWidgets('More keys sends a function key and returns to terminal',
      (tester) async {
    String? sent;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: KeyboardAccessoryBar(onKeyTap: (value) => sent = value))));
    await tester.tap(find.byTooltip('More keys'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('F5'));
    await tester.tap(find.text('F5'));
    await tester.pumpAndSettle();
    expect(sent, '\x1b[15~');
    expect(find.text('Customize keys'), findsNothing);
  });

  testWidgets('TactileKeyButton applies 0.94 micro-depression scale on press',
      (tester) async {
    bool tapped = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: KeyboardAccessoryBar(
            onKeyTap: (_) => tapped = true,
          ),
        ),
      ),
    );

    final keyFinder = find.text('Tab');
    expect(keyFinder, findsOneWidget);

    // Pointer down -> check AnimatedScale scale becomes 0.94
    final gesture = await tester.startGesture(tester.getCenter(keyFinder));
    await tester.pump(const Duration(milliseconds: 70));

    final scaleFinder = find
        .ancestor(of: keyFinder, matching: find.byType(AnimatedScale))
        .first;
    final animatedScale = tester.widget<AnimatedScale>(scaleFinder);
    expect(animatedScale.scale, 0.94);

    // Pointer up -> restores to 1.0 and fires callback
    await gesture.up();
    await tester.pumpAndSettle();

    final restoredScale = tester.widget<AnimatedScale>(scaleFinder);
    expect(restoredScale.scale, 1.0);
    expect(tapped, isTrue);
  });

  testWidgets(
      'KeyboardAccessoryBar keeps More keys available in the default row',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: KeyboardAccessoryBar(
            onKeyTap: (_) {},
          ),
        ),
      ),
    );

    expect(find.byIcon(Icons.more_horiz), findsOneWidget);
    expect(find.byIcon(Icons.bolt_rounded), findsNothing);
  });

  testWidgets(
      'KeyboardAccessoryBar renders pinned extended keys button when showExtendedKeys is true',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: KeyboardAccessoryBar(
            onKeyTap: (_) {},
            showExtendedKeys: true,
          ),
        ),
      ),
    );

    expect(find.byIcon(Icons.more_horiz), findsOneWidget);
  });

  testWidgets(
      'KeyboardAccessoryBar and buttons have canRequestFocus disabled to prevent dropping virtual keyboard',
      (tester) async {
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
    final nonFocusable = focusWidgets
        .where((f) => !f.canRequestFocus && !f.descendantsAreFocusable);
    expect(nonFocusable.isNotEmpty, isTrue);

    // Verify InkWells in accessory bar have canRequestFocus false
    final inkWells = tester.widgetList<InkWell>(find.byType(InkWell));
    expect(inkWells.isNotEmpty, isTrue);
    for (final inkWell in inkWells) {
      expect(inkWell.canRequestFocus, isFalse);
    }
  });

  testWidgets(
      'KeyboardAccessoryBar renders toggle keyboard button with down arrow when open and up arrow when hidden',
      (tester) async {
    bool toggleKeyboardCalled = false;

    // Test when open (isKeyboardVisible = true)
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: KeyboardAccessoryBar(
            onKeyTap: (_) {},
            isKeyboardVisible: true,
            onToggleKeyboard: () => toggleKeyboardCalled = true,
          ),
        ),
      ),
    );

    final downArrowButton = find.byIcon(Icons.keyboard_arrow_down_rounded);
    expect(downArrowButton, findsOneWidget);

    await tester.tap(downArrowButton);
    await tester.pump();
    expect(toggleKeyboardCalled, isTrue);

    // Test when hidden (isKeyboardVisible = false)
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: KeyboardAccessoryBar(
            onKeyTap: (_) {},
            isKeyboardVisible: false,
            onToggleKeyboard: () {},
          ),
        ),
      ),
    );

    final upArrowButton = find.byIcon(Icons.keyboard_arrow_up_rounded);
    expect(upArrowButton, findsOneWidget);
  });

  testWidgets(
      'KeyboardAccessoryBar renders paste button when onPaste is provided and triggers callback',
      (tester) async {
    bool pasteCalled = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: KeyboardAccessoryBar(
            onKeyTap: (_) {},
            onPaste: () => pasteCalled = true,
          ),
        ),
      ),
    );

    final pasteButton = find.byTooltip('Paste');
    expect(pasteButton, findsOneWidget);
    expect(find.byIcon(Icons.paste_rounded), findsOneWidget);

    await tester.tap(pasteButton);
    await tester.pump();
    expect(pasteCalled, isTrue);
  });
  testWidgets('locked Alt stays visible and can be released from the key row',
      (tester) async {
    final sent = <String>[];
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: KeyboardAccessoryBar(onKeyTap: sent.add, keys: const [
      TerminalKeyShortcut(label: 'C', sequence: 'c')
    ]))));
    await tester.tap(find.byTooltip('More keys'));
    await tester.pumpAndSettle();
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
    expect(find.text('Alt'), findsNothing);
    await tester.tap(find.text('C'));
    await tester.pump();
    expect(sent.last, 'c');
  });
}
