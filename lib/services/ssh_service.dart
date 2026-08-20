import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:dartssh2/dartssh2.dart';
import '../config/app_config.dart';
import '../models/auth_method.dart';
import '../models/server_profile.dart';
import 'key_parser.dart';
import 'ssh_socket_factory.dart';
import 'storage_service.dart';

enum SSHConnectionState {
  disconnected,
  connecting,
  connected,
  error,
}

class SSHService {
  final StorageService _storageService;
  SSHClient? _client;
  SSHSession? _shellSession;
  SSHConnectionState _state = SSHConnectionState.disconnected;
  String? _lastError;

  StreamSubscription<Uint8List>? _stdoutSub;
  StreamSubscription<Uint8List>? _stderrSub;

  SSHService({StorageService? storageService})
      : _storageService = storageService ?? StorageService();

  SSHConnectionState get state => _state;
  String? get lastError => _lastError;
  bool get isConnected => _state == SSHConnectionState.connected;

  Future<void> connect({
    required ServerProfile profile,
    required int terminalWidth,
    required int terminalHeight,
    required void Function(String output) onOutput,
    required void Function(SSHConnectionState state, String? error) onStateChange,
    StorageService? storageService,
  }) async {
    _state = SSHConnectionState.connecting;
    _lastError = null;
    onStateChange(_state, null);

    try {
      final storage = storageService ?? _storageService;
      final auth = profile.authMethod;
      String? password;
      List<SSHKeyPair>? keyPairs;

      if (auth is PasswordAuth) {
        password = await storage.retrieveCredential(auth.credentialTag);
        if (password == null || password.isEmpty) {
          throw Exception('No password found for server profile.');
        }
      } else if (auth is SSHKeyAuth) {
        final pem = await storage.retrieveCredential(auth.privateKeyTag);
        if (pem == null || pem.isEmpty) {
          throw Exception('No private key found for server profile.');
        }
        keyPairs = SSHKeyParser.parse(pem);
      }

      final socket = await SSHSocketFactory.connect(
        host: profile.host,
        port: profile.port,
        timeout: SSHConfig.connectTimeout,
      );

      _client = SSHClient(
        socket,
        username: profile.username,
        onPasswordRequest: password != null ? () => password! : null,
        onUserInfoRequest: password != null
            ? (request) => request.prompts.map((_) => password!).toList()
            : null,
        identities: keyPairs,
        keepAliveInterval: SSHConfig.keepAliveInterval,
      );

      await _client!.authenticated;

      // Start PTY shell
      _shellSession = await _client!.shell(
        pty: SSHPtyConfig(
          width: terminalWidth > 0 ? terminalWidth : TerminalConfig.defaultWidth,
          height: terminalHeight > 0 ? terminalHeight : TerminalConfig.defaultHeight,
        ),
      );

      _state = SSHConnectionState.connected;
      onStateChange(_state, null);

      _stdoutSub = _shellSession!.stdout.listen((data) {
        onOutput(utf8.decode(data, allowMalformed: true));
      });

      _stderrSub = _shellSession!.stderr.listen((data) {
        onOutput(utf8.decode(data, allowMalformed: true));
      });

      _shellSession!.done.then((_) {
        disconnect();
        onStateChange(SSHConnectionState.disconnected, null);
      });

      // Execute persistent session (tmux) auto-attach or initial command
      if (profile.persistSession) {
        final rawName = profile.tmuxSessionName?.trim();
        final sessionName = (rawName != null && rawName.isNotEmpty)
            ? rawName.replaceAll(RegExp(r'[^a-zA-Z0-9_\-]'), '_')
            : 'shelllite';

        // tmux new-session -A -s <name>:
        // -A: attaches to existing session if it exists, or creates a new session named <name> if stopped/killed outside
        // Checks if tmux binary exists to prevent terminating parent shell on servers without tmux
        final tmuxCmd =
            'if command -v tmux >/dev/null 2>&1; then '
            'exec tmux new-session -A -s "$sessionName"; '
            'else '
            'printf "\\r\\n\\033[33m[ShellLite] Notice: tmux is not installed on this host. Falling back to default shell.\\033[0m\\r\\n"; '
            'fi';
        sendInput('$tmuxCmd\n');

        if (profile.initialCommand != null && profile.initialCommand!.trim().isNotEmpty) {
          final cmd = profile.initialCommand!.trim();
          sendInput('$cmd\n');
        }
      } else if (profile.initialCommand != null && profile.initialCommand!.trim().isNotEmpty) {
        final cmd = profile.initialCommand!.trim();
        sendInput('$cmd\n');
      }
    } catch (e) {
      _state = SSHConnectionState.error;
      _lastError = e.toString();
      onStateChange(_state, _lastError);
      await disconnect();
    }
  }

  void sendInput(String text) {
    if (_shellSession != null && isConnected) {
      _shellSession!.write(Uint8List.fromList(utf8.encode(text)));
    }
  }

  void resizeTerminal(int width, int height) {
    if (_shellSession != null && isConnected) {
      try {
        _shellSession!.resizeTerminal(width, height);
      } catch (_) {}
    }
  }

  Future<void> disconnect() async {
    await _stdoutSub?.cancel();
    await _stderrSub?.cancel();
    _stdoutSub = null;
    _stderrSub = null;

    _shellSession?.close();
    _shellSession = null;

    _client?.close();
    _client = null;

    if (_state != SSHConnectionState.error) {
      _state = SSHConnectionState.disconnected;
    }
  }
}
