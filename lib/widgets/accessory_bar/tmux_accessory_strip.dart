import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import 'tactile_key_button.dart';

/// Contextual secondary accessory strip for active tmux sessions.
class TmuxAccessoryStrip extends StatelessWidget {
  final ValueChanged<String> onKeyTap;
  final VoidCallback? onTriggerHaptic;
  final AppThemeExtension theme;

  const TmuxAccessoryStrip({
    super.key,
    required this.onKeyTap,
    this.onTriggerHaptic,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 38,
      color: theme.cardSurface,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 3),
      child: Row(
        children: [
          _buildTmuxChip('+Win', '\x02c'),
          const SizedBox(width: 6),
          _buildTmuxChip('→Next', '\x02n'),
          const SizedBox(width: 6),
          _buildTmuxChip('←Prev', '\x02p'),
          const SizedBox(width: 6),
          _buildTmuxChip('📜Scroll', '\x02['),
          const SizedBox(width: 6),
          _buildTmuxChip('⏏Detach', '\x02d'),
        ],
      ),
    );
  }

  Widget _buildTmuxChip(String label, String sequence) {
    return TactileKeyButton(
      theme: theme,
      backgroundColor: theme.surface,
      constraints: const BoxConstraints(minHeight: 28),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      customBorder: Border.all(color: theme.border),
      onTap: () {
        onTriggerHaptic?.call();
        onKeyTap(sequence);
      },
      child: Text(
        label,
        style: TextStyle(
          fontFamily: 'monospace',
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: theme.primaryAccent,
        ),
      ),
    );
  }
}
