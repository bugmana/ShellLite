import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/security_store.dart';
import '../providers/terminal_settings_store.dart';
import '../theme/app_theme.dart';
import '../theme/terminal_theme_presets.dart';

class TerminalAppearanceModal extends StatelessWidget {
  const TerminalAppearanceModal({super.key});

  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
        side: BorderSide(color: AppTheme.border, width: 1),
      ),
      builder: (_) => const TerminalAppearanceModal(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<TerminalSettingsStore>();

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Bar
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Terminal Appearance',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                ),
                TextButton(
                  onPressed: () => settings.resetDefaults(),
                  child: const Text(
                    'Reset',
                    style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
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
                border: Border.all(color: AppTheme.border, width: 1),
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
                          color: settings.activeTheme.foreground.withOpacity(0.6),
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
            const Text(
              'COLOR SCHEME',
              style: TextStyle(
                color: AppTheme.textSecondary,
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
                          color: isSelected ? AppTheme.terminalGreen : AppTheme.border,
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
                                const Icon(
                                  Icons.check_circle_rounded,
                                  color: AppTheme.terminalGreen,
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
                const Text(
                  'FONT SIZE',
                  style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.8,
                  ),
                ),
                Text(
                  '${settings.fontSize.toStringAsFixed(1)} pt',
                  style: const TextStyle(
                    color: AppTheme.terminalGreen,
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
                  color: AppTheme.textSecondary,
                  onPressed: settings.fontSize > 10
                      ? () => settings.setFontSize(settings.fontSize - 0.5)
                      : null,
                ),
                Expanded(
                  child: SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      activeTrackColor: AppTheme.terminalGreen,
                      inactiveTrackColor: AppTheme.border,
                      thumbColor: AppTheme.terminalGreen,
                      overlayColor: AppTheme.terminalGreen.withOpacity(0.2),
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
                  color: AppTheme.textSecondary,
                  onPressed: settings.fontSize < 22
                      ? () => settings.setFontSize(settings.fontSize + 0.5)
                      : null,
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Security & Biometrics
            Consumer<SecurityStore?>(
              builder: (context, secStore, _) {
                if (secStore == null || !secStore.isBiometricsSupported) {
                  return const SizedBox.shrink();
                }
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppTheme.cardSurface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppTheme.border),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.fingerprint_rounded, color: AppTheme.terminalGreen, size: 20),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Biometric App Lock',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                            Text(
                              'Require Face ID / Fingerprint on launch',
                              style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: secStore.isBiometricEnabled,
                        activeColor: AppTheme.terminalGreen,
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
