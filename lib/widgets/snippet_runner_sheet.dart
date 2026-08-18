import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/snippet.dart';
import '../providers/snippet_store.dart';
import '../theme/app_theme.dart';
import '../screens/snippet_manager_screen.dart';

class SnippetRunnerSheet extends StatefulWidget {
  final ValueChanged<String> onExecute;

  const SnippetRunnerSheet({super.key, required this.onExecute});

  static Future<void> show(BuildContext context, ValueChanged<String> onExecute) {
    final theme = context.appTheme;
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: theme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
        side: BorderSide(color: theme.border),
      ),
      builder: (_) => SnippetRunnerSheet(onExecute: onExecute),
    );
  }

  @override
  State<SnippetRunnerSheet> createState() => _SnippetRunnerSheetState();
}

class _SnippetRunnerSheetState extends State<SnippetRunnerSheet> {
  String _selectedCategory = 'All';
  String _searchQuery = '';

  List<String> _extractPlaceholders(String cmd) {
    final regex = RegExp(r'\{\{([^}]+)\}\}');
    return regex.allMatches(cmd).map((m) => m.group(1)!.trim()).toSet().toList();
  }

  Future<void> _handleSnippetTap(Snippet snippet) async {
    final placeholders = _extractPlaceholders(snippet.command);

    if (placeholders.isEmpty) {
      Navigator.of(context).pop();
      widget.onExecute(snippet.command);
      return;
    }

    // Prompt for placeholder parameters
    final controllers = {for (var p in placeholders) p: TextEditingController()};
    final theme = context.appTheme;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: theme.surface,
        shape: RoundedRectangleBorder(
          side: BorderSide(color: theme.border),
          borderRadius: BorderRadius.circular(14),
        ),
        title: Text(
          'Fill Parameters — ${snippet.title}',
          style: TextStyle(fontSize: 16, color: theme.textPrimary),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: placeholders.map((p) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: TextField(
                controller: controllers[p],
                autofocus: p == placeholders.first,
                decoration: InputDecoration(
                  labelText: p,
                  hintText: 'Enter value for $p',
                ),
              ),
            );
          }).toList(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('Cancel', style: TextStyle(color: theme.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Run'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      var finalCommand = snippet.command;
      for (final entry in controllers.entries) {
        final val = entry.value.text.trim();
        finalCommand = finalCommand.replaceAll('{{${entry.key}}}', val);
      }
      Navigator.of(context).pop();
      widget.onExecute(finalCommand);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.appTheme;
    final store = context.watch<SnippetStore>();
    final categories = store.categories;

    final filtered = store.snippets.where((s) {
      final matchesCategory = _selectedCategory == 'All' || s.category == _selectedCategory;
      final matchesQuery = _searchQuery.isEmpty ||
          s.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          s.command.toLowerCase().contains(_searchQuery.toLowerCase());
      return matchesCategory && matchesQuery;
    }).toList();

    return SafeArea(
      child: Container(
        height: MediaQuery.of(context).size.height * 0.65,
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.bolt_rounded, color: theme.primaryAccent, size: 22),
                    const SizedBox(width: 8),
                    Text(
                      'Command Snippets',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: theme.textPrimary,
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.tune_rounded, size: 20),
                      tooltip: 'Manage Snippets',
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const SnippetManagerScreen(),
                          ),
                        );
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 20),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Search bar
            TextField(
              decoration: InputDecoration(
                hintText: 'Search snippets...',
                prefixIcon: const Icon(Icons.search_rounded, size: 18),
                isDense: true,
                filled: true,
                fillColor: theme.cardSurface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: theme.border),
                ),
              ),
              onChanged: (val) => setState(() => _searchQuery = val),
            ),
            const SizedBox(height: 10),

            // Category filter chips
            if (categories.length > 1)
              SizedBox(
                height: 34,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: categories.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, idx) {
                    final cat = categories[idx];
                    final isSelected = cat == _selectedCategory;
                    return ChoiceChip(
                      label: Text(cat, style: TextStyle(fontSize: 12, color: isSelected ? Colors.white : theme.textSecondary)),
                      selected: isSelected,
                      selectedColor: theme.primaryAccent,
                      backgroundColor: theme.cardSurface,
                      side: BorderSide(color: isSelected ? theme.primaryAccent : theme.border),
                      onSelected: (_) => setState(() => _selectedCategory = cat),
                    );
                  },
                ),
              ),
            const SizedBox(height: 12),

            // Snippet list
            Expanded(
              child: filtered.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.code_off_rounded, size: 36, color: theme.textSecondary),
                          const SizedBox(height: 8),
                          Text(
                            _searchQuery.isEmpty
                                ? 'No snippets in this category'
                                : 'No matching snippets found',
                            style: TextStyle(color: theme.textSecondary, fontSize: 13),
                          ),
                        ],
                      ),
                    )
                  : ListView.separated(
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final snippet = filtered[index];
                        final hasVars = _extractPlaceholders(snippet.command).isNotEmpty;

                        return Material(
                          color: theme.cardSurface,
                          borderRadius: BorderRadius.circular(10),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(10),
                            onTap: () => _handleSnippetTap(snippet),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: theme.border, width: 1),
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
                                              style: TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.bold,
                                                color: theme.textPrimary,
                                              ),
                                            ),
                                            if (hasVars) ...[
                                              const SizedBox(width: 6),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                                decoration: BoxDecoration(
                                                  color: theme.secondaryAccent.withValues(alpha: 0.15),
                                                  borderRadius: BorderRadius.circular(4),
                                                ),
                                                child: Text(
                                                  'params',
                                                  style: TextStyle(
                                                    fontSize: 10,
                                                    color: theme.secondaryAccent,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          snippet.command.trimRight(),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontFamily: 'monospace',
                                            fontSize: 11,
                                            color: theme.primaryAccent,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Icon(
                                    Icons.play_circle_fill_rounded,
                                    color: theme.primaryAccent,
                                    size: 22,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
