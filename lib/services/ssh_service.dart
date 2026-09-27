import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:dartssh2/dartssh2.dart';
import '../config/app_config.dart';
import '../models/auth_method.dart';
import '../models/server_profile.dart';
import 'file_transfer_service.dart';
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
  static final _tmuxSanitizeRegex = RegExp(r'[^a-zA-Z0-9_\-]');

  /// Builds the persistent tmux startup command with mouse scrolling support enabled.
  static String buildTmuxCommand(String? rawSessionName) {
    final rawName = rawSessionName?.trim();
    final sessionName = (rawName != null && rawName.isNotEmpty)
        ? rawName.replaceAll(_tmuxSanitizeRegex, '_')
        : 'shelllite';

    // tmux new-session -A -s <name>:
    // -A: attaches to existing session if it exists, or creates a new session named <name> if stopped/killed outside
    // Checks if tmux binary exists to prevent terminating parent shell on servers without tmux.
    // Explicitly forces `mouse on` both globally and on session creation so mouse scrolling works reliably.
    return 'if command -v tmux >/dev/null 2>&1; then '
        'tmux set -g mouse on 2>/dev/null; '
        'exec tmux new-session -A -s "$sessionName" \\; set -g mouse on; '
        'else '
        'printf "\\r\\n\\033[33m[ShellLite] Notice: tmux is not installed on this host. Falling back to default shell.\\033[0m\\r\\n"; '
        'fi';
  }

  final StorageService _storageService;

  SSHService({StorageService? storageService})
      : _storageService = storageService ?? StorageService();
  SSHClient? _client;
  SSHSession? _shellSession;
  SSHConnectionState _state = SSHConnectionState.disconnected;
  String? _lastError;

  StreamSubscription<String>? _stdoutSub;
  StreamSubscription<String>? _stderrSub;

  int _terminalWidth = TerminalConfig.defaultWidth;
  int _terminalHeight = TerminalConfig.defaultHeight;
  int _pixelWidth = 0;
  int _pixelHeight = 0;

  int _connectionEpoch = 0;

  SSHConnectionState get state => _state;
  String? get lastError => _lastError;
  bool get isConnected => _state == SSHConnectionState.connected;
  bool get isSocketAlive =>
      _client != null && !_client!.isClosed && _shellSession != null;
  SSHClient? get client => _client;
  int get terminalWidth => _terminalWidth;
  int get terminalHeight => _terminalHeight;

  Future<String> resolveRemoteCurrentDirectory() async {
    if (_client == null || !isConnected) return '~';
    return FileTransferService.resolveRemoteCurrentDirectory(_client!);
  }

  Future<void> connect({
    required ServerProfile profile,
    required int terminalWidth,
    required int terminalHeight,
    int pixelWidth = 0,
    int pixelHeight = 0,
    required void Function(String output) onOutput,
    required void Function(SSHConnectionState state, String? error) onStateChange,
    StorageService? storageService,
  }) async {
    await disconnect();
    final currentEpoch = ++_connectionEpoch;

    _terminalWidth = terminalWidth > 0 ? terminalWidth : _terminalWidth;
    _terminalHeight = terminalHeight > 0 ? terminalHeight : _terminalHeight;
    _pixelWidth = pixelWidth >= 0 ? pixelWidth : 0;
    _pixelHeight = pixelHeight >= 0 ? pixelHeight : 0;
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
        String? keyPassphrase;
        if (auth.passphraseTag != null) {
          keyPassphrase = await storage.retrieveCredential(auth.passphraseTag!);
        }
        keyPairs = SSHKeyParser.parse(pem, passphrase: keyPassphrase);
      }

      final socket = await SSHSocketFactory.connect(
        host: profile.host,
        port: profile.port,
        timeout: SSHConfig.connectTimeout,
      );

      if (currentEpoch != _connectionEpoch) {
        socket.destroy();
        return;
      }

      _client = SSHClient(
        socket,
        username: profile.username,
        onPasswordRequest: password != null ? () => password! : null,
        onUserInfoRequest: password != null
            ? (request) => request.prompts.map((_) => password!).toList()
            : null,
        identities: keyPairs,
        keepAliveInterval: SSHConfig.keepAliveInterval,
        onVerifyHostKey: (String type, Uint8List fingerprintBytes) async {
          final fp = utf8.decode(fingerprintBytes);
          final knownFp = await _storageService.getKnownHostFingerprint(
            profile.host,
            profile.port,
          );
          if (knownFp == null) {
            // TOFU (Trust-On-First-Use): Store fingerprint on initial connection
            await _storageService.saveKnownHostFingerprint(
              profile.host,
              profile.port,
              fp,
            );
            return true;
          }
          // Enforce strict matching to prevent MITM attacks
          return knownFp == fp;
        },
      );

      await _client!.authenticated;

      if (currentEpoch != _connectionEpoch) {
        _client?.close();
        _client = null;
        return;
      }

      // Start PTY shell with latest resolved dimensions
      _shellSession = await _client!.shell(
        pty: SSHPtyConfig(
          type: 'xterm-256color',
          width: _terminalWidth,
          height: _terminalHeight,
          pixelWidth: _pixelWidth,
          pixelHeight: _pixelHeight,
        ),
      );

      _state = SSHConnectionState.connected;
      onStateChange(_state, null);

      // Explicitly synchronize terminal dimensions to avoid any race condition with early layouts
      try {
        _shellSession!.resizeTerminal(
          _terminalWidth,
          _terminalHeight,
          _pixelWidth,
          _pixelHeight,
        );
      } catch (_) {}

      // Decode stream using stateful Utf8Decoder to prevent multi-byte UTF-8 character
      // truncation/corruption across packet boundaries in long sessions and TUI apps
      _stdoutSub = _shellSession!.stdout
          .cast<List<int>>()
          .transform(const Utf8Decoder(allowMalformed: true))
          .listen((data) {
        onOutput(data);
      });

      _stderrSub = _shellSession!.stderr
          .cast<List<int>>()
          .transform(const Utf8Decoder(allowMalformed: true))
          .listen((data) {
        onOutput(data);
      });

      final currentSession = _shellSession;
      currentSession!.done.then((_) {
        if (_shellSession == currentSession) {
          disconnect();
          onStateChange(SSHConnectionState.disconnected, null);
        }
      });

      if (profile.persistSession) {
        final tmuxCmd = buildTmuxCommand(profile.tmuxSessionName);
        sendInput('$tmuxCmd\n');
      } else if (profile.initialCommand != null && profile.initialCommand!.trim().isNotEmpty) {
        final cmd = profile.initialCommand!.trim();
        sendInput('$cmd\n');
      }
    } catch (e) {
      if (currentEpoch != _connectionEpoch) return;
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

  void resizeTerminal(int width, int height, [int pixelWidth = 0, int pixelHeight = 0]) {
    if (width > 0) _terminalWidth = width;
    if (height > 0) _terminalHeight = height;
    if (pixelWidth >= 0) _pixelWidth = pixelWidth;
    if (pixelHeight >= 0) _pixelHeight = pixelHeight;

    if (_shellSession != null && isConnected) {
      try {
        _shellSession!.resizeTerminal(
          _terminalWidth,
          _terminalHeight,
          _pixelWidth,
          _pixelHeight,
        );
      } catch (_) {}
    }
  }

  Future<void> disconnect() async {
    _connectionEpoch++;
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
