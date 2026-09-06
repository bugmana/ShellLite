import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:xterm/xterm.dart';
import '../config/app_config.dart';
import '../models/server_profile.dart';
import '../providers/session_store.dart';
import '../providers/terminal_settings_store.dart';
import '../services/ssh_service.dart';
import '../theme/app_theme.dart';
import '../widgets/file_upload_modal.dart';
import '../widgets/keyboard_accessory_bar.dart';
import '../widgets/terminal_appearance_modal.dart';
import '../widgets/terminal_selection_handle.dart';

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

  bool _isKeyboardVisible = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _fallbackTerminal = Terminal(maxLines: TerminalConfig.maxScrollbackLines);
    _fallbackController = TerminalController();
    _terminalFocusNode = FocusNode();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final sessionStore = context.maybeRead<SessionStore>();
      if (sessionStore != null) {
        sessionStore.getOrCreateSession(widget.profile);
      }
      _focusTerminal();
    });
  }

  @override
  void didChangeMetrics() {
    super.didChangeMetrics();
    final bottomInset = View.of(context).viewInsets.bottom;
    final isVisible = bottomInset > 0 || _terminalFocusNode.hasFocus;
    if (_isKeyboardVisible != isVisible && mounted) {
      setState(() {
        _isKeyboardVisible = isVisible;
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
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
    if (!_terminalFocusNode.hasFocus) {
      _terminalFocusNode.requestFocus();
    }
    _terminalViewKey.currentState?.requestKeyboard();
    if (!_isKeyboardVisible) {
      setState(() {
        _isKeyboardVisible = true;
      });
    }
  }

  void _closeKeyboard() {
    if (!mounted) return;
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
            padding: const EdgeInsets.all(10),
            constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
            visualDensity: VisualDensity.compact,
            onPressed: () => _openFileUpload(context),
          ),
          IconButton(
            icon: const Icon(Icons.paste_rounded, size: 20),
            tooltip: 'Paste',
            padding: const EdgeInsets.all(10),
            constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
            visualDensity: VisualDensity.compact,
            onPressed: _pasteClipboard,
          ),
          IconButton(
            icon: const Icon(Icons.tune_rounded, size: 20),
            tooltip: 'Terminal Settings',
            padding: const EdgeInsets.all(10),
            constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
            visualDensity: VisualDensity.compact,
            onPressed: () => TerminalAppearanceModal.show(context).then((_) => _focusTerminal()),
          ),
          HoldToDisconnectButton(
            theme: theme,
            onDisconnect: () {
              if (session != null) {
                sessionStore?.closeSession(session.id);
              }
              Navigator.of(context).maybePop();
            },
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
                  final canvasHeight = constraints.maxHeight;
                  return ListenableBuilder(
                    listenable: Listenable.merge([controller, _terminalScrollController]),
                    builder: (context, _) {
                      final selection = controller.selection?.normalized;
                      final hasSelection = selection != null;
                      final renderTerminal = _renderTerminal;

                      Offset? startOffset;
                      Offset? endOffset;
                      double lineHeight = 16.0;

                      if (hasSelection && renderTerminal != null) {
                        try {
                          lineHeight = renderTerminal.lineHeight as double;
                          startOffset = renderTerminal.getOffset(selection.begin) as Offset;
                          endOffset = renderTerminal.getOffset(selection.end) as Offset;
                        } catch (_) {
                          startOffset = null;
                          endOffset = null;
                        }
                      }

                      final isStartNearBottom = startOffset != null &&
                          (canvasHeight - (startOffset.dy + lineHeight)) < 32.0;
                      final isEndNearBottom = endOffset != null &&
                          (canvasHeight - (endOffset.dy + lineHeight)) < 32.0;

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
                          onTapUp: (details, offset) => _focusTerminal(),
                        ),
                      ),
                      if (hasSelection && startOffset != null && endOffset != null) ...[
                        TerminalSelectionHandle(
                          handleKey: const Key('terminal_selection_handle_start'),
                          position: TerminalHandlePosition.left,
                          offset: startOffset,
                          lineHeight: lineHeight,
                          color: theme.primaryAccent,
                          invertStem: isStartNearBottom,
                          onDragUpdate: (details) => _handleStartHandleDrag(
                            details,
                            selection,
                            terminal,
                            controller,
                          ),
                        ),
                        TerminalSelectionHandle(
                          handleKey: const Key('terminal_selection_handle_end'),
                          position: TerminalHandlePosition.right,
                          offset: endOffset,
                          lineHeight: lineHeight,
                          color: theme.primaryAccent,
                          invertStem: isEndNearBottom,
                          onDragUpdate: (details) => _handleEndHandleDrag(
                            details,
                            selection,
                            terminal,
                            controller,
                          ),
                        ),
                      ],
                      if (isDisconnected)
                        Positioned(
                          top: 0,
                          left: 0,
                          right: 0,
                          child: Semantics(
                            liveRegion: true,
                            label: 'Connection lost. Buffer preserved.',
                            child: Container(
                              height: 48,
                              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                              decoration: BoxDecoration(
                                color: theme.cardSurface.withValues(alpha: 0.94),
                                border: Border(
                                  bottom: BorderSide(
                                    color: theme.warning.withValues(alpha: 0.5),
                                    width: 1.0,
                                  ),
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.3),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.warning_amber_rounded, color: theme.warning, size: 20),
                                  const SizedBox(width: AppSpacing.sm),
                                  Expanded(
                                    child: Text(
                                      'Connection lost. Buffer preserved.',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: theme.textPrimary,
                                        fontWeight: FontWeight.w500,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: AppSpacing.sm),
                                  ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: theme.primaryAccent,
                                      foregroundColor: AppTheme.computeOnPrimary(theme.primaryAccent),
                                      minimumSize: const Size(0, 36),
                                      padding: const EdgeInsets.symmetric(horizontal: 12),
                                    ),
                                    onPressed: () {
                                      if (session != null) {
                                        sessionStore?.reconnectSession(session.id);
                                      }
                                    },
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.refresh_rounded, size: 16),
                                        SizedBox(width: 4),
                                        Text('Reconnect', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                    ],
                  );
                },
              );
            },
          ),
        ),
        ListenableBuilder(
          listenable: controller,
          builder: (context, _) => _buildBottomBar(context, theme, terminal, controller),
        ),
      ],
    ),
  ),
);
}

  Widget _buildBottomBar(
    BuildContext context,
    AppThemeExtension theme,
    Terminal terminal,
    TerminalController controller,
  ) {
    final hasSelection = controller.selection != null;
    final textScale = MediaQuery.textScalerOf(context).scale(1.0);
    final dynamicHeight = (52.0 * textScale.clamp(1.0, 1.35)).clamp(52.0, 72.0);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      curve: Curves.easeOutCubic,
      height: dynamicHeight + 1.0,
      decoration: BoxDecoration(
        color: theme.surface,
        border: Border(top: BorderSide(color: theme.border, width: 1.0)),
      ),
      child: hasSelection
          ? _buildContextualSelectionBar(context, theme, terminal, controller)
          : KeyboardAccessoryBar(
              onKeyTap: _handleKeyTap,
              onInteraction: _focusTerminal,
              isKeyboardVisible: _isKeyboardVisible,
              onToggleKeyboard: _toggleKeyboard,
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
    );
  }

  Widget _buildContextualSelectionBar(
    BuildContext context,
    AppThemeExtension theme,
    Terminal terminal,
    TerminalController controller,
  ) {
    final onPrimary = AppTheme.computeOnPrimary(theme.primaryAccent);

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          const SizedBox(width: AppSpacing.sm),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.primaryAccent,
              foregroundColor: onPrimary,
              minimumSize: const Size(0, 44),
            ),
            icon: const Icon(Icons.copy_rounded, size: 18),
            label: const Text(
              'Copy',
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            onPressed: () {
              HapticFeedback.lightImpact();
              final selection = controller.selection;
              if (selection != null) {
                final text = terminal.buffer.getText(selection);
                Clipboard.setData(ClipboardData(text: text));
                controller.clearSelection();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('Copied to clipboard'),
                    duration: const Duration(seconds: 1),
                    behavior: SnackBarBehavior.floating,
                    backgroundColor: theme.cardSurface,
                  ),
                );
              }
              SemanticsService.sendAnnouncement(
                View.of(context),
                'Selection copied to clipboard',
                TextDirection.ltr,
              );
            },
          ),
          const SizedBox(width: AppSpacing.sm),
          OutlinedButton(
            style: OutlinedButton.styleFrom(minimumSize: const Size(64, 44)),
            onPressed: () => _expandSelectionToWord(terminal, controller),
            child: const Text('Word'),
          ),
          const SizedBox(width: AppSpacing.sm),
          IconButton(
            constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
            icon: const Icon(Icons.close_rounded, size: 20),
            tooltip: 'Clear Selection',
            onPressed: () => controller.clearSelection(),
          ),
          const SizedBox(width: AppSpacing.sm),
          // Pinned Emergency Keys: Eliminates CLI Key Lockout in vim/nano/tmux
          Container(
            height: 24,
            width: 1,
            color: theme.border,
            margin: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.cardSurface,
              foregroundColor: theme.textPrimary,
              minimumSize: const Size(44, 44),
              padding: const EdgeInsets.symmetric(horizontal: 10),
            ),
            onPressed: () => terminal.keyInput(TerminalKey.escape),
            child: const Text('Esc'),
          ),
          const SizedBox(width: AppSpacing.xs),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.cardSurface,
              foregroundColor: theme.error,
              minimumSize: const Size(44, 44),
              padding: const EdgeInsets.symmetric(horizontal: 10),
            ),
            onPressed: () => terminal.textInput('\x03'),
            child: const Text('^C'),
          ),
          const SizedBox(width: AppSpacing.sm),
        ],
      ),
    );
  }

  void _expandSelectionToWord(Terminal terminal, TerminalController controller) {
    final selection = controller.selection?.normalized;
    if (selection == null) return;

    final lineIndex = selection.begin.y;
    if (lineIndex < 0 || lineIndex >= terminal.buffer.lines.length) return;

    final lineText = terminal.buffer.lines[lineIndex].getText();
    if (lineText.isEmpty) return;

    int col = selection.begin.x.clamp(0, lineText.length - 1);
    bool isWordChar(String ch) {
      final code = ch.codeUnitAt(0);
      return (code >= 48 && code <= 57) || // 0-9
          (code >= 65 && code <= 90) || // A-Z
          (code >= 97 && code <= 122) || // a-z
          code == 95 || // _
          code == 45 || // -
          code == 46; // .
    }

    int startCol = col;
    while (startCol > 0 && isWordChar(lineText[startCol - 1])) {
      startCol--;
    }

    int endCol = col;
    while (endCol < lineText.length && isWordChar(lineText[endCol])) {
      endCol++;
    }

    if (endCol > startCol) {
      controller.setSelection(
        terminal.buffer.createAnchor(startCol, lineIndex),
        terminal.buffer.createAnchor(endCol, lineIndex),
        mode: controller.selectionMode,
      );
      HapticFeedback.selectionClick();
    }
  }

  void _handleStartHandleDrag(
    DragUpdateDetails details,
    BufferRange normalized,
    Terminal terminal,
    TerminalController controller,
  ) {
    final renderBox = _terminalViewKey.currentContext?.findRenderObject() as RenderBox?;
    final renderTerminal = _renderTerminal;
    if (renderBox == null || renderTerminal == null) return;

    final localPos = renderBox.globalToLocal(details.globalPosition);
    final lineHeight = renderTerminal.lineHeight as double;

    // Aim for the vertical center of the character cell
    final targetOffset = Offset(localPos.dx, localPos.dy - (lineHeight * 0.5));
    final cellOffset = renderTerminal.getCellOffset(targetOffset) as CellOffset;

    // The start marker cannot be dragged past the last character of the selection
    final currentEnd = normalized.end;
    CellOffset lastValidStart;
    if (currentEnd.x > 0) {
      lastValidStart = CellOffset(currentEnd.x - 1, currentEnd.y);
    } else if (currentEnd.y > 0) {
      lastValidStart = CellOffset(terminal.viewWidth - 1, currentEnd.y - 1);
    } else {
      lastValidStart = const CellOffset(0, 0);
    }

    final newStart = cellOffset.isAfter(lastValidStart) ? lastValidStart : cellOffset;

    if (!newStart.isEqual(normalized.begin)) {
      controller.setSelection(
        terminal.buffer.createAnchorFromOffset(newStart),
        terminal.buffer.createAnchorFromOffset(currentEnd),
        mode: controller.selectionMode,
      );
      HapticFeedback.selectionClick();
    }
  }

  void _handleEndHandleDrag(
    DragUpdateDetails details,
    BufferRange normalized,
    Terminal terminal,
    TerminalController controller,
  ) {
    final renderBox = _terminalViewKey.currentContext?.findRenderObject() as RenderBox?;
    final renderTerminal = _renderTerminal;
    if (renderBox == null || renderTerminal == null) return;

    final localPos = renderBox.globalToLocal(details.globalPosition);
    final lineHeight = renderTerminal.lineHeight as double;

    // Aim for the vertical center of the character cell
    final targetOffset = Offset(localPos.dx, localPos.dy - (lineHeight * 0.5));
    final cellOffset = renderTerminal.getCellOffset(targetOffset) as CellOffset;

    // Target cell should be included in selection, so end boundary is cellOffset.x + 1
    final targetEnd = CellOffset(
      (cellOffset.x + 1).clamp(1, terminal.viewWidth),
      cellOffset.y,
    );

    // End marker cannot be dragged before or same as the start marker
    final minEnd = CellOffset(
      (normalized.begin.x + 1).clamp(1, terminal.viewWidth),
      normalized.begin.y,
    );

    final newEnd = targetEnd.isBefore(minEnd) ? minEnd : targetEnd;

    if (!newEnd.isEqual(normalized.end)) {
      controller.setSelection(
        terminal.buffer.createAnchorFromOffset(normalized.begin),
        terminal.buffer.createAnchorFromOffset(newEnd),
        mode: controller.selectionMode,
      );
      HapticFeedback.selectionClick();
    }
  }
}

