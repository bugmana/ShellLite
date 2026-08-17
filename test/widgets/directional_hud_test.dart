import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shell_lite/widgets/directional_hud.dart';

void main() {
  testWidgets('DirectionalHUDOverlay renders child and shows HUD on long press', (tester) async {
    final actions = <String>[];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DirectionalHUDOverlay(
            onAction: (act) => actions.add(act),
            child: const Center(child: Text('Terminal Body')),
          ),
        ),
      ),
    );

    expect(find.text('Terminal Body'), findsOneWidget);
    expect(find.text('Up'), findsNothing);

    // Start long press
    final gesture = await tester.startGesture(const Offset(200, 200));
    await tester.pump(const Duration(milliseconds: 600));

    // HUD labels should appear
    expect(find.text('Up'), findsOneWidget);
    expect(find.text('Down'), findsOneWidget);
    expect(find.text('Tab'), findsOneWidget);
    expect(find.text('Left'), findsOneWidget);

    // Drag up (History Up)
    await gesture.moveBy(const Offset(0, -40));
    await tester.pump();
    expect(actions, contains('\x1B[A'));

    // Drag right (Tab autocomplete)
    await gesture.moveBy(const Offset(60, 40));
    await tester.pump();
    expect(actions, contains('\t'));

    // Drag down (History Down)
    await gesture.moveBy(const Offset(-60, 60));
    await tester.pump();
    expect(actions, contains('\x1B[B'));

    // Drag left (Move cursor Left)
    await gesture.moveBy(const Offset(-60, -60));
    await tester.pump();
    expect(actions, contains('\x1B[D'));

    // Release gesture
    await gesture.up();
    await tester.pumpAndSettle();

    expect(find.text('Up'), findsNothing);
  });
}
