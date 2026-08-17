import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:xterm/xterm.dart';
import '../config/app_config.dart';
import '../models/server_profile.dart';
import '../providers/session_store.dart';
import '../providers/terminal_settings_store.dart';
import '../services/ssh_service.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';
import '../widgets/directional_hud.dart';
import '../widgets/keyboard_accessory_bar.dart';
import '../widgets/snippet_runner_sheet.dart';
import '../widgets/terminal_appearance_modal.dart';
import '../widgets/terminal_search_bar.dart';

class TerminalScreen extends StatefulWidget {
  final ServerProfile profile;

  const TerminalScreen({super.key, required this.profile});

  @override
  State<TerminalScreen> createState() => _TerminalScreenState();
}

class _TerminalScreenState extends State<TerminalScreen> {
  late final Terminal _fallbackTerminal;
  late final TerminalController _fallbackController;
  late final SSHService _fallbackSSHService;

  bool _showGestureTip = false;
  bool _isSearching = false;
  Timer? _tipDismissTimer;

  T? _tryWatch<T>(BuildContext context) {
    try {
      return Provider.of<T>(context, listen: true);
    } catch (_) {
      return null;
    }
  }

  T? _tryRead<T>(BuildContext context) {
    try {
      return Provider.of<T>(context, listen: false);
    } catch (_) {
      return null;
    }
  }

