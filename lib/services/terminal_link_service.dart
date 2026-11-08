import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

/// Resolves an explicitly selected web address without changing its query.
Uri? terminalLink(String text) {
  final value = text.trim();
  if (RegExp(r'\s').hasMatch(value)) return null;
  final uri = Uri.tryParse(value);
  if (uri == null ||
      !const ['http', 'https'].contains(uri.scheme) ||
      uri.host.isEmpty) {
    return null;
  }
  return uri;
}

typedef TerminalUrlLauncher = Future<bool> Function(
  Uri uri, {
  required LaunchMode mode,
  String? webOnlyWindowName,
});

class TerminalLinkService {
  const TerminalLinkService({this.launcher = launchUrl});

  final TerminalUrlLauncher launcher;

  Future<bool> _launch(Uri uri, LaunchMode mode) async {
    try {
      return await launcher(uri, mode: mode, webOnlyWindowName: '_blank');
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  Future<bool> open(Uri uri) async {
    if (terminalLink(uri.toString()) == null) return false;
    // Launch immediately so Web retains the button's user activation.
    if (await _launch(uri, LaunchMode.externalApplication)) return true;
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      // Android WebView does not require an installed external browser.
      return _launch(uri, LaunchMode.inAppWebView);
    }
    return false;
  }
}
