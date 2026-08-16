import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:xterm/xterm.dart';
import '../models/server_profile.dart';
import '../services/ssh_service.dart';
import '../theme/app_theme.dart';
import '../widgets/keyboard_accessory_bar.dart';

class TerminalScreen extends StatefulWidget {
  final ServerProfile profile;

  const TerminalScreen({super.key, required this.profile});

  @override
  State<TerminalScreen> createState() => _TerminalScreenState();
}

class _TerminalScreenState extends State<TerminalScreen> {
  late final Terminal _terminal;
  late final SSHService _sshService;
  SSHConnectionState _connectionState = SSHConnectionState.disconnected;

  @override
  void initState() {
    super.initState();

    _terminal = Terminal(
      maxLines: 10000,
    );

    _terminal.onOutput = (data) {
      _sshService.sendInput(data);
    };

    _terminal.onResize = (width, height, pixelWidth, pixelHeight) {
      _sshService.resizeTerminal(width, height);
    };

    _sshService = SSHService();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _connect();
    });
  }

  Future<void> _connect() async {
    _terminal.write('\r\n\x1b[33mConnecting to ${widget.profile.username}@${widget.profile.host}:${widget.profile.port}...\x1b[0m\r\n');

    await _sshService.connect(
      profile: widget.profile,
      terminalWidth: _terminal.viewWidth > 0 ? _terminal.viewWidth : 80,
      terminalHeight: _terminal.viewHeight > 0 ? _terminal.viewHeight : 24,
      onOutput: (output) {
        if (mounted) {
          _terminal.write(output);
        }
      },
      onStateChange: (state, error) {
        if (mounted) {
          setState(() {
            _connectionState = state;
          });
          if (state == SSHConnectionState.connected) {
            _terminal.write('\x1b[32m✔ Connected!\x1b[0m\r\n\r\n');
          } else if (state == SSHConnectionState.error && error != null) {
            _terminal.write('\r\n\x1b[31m✖ Error: $error\x1b[0m\r\n');
          } else if (state == SSHConnectionState.disconnected) {
            _terminal.write('\r\n\x1b[33mSession disconnected.\x1b[0m\r\n');
          }
        }
      },
    );
  }

  @override
  void dispose() {
    _sshService.disconnect();
    super.dispose();
  }

  void _handleKeyTap(String sequence) {
    _sshService.sendInput(sequence);
  }

  Future<void> _pasteClipboard() async {
    final data = await Clipboard.getData('text/plain');
    if (data != null && data.text != null) {
      _sshService.sendInput(data.text!);
    }
  }

  void _clearTerminal() {
    _terminal.eraseDisplay();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          children: [
            Text(widget.profile.displayName, style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 2),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _getStatusColor(),
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  _getStatusText(),
                  style: TextStyle(
                    fontSize: 11,
                    color: _getStatusColor(),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.paste_rounded, size: 20),
            tooltip: 'Paste',
            onPressed: _pasteClipboard,
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded, size: 20),
            tooltip: 'Reconnect',
            onPressed: _connectionState == SSHConnectionState.connecting ? null : _connect,
          ),
          IconButton(
            icon: const Icon(Icons.clear_all_rounded, size: 20),
            tooltip: 'Clear Screen',
            onPressed: _clearTerminal,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Container(
                color: const Color(0xFF0D1117),
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: TerminalView(
                  _terminal,
                  autofocus: true,
                  textStyle: const TerminalStyle(
                    fontSize: 13,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
            ),
            KeyboardAccessoryBar(onKeyTap: _handleKeyTap),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor() {
    switch (_connectionState) {
      case SSHConnectionState.connected:
        return AppTheme.terminalGreen;
      case SSHConnectionState.connecting:
        return AppTheme.warningYellow;
      case SSHConnectionState.error:
        return AppTheme.errorRed;
      case SSHConnectionState.disconnected:
        return AppTheme.textSecondary;
    }
  }

  String _getStatusText() {
    switch (_connectionState) {
      case SSHConnectionState.connected:
        return 'Connected';
      case SSHConnectionState.connecting:
        return 'Connecting...';
      case SSHConnectionState.error:
        return 'Connection Failed';
      case SSHConnectionState.disconnected:
        return 'Disconnected';
    }
  }
}
