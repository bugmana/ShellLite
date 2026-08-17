import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
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

  T? _tryWatch<T>(BuildContext context) {
    try {
      return Provider.of<T>(context, listen: true);
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isKeyAuth = profile.authMethod is SSHKeyAuth;
    final telemetryStore = _tryWatch<TelemetryStore>(context);
    final sessionStore = _tryWatch<SessionStore>(context);
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
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppTheme.surface,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: hasActiveSession
                            ? AppTheme.terminalGreen.withOpacity(0.5)
                            : AppTheme.border,
                      ),
                    ),
                    child: Icon(
                      Icons.terminal_rounded,
                      color: hasActiveSession
                          ? AppTheme.terminalGreen
                          : AppTheme.textSecondary,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          profile.displayName,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${profile.username}@${profile.host}:${profile.port}',
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppTheme.textSecondary,
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
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.surface,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: AppTheme.border),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isKeyAuth ? Icons.key_rounded : Icons.lock_outline_rounded,
                          size: 13,
                          color: AppTheme.textSecondary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          isKeyAuth ? 'Key' : 'Pass',
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppTheme.textSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  PopupMenuButton<String>(
                    tooltip: '',
                    icon: const Icon(Icons.more_vert_rounded, color: AppTheme.textSecondary, size: 20),
                    color: AppTheme.surface,
                    shape: RoundedRectangleBorder(
                      side: const BorderSide(color: AppTheme.border),
                      borderRadius: BorderRadius.circular(8),
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
                      const PopupMenuItem(
                        value: 'telemetry',
                        child: Row(
                          children: [
                            Icon(Icons.monitor_heart_outlined, size: 18, color: AppTheme.accentBlue),
                            SizedBox(width: 10),
                            Text('Health Check', style: TextStyle(color: AppTheme.textPrimary)),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'edit',
                        child: Row(
                          children: [
                            Icon(Icons.edit_outlined, size: 18, color: AppTheme.textPrimary),
                            SizedBox(width: 10),
                            Text('Edit', style: TextStyle(color: AppTheme.textPrimary)),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete_outline_rounded, size: 18, color: AppTheme.errorRed),
                            SizedBox(width: 10),
                            Text('Delete', style: TextStyle(color: AppTheme.errorRed)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              if (isLoadingTelemetry) ...[
                const SizedBox(height: 12),
                const Row(
                  children: [
                    SizedBox(width: 10, height: 10, child: CircularProgressIndicator(strokeWidth: 1.5, color: AppTheme.accentBlue)),
                    SizedBox(width: 8),
                    Text('Updating server metrics...', style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                  ],
                ),
              ] else if (telemetry != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.border),
                  ),
                  child: Row(
                    children: [
                      if (telemetry.memUsage != null) ...[
                        const Icon(Icons.memory_rounded, size: 13, color: AppTheme.terminalGreen),
                        const SizedBox(width: 4),
                        Text(
                          'RAM: ${telemetry.memUsage}',
                          style: const TextStyle(fontSize: 11, fontFamily: 'monospace', color: AppTheme.textPrimary),
                        ),
                        const SizedBox(width: 12),
                      ],
                      if (telemetry.diskUsage != null) ...[
                        const Icon(Icons.storage_rounded, size: 13, color: AppTheme.accentBlue),
                        const SizedBox(width: 4),
                        Text(
                          'Disk: ${telemetry.diskUsage}',
                          style: const TextStyle(fontSize: 11, fontFamily: 'monospace', color: AppTheme.textPrimary),
                        ),
                      ],
                      if (telemetry.uptime != null) ...[
                        const Spacer(),
                        const Icon(Icons.schedule_rounded, size: 12, color: AppTheme.textSecondary),
                        const SizedBox(width: 4),
                        Text(
                          telemetry.uptime!,
                          style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary),
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
