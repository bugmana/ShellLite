import 'package:flutter/material.dart';
import '../models/server_profile.dart';
import '../providers/session_store.dart';
import '../theme/app_theme.dart';

class ServerCard extends StatelessWidget {
  final ServerProfile profile;
  final VoidCallback onTap, onEdit, onDelete;
  const ServerCard(
      {super.key,
      required this.profile,
      required this.onTap,
      required this.onEdit,
      required this.onDelete});
  @override
  Widget build(BuildContext context) {
    final connected =
        context.maybeWatch<SessionStore>()?.isSessionConnected(profile.id) ??
            false;
    return Card(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: ListTile(
          leading: Icon(Icons.terminal,
              color: connected
                  ? context.appTheme.success
                  : context.appTheme.textSecondary),
          title: Text(profile.displayName,
              maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
                '${profile.username}@${profile.host}${profile.port == 22 ? '' : ':${profile.port}'}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
            Text(connected ? 'Connected' : 'Disconnected'),
          ]),
          onTap: onTap,
          trailing: PopupMenuButton<String>(
              tooltip: 'Server options',
              onSelected: (value) => value == 'edit' ? onEdit() : onDelete(),
              itemBuilder: (_) => const [
                    PopupMenuItem(value: 'edit', child: Text('Edit')),
                    PopupMenuItem(value: 'delete', child: Text('Delete')),
                  ]),
        ));
  }
}
