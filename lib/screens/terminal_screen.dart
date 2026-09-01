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
import '../widgets/file_upload_modal.dart';
import '../widgets/keyboard_accessory_bar.dart';
import '../widgets/terminal_appearance_modal.dart';

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
  late final FocusNode _terminalFocusNode;
  final GlobalKey<TerminalViewState> _terminalViewKey = GlobalKey<TerminalViewState>();

  bool _showGestureTip = false;
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
    _terminalFocusNode = FocusNode();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkGestureTip();
      final sessionStore = _tryRead<SessionStore>(context);
      if (sessionStore != null) {
        sessionStore.getOrCreateSession(widget.profile);
      }
      _focusTerminal();
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
    _terminalFocusNode.dispose();
    _fallbackController.dispose();
    _fallbackSSHService.disconnect();
    super.dispose();
  }

  OpenSession? _readSession(BuildContext context) {
    final store = _tryRead<SessionStore>(context);
    return store?.activeSession ?? store?.getSession(widget.profile.id);
  }

  Terminal _readTerminal(BuildContext context) =>
      _readSession(context)?.terminal ?? _fallbackTerminal;

  void _focusTerminal() {
    if (!mounted) return;
    if (!_terminalFocusNode.hasFocus) {
      _terminalFocusNode.requestFocus();
    }
    _terminalViewKey.currentState?.requestKeyboard();
  }

  void _closeKeyboard() {
    if (!mounted) return;
    _terminalViewKey.currentState?.closeKeyboard();
    _terminalFocusNode.unfocus();
    SystemChannels.textInput.invokeMethod('TextInput.hide');
  }

  void _handleKeyTap(String sequence) {
    final session = _readSession(context);
    if (session != null) {
      session.sshService.sendInput(sequence);
    } else {
      _fallbackSSHService.sendInput(sequence);
    }
    _focusTerminal();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _focusTerminal();
      }
    });
  }

  Future<void> _pasteClipboard() async {
    final data = await Clipboard.getData('text/plain');
    if (data != null && data.text != null) {
      _readTerminal(context).paste(data.text!);
    }
    _focusTerminal();
  }

  void _clearTerminal() {
    _readTerminal(context).eraseDisplay();
    _focusTerminal();
  }

  void _openFileUpload(BuildContext context) {
    final session = _readSession(context);
    if (session == null || !session.sshService.isConnected) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Terminal session is not connected'),
          backgroundColor: context.appTheme.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    FileUploadModal.show(context, session: session).then((_) {
      _focusTerminal();
    });
  }

  Color _getStatusColor(SSHConnectionState state, AppThemeExtension theme) {
    switch (state) {
      case SSHConnectionState.connected:
        return theme.success;
      case SSHConnectionState.connecting:
        return theme.warning;
      case SSHConnectionState.error:
        return theme.error;
      case SSHConnectionState.disconnected:
        return theme.textSecondary;
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
    final theme = context.appTheme;
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
                    color: _getStatusColor(connectionState, theme),
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  _getStatusText(connectionState),
                  style: TextStyle(
                    fontSize: 11,
                    color: _getStatusColor(connectionState, theme),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.cloud_upload_outlined, size: 20),
            tooltip: 'Upload File to Server',
            onPressed: () => _openFileUpload(context),
          ),
          IconButton(
            icon: const Icon(Icons.paste_rounded, size: 20),
            tooltip: 'Paste',
            onPressed: _pasteClipboard,
          ),
          IconButton(
            icon: const Icon(Icons.palette_outlined, size: 20),
            tooltip: 'Appearance & Themes',
            onPressed: () => TerminalAppearanceModal.show(context).then((_) => _focusTerminal()),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded, size: 20),
            tooltip: 'More actions',
            color: theme.surface,
            shape: RoundedRectangleBorder(
              side: BorderSide(color: theme.border),
              borderRadius: BorderRadius.circular(10),
            ),
            onSelected: (val) {
              switch (val) {
                case 'clear':
                  _clearTerminal();
                  break;
                case 'reconnect':
                  if (session != null) {
                    sessionStore?.reconnectSession(session.id);
                  }
                  _focusTerminal();
                  break;
                case 'disconnect':
                  if (session != null) {
                    sessionStore?.closeSession(session.id);
                  }
                  Navigator.of(context).maybePop();
                  break;
                case 'guide':
                  setState(() => _showGestureTip = true);
                  _tipDismissTimer?.cancel();
                  _tipDismissTimer = Timer(const Duration(seconds: 7), _dismissGestureTip);
                  _focusTerminal();
                  break;
              }
            },
            itemBuilder: (ctx) => [
              PopupMenuItem(
                value: 'clear',
                child: Row(
                  children: [
                    Icon(Icons.clear_all_rounded, size: 18, color: theme.textSecondary),
                    const SizedBox(width: 10),
                    const Expanded(child: Text('Clear Screen')),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'reconnect',
                child: Row(
                  children: [
                    Icon(Icons.refresh_rounded, size: 18, color: theme.textSecondary),
                    const SizedBox(width: 10),
                    const Expanded(child: Text('Reconnect')),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'disconnect',
                child: Row(
                  children: [
                    Icon(Icons.power_settings_new_rounded, size: 18, color: theme.error),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text('Disconnect Session', style: TextStyle(color: theme.error)),
                    ),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              PopupMenuItem(
                value: 'guide',
                child: Row(
                  children: [
                    Icon(Icons.help_outline_rounded, size: 18, color: theme.secondaryAccent),
                    const SizedBox(width: 10),
                    const Expanded(child: Text('Gesture Tips')),
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
                    child: DirectionalHUDOverlay(
                      onAction: _handleKeyTap,
                      child: TerminalView(
                        terminal,
                        key: _terminalViewKey,
                        controller: controller,
                        theme: activeTheme,
                        focusNode: _terminalFocusNode,
                        autofocus: true,
                        textStyle: textStyle,
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        deleteDetection: true,
                        onTapUp: (details, offset) => _focusTerminal(),
                      ),
                    ),
                  ),
                  if (_showGestureTip)
                    Positioned(
                      top: 10,
                      left: 12,
                      right: 12,
                      child: _buildGestureTipBanner(theme),
                    ),
                ],
              ),
            ),
            KeyboardAccessoryBar(
              onKeyTap: _handleKeyTap,
              onInteraction: _focusTerminal,
              onCloseKeyboard: _closeKeyboard,
              onExtendedKeysTap: () {
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (_) => ExtendedKeysSheet(onKeyTap: _handleKeyTap),
                ).then((_) {
                  _focusTerminal();
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGestureTipBanner(AppThemeExtension theme) {
    return Material(
      color: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: theme.cardSurface.withValues(alpha: 0.96),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: theme.primaryAccent.withValues(alpha: 0.6),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.4),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            Icon(
              Icons.lightbulb_outline_rounded,
              color: theme.primaryAccent,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Tip: Hold anywhere on screen for navigation joystick (↑/↓ History, → Tab, ← Cursor)',
                style: TextStyle(
                  color: theme.textPrimary,
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
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Icon(
                  Icons.close_rounded,
                  color: theme.textSecondary,
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
