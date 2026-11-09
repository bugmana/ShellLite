import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/terminal_settings_store.dart';
import '../screens/privacy_policy_screen.dart';
import '../screens/terminal_keys_screen.dart';
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
    final textScale = MediaQuery.textScalerOf(context).scale(1);

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
                Expanded(
                    child: Text(
                  'Settings',
                  style: Theme.of(context).textTheme.titleLarge,
                )),
                TextButton(
                  onPressed: () => settings.resetDefaults(),
                  child: Text(
                    'Reset settings',
                    style: TextStyle(color: theme.textSecondary, fontSize: 13),
                  ),
                ),
                IconButton(
                  tooltip: 'Close settings',
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Color Themes Section
            Text(
              'Theme',
              style: TextStyle(
                color: theme.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: 10),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount:
                    MediaQuery.sizeOf(context).width / textScale < 360 ? 2 : 3,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                childAspectRatio: (1.4 / textScale).clamp(0.6, 1.4),
              ),
              itemCount: TerminalThemePresets.all.length,
              itemBuilder: (context, index) {
                final preset = TerminalThemePresets.all[index];
                final isSelected = preset.id == settings.themeId;

                return Semantics(
                  selected: isSelected,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () => settings.setTheme(preset.id),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: preset.theme.background,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isSelected
                              ? preset.palette.primaryAccent
                              : theme.border,
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
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: preset.palette.textPrimary,
                                    fontSize: 11,
                                    fontWeight: isSelected
                                        ? FontWeight.bold
                                        : FontWeight.w500,
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
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                margin: const EdgeInsets.only(right: 4),
                                decoration: BoxDecoration(
                                  color: preset.palette.primaryAccent,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              Container(
                                width: 8,
                                height: 8,
                                margin: const EdgeInsets.only(right: 4),
                                decoration: BoxDecoration(
                                  color: preset.palette.secondaryAccent,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: preset.palette.warning,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 16),

            // Monospace CLI Preview Strip
            Builder(
              builder: (context) {
                final activePreset =
                    TerminalThemePresets.getById(settings.themeId);
                return Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: activePreset.theme.background,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: theme.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      RichText(
                        text: TextSpan(
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize:
                                (settings.fontSize * 0.9).clamp(10.0, 14.0),
                          ),
                          children: [
                            TextSpan(
                              text: 'user@server',
                              style: TextStyle(
                                color: activePreset.palette.primaryAccent,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            TextSpan(
                              text: ':~# ',
                              style: TextStyle(
                                  color: activePreset.palette.textSecondary),
                            ),
                            TextSpan(
                              text: 'ls -la /var/log | grep error',
                              style: TextStyle(
                                  color: activePreset.palette.textPrimary),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'nginx/error.log  auth.log  syslog',
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: (settings.fontSize * 0.9).clamp(10.0, 14.0),
                          color: activePreset.palette.textMuted,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 16),

            // Font Size Controls
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Text size',
                  style: TextStyle(
                    color: theme.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.8,
                  ),
                ),
                Row(
                  children: [
                    IconButton(
                      constraints:
                          const BoxConstraints(minWidth: 44, minHeight: 44),
                      icon: const Icon(Icons.remove_circle_outline_rounded,
                          size: 20),
                      color: theme.primaryAccent,
                      tooltip: 'Decrease font size',
                      onPressed: settings.fontSize > 10.0
                          ? () => settings.setFontSize(
                              (settings.fontSize - 0.5).clamp(10.0, 22.0))
                          : null,
                    ),
                    Semantics(
                      liveRegion: true,
                      child: Text(
                        '${settings.fontSize.toStringAsFixed(1)} pt',
                        semanticsLabel:
                            'Text size ${settings.fontSize.toStringAsFixed(1)} points',
                        style: TextStyle(
                          color: theme.primaryAccent,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    IconButton(
                      constraints:
                          const BoxConstraints(minWidth: 44, minHeight: 44),
                      icon: const Icon(Icons.add_circle_outline_rounded,
                          size: 20),
                      color: theme.primaryAccent,
                      tooltip: 'Increase font size',
                      onPressed: settings.fontSize < 22.0
                          ? () => settings.setFontSize(
                              (settings.fontSize + 0.5).clamp(10.0, 22.0))
                          : null,
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Keyboard & Shortcut Keys
            Text(
              'Keyboard',
              style: TextStyle(
                color: theme.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: 10),
            InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () {
                Navigator.of(context).pop();
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const TerminalKeysScreen()),
                );
              },
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: theme.cardSurface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: theme.border),
                ),
                child: Row(
                  children: [
                    Icon(Icons.keyboard_rounded,
                        color: theme.primaryAccent, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Keys',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: theme.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Choose keys and shortcuts',
                            style: TextStyle(
                                fontSize: 11, color: theme.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right_rounded,
                        color: theme.textSecondary, size: 20),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: theme.cardSurface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: theme.border),
              ),
              child: Row(
                children: [
                  Icon(Icons.space_bar_rounded,
                      color: theme.secondaryAccent, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Show key row',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: theme.textPrimary,
                          ),
                        ),
                        Text(
                          'Show shortcuts above the keyboard',
                          style: TextStyle(
                              fontSize: 11, color: theme.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  Semantics(
                    label: "Show key row",
                    child: Switch(
                      value: settings.showKeyboardBar,
                      activeThumbColor: theme.primaryAccent,
                      onChanged: (val) => settings.setShowKeyboardBar(val),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: theme.cardSurface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: theme.border),
              ),
              child: Row(
                children: [
                  Icon(Icons.vibration_rounded,
                      color: theme.secondaryAccent, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Haptics',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: theme.textPrimary,
                          ),
                        ),
                        Text(
                          'Vibrate when pressing terminal keys',
                          style: TextStyle(
                              fontSize: 11, color: theme.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  Semantics(
                    label: "Haptics",
                    child: Switch(
                      value: settings.hapticFeedbackEnabled,
                      activeThumbColor: theme.primaryAccent,
                      onChanged: (val) =>
                          settings.setHapticFeedbackEnabled(val),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // About & Legal
            Text(
              'About',
              style: TextStyle(
                color: theme.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: 10),
            InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () {
                Navigator.of(context).pop();
                Navigator.of(context).push(
                  MaterialPageRoute(
                      builder: (_) => const PrivacyPolicyScreen()),
                );
              },
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: theme.cardSurface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: theme.border),
                ),
                child: Row(
                  children: [
                    Icon(Icons.privacy_tip_outlined,
                        color: theme.primaryAccent, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Privacy',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: theme.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'No analytics or tracking',
                            style: TextStyle(
                                fontSize: 11, color: theme.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right_rounded,
                        color: theme.textSecondary, size: 20),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

typedef TerminalSettingsModal = TerminalAppearanceModal;
typedef SettingsModal = TerminalAppearanceModal;
