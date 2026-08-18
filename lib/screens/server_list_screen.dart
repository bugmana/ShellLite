import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/server_profile.dart';
import '../providers/server_store.dart';
import '../providers/telemetry_store.dart';
import '../theme/app_theme.dart';
import '../widgets/server_card.dart';
import '../widgets/terminal_appearance_modal.dart';
import 'server_form_screen.dart';
import 'snippet_manager_screen.dart';
import 'terminal_screen.dart';

class ServerListScreen extends StatefulWidget {
  const ServerListScreen({super.key});

  @override
  State<ServerListScreen> createState() => _ServerListScreenState();
}

class _ServerListScreenState extends State<ServerListScreen> {
  void _openForm({ServerProfile? existingProfile}) {
    final store = context.read<ServerStore>();
    final theme = context.appTheme;
    if (existingProfile == null && !store.canAddServer) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Maximum server limit reached (${store.maxServers} servers). Remove a server to add another.',
          ),
          backgroundColor: theme.surface,
          duration: const Duration(seconds: 3),
        ),
      );
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ServerFormScreen(existingProfile: existingProfile),
      ),
    );
  }

  void _connect(ServerProfile profile) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TerminalScreen(profile: profile),
      ),
    );
  }

  void _confirmDelete(ServerProfile profile) {
    final theme = context.appTheme;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: theme.surface,
        shape: RoundedRectangleBorder(
          side: BorderSide(color: theme.border),
          borderRadius: BorderRadius.circular(12),
        ),
        title: Text('Delete Server', style: TextStyle(color: theme.textPrimary)),
        content: Text(
          'Are you sure you want to delete "${profile.displayName}"?',
          style: TextStyle(color: theme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('Cancel', style: TextStyle(color: theme.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: theme.error),
            onPressed: () {
              context.read<ServerStore>().deleteProfile(profile.id);
              Navigator.of(ctx).pop();
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Future<void> _handleRefresh() async {
    final serverStore = context.read<ServerStore>();
    final telemetryStore = context.read<TelemetryStore?>();
    await serverStore.load();
    if (telemetryStore != null) {
      for (final profile in serverStore.profiles) {
        telemetryStore.refresh(profile);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<ServerStore>();
    final profiles = store.profiles;
    final theme = context.appTheme;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.terminal_rounded, color: theme.primaryAccent, size: 22),
            const SizedBox(width: 8),
            const Text('ShellLite'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.palette_outlined),
            tooltip: 'Appearance & Themes',
            onPressed: () => TerminalAppearanceModal.show(context),
          ),
          IconButton(
            icon: const Icon(Icons.bolt_rounded),
            tooltip: 'Command Snippets',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SnippetManagerScreen()),
            ),
          ),
        ],
      ),
      body: store.isLoading && store.profiles.isEmpty
          ? Center(child: CircularProgressIndicator(color: theme.primaryAccent))
          : profiles.isEmpty
              ? _buildEmptyState(theme)
              : RefreshIndicator(
                  color: theme.primaryAccent,
                  backgroundColor: theme.surface,
                  onRefresh: _handleRefresh,
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: profiles.length + (store.canAddServer ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index < profiles.length) {
                        final profile = profiles[index];
                        return ServerCard(
                          key: ValueKey(profile.id),
                          profile: profile,
                          onTap: () => _connect(profile),
                          onEdit: () => _openForm(existingProfile: profile),
                          onDelete: () => _confirmDelete(profile),
                        );
                      }

                      return Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                        child: Material(
                          color: theme.surface,
                          borderRadius: BorderRadius.circular(12),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () => _openForm(),
                            child: Container(
                              height: 48,
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: theme.border),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.add_rounded, color: theme.primaryAccent, size: 20),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Add Server',
                                    style: TextStyle(
                                      color: theme.textPrimary,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    '(${profiles.length}/${store.maxServers})',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: store.canAddServer ? theme.textSecondary : theme.warning,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }

  Widget _buildEmptyState(AppThemeExtension theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: theme.surface,
                shape: BoxShape.circle,
                border: Border.all(color: theme.border),
              ),
              child: Icon(
                Icons.dns_rounded,
                size: 36,
                color: theme.textSecondary,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'No Servers Configured',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: theme.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Add your first SSH server profile to start connecting.',
              style: TextStyle(
                fontSize: 14,
                color: theme.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => _openForm(),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add First Server'),
            ),
          ],
        ),
      ),
    );
  }
}
