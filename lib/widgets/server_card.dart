import 'package:flutter/material.dart';
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

    return Card(
      elevation: 0,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: hasActiveSession
              ? theme.primaryAccent.withValues(alpha: 0.6)
              : theme.border,
          width: hasActiveSession ? 1.5 : 1,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: theme.surface,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: hasActiveSession
                            ? theme.primaryAccent.withValues(alpha: 0.5)
                            : theme.border,
                        width: hasActiveSession ? 1.5 : 1,
                      ),
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Icon(
                          Icons.terminal_rounded,
                          color: hasActiveSession
                              ? theme.primaryAccent
                              : theme.textSecondary,
                          size: 22,
                        ),
                        if (hasActiveSession)
                          Positioned(
                            top: 4,
                            right: 4,
                            child: Container(
                              width: 7,
                              height: 7,
                              decoration: BoxDecoration(
                                color: theme.success,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
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
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '${profile.username}@${profile.host}:${profile.port}',
                          style: TextStyle(
                            fontSize: 12.5,
                            color: theme.textSecondary,
                            fontFamily: 'monospace',
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3.5),
                    decoration: BoxDecoration(
                      color: theme.surface,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: theme.border),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isKeyAuth ? Icons.key_rounded : Icons.lock_outline_rounded,
                          size: 12,
                          color: theme.textSecondary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          isKeyAuth ? 'Key' : 'Pass',
                          style: TextStyle(
                            fontSize: 11,
                            color: theme.textSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (profile.persistSession) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3.5),
                      decoration: BoxDecoration(
                        color: theme.primaryAccent.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: theme.primaryAccent.withValues(alpha: 0.4),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.all_inclusive_rounded,
                            size: 11,
                            color: theme.primaryAccent,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            'tmux',
                            style: TextStyle(
                              fontSize: 10,
                              color: theme.primaryAccent,
                              fontWeight: FontWeight.w600,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  PopupMenuButton<String>(
                    tooltip: 'Server options',
                    icon: Icon(Icons.more_vert_rounded, color: theme.textSecondary, size: 20),
                    color: theme.surface,
                    shape: RoundedRectangleBorder(
                      side: BorderSide(color: theme.border),
                      borderRadius: BorderRadius.circular(10),
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
                ],
              ),
              if (isLoadingTelemetry) ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    SizedBox(width: 10, height: 10, child: CircularProgressIndicator(strokeWidth: 1.5, color: theme.secondaryAccent)),
                    const SizedBox(width: 8),
                    Text('Updating server metrics...', style: TextStyle(fontSize: 11, color: theme.textSecondary)),
                  ],
                ),
              ] else if (telemetry != null) ...[
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                  decoration: BoxDecoration(
                    color: theme.surface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: theme.border),
                  ),
                  child: Wrap(
                    spacing: 12,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      if (telemetry.cpuUsage != null || telemetry.cpuLoad != null) ...[
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.speed_rounded, size: 13, color: theme.warning),
                            const SizedBox(width: 4),
                            Text(
                              'CPU: ${telemetry.cpuUsage ?? telemetry.cpuLoad}',
                              style: TextStyle(fontSize: 11, fontFamily: 'monospace', color: theme.textPrimary),
                            ),
                          ],
                        ),
                      ],
                      if (telemetry.memUsage != null) ...[
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.memory_rounded, size: 13, color: theme.primaryAccent),
                            const SizedBox(width: 4),
                            Text(
                              'RAM: ${telemetry.memUsage}',
                              style: TextStyle(fontSize: 11, fontFamily: 'monospace', color: theme.textPrimary),
                            ),
                          ],
                        ),
                      ],
                      if (telemetry.diskUsage != null) ...[
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.storage_rounded, size: 13, color: theme.secondaryAccent),
                            const SizedBox(width: 4),
                            Text(
                              'Disk: ${telemetry.diskUsage}',
                              style: TextStyle(fontSize: 11, fontFamily: 'monospace', color: theme.textPrimary),
                            ),
                          ],
                        ),
                      ],
                      if (telemetry.uptime != null) ...[
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.schedule_rounded, size: 12, color: theme.textSecondary),
                            const SizedBox(width: 4),
                            Text(
                              telemetry.uptime!,
                              style: TextStyle(fontSize: 10, color: theme.textSecondary),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
