import 'package:flutter/foundation.dart';
import 'package:xterm/xterm.dart';
import '../config/app_config.dart';
import '../models/server_profile.dart';
import '../services/ssh_service.dart';
import '../services/storage_service.dart';

class OpenSession {
  final String id;
  final ServerProfile profile;
  final Terminal terminal;
  final TerminalController controller;
  final SSHService sshService;
  SSHConnectionState connectionState;
  bool wasConnected;

  OpenSession({
    required this.id,
    required this.profile,
    required this.terminal,
    required this.controller,
    required this.sshService,
    this.connectionState = SSHConnectionState.disconnected,
    this.wasConnected = false,
  });
}

class SessionStore extends ChangeNotifier {
  final StorageService _storageService;
  final Map<String, OpenSession> _sessions = {};
  String? _activeSessionId;

  SessionStore({StorageService? storageService})
      : _storageService = storageService ?? StorageService();

  String? get activeSessionId => _activeSessionId;
  OpenSession? get activeSession =>
      _activeSessionId != null ? _sessions[_activeSessionId] : null;

  bool hasActiveSession(String profileId) => _sessions.containsKey(profileId);
  OpenSession? getSession(String profileId) => _sessions[profileId];

  OpenSession getOrCreateSession(ServerProfile profile) {
    // Enforce single server session: close other running sessions
    final otherIds = _sessions.keys.where((k) => k != profile.id).toList();
    for (final id in otherIds) {
      closeSession(id);
    }

    if (_sessions.containsKey(profile.id)) {
      _activeSessionId = profile.id;
      notifyListeners();
      return _sessions[profile.id]!;
    }

    final terminal = Terminal(maxLines: TerminalConfig.maxScrollbackLines);
    final controller = TerminalController();
    final sshService = SSHService();

    terminal.onOutput = (data) {
      sshService.sendInput(data);
    };

    terminal.onResize = (width, height, pw, ph) {
      sshService.resizeTerminal(width, height);
    };

    final session = OpenSession(
      id: profile.id,
      profile: profile,
      terminal: terminal,
      controller: controller,
      sshService: sshService,
    );

    _sessions[profile.id] = session;
    _activeSessionId = profile.id;
    notifyListeners();

    _connectSession(session);
    return session;
  }

  Future<void> _connectSession(OpenSession session) async {
    session.terminal.write(
      '\r\n\x1b[38;2;139;148;158mConnecting to \x1b[38;2;88;166;255m${session.profile.username}@${session.profile.host}\x1b[38;2;110;118;129m:\x1b[38;2;88;166;255m${session.profile.port}\x1b[38;2;139;148;158m...\x1b[0m\r\n',
    );

    await session.sshService.connect(
      profile: session.profile,
      terminalWidth: session.terminal.viewWidth > 0 ? session.terminal.viewWidth : TerminalConfig.defaultWidth,
      terminalHeight: session.terminal.viewHeight > 0 ? session.terminal.viewHeight : TerminalConfig.defaultHeight,
      storageService: _storageService,
      onOutput: (output) {
        session.terminal.write(output);
      },
      onStateChange: (state, error) {
        session.connectionState = state;
        if (state == SSHConnectionState.connected) {
          session.wasConnected = true;
          session.terminal.write(
            '\x1b[38;2;63;185;80m✔ Connected to ${session.profile.displayName}\x1b[0m\r\n\r\n',
          );
        } else if (state == SSHConnectionState.error && error != null) {
          session.terminal.write(
            '\r\n\x1b[38;2;248;81;73m✖ Connection failed: $error\x1b[0m\r\n',
          );
        } else if (state == SSHConnectionState.disconnected) {
          session.terminal.write(
            '\r\n\x1b[38;2;139;148;158mSession closed.\x1b[0m\r\n',
          );
          if (session.wasConnected) {
            _sessions.remove(session.id);
            if (_activeSessionId == session.id) {
              _activeSessionId = null;
            }
          }
        }
        notifyListeners();
      },
    );
  }

  void closeSession(String sessionId) {
    final session = _sessions.remove(sessionId);
    if (session != null) {
      session.sshService.disconnect();
      session.controller.dispose();
    }

    if (_activeSessionId == sessionId) {
      _activeSessionId = _sessions.isNotEmpty ? _sessions.keys.last : null;
    }
    notifyListeners();
  }

  void reconnectSession(String sessionId) {
    final session = _sessions[sessionId];
    if (session != null && session.connectionState != SSHConnectionState.connecting) {
      _connectSession(session);
    }
  }
}
