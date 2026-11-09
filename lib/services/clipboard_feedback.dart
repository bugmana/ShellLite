import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class ClipboardFeedback {
  static const _channel = MethodChannel('com.bugmana.shell_lite/platform');
  static Future<bool> get showSuccessMessage async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return true;
    try {
      return (await _channel.invokeMethod<int>('sdkInt') ?? 0) < 33;
    } on PlatformException {
      return true;
    } on MissingPluginException {
      return true;
    }
  }
}
