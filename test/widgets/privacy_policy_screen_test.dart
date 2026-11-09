import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shell_lite/screens/privacy_policy_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (_) async => null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('com.bugmana.shell_lite/platform'),
            (_) async => 32);
  });

  testWidgets(
      'PrivacyPolicyScreen renders all essential policy sections and hero card',
      (tester) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: PrivacyPolicyScreen(),
      ),
    );

    for (final title in [
      'Privacy',
      'Stored on your device',
      'Connections',
      'No tracking',
      'Delete a server',
      'Publisher and contact'
    ]) {
      expect(find.text(title), findsOneWidget);
    }
    expect(find.text(PrivacyPolicyScreen.canonicalUrl), findsOneWidget);

    // Tap canonical link copy card
    await tester.tap(find.text(PrivacyPolicyScreen.canonicalUrl));
    await tester.pumpAndSettle();

    expect(find.text('Policy link copied'), findsOneWidget);
  });
}
