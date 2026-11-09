import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../config/app_config.dart';
import '../providers/terminal_settings_store.dart';
import '../theme/app_theme.dart';
import 'accessory_bar/sticky_modifier_key.dart';
import 'accessory_bar/tactile_key_button.dart';
import '../screens/terminal_keys_screen.dart';

// Re-export extracted classes for backward compatibility
export 'accessory_bar/add_custom_key_dialog.dart';
export 'accessory_bar/sticky_modifier_key.dart';
export 'accessory_bar/tactile_key_button.dart';

class KeyboardAccessoryBar extends StatefulWidget {
  final ValueChanged<String> onKeyTap;
  final VoidCallback? onExtendedKeysTap;
  final VoidCallback? onInteraction;
  final VoidCallback? onCloseKeyboard;
  final VoidCallback? onToggleKeyboard;
  final VoidCallback? onPaste;
  final bool isKeyboardVisible;
  final bool isTmuxEnabled;
  final List<TerminalKeyShortcut>? keys;
  final bool showExtendedKeys;

  static const List<TerminalKeyShortcut> defaultKeys =
      AccessoryBarConfig.defaultKeys;

  const KeyboardAccessoryBar({
    super.key,
    required this.onKeyTap,
    this.onExtendedKeysTap,
    this.onInteraction,
    this.onCloseKeyboard,
    this.onToggleKeyboard,
    this.onPaste,
    this.isKeyboardVisible = true,
    this.isTmuxEnabled = false,
    this.keys,
    this.showExtendedKeys = true,
  });

  @override
  State<KeyboardAccessoryBar> createState() => _KeyboardAccessoryBarState();
}

class _KeyboardAccessoryBarState extends State<KeyboardAccessoryBar> {
  ModifierState _ctrlState = ModifierState.inactive;
  ModifierState _altState = ModifierState.inactive;

  void _triggerHaptic() {
    final store = context.maybeRead<TerminalSettingsStore>();
    if (store?.hapticFeedbackEnabled ?? true) {
      HapticFeedback.lightImpact();
    }
  }

  void _toggleCtrl() {
    _triggerHaptic();
    setState(() {
      _ctrlState = _ctrlState == ModifierState.inactive
          ? ModifierState.latched
          : ModifierState.inactive;
    });
  }

  void _lockCtrl() {
    _triggerHaptic();
    setState(() {
      _ctrlState = ModifierState.locked;
    });
  }

  void _toggleAlt() {
    _triggerHaptic();
    setState(() {
      _altState = _altState == ModifierState.inactive
          ? ModifierState.latched
          : ModifierState.inactive;
    });
  }

  void _handleKey(String sequence) {
    String output = sequence;

    // Apply Ctrl modifier if active
    if (_ctrlState != ModifierState.inactive) {
      if (sequence.length == 1) {
        final code = sequence.codeUnitAt(0);
        if (code >= 97 && code <= 122) {
          // lowercase a-z -> 1-26
          output = String.fromCharCode(code - 96);
        } else if (code >= 65 && code <= 90) {
          // uppercase A-Z -> 1-26
          output = String.fromCharCode(code - 64);
        }
      }
      if (_ctrlState == ModifierState.latched) {
        setState(() => _ctrlState = ModifierState.inactive);
      }
    }

    // Apply Alt modifier if active (prefix with ESC \x1B)
    if (_altState != ModifierState.inactive) {
      output = '\x1B$output';
      if (_altState == ModifierState.latched) {
        setState(() => _altState = ModifierState.inactive);
      }
    }

    widget.onInteraction?.call();
    widget.onKeyTap(output);
  }

