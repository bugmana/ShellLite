import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:xterm/xterm.dart';
import '../config/app_config.dart';
import '../models/server_profile.dart';
import '../providers/session_store.dart';
import '../providers/terminal_settings_store.dart';
import '../services/ssh_service.dart';
import '../services/terminal_mouse_handler.dart';
import '../theme/app_theme.dart';
import '../widgets/file_upload_modal.dart';
import '../widgets/keyboard_accessory_bar.dart';
import '../widgets/terminal_appearance_modal.dart';
import 'terminal/terminal_selection_overlay.dart';
import 'terminal/terminal_session_menu.dart';

class TerminalScreen extends StatefulWidget {
  final ServerProfile profile;

  const TerminalScreen({super.key, required this.profile});

  @override
  State<TerminalScreen> createState() => _TerminalScreenState();
}

class _TerminalScreenState extends State<TerminalScreen> with WidgetsBindingObserver {
  late final Terminal _fallbackTerminal;
  late final TerminalController _fallbackController;
  late final FocusNode _terminalFocusNode;
  final ScrollController _terminalScrollController = ScrollController();
  final GlobalKey<TerminalViewState> _terminalViewKey = GlobalKey<TerminalViewState>();
  ScrollPosition? _attachedScrollPosition;

  bool _isKeyboardVisible = true;
  bool _hasObservedKeyboardInset = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _fallbackTerminal = Terminal(
      maxLines: TerminalConfig.maxScrollbackLines,
      mouseHandler: const ShellLiteMouseHandler(),
    );
    _fallbackController = TerminalController();
    _terminalFocusNode = FocusNode();
    _terminalScrollController.addListener(_handleTerminalScroll);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final sessionStore = context.maybeRead<SessionStore>();
      if (sessionStore != null) {
        sessionStore.getOrCreateSession(widget.profile);
      }
      _focusTerminal();
    });
  }

  void _attachScrollPositionListener() {
    if (!_terminalScrollController.hasClients) return;
    final pos = _terminalScrollController.position;
    if (_attachedScrollPosition != pos) {
      _attachedScrollPosition?.isScrollingNotifier.removeListener(_handleScrollSettled);
      _attachedScrollPosition = pos;
      _attachedScrollPosition?.isScrollingNotifier.addListener(_handleScrollSettled);
    }
  }

  void _handleScrollSettled() {
    if (!mounted || !_terminalScrollController.hasClients) return;
    final pos = _terminalScrollController.position;
    // When scroll inertia settles within 16px of bottom, snap to maxScrollExtent
    // so xterm's _stickToBottom check stays active for subsequent streaming output.
    if (!pos.isScrollingNotifier.value) {
      if (pos.pixels > 0 &&
          pos.pixels < pos.maxScrollExtent &&
          pos.pixels >= pos.maxScrollExtent - 16.0) {
        _terminalScrollController.jumpTo(pos.maxScrollExtent);
      }
    }
  }

  void _handleTerminalScroll() {
    _attachScrollPositionListener();
    if (!_terminalScrollController.hasClients) return;
    final pos = _terminalScrollController.position;
    if (pos.pixels > 0 &&
        pos.pixels < pos.maxScrollExtent &&
        pos.pixels >= pos.maxScrollExtent - 4.0) {
      if (!pos.isScrollingNotifier.value) {
        _terminalScrollController.jumpTo(pos.maxScrollExtent);
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed && mounted) {
      final session = _readSession(context);
      if (session != null && session.connectionState == SSHConnectionState.connected) {
        if (!session.sshService.isSocketAlive) {
          session.sshService.disconnect();
          context.maybeRead<SessionStore>()?.updateSessionConnectionState(
            session.id,
            SSHConnectionState.disconnected,
            wasConnected: true,
            triggerAutoReconnect: true,
          );
        }
      }
    }
  }

  @override
  void didChangeMetrics() {
    super.didChangeMetrics();
    final bottomInset = View.of(context).viewInsets.bottom;
    if (bottomInset > 0) {
      _hasObservedKeyboardInset = true;
      if (!_isKeyboardVisible && mounted) {
        setState(() {
          _isKeyboardVisible = true;
        });
      }
    } else if (_hasObservedKeyboardInset && bottomInset == 0) {
      _hasObservedKeyboardInset = false;
      if (_isKeyboardVisible && mounted) {
        setState(() {
          _isKeyboardVisible = false;
        });
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _attachedScrollPosition?.isScrollingNotifier.removeListener(_handleScrollSettled);
    _attachedScrollPosition = null;
    _terminalScrollController.removeListener(_handleTerminalScroll);
    _terminalScrollController.dispose();
    _terminalFocusNode.dispose();
    _fallbackController.dispose();
    super.dispose();
  }

  dynamic get _renderTerminal {
    try {
      return _terminalViewKey.currentState?.renderTerminal;
    } catch (_) {
      return null;
    }
  }

  OpenSession? _readSession(BuildContext context) {
    final store = context.maybeRead<SessionStore>();
    return store?.activeSession ?? store?.getSession(widget.profile.id);
  }

  Terminal _readTerminal(BuildContext context) =>
      _readSession(context)?.terminal ?? _fallbackTerminal;

  void _focusTerminal() {
    if (!mounted) return;
    final wasHidden = !_isKeyboardVisible;
    if (wasHidden) {
      setState(() {
        _isKeyboardVisible = true;
      });
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (!_terminalFocusNode.hasFocus) {
        _terminalFocusNode.requestFocus();
      }
      _terminalViewKey.currentState?.requestKeyboard();
      SystemChannels.textInput.invokeMethod('TextInput.show');
    });

    if (!wasHidden) {
      if (!_terminalFocusNode.hasFocus) {
        _terminalFocusNode.requestFocus();
      }
      _terminalViewKey.currentState?.requestKeyboard();
      SystemChannels.textInput.invokeMethod('TextInput.show');
    }
  }

  void _closeKeyboard() {
    if (!mounted) return;
    _hasObservedKeyboardInset = false;
    _terminalViewKey.currentState?.closeKeyboard();
    _terminalFocusNode.unfocus();
    SystemChannels.textInput.invokeMethod('TextInput.hide');
    if (_isKeyboardVisible) {
      setState(() {
        _isKeyboardVisible = false;
      });
    }
  }

  void _toggleKeyboard() {
    if (_isKeyboardVisible) {
      _closeKeyboard();
    } else {
      _focusTerminal();
    }
  }

  void _handleKeyTap(String sequence) {
    final session = _readSession(context);
    session?.sshService.sendInput(sequence);
  }

  Future<void> _pasteClipboard() async {
    final data = await Clipboard.getData('text/plain');
    if (!mounted) return;
    if (data != null && data.text != null) {
      _readTerminal(context).paste(data.text!);
    }
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

  Color _getStatusColor(OpenSession? session, SSHConnectionState state, AppThemeExtension theme) {
    if (session?.autoReconnectCountdown != null) {
      return theme.warning;
    }
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

  String _getStatusText(OpenSession? session, SSHConnectionState state) {
    if (session?.autoReconnectCountdown != null) {
      return 'Retrying in ${session!.autoReconnectCountdown}s...';
    }
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
    final terminalSettings = context.maybeWatch<TerminalSettingsStore>();
    final sessionStore = context.maybeWatch<SessionStore>();
    final session = sessionStore?.activeSession ?? sessionStore?.getSession(widget.profile.id);

    final terminal = session?.terminal ?? _fallbackTerminal;
    final controller = session?.controller ?? _fallbackController;
    final connectionState = session?.connectionState ?? SSHConnectionState.disconnected;

    final activeTheme = terminalSettings?.activeTheme ?? TerminalConfig.theme;
    final textStyle = terminalSettings?.terminalStyle ?? TerminalConfig.textStyle;

    return Scaffold(
      appBar: AppBar(
        centerTitle: MediaQuery.sizeOf(context).width >= 380,
        titleSpacing: 0,
        title: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              session?.profile.displayName ?? widget.profile.displayName,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _getStatusColor(session, connectionState, theme),
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  _getStatusText(session, connectionState),
                  style: TextStyle(
                    fontSize: 11,
                    color: _getStatusColor(session, connectionState, theme),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TerminalSessionMenu(
            onUpload: () => _openFileUpload(context),
            onSettings: () => TerminalAppearanceModal.show(context).then((_) => _focusTerminal()),
            onDisconnect: () {
              if (session != null) {
                sessionStore?.closeSession(session.id);
              }
              Navigator.of(context).maybePop();
            },
            theme: theme,
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final canvasWidth = constraints.maxWidth;
                  final canvasHeight = constraints.maxHeight;
                  final isDisconnected = connectionState == SSHConnectionState.disconnected ||
                      connectionState == SSHConnectionState.error;

                  return Stack(
                    children: [
                      Container(
                        color: activeTheme.background,
                        child: TerminalView(
                          terminal,
                          key: _terminalViewKey,
                          controller: controller,
                          scrollController: _terminalScrollController,
                          theme: activeTheme,
                          focusNode: _terminalFocusNode,
                          autofocus: true,
                          textStyle: textStyle,
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          deleteDetection: true,
                          hardwareKeyboardOnly: !_isKeyboardVisible,
                          simulateScroll: false,
                          onTapUp: (details, offset) => _focusTerminal(),
                        ),
                      ),
                      TerminalSelectionOverlay(
                        terminal: terminal,
                        controller: controller,
                        scrollController: _terminalScrollController,
                        renderTerminal: _renderTerminal,
                        terminalViewKey: _terminalViewKey,
                        canvasWidth: canvasWidth,
                        canvasHeight: canvasHeight,
                        isDisconnected: isDisconnected,
                        theme: theme,
                      ),
                    ],
                  );
                },
              ),
            ),
            _buildBottomBar(context, theme),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomBar(
    BuildContext context,
    AppThemeExtension theme,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: theme.surface,
        border: Border(top: BorderSide(color: theme.border, width: 1.0)),
      ),
      child: KeyboardAccessoryBar(
        onKeyTap: _handleKeyTap,
        onInteraction: _focusTerminal,
        isKeyboardVisible: _isKeyboardVisible,
        onToggleKeyboard: _toggleKeyboard,
        onCloseKeyboard: _closeKeyboard,
        onPaste: _pasteClipboard,
      ),
    );
  }
}
