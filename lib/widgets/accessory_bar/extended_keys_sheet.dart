import 'package:flutter/material.dart';
import '../../screens/terminal_keys_screen.dart';

/// Legacy compatibility wrapper for Terminal Keys & Shortcuts.
/// All terminal and extended keys are unified under [TerminalKeysScreen] in Settings.
class ExtendedKeysSheet extends StatelessWidget {
  final ValueChanged<String>? onKeyTap;
  final bool autoDismiss;

  const ExtendedKeysSheet({
    super.key,
    this.onKeyTap,
    this.autoDismiss = false,
  });

  @override
  Widget build(BuildContext context) {
    return const TerminalKeysScreen();
  }
}
