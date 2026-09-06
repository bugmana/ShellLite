import 'dart:async';
import 'dart:math' as math;
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
    _terminalScrollController.addListener(_handleTerminalScroll);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final sessionStore = context.maybeRead<SessionStore>();
      if (sessionStore != null) {
        sessionStore.getOrCreateSession(widget.profile);
      }
      _focusTerminal();
    });
  }

  void _handleTerminalScroll() {
    if (!_terminalScrollController.hasClients) return;
    final pos = _terminalScrollController.position;
    // When user scrolls to within 4px of the bottom and scrolling settles,
    // ensure exact alignment with maxScrollExtent so xterm's floating-point
    // _stickToBottom check reliably activates and streams incoming output.
    if (pos.pixels > 0 &&
        pos.pixels < pos.maxScrollExtent &&
        pos.pixels >= pos.maxScrollExtent - 4.0) {
      if (!pos.isScrollingNotifier.value) {
        _terminalScrollController.jumpTo(pos.maxScrollExtent);
      }
    }
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
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert_rounded, color: theme.textPrimary, size: 20),
            tooltip: 'Session Menu',
            padding: const EdgeInsets.all(10),
            constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
            color: theme.cardSurface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.md),
              side: BorderSide(color: theme.border, width: 1),
            ),
            onSelected: (value) {
              switch (value) {
                case 'upload':
                  _openFileUpload(context);
                  break;
                case 'settings':
                  TerminalAppearanceModal.show(context).then((_) => _focusTerminal());
                  break;
                case 'disconnect':
                  if (session != null) {
                    sessionStore?.closeSession(session.id);
                  }
                  Navigator.of(context).maybePop();
                  break;
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem<String>(
                value: 'upload',
                child: Row(
                  children: [
                    Icon(Icons.cloud_upload_outlined, size: 18, color: theme.textSecondary),
                    const SizedBox(width: AppSpacing.sm),
                    Text('Upload File', style: TextStyle(color: theme.textPrimary, fontSize: 14)),
                  ],
                ),
              ),
              PopupMenuItem<String>(
                value: 'settings',
                child: Row(
                  children: [
                    Icon(Icons.tune_rounded, size: 18, color: theme.textSecondary),
                    const SizedBox(width: AppSpacing.sm),
                    Text('Terminal Settings', style: TextStyle(color: theme.textPrimary, fontSize: 14)),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              PopupMenuItem<String>(
                value: 'disconnect',
                child: Row(
                  children: [
                    Icon(Icons.power_settings_new_rounded, size: 18, color: theme.error),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      'Disconnect',
                      style: TextStyle(
                        color: theme.error,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
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
                          onTapUp: (details, offset) => _focusTerminal(),
                        ),
                      ),
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
                      ListenableBuilder(
                        listenable: Listenable.merge([controller, _terminalScrollController]),
                        builder: (context, _) {
                          final selection = controller.selection?.normalized;
                          if (selection == null) return const SizedBox.shrink();
                          final renderTerminal = _renderTerminal;
                          if (renderTerminal == null) return const SizedBox.shrink();

                          final Offset startOffset;
                          final Offset endOffset;
                          double lineHeight = 16.0;

                          try {
                            lineHeight = renderTerminal.lineHeight as double;
                            startOffset = renderTerminal.getOffset(selection.begin) as Offset;
                            endOffset = renderTerminal.getOffset(selection.end) as Offset;
                          } catch (_) {
                            return const SizedBox.shrink();
                          }

                          final isStartNearBottom =
                              (canvasHeight - (startOffset.dy + lineHeight)) < 32.0;
                          final isEndNearBottom =
                              (canvasHeight - (endOffset.dy + lineHeight)) < 32.0;

                          return Stack(
                            children: [
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
                              _buildFloatingSelectionToolbar(
                                context: context,
                                theme: theme,
                                terminal: terminal,
                                controller: controller,
                                startOffset: startOffset,
                                endOffset: endOffset,
                                lineHeight: lineHeight,
                                canvasWidth: canvasWidth,
                                canvasHeight: canvasHeight,
                                isDisconnected: isDisconnected,
                              ),
                            ],
                          );
                        },
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

  Widget _buildFloatingSelectionToolbar({
    required BuildContext context,
    required AppThemeExtension theme,
    required Terminal terminal,
    required TerminalController controller,
    required Offset startOffset,
    required Offset endOffset,
    required double lineHeight,
    required double canvasWidth,
    required double canvasHeight,
    required bool isDisconnected,
  }) {
    const toolbarHeight = 38.0;
    const estimatedWidth = 196.0;

    final isSingleLine = (endOffset.dy - startOffset.dy).abs() < lineHeight * 1.5;
    final centerX = isSingleLine ? (startOffset.dx + endOffset.dx) / 2 : startOffset.dx;
    final left = (centerX - (estimatedWidth / 2)).clamp(
      AppSpacing.sm,
      math.max(AppSpacing.sm, canvasWidth - estimatedWidth - AppSpacing.sm),
    ).toDouble();

    final topBoundary = (isDisconnected ? 48.0 : 0.0) + 8.0;
    final preferredTop = startOffset.dy - toolbarHeight - 10.0;
    final top = (preferredTop >= topBoundary
        ? preferredTop
        : (endOffset.dy + lineHeight + 10.0).clamp(
            topBoundary,
            math.max(topBoundary, canvasHeight - toolbarHeight - 8.0),
          )).toDouble();

    return Positioned(
      left: left,
      top: top,
      child: Material(
        color: Colors.transparent,
        child: Container(
          height: toolbarHeight,
          decoration: BoxDecoration(
            color: theme.cardSurface,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: theme.border, width: 1.0),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.4),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.md),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                InkWell(
                  key: const Key('terminal_selection_copy_button'),
                  onTap: () => _copySelection(context, theme, terminal, controller),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.copy_rounded, size: 15, color: theme.primaryAccent),
                        const SizedBox(width: 6),
                        Text(
                          'Copy',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: theme.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Container(
                  width: 1,
                  height: 18,
                  color: theme.border,
                ),
                InkWell(
                  key: const Key('terminal_selection_select_all_button'),
                  onTap: () => _selectAll(terminal, controller),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.select_all_rounded, size: 16, color: theme.textSecondary),
                        const SizedBox(width: 6),
                        Text(
                          'Select All',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: theme.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _copySelection(
    BuildContext context,
    AppThemeExtension theme,
    Terminal terminal,
    TerminalController controller,
  ) {
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
  }

  void _selectAll(Terminal terminal, TerminalController controller) {
    HapticFeedback.selectionClick();
    if (terminal.buffer.lines.length == 0) return;
    final lastLine = terminal.buffer.lines.length - 1;
    final lastCol = terminal.viewWidth;
    controller.setSelection(
      terminal.buffer.createAnchor(0, 0),
      terminal.buffer.createAnchor(lastCol, lastLine),
    );
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
