import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shell_lite/screens/privacy_policy_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('PrivacyPolicyScreen renders all essential policy sections and hero card', (tester) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: PrivacyPolicyScreen(),
      ),
    );

    expect(find.text('Privacy Policy'), findsWidgets);
    expect(find.text('Privacy & Security First'), findsOneWidget);
    expect(find.text(PrivacyPolicyScreen.canonicalUrl), findsOneWidget);

    expect(find.text('Zero Data Collection & Telemetry'), findsOneWidget);
    expect(find.text('Hardware-Backed Encryption'), findsOneWidget);
    expect(find.text('Direct Peer-to-Peer SSH'), findsOneWidget);
    expect(find.text('On-Device Key Generation'), findsOneWidget);
    expect(find.text('Transient Server Telemetry'), findsOneWidget);
    expect(find.text('Data Sovereignty & Deletion'), findsOneWidget);
    expect(find.text('Publisher & Contact'), findsOneWidget);

    // Tap canonical link copy card
    await tester.tap(find.text(PrivacyPolicyScreen.canonicalUrl));
    await tester.pump();

    expect(find.text('Official policy URL copied to clipboard'), findsOneWidget);
  });
}
