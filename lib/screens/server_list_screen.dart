import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/server_profile.dart';
import '../providers/server_store.dart';
import '../theme/app_theme.dart';
import '../widgets/server_card.dart';
import 'server_form_screen.dart';
import 'terminal_screen.dart';

class ServerListScreen extends StatefulWidget {
  const ServerListScreen({super.key});

  @override
  State<ServerListScreen> createState() => _ServerListScreenState();
}

class _ServerListScreenState extends State<ServerListScreen> {
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _openForm({ServerProfile? existingProfile}) {
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

  @override
  Widget build(BuildContext context) {
    final store = context.watch<ServerStore>();
    final allProfiles = store.profiles;

    final filteredProfiles = _searchQuery.isEmpty
        ? allProfiles
        : allProfiles.where((p) {
            final query = _searchQuery.toLowerCase();
            return p.displayName.toLowerCase().contains(query) ||
                p.host.toLowerCase().contains(query) ||
                p.username.toLowerCase().contains(query);
          }).toList();

    return Scaffold(
      appBar: AppBar(
        title: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                style: const TextStyle(color: AppTheme.textPrimary, fontSize: 16),
                decoration: const InputDecoration(
                  hintText: 'Search servers...',
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  filled: false,
                  contentPadding: EdgeInsets.zero,
                ),
                onChanged: (val) => setState(() => _searchQuery = val),
              )
            : const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.terminal_rounded, color: AppTheme.terminalGreen, size: 22),
                  SizedBox(width: 8),
                  Text('ShellLite'),
                ],
              ),
        actions: [
          IconButton(
            icon: Icon(_isSearching ? Icons.close_rounded : Icons.search_rounded),
            onPressed: () {
              setState(() {
                if (_isSearching) {
                  _isSearching = false;
                  _searchQuery = '';
                  _searchController.clear();
                } else {
                  _isSearching = true;
                }
              });
            },
          ),
          IconButton(
            icon: const Icon(Icons.add_rounded),
            tooltip: 'Add Server',
            onPressed: () => _openForm(),
          ),
        ],
      ),
      body: store.isLoading && store.profiles.isEmpty
          ? const Center(child: CircularProgressIndicator(color: AppTheme.terminalGreen))
          : filteredProfiles.isEmpty
              ? _buildEmptyState(isSearch: _searchQuery.isNotEmpty)
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: filteredProfiles.length,
                  itemBuilder: (context, index) {
                    final profile = filteredProfiles[index];
                    return ServerCard(
                      key: ValueKey(profile.id),
                      profile: profile,
                      onTap: () => _connect(profile),
                      onEdit: () => _openForm(existingProfile: profile),
                      onDelete: () => _confirmDelete(profile),
                    );
                  },
                ),
      floatingActionButton: filteredProfiles.isEmpty
          ? null
          : FloatingActionButton(
              backgroundColor: AppTheme.accentGreen,
              foregroundColor: Colors.white,
              onPressed: () => _openForm(),
              child: const Icon(Icons.add_rounded),
            ),
    );
  }

  Widget _buildEmptyState({required bool isSearch}) {
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
              child: Icon(
                isSearch ? Icons.search_off_rounded : Icons.dns_rounded,
                size: 36,
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              isSearch ? 'No servers match "$_searchQuery"' : 'No Servers Configured',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              isSearch
                  ? 'Check your search query or clear the filter.'
                  : 'Add your first SSH server profile to start connecting.',
              style: const TextStyle(
                fontSize: 14,
                color: AppTheme.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            if (!isSearch) ...[
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () => _openForm(),
                icon: const Icon(Icons.add_rounded),
                label: const Text('Add First Server'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
