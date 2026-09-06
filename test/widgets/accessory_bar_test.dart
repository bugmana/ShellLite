import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shell_lite/providers/terminal_settings_store.dart';
import 'package:shell_lite/services/storage_service.dart';
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

    await tester.tap(find.text('Tab'));
    await tester.pump();
    expect(tappedSequence, '\t');

    await tester.tap(find.text('⇧Tab'));
    await tester.pump();
    expect(tappedSequence, '\x1B[Z');

    await tester.tap(find.text('↑'));
    await tester.pump();
    expect(tappedSequence, '\x1B[A');

    await tester.tap(find.text('Esc'));
    await tester.pump();
    expect(tappedSequence, '\x1B');
  });

  testWidgets('KeyboardAccessoryBar opens non-dismissing inline accordion keypad drawer and triggers keys', (tester) async {
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

    // Verify inline accordion drawer is open
    expect(find.text('Extended Keys'), findsOneWidget);
    expect(find.text('Control Keys'), findsOneWidget);
    expect(find.text('Navigation'), findsOneWidget);
    expect(find.text('Function (F1-F12)'), findsOneWidget);

    // Tap ^A in Control Keys tab
    expect(find.text('^A'), findsOneWidget);
    await tester.tap(find.text('^A'));
    await tester.pump();

    // Key sequence sent and drawer remains OPEN (non-dismissing)
    expect(tappedSequence, '\x01');
    expect(find.text('Extended Keys'), findsOneWidget);

    // Tap collapse chevron button in drawer
    final collapseButton = find.byTooltip('Collapse keys').first;
    expect(collapseButton, findsOneWidget);
    await tester.tap(collapseButton);
    await tester.pumpAndSettle();

    // Drawer is now collapsed
    expect(find.text('Extended Keys'), findsNothing);
  });

  testWidgets('ExtendedKeysSheet renders and sends keys', (tester) async {
    String? tappedSequence;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ExtendedKeysSheet(
            onKeyTap: (seq) => tappedSequence = seq,
            autoDismiss: true,
          ),
        ),
      ),
    );

    expect(find.text('Extended Keys & Shortcuts'), findsOneWidget);
    expect(find.text('Control Keys'), findsOneWidget);

    await tester.tap(find.text('^A'));
    await tester.pump();
    expect(tappedSequence, '\x01');
  });

  testWidgets('TactileKeyButton applies 0.94 micro-depression scale on press', (tester) async {
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

    final scaleFinder = find.ancestor(of: keyFinder, matching: find.byType(AnimatedScale)).first;
    final animatedScale = tester.widget<AnimatedScale>(scaleFinder);
    expect(animatedScale.scale, 0.94);

    // Pointer up -> restores to 1.0 and fires callback
    await gesture.up();
    await tester.pumpAndSettle();

    final restoredScale = tester.widget<AnimatedScale>(scaleFinder);
    expect(restoredScale.scale, 1.0);
    expect(tapped, isTrue);
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

  testWidgets('KeyboardAccessoryBar renders toggle keyboard button with down arrow when open and up arrow when hidden', (tester) async {
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

  testWidgets('KeyboardAccessoryBar renders paste button when onPaste is provided and triggers callback', (tester) async {
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

  testWidgets('KeyboardAccessoryBar keypad drawer uses adaptive height (Option A)', (tester) async {
    // 1. When keyboard is visible (isKeyboardVisible = true), drawer defaults to compact (~180dp)
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: KeyboardAccessoryBar(
            onKeyTap: (_) {},
            isKeyboardVisible: true,
          ),
        ),
      ),
    );

    await tester.tap(find.byIcon(Icons.keyboard_double_arrow_up_rounded));
    await tester.pumpAndSettle();

    // Drawer height should be 180.0
    final drawerBox = tester.renderObject<RenderBox>(find.byType(DefaultTabController));
    expect(drawerBox.size.height, closeTo(180.0, 1.0));

    // Tap expand button -> expands to 280.0
    final expandButton = find.byTooltip('Expand drawer');
    expect(expandButton, findsOneWidget);
    await tester.tap(expandButton);
    await tester.pumpAndSettle();

    final expandedBox = tester.renderObject<RenderBox>(find.byType(DefaultTabController));
    expect(expandedBox.size.height, closeTo(280.0, 1.0));

    // Tap compact button -> back to 180.0
    final compactButton = find.byTooltip('Compact drawer');
    expect(compactButton, findsOneWidget);
    await tester.tap(compactButton);
    await tester.pumpAndSettle();

    final recompactedBox = tester.renderObject<RenderBox>(find.byType(DefaultTabController));
    expect(recompactedBox.size.height, closeTo(180.0, 1.0));
  });

  testWidgets('KeyboardAccessoryBar keypad drawer expands automatically when keyboard is hidden', (tester) async {
    // When isKeyboardVisible is false, default height is expanded (~280dp)
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: KeyboardAccessoryBar(
            onKeyTap: (_) {},
            isKeyboardVisible: false,
          ),
        ),
      ),
    );

    await tester.tap(find.byIcon(Icons.keyboard_double_arrow_up_rounded));
    await tester.pumpAndSettle();

    final drawerBox = tester.renderObject<RenderBox>(find.byType(DefaultTabController));
    expect(drawerBox.size.height, closeTo(280.0, 1.0));
  });

  testWidgets('KeyboardAccessoryBar respects ctrlModifierEnabled and altModifierEnabled', (tester) async {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final storageService = StorageService(prefs: prefs);
    final settingsStore = TerminalSettingsStore(storageService: storageService);
    await settingsStore.load();

    await tester.pumpWidget(
      ChangeNotifierProvider<TerminalSettingsStore>.value(
        value: settingsStore,
        child: MaterialApp(
          home: Scaffold(
            body: KeyboardAccessoryBar(
              onKeyTap: (_) {},
            ),
          ),
        ),
      ),
    );

    expect(find.text('Ctrl'), findsOneWidget);
    expect(find.text('Alt'), findsOneWidget);

    // Disable Ctrl
    await settingsStore.setCtrlModifierEnabled(false);
    await tester.pumpAndSettle();
    expect(find.text('Ctrl'), findsNothing);
    expect(find.text('Alt'), findsOneWidget);

    // Disable Alt
    await settingsStore.setAltModifierEnabled(false);
    await tester.pumpAndSettle();
    expect(find.text('Ctrl'), findsNothing);
    expect(find.text('Alt'), findsNothing);

    // Re-enable both
    await settingsStore.setCtrlModifierEnabled(true);
    await settingsStore.setAltModifierEnabled(true);
    await tester.pumpAndSettle();
    expect(find.text('Ctrl'), findsOneWidget);
    expect(find.text('Alt'), findsOneWidget);
  });
}