class HoldToDisconnectButton extends StatefulWidget {
  final VoidCallback onDisconnect;
  final AppThemeExtension theme;

  const HoldToDisconnectButton({
    super.key,
    required this.onDisconnect,
    required this.theme,
  });

  @override
  State<HoldToDisconnectButton> createState() => _HoldToDisconnectButtonState();
}

class _HoldToDisconnectButtonState extends State<HoldToDisconnectButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _progressController;
  Timer? _holdTimer;

  @override
  void initState() {
    super.initState();
    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
  }

  @override
  void dispose() {
    _holdTimer?.cancel();
    _progressController.dispose();
    super.dispose();
  }

  void _startHold() {
    _progressController.forward(from: 0.0);
    _holdTimer?.cancel();
    _holdTimer = Timer(const Duration(milliseconds: 600), () {
      HapticFeedback.heavyImpact();
      widget.onDisconnect();
    });
  }

  void _cancelHold() {
    _holdTimer?.cancel();
    _holdTimer = null;
    if (_progressController.isAnimating || _progressController.value > 0.0) {
      _progressController.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Disconnect Session',
      triggerMode: TooltipTriggerMode.manual,
      child: Semantics(
        button: true,
        label: 'Disconnect Session',
        hint: 'Press and hold for 600 milliseconds to disconnect',
        onLongPress: () {
          HapticFeedback.heavyImpact();
          widget.onDisconnect();
        },
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (_) => _startHold(),
          onTapUp: (_) => _cancelHold(),
          onTapCancel: _cancelHold,
          child: Container(
            constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
            alignment: Alignment.center,
            padding: const EdgeInsets.all(10),
            child: Stack(
              alignment: Alignment.center,
              children: [
                AnimatedBuilder(
                  animation: _progressController,
                  builder: (context, _) {
                    if (_progressController.value == 0.0) {
                      return const SizedBox(width: 24, height: 24);
                    }
                    return SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        value: _progressController.value,
                        strokeWidth: 2.5,
                        valueColor: AlwaysStoppedAnimation<Color>(widget.theme.error),
                        backgroundColor: widget.theme.error.withValues(alpha: 0.2),
                      ),
                    );
                  },
                ),
                Icon(
                  Icons.power_settings_new_rounded,
                  size: 20,
                  color: widget.theme.error,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