  void _openExtendedKeysModal(BuildContext context) {
    if (widget.onExtendedKeysTap != null) {
      widget.onExtendedKeysTap!();
      return;
    }
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
          child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text('More keys',
                    style: Theme.of(sheetContext).textTheme.titleLarge),
                const SizedBox(height: AppSpacing.lg),
                if (context
                        .maybeRead<TerminalSettingsStore>()
                        ?.altModifierEnabled ??
                    true)
                  StickyModifierKey(
                      label: 'Alt',
                      state: _altState,
                      theme: context.appTheme,
                      onTap: () {
                        _toggleAlt();
                        Navigator.pop(sheetContext);
                      },
                      onDoubleTap: () {
                        setState(() => _altState = ModifierState.locked);
                        Navigator.pop(sheetContext);
                      }),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  for (final key in [
                    const TerminalKeyShortcut(
                        label: 'Ctrl-C', sequence: '\x03'),
                    const TerminalKeyShortcut(
                        label: 'Ctrl-D', sequence: '\x04'),
                    const TerminalKeyShortcut(
                        label: 'Ctrl-Z', sequence: '\x1a'),
                    const TerminalKeyShortcut(
                        label: 'Ctrl-L', sequence: '\x0c'),
                    const TerminalKeyShortcut(
                        label: 'Shift-Tab', sequence: '\x1b[Z'),
                    const TerminalKeyShortcut(
                        label: 'Home', sequence: '\x1b[H'),
                    const TerminalKeyShortcut(label: 'End', sequence: '\x1b[F'),
                    const TerminalKeyShortcut(
                        label: 'Page up', sequence: '\x1b[5~'),
                    const TerminalKeyShortcut(
                        label: 'Page down', sequence: '\x1b[6~'),
                    const TerminalKeyShortcut(
                        label: 'Delete', sequence: '\x1b[3~'),
                    for (var i = 1; i <= 12; i++)
                      TerminalKeyShortcut(
                          label: 'F$i',
                          sequence: i <= 4
                              ? '\x1bO${String.fromCharCode(79 + i)}'
                              : '\x1b[${[
                                  15,
                                  17,
                                  18,
                                  19,
                                  20,
                                  21,
                                  23,
                                  24
                                ][i - 5]}~'),
                    if (widget.isTmuxEnabled) ...const [
                      TerminalKeyShortcut(
                          label: 'New window', sequence: '\x02c'),
                      TerminalKeyShortcut(
                          label: 'Next window', sequence: '\x02n'),
                      TerminalKeyShortcut(
                          label: 'Previous window', sequence: '\x02p'),
                      TerminalKeyShortcut(label: 'Scroll', sequence: '\x02['),
                      TerminalKeyShortcut(label: 'Detach', sequence: '\x02d'),
                    ],
                  ])
                    OutlinedButton(
                        onPressed: () {
                          _triggerHaptic();
                          _handleKey(key.sequence);
                          Navigator.pop(sheetContext);
                        },
                        child: Text(key.label)),
                ]),
                TextButton(
                    onPressed: () {
                      Navigator.pop(sheetContext);
                      TerminalKeysScreen.open(context);
                    },
                    child: const Text('Customize keys')),
              ]))),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.appTheme;
    final settingsStore = context.maybeWatch<TerminalSettingsStore>();
    final activeKeys = widget.keys ??
        settingsStore?.accessoryKeys ??
        KeyboardAccessoryBar.defaultKeys;
    final textScale = MediaQuery.textScalerOf(context).scale(1.0);
    final dynamicHeight =
        (AccessoryBarConfig.barHeight * textScale.clamp(1.0, 1.35));

    final ctrlEnabled = settingsStore?.ctrlModifierEnabled ?? true;

    return Focus(
      canRequestFocus: false,
      descendantsAreFocusable: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            height: dynamicHeight,
            decoration: BoxDecoration(
              color: theme.surface,
              border: Border(
                top: BorderSide(color: theme.border, width: 1),
              ),
            ),
            child: Row(
              children: [
                // Scrollable keys list (starts with sticky modifiers if enabled)
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm, vertical: 4),
                    scrollDirection: Axis.horizontal,
                    children: [
                      if (_altState != ModifierState.inactive) ...[
                        StickyModifierKey(
                            label: 'Alt',
                            state: _altState,
                            onTap: () => setState(
                                () => _altState = ModifierState.inactive),
                            onDoubleTap: () => setState(
                                () => _altState = ModifierState.locked),
                            theme: theme),
                        const SizedBox(width: AppSpacing.sm),
                      ],
                      // Sticky Ctrl Modifier
                      if (ctrlEnabled) ...[
                        StickyModifierKey(
                          label: 'Ctrl',
                          state: _ctrlState,
                          onTap: _toggleCtrl,
                          onDoubleTap: _lockCtrl,
                          theme: theme,
                        ),
                        const SizedBox(width: 6),
                      ],
                      ...activeKeys.map((k) => Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: _buildKeyButton(context, k, theme),
                          )),
                    ],
                  ),
                ),
                // Pinned right action area (Paste, Extended Keys, Toggle Keyboard)
                if (widget.onPaste != null ||
                    widget.showExtendedKeys ||
                    widget.onToggleKeyboard != null ||
                    widget.onCloseKeyboard != null)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                    decoration: BoxDecoration(
                      border: Border(
                          left: BorderSide(color: theme.border, width: 1)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (widget.onPaste != null) ...[
                          _buildPasteButton(context, theme),
                          if (widget.showExtendedKeys ||
                              widget.onToggleKeyboard != null ||
                              widget.onCloseKeyboard != null)
                            const SizedBox(width: 6),
                        ],
                        if (widget.showExtendedKeys) ...[
                          _buildExtendedKeysButton(context, theme),
                          if (widget.onToggleKeyboard != null ||
                              widget.onCloseKeyboard != null)
                            const SizedBox(width: 6),
                        ],
                        if (widget.onToggleKeyboard != null ||
                            widget.onCloseKeyboard != null) ...[
                          _buildToggleKeyboardButton(context, theme),
                        ],
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKeyButton(
      BuildContext context, TerminalKeyShortcut key, AppThemeExtension theme) {
    final isInterrupt = key.label == '^C';

    return TactileKeyButton(
      theme: theme,
      isInterrupt: isInterrupt,
      onTap: () {
        _triggerHaptic();
        _handleKey(key.sequence);
      },
      child: Text(
        key.label,
        style: TextStyle(
          color: isInterrupt ? theme.error : theme.textPrimary,
          fontSize: 13,
          fontFamily: 'monospace',
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildPasteButton(BuildContext context, AppThemeExtension theme) {
    return Tooltip(
      message: 'Paste',
      child: TactileKeyButton(
        theme: theme,
        constraints: const BoxConstraints(
          minWidth: AppTouchTarget.min,
          minHeight: AppTouchTarget.min,
        ),
        padding: EdgeInsets.zero,
        onTap: () {
          _triggerHaptic();
          widget.onPaste?.call();
        },
        child: Icon(
          Icons.paste_rounded,
          size: 18,
          color: theme.textPrimary,
        ),
      ),
    );
  }

  Widget _buildExtendedKeysButton(
      BuildContext context, AppThemeExtension theme) {
    return Tooltip(
      message: 'More keys',
      child: TactileKeyButton(
        theme: theme,
        constraints: const BoxConstraints(
          minWidth: AppTouchTarget.min,
          minHeight: AppTouchTarget.min,
        ),
        padding: EdgeInsets.zero,
        onTap: () => _openExtendedKeysModal(context),
        child: Icon(
          Icons.more_horiz,
          size: 20,
          color: theme.secondaryAccent,
        ),
      ),
    );
  }

  Widget _buildToggleKeyboardButton(
      BuildContext context, AppThemeExtension theme) {
    final tooltip =
        widget.isKeyboardVisible ? 'Hide keyboard' : 'Show keyboard';
    final icon = widget.isKeyboardVisible
        ? Icons.keyboard_arrow_down_rounded
        : Icons.keyboard_arrow_up_rounded;

    return Tooltip(
      message: tooltip,
      child: TactileKeyButton(
        theme: theme,
        constraints: const BoxConstraints(
          minWidth: AppTouchTarget.min,
          minHeight: AppTouchTarget.min,
        ),
        padding: EdgeInsets.zero,
        onTap: () {
          _triggerHaptic();
          if (widget.onToggleKeyboard != null) {
            widget.onToggleKeyboard!();
          } else {
            widget.onCloseKeyboard?.call();
          }
        },
        child: Icon(
          icon,
          size: 20,
          color: theme.textSecondary,
        ),
      ),
    );
  }
}
