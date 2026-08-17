import 'package:uuid/uuid.dart';

class Snippet {
  final String id;
  final String title;
  final String command;
  final String category;

  const Snippet({
    required this.id,
    required this.title,
    required this.command,
    this.category = 'General',
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'command': command,
        'category': category,
      };

  factory Snippet.fromJson(Map<String, dynamic> json) => Snippet(
        id: json['id'] as String? ?? const Uuid().v4(),
        title: json['title'] as String? ?? '',
        command: json['command'] as String? ?? '',
        category: json['category'] as String? ?? 'General',
      );

  Snippet copyWith({
    String? title,
    String? command,
    String? category,
  }) =>
      Snippet(
        id: id,
        title: title ?? this.title,
        command: command ?? this.command,
        category: category ?? this.category,
      );
}

class DefaultSnippets {
  static List<Snippet> get defaults => [
        const Snippet(
          id: 'snip_uptime',
          title: 'System Uptime & Load',
          command: 'uptime\n',
          category: 'Monitoring',
        ),
        const Snippet(
          id: 'snip_htop',
          title: 'Launch HTop',
          command: 'htop\n',
          category: 'Monitoring',
        ),
        const Snippet(
          id: 'snip_free',
          title: 'Memory Usage (Human-readable)',
          command: 'free -h\n',
          category: 'Monitoring',
        ),
        const Snippet(
          id: 'snip_df',
          title: 'Disk Space (Human-readable)',
          command: 'df -h\n',
          category: 'System',
        ),
        const Snippet(
          id: 'snip_docker_ps',
          title: 'Docker Running Containers',
          command: 'docker ps\n',
          category: 'Docker',
        ),
        const Snippet(
          id: 'snip_docker_logs',
          title: 'Follow Docker Logs',
          command: 'docker logs -f --tail 100 {{container_name}}\n',
          category: 'Docker',
        ),
        const Snippet(
          id: 'snip_systemctl_status',
          title: 'Systemctl Service Status',
          command: 'systemctl status {{service_name}}\n',
          category: 'System',
        ),
        const Snippet(
          id: 'snip_tail_syslog',
          title: 'Follow Syslog',
          command: 'tail -f /var/log/syslog\n',
          category: 'Logs',
        ),
      ];
}
