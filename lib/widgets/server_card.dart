import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/auth_method.dart';
import '../models/server_profile.dart';
import '../providers/session_store.dart';
import '../providers/telemetry_store.dart';
import '../theme/app_theme.dart';

class ServerCard extends StatelessWidget {
  final ServerProfile profile;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const ServerCard({
    super.key,
    required this.profile,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.appTheme;
    final isKeyAuth = profile.authMethod is SSHKeyAuth;
    final telemetryStore = context.maybeWatch<TelemetryStore>();
    final sessionStore = context.maybeWatch<SessionStore>();
    final hasActiveSession = sessionStore?.hasActiveSession(profile.id) ?? false;
    final telemetry = telemetryStore?.getTelemetry(profile.id);
    final isLoadingTelemetry = telemetryStore?.isLoading(profile.id) ?? false;

    // Auto-fetch telemetry once when card is rendered if not yet attempted
    if (telemetry == null &&
        !isLoadingTelemetry &&
        telemetryStore != null &&
        !telemetryStore.hasAttempted(profile.id)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        telemetryStore.refresh(profile);
      });
    }

    final semanticLabel = '${profile.displayName}, ${profile.username} at ${profile.host}, port ${profile.port}. '
        '${hasActiveSession ? "Active SSH session running." : "Disconnected."} '
        '${telemetry != null ? "CPU ${telemetry.cpuUsage ?? telemetry.cpuLoad ?? ""}, RAM ${telemetry.memUsage ?? ""}." : ""}';

    return Semantics(
      container: true,
      button: true,
      label: semanticLabel,
      hint: 'Double tap to connect',
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.xs),
        elevation: 0,
        color: theme.cardSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          side: BorderSide(
            color: hasActiveSession
                ? theme.primaryAccent.withValues(alpha: 0.7)
                : theme.border,
            width: hasActiveSession ? 1.5 : 1.0,
          ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.md),
          onTap: () {
            HapticFeedback.selectionClick();
            onTap();
          },
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // TIER 1: Header Block (Icon + Full Titles + 48x48 Kebab Menu)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    _buildIconBox(theme, hasActiveSession),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            profile.displayName,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: theme.textPrimary,
                              letterSpacing: -0.2,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: AppSpacing.xxs),
                          Text(
                            '${profile.username}@${profile.host}:${profile.port}',
                            style: TextStyle(
                              fontSize: 12,
                              fontFamily: 'monospace',
                              color: theme.textSecondary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    _buildKebabMenu(context, theme, telemetryStore),
                  ],
                ),

                // TIER 2: Divider & Telemetry Strip
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                  child: Divider(height: 1, color: theme.border.withValues(alpha: 0.4)),
                ),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.xs,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    _buildBadge(
                      isKeyAuth ? 'Key' : 'Pass',
                      theme,
                      icon: isKeyAuth ? Icons.key_rounded : Icons.lock_outline_rounded,
                    ),
                    if (profile.persistSession)
                      _buildBadge('tmux', theme, isAccent: true, icon: Icons.all_inclusive_rounded),
                    if (isLoadingTelemetry)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 10,
                            height: 10,
                            child: CircularProgressIndicator(strokeWidth: 1.5, color: theme.secondaryAccent),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Updating...',
                            style: TextStyle(fontSize: 11, fontFamily: 'monospace', color: theme.textSecondary),
                          ),
                        ],
                      )
                    else if (telemetry != null) ...[
                      if (telemetry.cpuUsage != null || telemetry.cpuLoad != null)
                        _buildMetricChip(
                          icon: Icons.speed_rounded,
                          label: 'CPU: ${telemetry.cpuUsage ?? telemetry.cpuLoad}',
                          color: theme.warning,
                          theme: theme,
                        ),
                      if (telemetry.memUsage != null)
                        _buildMetricChip(
                          icon: Icons.memory_rounded,
                          label: 'RAM: ${telemetry.memUsage}',
                          color: theme.primaryAccent,
                          theme: theme,
                        ),
                      if (telemetry.diskUsage != null)
                        _buildMetricChip(
                          icon: Icons.storage_rounded,
                          label: 'Disk: ${telemetry.diskUsage}',
                          color: theme.secondaryAccent,
                          theme: theme,
                        ),
                      if (telemetry.uptime != null)
                        Text(
                          telemetry.uptime!,
                          style: TextStyle(fontSize: 10, color: theme.textSecondary),
                        ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildIconBox(AppThemeExtension theme, bool hasActive) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: theme.surface,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(
          color: hasActive ? theme.primaryAccent.withValues(alpha: 0.6) : theme.border,
          width: hasActive ? 1.5 : 1.0,
        ),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Icon(
            Icons.terminal_rounded,
            size: 20,
            color: hasActive ? theme.primaryAccent : theme.textSecondary,
          ),
          if (hasActive)
            Positioned(
              top: 3,
              right: 3,
              child: Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: theme.success,
                  shape: BoxShape.circle,
                  border: Border.all(color: theme.surface, width: 1.5),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildKebabMenu(BuildContext context, AppThemeExtension theme, TelemetryStore? telemetryStore) {
    return SizedBox(
      width: 48,
      height: 48,
      child: PopupMenuButton<String>(
        tooltip: 'Server options',
        icon: Icon(Icons.more_vert_rounded, color: theme.textSecondary, size: 20),
        color: theme.surface,
        shape: RoundedRectangleBorder(
          side: BorderSide(color: theme.border),
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        onSelected: (action) {
          if (action == 'telemetry') {
            telemetryStore?.refresh(profile);
          } else if (action == 'edit') {
            onEdit();
          } else if (action == 'delete') {
            onDelete();
          }
        },
        itemBuilder: (context) => [
          PopupMenuItem(
            value: 'telemetry',
            child: Row(
              children: [
                Icon(Icons.monitor_heart_outlined, size: 18, color: theme.secondaryAccent),
                const SizedBox(width: 10),
                Text('Health Check', style: TextStyle(color: theme.textPrimary)),
              ],
            ),
          ),
          PopupMenuItem(
            value: 'edit',
            child: Row(
              children: [
                Icon(Icons.edit_outlined, size: 18, color: theme.textPrimary),
                const SizedBox(width: 10),
                Text('Edit', style: TextStyle(color: theme.textPrimary)),
              ],
            ),
          ),
          PopupMenuItem(
            value: 'delete',
            child: Row(
              children: [
                Icon(Icons.delete_outline_rounded, size: 18, color: theme.error),
                const SizedBox(width: 10),
                Text('Delete', style: TextStyle(color: theme.error)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBadge(String text, AppThemeExtension theme, {bool isAccent = false, IconData? icon}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
      decoration: BoxDecoration(
        color: isAccent ? theme.primaryAccent.withValues(alpha: 0.15) : theme.surface,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: isAccent ? theme.primaryAccent.withValues(alpha: 0.4) : theme.border,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(
              icon,
              size: 11,
              color: isAccent ? theme.primaryAccent : theme.textSecondary,
            ),
            const SizedBox(width: 3),
          ],
          Text(
            text,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
              fontFamily: 'monospace',
              color: isAccent ? theme.primaryAccent : theme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricChip({
    required IconData icon,
    required String label,
    required Color color,
    required AppThemeExtension theme,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 3),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontFamily: 'monospace',
            color: theme.textPrimary,
          ),
        ),
      ],
    );
  }
}
