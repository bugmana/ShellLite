import 'package:flutter/material.dart';
import '../screens/terminal_keys_screen.dart';

/// Compatibility wrapper for [TerminalKeysScreen].
/// Terminal keys and shortcuts are now a full screen page accessible under Settings.
class CustomizeAccessoryKeysModal extends StatelessWidget {
  const CustomizeAccessoryKeysModal({super.key});

  static Future<void> show(BuildContext context) {
    return TerminalKeysScreen.open(context);
  }

  @override
  Widget build(BuildContext context) {
    return const TerminalKeysScreen();
  }
}
