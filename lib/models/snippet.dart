import 'package:uuid/uuid.dart';

class Snippet {
  final String id;
  final String title;
  final String command;

  const Snippet({
    required this.id,
    required this.title,
    required this.command,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'command': command,
      };

  factory Snippet.fromJson(Map<String, dynamic> json) => Snippet(
        id: json['id'] as String? ?? const Uuid().v4(),
        title: json['title'] as String? ?? '',
        command: json['command'] as String? ?? '',
      );

  Snippet copyWith({
    String? title,
    String? command,
  }) =>
      Snippet(
        id: id,
        title: title ?? this.title,
        command: command ?? this.command,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Snippet &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          title == other.title &&
          command == other.command;

  @override
  int get hashCode => Object.hash(id, title, command);
}

class DefaultSnippets {
  static List<Snippet> get defaults => [
        const Snippet(
          id: 'snip_exit_vim',
          title: 'Exit Vim (Force Quit)',
          command: '\x1B:q!\n',
        ),
        const Snippet(
          id: 'snip_save_exit_vim',
          title: 'Save & Exit Vim',
          command: '\x1B:wq\n',
        ),
        const Snippet(
          id: 'snip_htop',
          title: 'System Monitor (htop)',
          command: 'htop\n',
        ),
        const Snippet(
          id: 'snip_df',
          title: 'Disk Space (df -h)',
          command: 'df -h\n',
        ),
        const Snippet(
          id: 'snip_free',
          title: 'Memory Usage (free -h)',
          command: 'free -h\n',
        ),
        const Snippet(
          id: 'snip_journalctl',
          title: 'Follow Service Log',
          command: 'journalctl -fu {{service}}\n',
        ),
        const Snippet(
          id: 'snip_ss',
          title: 'Listening Ports & Sockets',
          command: 'ss -tulpn\n',
        ),
        const Snippet(
          id: 'snip_tmux_attach',
          title: 'Reattach Tmux Session',
          command: 'tmux attach || tmux new\n',
        ),
        const Snippet(
          id: 'snip_docker_ps',
          title: 'Docker Container Status',
          command: 'docker ps -a\n',
        ),
        const Snippet(
          id: 'snip_fuser_kill',
          title: 'Kill Process on Port',
          command: 'fuser -k {{port}}/tcp\n',
        ),
      ];
}