  @override
  void initState() {
    super.initState();

    _fallbackTerminal = Terminal(maxLines: TerminalConfig.maxScrollbackLines);
    _fallbackController = TerminalController();
    _fallbackSSHService = SSHService();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkGestureTip();
      final sessionStore = _tryRead<SessionStore>(context);
      if (sessionStore != null) {
        sessionStore.getOrCreateSession(widget.profile);
      }
    });
  }

  Future<void> _checkGestureTip() async {
    final storage = mounted ? _tryRead<StorageService>(context) : null;
    if (storage != null) {
      final seen = await storage.hasSeenGestureTip();
      if (!seen && mounted) {
        setState(() {
          _showGestureTip = true;
        });
        _tipDismissTimer = Timer(const Duration(seconds: 7), _dismissGestureTip);
      }
    }
  }

  void _dismissGestureTip() {
    _tipDismissTimer?.cancel();
    _tipDismissTimer = null;
    if (_showGestureTip && mounted) {
      setState(() {
        _showGestureTip = false;
      });
      final storage = mounted ? _tryRead<StorageService>(context) : null;
      storage?.markGestureTipSeen();
    }
  }

  @override
  void dispose() {
    _tipDismissTimer?.cancel();
    _fallbackController.dispose();
    _fallbackSSHService.disconnect();
    super.dispose();
  }

  void _handleKeyTap(String sequence) {
    final sessionStore = _tryRead<SessionStore>(context);
    final session = sessionStore?.activeSession ?? sessionStore?.getSession(widget.profile.id);
    if (session != null) {
      session.sshService.sendInput(sequence);
    } else {
      _fallbackSSHService.sendInput(sequence);
    }
  }

  Future<void> _pasteClipboard() async {
    final data = await Clipboard.getData('text/plain');
    if (data != null && data.text != null) {
      _handleKeyTap(data.text!);
    }
  }

  void _copyBuffer() async {
    final sessionStore = _tryRead<SessionStore>(context);
    final session = sessionStore?.activeSession ?? sessionStore?.getSession(widget.profile.id);
    final term = session?.terminal ?? _fallbackTerminal;
    final text = term.buffer.getText();
    if (text.isEmpty) return;

    await Clipboard.setData(ClipboardData(text: text));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Copied ${text.length} characters of terminal output to clipboard'),
          backgroundColor: AppTheme.cardSurface,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _clearTerminal() {
    final sessionStore = _tryRead<SessionStore>(context);
    final session = sessionStore?.activeSession ?? sessionStore?.getSession(widget.profile.id);
    final term = session?.terminal ?? _fallbackTerminal;
    term.eraseDisplay();
  }

  void _toggleSearch() {
    setState(() {
      _isSearching = !_isSearching;
    });
  }

  Color _getStatusColor(SSHConnectionState state) {
    switch (state) {
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

  String _getStatusText(SSHConnectionState state) {
    switch (state) {
      case SSHConnectionState.connected:
        return 'Connected';
      case SSHConnectionState.connecting:
        return 'Connecting...';
      case SSHConnectionState.error:
        return 'Connection Error';
      case SSHConnectionState.disconnected:
        return 'Disconnected';
    }
  }

  @override
  Widget build(BuildContext context) {
    final terminalSettings = _tryWatch<TerminalSettingsStore>(context);
    final sessionStore = _tryWatch<SessionStore>(context);
    final session = sessionStore?.activeSession ?? sessionStore?.getSession(widget.profile.id);

    final terminal = session?.terminal ?? _fallbackTerminal;
    final controller = session?.controller ?? _fallbackController;
    final connectionState = session?.connectionState ?? SSHConnectionState.disconnected;

    final activeTheme = terminalSettings?.activeTheme ?? TerminalConfig.theme;
    final textStyle = terminalSettings?.terminalStyle ?? TerminalConfig.textStyle;

    // Auto-pop to Server List when remote connection is exited via exit command or Ctrl+D
    if (session != null &&
        session.connectionState == SSHConnectionState.disconnected &&
        session.wasConnected) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          Navigator.of(context).maybePop();
        }
      });
    }

    return Scaffold(
      appBar: AppBar(
        title: Column(
          children: [
            Text(session?.profile.displayName ?? widget.profile.displayName, style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 2),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _getStatusColor(connectionState),
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  _getStatusText(connectionState),
                  style: TextStyle(
                    fontSize: 11,
                    color: _getStatusColor(connectionState),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(
              _isSearching ? Icons.search_off_rounded : Icons.search_rounded,
              size: 20,
              color: _isSearching ? AppTheme.terminalGreen : null,
            ),
            tooltip: _isSearching ? 'Close Search' : 'Search Buffer',
            onPressed: _toggleSearch,
          ),
          IconButton(
            icon: const Icon(Icons.palette_outlined, size: 20),
            tooltip: 'Appearance & Themes',
            onPressed: () => TerminalAppearanceModal.show(context),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded, size: 20),
            tooltip: 'More actions',
            color: AppTheme.surface,
            shape: RoundedRectangleBorder(
              side: const BorderSide(color: AppTheme.border),
              borderRadius: BorderRadius.circular(10),
            ),
            onSelected: (val) {
              switch (val) {
                case 'snippets':
                  SnippetRunnerSheet.show(context, _handleKeyTap);
                  break;
                case 'copy':
                  _copyBuffer();
                  break;
                case 'paste':
                  _pasteClipboard();
                  break;
                case 'reconnect':
                  if (session != null) {
                    sessionStore?.reconnectSession(session.id);
                  }
                  break;
                case 'disconnect':
                  if (session != null) {
                    sessionStore?.closeSession(session.id);
                  }
                  Navigator.of(context).maybePop();
                  break;
                case 'clear':
                  _clearTerminal();
                  break;
                case 'guide':
                  setState(() => _showGestureTip = true);
                  _tipDismissTimer?.cancel();
                  _tipDismissTimer = Timer(const Duration(seconds: 7), _dismissGestureTip);
                  break;
              }
            },
            itemBuilder: (ctx) => [
              const PopupMenuItem(
                value: 'snippets',
                child: Row(
                  children: [
                    Icon(Icons.bolt_rounded, size: 18, color: AppTheme.terminalGreen),
                    SizedBox(width: 10),
                    Text('Command Snippets'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'copy',
                child: Row(
                  children: [
                    Icon(Icons.copy_all_rounded, size: 18, color: AppTheme.textSecondary),
                    SizedBox(width: 10),
                    Text('Copy Buffer Log'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'paste',
                child: Row(
                  children: [
                    Icon(Icons.paste_rounded, size: 18, color: AppTheme.textSecondary),
                    SizedBox(width: 10),
                    Text('Paste'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'clear',
                child: Row(
                  children: [
                    Icon(Icons.clear_all_rounded, size: 18, color: AppTheme.textSecondary),
                    SizedBox(width: 10),
                    Text('Clear Screen'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'reconnect',
                child: Row(
                  children: [
                    Icon(Icons.refresh_rounded, size: 18, color: AppTheme.textSecondary),
                    SizedBox(width: 10),
                    Text('Reconnect'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'disconnect',
                child: Row(
                  children: [
                    Icon(Icons.power_settings_new_rounded, size: 18, color: AppTheme.errorRed),
                    SizedBox(width: 10),
                    Text('Disconnect Session', style: TextStyle(color: AppTheme.errorRed)),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'guide',
                child: Row(
                  children: [
                    Icon(Icons.help_outline_rounded, size: 18, color: AppTheme.textSecondary),
                    SizedBox(width: 10),
                    Text('Gestures Guide'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Stack(
                children: [
                  Container(
                    color: activeTheme.background,
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    child: DirectionalHUDOverlay(
                      onAction: _handleKeyTap,
                      child: TerminalView(
                        terminal,
                        controller: controller,
                        theme: activeTheme,
                        autofocus: true,
                        textStyle: textStyle,
                      ),
                    ),
                  ),
                  if (_isSearching)
                    Positioned(
                      top: 8,
                      left: 12,
                      right: 12,
                      child: TerminalSearchBar(
                        terminal: terminal,
                        controller: controller,
                        onClose: _toggleSearch,
                      ),
                    ),
                  if (_showGestureTip && !_isSearching)
                    Positioned(
                      top: 10,
                      left: 12,
                      right: 12,
                      child: _buildGestureTipBanner(),
                    ),
                ],
              ),
            ),
            KeyboardAccessoryBar(
              onKeyTap: _handleKeyTap,
              onSnippetTap: () => SnippetRunnerSheet.show(context, _handleKeyTap),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGestureTipBanner() {
    return Material(
      color: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppTheme.cardSurface.withOpacity(0.96),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: AppTheme.terminalGreen.withOpacity(0.6),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.4),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            const Icon(
              Icons.lightbulb_outline_rounded,
              color: AppTheme.terminalGreen,
              size: 20,
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'Tip: Hold anywhere on screen for navigation joystick (↑/↓ History, → Tab, ← Cursor)',
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  height: 1.3,
                ),
              ),
            ),
            const SizedBox(width: 6),
            InkWell(
              borderRadius: BorderRadius.circular(4),
              onTap: _dismissGestureTip,
              child: const Padding(
                padding: EdgeInsets.all(4),
                child: Icon(
                  Icons.close_rounded,
                  color: AppTheme.textSecondary,
                  size: 16,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
