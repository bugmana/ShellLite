import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../models/snippet.dart';
import '../providers/snippet_store.dart';
import '../theme/app_theme.dart';

class SnippetManagerScreen extends StatelessWidget {
  const SnippetManagerScreen({super.key});

  void _openEditor(BuildContext context, [Snippet? existing]) {
    final titleController = TextEditingController(text: existing?.title ?? '');
    final commandController = TextEditingController(text: existing?.command ?? '');
    final categoryController = TextEditingController(text: existing?.category ?? 'General');
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(
          side: const BorderSide(color: AppTheme.border),
          borderRadius: BorderRadius.circular(14),
        ),
        title: Text(
          existing == null ? 'New Snippet' : 'Edit Snippet',
          style: const TextStyle(fontSize: 17, color: AppTheme.textPrimary),
        ),
        content: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: titleController,
                  decoration: const InputDecoration(
                    labelText: 'Title',
                    hintText: 'e.g. Restart Docker Container',
                  ),
                  validator: (v) => v == null || v.trim().isEmpty ? 'Title is required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: categoryController,
                  decoration: const InputDecoration(
                    labelText: 'Category',
                    hintText: 'e.g. Docker, Monitoring, System',
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: commandController,
                  maxLines: 3,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                  decoration: const InputDecoration(
                    labelText: 'Command',
                    hintText: 'docker restart {{container_name}}',
                  ),
                  validator: (v) => v == null || v.trim().isEmpty ? 'Command is required' : null,
                ),
                const SizedBox(height: 8),
                const Text(
                  '💡 Use {{placeholder}} for dynamic values prompted on run.',
                  style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel', style: TextStyle(color: AppTheme.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                var cmd = commandController.text.trim();
                if (!cmd.endsWith('\n')) cmd += '\n';

                final snippet = Snippet(
                  id: existing?.id ?? const Uuid().v4(),
                  title: titleController.text.trim(),
                  command: cmd,
                  category: categoryController.text.trim().isNotEmpty
                      ? categoryController.text.trim()
                      : 'General',
                );

                if (existing == null) {
                  context.read<SnippetStore>().addSnippet(snippet);
                } else {
                  context.read<SnippetStore>().updateSnippet(snippet);
                }
                Navigator.of(ctx).pop();
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, Snippet snippet) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(
          side: const BorderSide(color: AppTheme.border),
          borderRadius: BorderRadius.circular(12),
        ),
        title: const Text('Delete Snippet', style: TextStyle(color: AppTheme.textPrimary)),
        content: Text(
          'Are you sure you want to delete "${snippet.title}"?',
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
              context.read<SnippetStore>().deleteSnippet(snippet.id);
              Navigator.of(ctx).pop();
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _confirmReset(BuildContext context, SnippetStore store) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(
          side: const BorderSide(color: AppTheme.border),
          borderRadius: BorderRadius.circular(12),
        ),
        title: const Text('Restore Default Snippets', style: TextStyle(color: AppTheme.textPrimary)),
        content: const Text(
          'Are you sure you want to restore default snippets? This will overwrite your custom snippets.',
          style: TextStyle(color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel', style: TextStyle(color: AppTheme.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.errorRed),
            onPressed: () {
              store.resetToDefaults();
              Navigator.of(ctx).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Restored default snippets'),
                  backgroundColor: AppTheme.surface,
                ),
              );
            },
            child: const Text('Restore'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<SnippetStore>();
    final snippets = store.snippets;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Snippets'),
        actions: [
          IconButton(
            icon: const Icon(Icons.restore_rounded),
            tooltip: 'Restore Default Snippets',
            onPressed: () => _confirmReset(context, store),
          ),
        ],
      ),
      body: snippets.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.code_off_rounded, size: 48, color: AppTheme.textSecondary),
                  const SizedBox(height: 12),
                  const Text('No snippets found', style: TextStyle(color: AppTheme.textSecondary, fontSize: 16)),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Add Snippet'),
                    onPressed: () => _openEditor(context),
                  ),
                ],
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              itemCount: snippets.length + 1,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                if (index == snippets.length) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 4, bottom: 16),
                    child: Material(
                      color: AppTheme.surface,
                      borderRadius: BorderRadius.circular(10),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(10),
                        onTap: () => _openEditor(context),
                        child: Container(
                          height: 46,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppTheme.border),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.add_rounded, color: AppTheme.terminalGreen, size: 20),
                              SizedBox(width: 8),
                              Text(
                                'Add Snippet',
                                style: TextStyle(
                                  color: AppTheme.textPrimary,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }

                final snippet = snippets[index];
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppTheme.cardSurface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppTheme.border),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  snippet.title,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.textPrimary,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppTheme.surface,
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(color: AppTheme.border),
                                  ),
                                  child: Text(
                                    snippet.category,
                                    style: const TextStyle(
                                      fontSize: 10,
                                      color: AppTheme.textSecondary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              snippet.command.trimRight(),
                              style: const TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 11,
                                color: AppTheme.terminalGreen,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.edit_outlined, size: 18, color: AppTheme.textSecondary),
                        tooltip: 'Edit',
                        onPressed: () => _openEditor(context, snippet),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline_rounded, size: 18, color: AppTheme.errorRed),
                        tooltip: 'Delete',
                        onPressed: () => _confirmDelete(context, snippet),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}
