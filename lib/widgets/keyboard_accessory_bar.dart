import 'package:flutter/material.dart';
import '../config/app_config.dart';
import '../theme/app_theme.dart';

class KeyboardAccessoryBar extends StatelessWidget {
  final ValueChanged<String> onKeyTap;
  final VoidCallback? onSnippetTap;
  final List<TerminalKeyShortcut> keys;

  static const List<TerminalKeyShortcut> defaultKeys = AccessoryBarConfig.defaultKeys;

  const KeyboardAccessoryBar({
    super.key,
    required this.onKeyTap,
    this.onSnippetTap,
    this.keys = defaultKeys,
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.appTheme;

    return Container(
      height: AccessoryBarConfig.barHeight,
      decoration: BoxDecoration(
        color: theme.surface,
        border: Border(
          top: BorderSide(color: theme.border, width: 1),
        ),
      ),
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        scrollDirection: Axis.horizontal,
        children: [
          if (onSnippetTap != null) ...[
            Material(
              color: theme.primaryAccent.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(6),
              child: InkWell(
                borderRadius: BorderRadius.circular(6),
                onTap: onSnippetTap,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    border: Border.all(color: theme.primaryAccent.withValues(alpha: 0.6), width: 1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.bolt_rounded, size: 15, color: theme.primaryAccent),
                      const SizedBox(width: 4),
                      Text(
                        'Snippets',
                        style: TextStyle(
                          color: theme.primaryAccent,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],
          ...keys.map((key) => Padding(
                padding: const EdgeInsets.only(right: 8),
                child: _buildKeyButton(key, theme),
              )),
        ],
      ),
    );
  }

  Widget _buildKeyButton(TerminalKeyShortcut key, AppThemeExtension theme) {
    return Material(
      color: theme.cardSurface,
      borderRadius: BorderRadius.circular(6),
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: () => onKeyTap(key.sequence),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            border: Border.all(color: theme.border, width: 1),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            key.label,
            style: TextStyle(
              color: theme.textPrimary,
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
