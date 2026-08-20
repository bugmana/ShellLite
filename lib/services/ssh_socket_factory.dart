import 'package:dartssh2/dartssh2.dart';
import 'package:flutter/foundation.dart';
import 'web_ssh_socket.dart';

/// Factory providing transparent SSH socket creation across all platforms:
/// - Native (Android, iOS, Linux, macOS, Windows): Direct TCP socket connection
/// - Web: Secure WebSocket bridge connection (`wss://<host>/ssh-ws`)
class SSHSocketFactory {
  static Future<SSHSocket> connect({
    required String host,
    required int port,
    Duration? timeout,
  }) async {
    if (kIsWeb) {
      final scheme = Uri.base.scheme == 'http' ? 'ws' : 'wss';
      final wsHost = Uri.base.host.isNotEmpty ? Uri.base.host : host;
      final portSuffix = Uri.base.hasPort ? ':${Uri.base.port}' : '';
      final wsUri = Uri.parse('$scheme://$wsHost$portSuffix/ssh-ws');
      return WebSocketSSHSocket.connect(wsUri);
    } else {
      return SSHSocket.connect(
        host,
        port,
        timeout: timeout,
      );
    }
  }
}
