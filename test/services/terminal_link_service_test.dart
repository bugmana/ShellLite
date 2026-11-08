import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shell_lite/services/terminal_link_service.dart';

void main() {
  tearDown(() => debugDefaultTargetPlatformOverride = null);
  for (final platformFailure in [false, true]) {
    test(
        'Android falls back to WebView on browser failure (throws=$platformFailure)',
        () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      final calls = <LaunchMode>[];
      final uri = Uri.parse('https://example.com/?token=abc%2B!#done');
      final service = TerminalLinkService(
          launcher: (url, {required mode, webOnlyWindowName}) async {
        expect(url, uri);
        calls.add(mode);
        if (mode == LaunchMode.externalApplication) {
          if (platformFailure) throw PlatformException(code: 'NO_ACTIVITY');
          return false;
        }
        return true;
      });
      expect(await service.open(uri), isTrue);
      expect(calls, [LaunchMode.externalApplication, LaunchMode.inAppWebView]);
    });
  }
  test('successful browser launch does not open a second view', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    final calls = <LaunchMode>[];
    final service = TerminalLinkService(
        launcher: (url, {required mode, webOnlyWindowName}) async {
      calls.add(mode);
      return true;
    });
    expect(await service.open(Uri.parse('https://example.com')), isTrue);
    expect(calls, [LaunchMode.externalApplication]);
  });
  test('both Android launch paths failing return false', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    final calls = <LaunchMode>[];
    final service = TerminalLinkService(
        launcher: (url, {required mode, webOnlyWindowName}) async {
      calls.add(mode);
      throw PlatformException(code: 'unavailable');
    });
    expect(await service.open(Uri.parse('https://example.com')), isFalse);
    expect(calls, [LaunchMode.externalApplication, LaunchMode.inAppWebView]);
  });
  test('iOS does not use the Android fallback', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    final calls = <LaunchMode>[];
    final service = TerminalLinkService(
        launcher: (url, {required mode, webOnlyWindowName}) async {
      calls.add(mode);
      return false;
    });
    expect(await service.open(Uri.parse('https://example.com')), isFalse);
    expect(calls, [LaunchMode.externalApplication]);
  });
  test('rejects non-web URLs before launching', () async {
    final service = TerminalLinkService(
        launcher: (url, {required mode, webOnlyWindowName}) async {
      fail('Unsafe scheme must not reach the platform');
    });
    expect(await service.open(Uri.parse('javascript:alert(1)')), isFalse);
  });

  test('preserves authentication queries and fragments', () {
    const url = 'https://example.com:8443/login?code=a%2Bb&state=123#done';
    expect(terminalLink(url).toString(), url);
  });
  test('rejects commands, multiple links and non-web schemes', () {
    for (final text in [
      'echo https://example.com',
      'javascript:alert(1)',
      'https://a.com https://b.com',
      'https://'
    ]) {
      expect(terminalLink(text), isNull);
    }
  });
}
