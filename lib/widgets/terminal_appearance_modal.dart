import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/terminal_settings_store.dart';
import '../theme/app_theme.dart';
import '../theme/terminal_theme_presets.dart';

class TerminalAppearanceModal extends StatelessWidget {
  const TerminalAppearanceModal({super.key});

  static Future<void> show(BuildContext context) {
    final theme = context.appTheme;
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: theme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
        side: BorderSide(color: theme.border, width: 1),
      ),
      builder: (_) => const TerminalAppearanceModal(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.appTheme;
    final settings = context.watch<TerminalSettingsStore>();

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SheetDragHandle(),
            const SizedBox(height: 8),
            // Header Bar
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Terminal Settings',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: theme.textPrimary,
                  ),
                ),
                TextButton(
                  onPressed: () => settings.resetDefaults(),
                  child: Text(
                    'Reset',
                    style: TextStyle(color: theme.textSecondary, fontSize: 13),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Color Themes Section
            Text(
              'COLOR SCHEME',
              style: TextStyle(
                color: theme.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 94,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: TerminalThemePresets.all.length,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (context, index) {
                  final preset = TerminalThemePresets.all[index];
                  final isSelected = preset.id == settings.themeId;

                  return InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () => settings.setTheme(preset.id),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      width: 130,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: preset.previewPalette.first,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isSelected ? preset.palette.primaryAccent : theme.border,
                          width: isSelected ? 2 : 1,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  preset.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: preset.previewPalette.last,
                                    fontSize: 12,
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                  ),
                                ),
                              ),
                              if (isSelected)
                                Icon(
                                  Icons.check_circle_rounded,
                                  color: preset.palette.primaryAccent,
                                  size: 14,
                                ),
                            ],
                          ),
                          Row(
                            children: preset.previewPalette.skip(1).take(4).map((c) {
                              return Container(
                                width: 14,
                                height: 14,
                                margin: const EdgeInsets.only(right: 5),
                                decoration: BoxDecoration(
                                  color: c,
                                  shape: BoxShape.circle,
                                ),
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 20),

            // Font Size Controls
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'FONT SIZE',
                  style: TextStyle(
                    color: theme.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.8,
                  ),
                ),
                Text(
                  '${settings.fontSize.toStringAsFixed(1)} pt',
                  style: TextStyle(
                    color: theme.primaryAccent,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: theme.primaryAccent,
                inactiveTrackColor: theme.border,
                thumbColor: theme.primaryAccent,
                overlayColor: theme.primaryAccent.withValues(alpha: 0.2),
              ),
              child: Slider(
                value: settings.fontSize,
                min: 10.0,
                max: 22.0,
                divisions: 24,
                onChanged: (val) => settings.setFontSize(val),
              ),
            ),
            const SizedBox(height: 16),

            // Keyboard & Haptic Preferences
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: theme.cardSurface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: theme.border),
              ),
              child: Row(
                children: [
                  Icon(Icons.vibration_rounded, color: theme.secondaryAccent, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Haptic Feedback',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: theme.textPrimary,
                          ),
                        ),
                        Text(
                          'Tactile vibration on terminal key press',
                          style: TextStyle(fontSize: 11, color: theme.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: settings.hapticFeedbackEnabled,
                    activeThumbColor: theme.primaryAccent,
                    onChanged: (val) => settings.setHapticFeedbackEnabled(val),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

typedef TerminalSettingsModal = TerminalAppearanceModal;
