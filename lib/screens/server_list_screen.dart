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
    if (existingProfile == null && !store.canAddServer) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Maximum server limit reached (${store.maxServers} servers). Remove a server to add another.',
          ),
          backgroundColor: AppTheme.surface,
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
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(
          side: const BorderSide(color: AppTheme.border),
          borderRadius: BorderRadius.circular(12),
        ),
        title: const Text('Delete Server', style: TextStyle(color: AppTheme.textPrimary)),
        content: Text(
          'Are you sure you want to delete "${profile.displayName}"?',
          style: const TextStyle(color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel', style: TextStyle(color: AppTheme.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.errorRed),
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

    return Scaffold(
      appBar: AppBar(
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.terminal_rounded, color: AppTheme.terminalGreen, size: 22),
            SizedBox(width: 8),
            Text('ShellLite'),
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
          ? const Center(child: CircularProgressIndicator(color: AppTheme.terminalGreen))
          : profiles.isEmpty
              ? _buildEmptyState()
              : RefreshIndicator(
                  color: AppTheme.terminalGreen,
                  backgroundColor: AppTheme.surface,
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
                          color: AppTheme.surface,
                          borderRadius: BorderRadius.circular(12),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () => _openForm(),
                            child: Container(
                              height: 48,
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: AppTheme.border),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.add_rounded, color: AppTheme.terminalGreen, size: 20),
                                  const SizedBox(width: 8),
                                  const Text(
                                    'Add Server',
                                    style: TextStyle(
                                      color: AppTheme.textPrimary,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    '(${profiles.length}/${store.maxServers})',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: store.canAddServer ? AppTheme.textSecondary : AppTheme.warningYellow,
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

  Widget _buildEmptyState() {
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
                color: AppTheme.surface,
                shape: BoxShape.circle,
                border: Border.all(color: AppTheme.border),
              ),
              child: const Icon(
                Icons.dns_rounded,
                size: 36,
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'No Servers Configured',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              'Add your first SSH server profile to start connecting.',
              style: TextStyle(
                fontSize: 14,
                color: AppTheme.textSecondary,
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
