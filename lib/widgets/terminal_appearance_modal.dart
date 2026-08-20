import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/security_store.dart';
import '../providers/terminal_settings_store.dart';
import '../theme/app_theme.dart';
import '../theme/terminal_theme_presets.dart';
import 'customize_accessory_keys_modal.dart';

class TerminalAppearanceModal extends StatelessWidget {
  const TerminalAppearanceModal({super.key});

  static void show(BuildContext context) {
    final theme = context.appTheme;
    showModalBottomSheet(
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
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Bar
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Terminal Appearance',
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

            // Live Preview Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: settings.activeTheme.background,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: theme.border, width: 1),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(width: 8, height: 8, decoration: const BoxDecoration(color: Color(0xFFFF5F56), shape: BoxShape.circle)),
                      const SizedBox(width: 5),
                      Container(width: 8, height: 8, decoration: const BoxDecoration(color: Color(0xFFFFBD2E), shape: BoxShape.circle)),
                      const SizedBox(width: 5),
                      Container(width: 8, height: 8, decoration: const BoxDecoration(color: Color(0xFF27C93F), shape: BoxShape.circle)),
                      const SizedBox(width: 10),
                      Text(
                        'Preview — ${settings.activeThemePreset.name}',
                        style: TextStyle(
                          color: settings.activeTheme.foreground.withValues(alpha: 0.6),
                          fontSize: 11,
                          fontFamily: settings.fontFamily,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: 'user@shell-lite',
                          style: TextStyle(color: settings.activeTheme.green, fontWeight: FontWeight.bold),
                        ),
                        TextSpan(
                          text: ':~# ',
                          style: TextStyle(color: settings.activeTheme.blue),
                        ),
                        TextSpan(
                          text: 'echo "Ready to connect!"',
                          style: TextStyle(color: settings.activeTheme.foreground),
                        ),
                      ],
                    ),
                    style: TextStyle(
                      fontFamily: settings.fontFamily,
                      fontSize: settings.fontSize,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

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
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.remove_circle_outline_rounded, size: 22),
                  color: theme.textSecondary,
                  onPressed: settings.fontSize > 10
                      ? () => settings.setFontSize(settings.fontSize - 0.5)
                      : null,
                ),
                Expanded(
                  child: SliderTheme(
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
                ),
                IconButton(
                  icon: const Icon(Icons.add_circle_outline_rounded, size: 22),
                  color: theme.textSecondary,
                  onPressed: settings.fontSize < 22
                      ? () => settings.setFontSize(settings.fontSize + 0.5)
                      : null,
                ),
              ],
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
            const SizedBox(height: 10),

            // Customize Accessory Keys Tile
            InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () {
                Navigator.of(context).pop();
                CustomizeAccessoryKeysModal.show(context);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                decoration: BoxDecoration(
                  color: theme.cardSurface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: theme.border),
                ),
                child: Row(
                  children: [
                    Icon(Icons.tune_rounded, color: theme.primaryAccent, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Customize Accessory Keys',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: theme.textPrimary,
                            ),
                          ),
                          Text(
                            'Reorder, add custom macro keys, and toggle shortcuts',
                            style: TextStyle(fontSize: 11, color: theme.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right_rounded, color: theme.textSecondary, size: 20),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),

            // Security & Biometrics
            Consumer<SecurityStore?>(
              builder: (context, secStore, _) {
                if (secStore == null || !secStore.isBiometricsSupported) {
                  return const SizedBox.shrink();
                }
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: theme.cardSurface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: theme.border),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.fingerprint_rounded, color: theme.primaryAccent, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Biometric App Lock',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: theme.textPrimary,
                              ),
                            ),
                            Text(
                              'Require Face ID / Fingerprint on launch',
                              style: TextStyle(fontSize: 11, color: theme.textSecondary),
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: secStore.isBiometricEnabled,
                        activeThumbColor: theme.primaryAccent,
                        onChanged: (val) => secStore.setBiometricsEnabled(val),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
