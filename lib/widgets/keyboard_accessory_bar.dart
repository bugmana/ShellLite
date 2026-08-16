import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class TerminalKey {
  final String label;
  final String sequence;

  const TerminalKey({required this.label, required this.sequence});
}

class KeyboardAccessoryBar extends StatelessWidget {
  final ValueChanged<String> onKeyTap;

  static const List<TerminalKey> defaultKeys = [
    TerminalKey(label: '⇥ Tab', sequence: '\t'),
    TerminalKey(label: '^C', sequence: '\x03'),
    TerminalKey(label: '^D', sequence: '\x04'),
    TerminalKey(label: '↑', sequence: '\x1B[A'),
    TerminalKey(label: '↓', sequence: '\x1B[B'),
    TerminalKey(label: '←', sequence: '\x1B[D'),
    TerminalKey(label: '→', sequence: '\x1B[C'),
    TerminalKey(label: 'Esc', sequence: '\x1B'),
    TerminalKey(label: '|', sequence: '|'),
    TerminalKey(label: '~', sequence: '~'),
    TerminalKey(label: '/', sequence: '/'),
    TerminalKey(label: '-', sequence: '-'),
  ];

  const KeyboardAccessoryBar({
    super.key,
    required this.onKeyTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 46,
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        border: Border(
          top: BorderSide(color: AppTheme.border, width: 1),
        ),
      ),
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        scrollDirection: Axis.horizontal,
        itemCount: defaultKeys.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final key = defaultKeys[index];
          return _buildKeyButton(key);
        },
      ),
    );
  }

  Widget _buildKeyButton(TerminalKey key) {
    return Material(
      color: AppTheme.cardSurface,
      borderRadius: BorderRadius.circular(6),
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: () => onKeyTap(key.sequence),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            border: Border.all(color: AppTheme.border, width: 1),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            key.label,
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 13,
              fontFamily: 'monospace',
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}
