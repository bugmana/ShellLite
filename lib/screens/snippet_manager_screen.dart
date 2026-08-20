import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../models/snippet.dart';
import '../providers/snippet_store.dart';
import '../theme/app_theme.dart';

class SnippetManagerScreen extends StatelessWidget {
  const SnippetManagerScreen({super.key});

  void _openEditor(BuildContext context, [Snippet? existing]) {
    final store = context.read<SnippetStore>();
    final theme = context.appTheme;

    if (existing == null && !store.canAddSnippet) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Maximum snippet limit reached (${store.maxSnippets} snippets). Delete a snippet to add another.',
          ),
          backgroundColor: theme.surface,
          duration: const Duration(seconds: 3),
        ),
      );
      return;
    }

    final titleController = TextEditingController(text: existing?.title ?? '');
    final commandController = TextEditingController(text: existing?.command ?? '');
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: theme.surface,
        shape: RoundedRectangleBorder(
          side: BorderSide(color: theme.border),
          borderRadius: BorderRadius.circular(14),
        ),
        title: Text(
          existing == null ? 'New Snippet' : 'Edit Snippet',
          style: TextStyle(fontSize: 17, color: theme.textPrimary),
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
                Text(
                  '💡 Use {{placeholder}} for dynamic values prompted on run.',
                  style: TextStyle(fontSize: 11, color: theme.textSecondary),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('Cancel', style: TextStyle(color: theme.textSecondary)),
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
                );

                if (existing == null) {
                  if (context.read<SnippetStore>().canAddSnippet) {
                    context.read<SnippetStore>().addSnippet(snippet);
                  }
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
    final theme = context.appTheme;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: theme.surface,
        shape: RoundedRectangleBorder(
          side: BorderSide(color: theme.border),
          borderRadius: BorderRadius.circular(12),
        ),
        title: Text('Delete Snippet', style: TextStyle(color: theme.textPrimary)),
        content: Text(
          'Are you sure you want to delete "${snippet.title}"?',
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
    final theme = context.appTheme;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: theme.surface,
        shape: RoundedRectangleBorder(
          side: BorderSide(color: theme.border),
          borderRadius: BorderRadius.circular(12),
        ),
        title: Text('Restore Default Snippets', style: TextStyle(color: theme.textPrimary)),
        content: Text(
          'Are you sure you want to restore default snippets? This will overwrite your custom snippets.',
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
              store.resetToDefaults();
              Navigator.of(ctx).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('Restored default snippets'),
                  backgroundColor: theme.surface,
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
    final theme = context.appTheme;
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
                  Icon(Icons.code_off_rounded, size: 48, color: theme.textSecondary),
                  const SizedBox(height: 12),
                  Text('No snippets found', style: TextStyle(color: theme.textSecondary, fontSize: 16)),
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
              itemCount: snippets.length + (store.canAddSnippet ? 1 : 0),
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                if (index == snippets.length) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 4, bottom: 16),
                    child: Material(
                      color: theme.surface,
                      borderRadius: BorderRadius.circular(10),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(10),
                        onTap: () => _openEditor(context),
                        child: Container(
                          height: 46,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: theme.border),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.add_rounded, color: theme.primaryAccent, size: 20),
                              const SizedBox(width: 8),
                              Text(
                                'Add Snippet',
                                style: TextStyle(
                                  color: theme.textPrimary,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '(${snippets.length}/${store.maxSnippets})',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: store.canAddSnippet ? theme.textSecondary : theme.warning,
                                  fontWeight: FontWeight.w500,
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
                    color: theme.cardSurface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: theme.border),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              snippet.title,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: theme.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              snippet.command.trimRight(),
                              style: TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 11,
                                color: theme.primaryAccent,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.edit_outlined, size: 18, color: theme.textSecondary),
                        tooltip: 'Edit',
                        onPressed: () => _openEditor(context, snippet),
                      ),
                      IconButton(
                        icon: Icon(Icons.delete_outline_rounded, size: 18, color: theme.error),
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
