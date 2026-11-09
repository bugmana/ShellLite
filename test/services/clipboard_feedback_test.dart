import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shell_lite/services/clipboard_feedback.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('com.bugmana.shell_lite/platform');
  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });
  for (final sdk in [23, 32, 33, 36]) {
    test('Android SDK $sdk copy feedback', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (_) async => sdk);
      expect(await ClipboardFeedback.showSuccessMessage, sdk < 33);
    });
  }
  test('missing plugin retains success feedback', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    expect(await ClipboardFeedback.showSuccessMessage, isTrue);
  });
  test('iOS retains app feedback', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    expect(await ClipboardFeedback.showSuccessMessage, isTrue);
  });
}
