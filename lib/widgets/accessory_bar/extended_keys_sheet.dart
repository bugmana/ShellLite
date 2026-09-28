import 'package:flutter/material.dart';
import '../customize_accessory_keys_modal.dart';

/// Legacy compatibility wrapper for Terminal Keys & Shortcuts.
/// All terminal and extended keys are unified under [CustomizeAccessoryKeysModal] in Settings.
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
    return const CustomizeAccessoryKeysModal();
  }
}
