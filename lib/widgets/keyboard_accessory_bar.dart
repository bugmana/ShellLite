import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../config/app_config.dart';
import '../providers/terminal_settings_store.dart';
import '../theme/app_theme.dart';
import 'customize_accessory_keys_modal.dart';

enum ModifierState { inactive, latched, locked }

class StickyModifierKey extends StatelessWidget {
  final String label;
  final ModifierState state;
  final VoidCallback onTap;
  final VoidCallback onDoubleTap;
  final AppThemeExtension theme;

  const StickyModifierKey({
    super.key,
    required this.label,
    required this.state,
    required this.onTap,
    required this.onDoubleTap,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    final activeBg = state == ModifierState.locked
        ? theme.primaryAccent
        : theme.primaryAccent.withValues(alpha: 0.22);
    final activeFg = state == ModifierState.locked
        ? AppTheme.computeOnPrimary(theme.primaryAccent)
        : theme.primaryAccent;

    return Semantics(
      toggled: state != ModifierState.inactive,
      label: '$label modifier, ${state.name}',
      hint: 'Tap to latch, double tap to lock',
      child: GestureDetector(
        onTap: onTap,
        onDoubleTap: onDoubleTap,
        child: Container(
          constraints: const BoxConstraints(minWidth: AppTouchTarget.min, minHeight: AppTouchTarget.min),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: state != ModifierState.inactive ? activeBg : theme.cardSurface,
            borderRadius: BorderRadius.circular(AppRadius.sm),
            border: Border.all(
              color: state != ModifierState.inactive ? theme.primaryAccent : theme.border,
              width: state == ModifierState.locked ? 2.0 : 1.0,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: state != ModifierState.inactive ? activeFg : theme.textPrimary,
                ),
              ),
              if (state == ModifierState.locked) ...[
                const SizedBox(width: AppSpacing.xxs),
                Icon(Icons.lock_rounded, size: 10, color: activeFg),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class KeyboardAccessoryBar extends StatefulWidget {
  final ValueChanged<String> onKeyTap;
  final VoidCallback? onExtendedKeysTap;
  final VoidCallback? onInteraction;
  final VoidCallback? onCloseKeyboard;
  final VoidCallback? onToggleKeyboard;
  final bool isKeyboardVisible;
  final bool isTmuxEnabled;
  final List<TerminalKeyShortcut>? keys;

  static const List<TerminalKeyShortcut> defaultKeys = AccessoryBarConfig.defaultKeys;

  const KeyboardAccessoryBar({
    super.key,
    required this.onKeyTap,
    this.onExtendedKeysTap,
    this.onInteraction,
    this.onCloseKeyboard,
    this.onToggleKeyboard,
    this.isKeyboardVisible = true,
    this.isTmuxEnabled = false,
    this.keys,
  });

  @override
  State<KeyboardAccessoryBar> createState() => _KeyboardAccessoryBarState();
}

class _KeyboardAccessoryBarState extends State<KeyboardAccessoryBar> {
  ModifierState _ctrlState = ModifierState.inactive;
  ModifierState _altState = ModifierState.inactive;
  bool _isTmuxExpanded = false;

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

  void _lockAlt() {
    _triggerHaptic();
    setState(() {
      _altState = ModifierState.locked;
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

    widget.onKeyTap(output);
  }

  void _openExtendedKeysModal(BuildContext context) {
    if (widget.onExtendedKeysTap != null) {
      widget.onExtendedKeysTap!();
      return;
    }
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ExtendedKeysSheet(onKeyTap: _handleKey),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.appTheme;
    final settingsStore = context.maybeWatch<TerminalSettingsStore>();
    final activeKeys = widget.keys ?? settingsStore?.accessoryKeys ?? KeyboardAccessoryBar.defaultKeys;
    final textScale = MediaQuery.textScalerOf(context).scale(1.0);
    final dynamicHeight = (AccessoryBarConfig.barHeight * textScale.clamp(1.0, 1.35));

    return Focus(
      canRequestFocus: false,
      descendantsAreFocusable: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Optional Tmux secondary contextual strip
          if (widget.isTmuxEnabled && _isTmuxExpanded)
            Container(
              height: 38,
              color: theme.cardSurface,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 3),
              child: Row(
                children: [
                  _buildTmuxChip('+Win', '\x02c', theme),
                  const SizedBox(width: 6),
                  _buildTmuxChip('→Next', '\x02n', theme),
                  const SizedBox(width: 6),
                  _buildTmuxChip('←Prev', '\x02p', theme),
                  const SizedBox(width: 6),
                  _buildTmuxChip('📜Scroll', '\x02[', theme),
                  const SizedBox(width: 6),
                  _buildTmuxChip('⏏Detach', '\x02d', theme),
                ],
              ),
            ),
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
                // Scrollable keys list (starts with sticky modifiers)
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 4),
                    scrollDirection: Axis.horizontal,
                    children: [
                      // Sticky Ctrl Modifier
                      StickyModifierKey(
                        label: 'Ctrl',
                        state: _ctrlState,
                        onTap: _toggleCtrl,
                        onDoubleTap: _lockCtrl,
                        theme: theme,
                      ),
                      const SizedBox(width: 6),
                      // Sticky Alt Modifier
                      StickyModifierKey(
                        label: 'Alt',
                        state: _altState,
                        onTap: _toggleAlt,
                        onDoubleTap: _lockAlt,
                        theme: theme,
                      ),
                      if (widget.isTmuxEnabled) ...[
                        const SizedBox(width: 6),
                        _buildTmuxTogglePill(theme),
                      ],
                      const SizedBox(width: 6),
                      ...activeKeys.map((k) => Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: _buildKeyButton(context, k, theme),
                          )),
                    ],
                  ),
                ),
                // Pinned right action area (Extended Keys + Toggle Keyboard button)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  decoration: BoxDecoration(
                    border: Border(left: BorderSide(color: theme.border, width: 1)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildExtendedKeysButton(context, theme),
                      if (widget.onToggleKeyboard != null || widget.onCloseKeyboard != null) ...[
                        const SizedBox(width: 6),
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

  Widget _buildTmuxTogglePill(AppThemeExtension theme) {
    return InkWell(
      onTap: () {
        _triggerHaptic();
        setState(() => _isTmuxExpanded = !_isTmuxExpanded);
      },
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: Container(
        constraints: const BoxConstraints(minWidth: AppTouchTarget.min, minHeight: AppTouchTarget.min),
        padding: const EdgeInsets.symmetric(horizontal: 10),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: _isTmuxExpanded ? theme.primaryAccent.withValues(alpha: 0.2) : theme.cardSurface,
          borderRadius: BorderRadius.circular(AppRadius.sm),
          border: Border.all(
            color: _isTmuxExpanded ? theme.primaryAccent : theme.border,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.all_inclusive_rounded, size: 14, color: theme.primaryAccent),
            const SizedBox(width: 4),
            Text(
              'tmux',
              style: TextStyle(
                fontFamily: 'monospace',
                fontWeight: FontWeight.bold,
                fontSize: 12,
                color: theme.primaryAccent,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTmuxChip(String label, String sequence, AppThemeExtension theme) {
    return InkWell(
      onTap: () {
        _triggerHaptic();
        widget.onKeyTap(sequence);
      },
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: theme.surface,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: theme.border),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: 'monospace',
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: theme.primaryAccent,
          ),
        ),
      ),
    );
  }

  Widget _buildKeyButton(BuildContext context, TerminalKeyShortcut key, AppThemeExtension theme) {
    final isInterrupt = key.label == '^C';

    return Material(
      color: theme.cardSurface,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: InkWell(
        canRequestFocus: false,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        onTapDown: (_) {
          _triggerHaptic();
        },
        onTap: () {
          _handleKey(key.sequence);
        },
        child: Container(
          constraints: const BoxConstraints(minWidth: AppTouchTarget.min, minHeight: AppTouchTarget.min),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            border: Border.all(
              color: isInterrupt ? theme.error.withValues(alpha: 0.5) : theme.border,
              width: 1,
            ),
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
          child: Text(
            key.label,
            style: TextStyle(
              color: isInterrupt ? theme.error : theme.textPrimary,
              fontSize: 13,
              fontFamily: 'monospace',
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildExtendedKeysButton(BuildContext context, AppThemeExtension theme) {
    return Tooltip(
      message: 'More keys',
      child: Material(
        color: theme.cardSurface,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        child: InkWell(
          canRequestFocus: false,
          borderRadius: BorderRadius.circular(AppRadius.sm),
          onTap: () => _openExtendedKeysModal(context),
          child: Container(
            width: AppTouchTarget.min,
            height: AppTouchTarget.min,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              border: Border.all(color: theme.border, width: 1),
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Icon(
              Icons.keyboard_double_arrow_up_rounded,
              size: 20,
              color: theme.secondaryAccent,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildToggleKeyboardButton(BuildContext context, AppThemeExtension theme) {
    final tooltip = widget.isKeyboardVisible ? 'Hide keyboard' : 'Show keyboard';
    final icon = widget.isKeyboardVisible
        ? Icons.keyboard_arrow_down_rounded
        : Icons.keyboard_arrow_up_rounded;

    return Tooltip(
      message: tooltip,
      child: Material(
        color: theme.cardSurface,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        child: InkWell(
          canRequestFocus: false,
          borderRadius: BorderRadius.circular(AppRadius.sm),
          onTap: () {
            _triggerHaptic();
            if (widget.onToggleKeyboard != null) {
              widget.onToggleKeyboard!();
            } else {
              widget.onCloseKeyboard?.call();
            }
          },
          child: Container(
            width: AppTouchTarget.min,
            height: AppTouchTarget.min,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              border: Border.all(color: theme.border, width: 1),
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Icon(
              icon,
              size: 20,
              color: theme.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

class ExtendedKeysSheet extends StatelessWidget {
  final ValueChanged<String> onKeyTap;

  const ExtendedKeysSheet({super.key, required this.onKeyTap});

  void _triggerHaptic(BuildContext context) {
    try {
      final store = Provider.of<TerminalSettingsStore>(context, listen: false);
      if (store.hapticFeedbackEnabled) {
        HapticFeedback.lightImpact();
      }
    } catch (_) {
      HapticFeedback.lightImpact();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.appTheme;

    return DefaultTabController(
      length: 3,
      child: Container(
        height: MediaQuery.of(context).size.height * 0.55,
        decoration: BoxDecoration(
          color: theme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
          border: Border.all(color: theme.border),
        ),
        child: SafeArea(
          child: Column(
            children: [
              const SheetDragHandle(),
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 12, 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.keyboard_double_arrow_up_rounded, color: theme.secondaryAccent, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'Extended Keys & Shortcuts',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: theme.textPrimary,
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        IconButton(
                          constraints: const BoxConstraints(minWidth: AppTouchTarget.min, minHeight: AppTouchTarget.min),
                          icon: Icon(Icons.tune_rounded, color: theme.secondaryAccent, size: 20),
                          tooltip: 'Customize Accessory Keys',
                          onPressed: () {
                            Navigator.of(context).pop();
                            CustomizeAccessoryKeysModal.show(context);
                          },
                        ),
                        IconButton(
                          constraints: const BoxConstraints(minWidth: AppTouchTarget.min, minHeight: AppTouchTarget.min),
                          icon: const Icon(Icons.close_rounded, size: 20),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              TabBar(
                labelColor: theme.primaryAccent,
                unselectedLabelColor: theme.textSecondary,
                indicatorColor: theme.primaryAccent,
                tabs: const [
                  Tab(text: 'Control Keys'),
                  Tab(text: 'Navigation'),
                  Tab(text: 'Function (F1-F12)'),
                ],
              ),
              Expanded(
                child: TabBarView(
                  children: [
                    _buildGrid(context, AccessoryBarConfig.controlKeys, theme),
                    _buildGrid(context, AccessoryBarConfig.navigationKeys, theme),
                    _buildGrid(context, AccessoryBarConfig.functionKeys, theme),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGrid(BuildContext context, List<TerminalKeyShortcut> items, AppThemeExtension theme) {
    final textScale = MediaQuery.textScalerOf(context).scale(1.0);
    final childAspectRatio = (2.1 / textScale).clamp(1.1, 2.1);

    return GridView.builder(
      padding: const EdgeInsets.all(14),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: childAspectRatio,
      ),
      itemCount: items.length,
      itemBuilder: (ctx, index) {
        final item = items[index];
        return Material(
          color: theme.cardSurface,
          borderRadius: BorderRadius.circular(8),
          child: InkWell(
            canRequestFocus: false,
            borderRadius: BorderRadius.circular(8),
            onTap: () {
              _triggerHaptic(context);
              Navigator.of(ctx).pop();
              onKeyTap(item.sequence);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                border: Border.all(color: theme.border),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    item.label,
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: theme.textPrimary,
                    ),
                  ),
                  if (item.description != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      item.description!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 10,
                        color: theme.textSecondary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
