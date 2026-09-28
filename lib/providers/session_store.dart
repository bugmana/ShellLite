import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:xterm/xterm.dart';
import '../config/app_config.dart';
import '../models/server_profile.dart';
import '../services/ssh_service.dart';
import '../services/storage_service.dart';
import '../services/terminal_mouse_handler.dart';

class OpenSession {
  final String id;
  final ServerProfile profile;
  final Terminal terminal;
  final TerminalController controller;
  final SSHService sshService;
  SSHConnectionState connectionState;
  bool wasConnected;
  int? autoReconnectCountdown;
  int autoReconnectAttempts;
  bool autoReconnectCancelled;
  Timer? autoReconnectTimer;

  OpenSession({
    required this.id,
    required this.profile,
    required this.terminal,
    required this.controller,
    required this.sshService,
    this.connectionState = SSHConnectionState.disconnected,
    this.wasConnected = false,
    this.autoReconnectCountdown,
    this.autoReconnectAttempts = 0,
    this.autoReconnectCancelled = false,
    this.autoReconnectTimer,
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

    final terminal = Terminal(
      maxLines: TerminalConfig.maxScrollbackLines,
      mouseHandler: const ShellLiteMouseHandler(),
    );
    final controller = TerminalController();
    final sshService = SSHService(storageService: _storageService);

    terminal.onOutput = (data) {
      sshService.sendInput(data);
    };

    terminal.onResize = (width, height, pw, ph) {
      sshService.resizeTerminal(width, height, pw, ph);
    };

    final session = OpenSession(
      id: profile.id,
      profile: profile,
      terminal: terminal,
      controller: controller,
      sshService: sshService,
      connectionState: SSHConnectionState.connecting,
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
          session.autoReconnectAttempts = 0;
          session.autoReconnectCancelled = false;
          _cancelAutoReconnectTimer(session);
          session.terminal.write(
            '\x1b[38;2;63;185;80m✔ Connected to ${session.profile.displayName}\x1b[0m\r\n\r\n',
          );
        } else if (state == SSHConnectionState.error && error != null) {
          session.terminal.write(
            '\r\n\x1b[38;2;248;81;73m✖ Connection failed: $error\x1b[0m\r\n',
          );
          _scheduleAutoReconnect(session);
        } else if (state == SSHConnectionState.disconnected) {
          session.terminal.write(
            '\r\n\x1b[38;2;139;148;158mSession closed.\x1b[0m\r\n',
          );
          _scheduleAutoReconnect(session);
        }
        notifyListeners();
      },
    );
  }

  void _cancelAutoReconnectTimer(OpenSession session) {
    session.autoReconnectTimer?.cancel();
    session.autoReconnectTimer = null;
    session.autoReconnectCountdown = null;
  }

  void cancelAutoReconnect(String sessionId) {
    final session = _sessions[sessionId];
    if (session == null) return;
    _cancelAutoReconnectTimer(session);
    session.autoReconnectCancelled = true;
    if (session.connectionState == SSHConnectionState.connecting) {
      session.sshService.disconnect();
      session.connectionState = SSHConnectionState.disconnected;
    }
    notifyListeners();
  }

  void triggerAutoReconnect(String sessionId) {
    final session = _sessions[sessionId];
    if (session == null) return;
    session.autoReconnectCancelled = false;
    _scheduleAutoReconnect(session);
  }

  void _scheduleAutoReconnect(OpenSession session) {
    if (!session.wasConnected) return;
    if (session.autoReconnectCancelled) return;
    if (session.autoReconnectAttempts >= SSHConfig.maxAutoReconnectAttempts) {
      _cancelAutoReconnectTimer(session);
      return;
    }

    _cancelAutoReconnectTimer(session);

    // Initial drop: reconnect as soon as possible (immediately, 0s delay)
    if (session.autoReconnectAttempts == 0) {
      session.autoReconnectAttempts = 1;
      notifyListeners();
      reconnectSession(session.id);
      return;
    }

    // Subsequent drops/failures: short backoff (3 seconds)
    session.autoReconnectAttempts++;
    session.autoReconnectCountdown = SSHConfig.autoReconnectDelay.inSeconds;
    notifyListeners();

    session.autoReconnectTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (session.autoReconnectCountdown == null || session.autoReconnectCountdown! <= 1) {
        _cancelAutoReconnectTimer(session);
        if (!session.autoReconnectCancelled &&
            (session.connectionState == SSHConnectionState.disconnected ||
             session.connectionState == SSHConnectionState.error)) {
          reconnectSession(session.id);
        }
      } else {
        session.autoReconnectCountdown = session.autoReconnectCountdown! - 1;
        notifyListeners();
      }
    });
  }

  Future<void> reconnectSession(String sessionId, {bool isManual = false}) async {
    final session = _sessions[sessionId];
    if (session == null) return;
    if (session.connectionState == SSHConnectionState.connecting) return;
    _cancelAutoReconnectTimer(session);
    if (isManual) {
      session.autoReconnectAttempts = 0;
    }
    session.autoReconnectCancelled = false;
    session.connectionState = SSHConnectionState.connecting;
    notifyListeners();
    await _connectSession(session);
  }

  void closeSession(String sessionId) {
    final session = _sessions.remove(sessionId);
    if (session != null) {
      _cancelAutoReconnectTimer(session);
      session.sshService.disconnect();
      session.controller.dispose();
    }

    if (_activeSessionId == sessionId) {
      _activeSessionId = _sessions.isNotEmpty ? _sessions.keys.last : null;
    }
    notifyListeners();
  }

  void updateSessionConnectionState(
    String sessionId,
    SSHConnectionState state, {
    bool? wasConnected,
    bool triggerAutoReconnect = false,
  }) {
    final session = _sessions[sessionId];
    if (session != null) {
      session.connectionState = state;
      if (wasConnected != null) {
        session.wasConnected = wasConnected;
      }
      if (triggerAutoReconnect) {
        _scheduleAutoReconnect(session);
      } else {
        _cancelAutoReconnectTimer(session);
      }
      notifyListeners();
    }
  }

  @override
  void dispose() {
    for (final session in _sessions.values) {
      _cancelAutoReconnectTimer(session);
      session.sshService.disconnect();
      session.controller.dispose();
    }
    _sessions.clear();
    super.dispose();
  }
}
