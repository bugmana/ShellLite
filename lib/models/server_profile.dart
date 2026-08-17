import 'package:uuid/uuid.dart';
import '../config/app_config.dart';
import 'auth_method.dart';

/// Represents a saved SSH server connection profile.
class ServerProfile {
  final String id;
  final String displayName;
  final String host;
  final int port;
  final String username;
  final AuthMethod authMethod;
  final String? initialCommand;

  ServerProfile({
    String? id,
    required this.displayName,
    required this.host,
    this.port = SSHConfig.defaultPort,
    required this.username,
    required this.authMethod,
    this.initialCommand,
  }) : id = id ?? const Uuid().v4();

  ServerProfile copyWith({
    String? id,
    String? displayName,
    String? host,
    int? port,
    String? username,
    AuthMethod? authMethod,
    String? initialCommand,
  }) {
    return ServerProfile(
      id: id ?? this.id,
      displayName: displayName ?? this.displayName,
      host: host ?? this.host,
      port: port ?? this.port,
      username: username ?? this.username,
      authMethod: authMethod ?? this.authMethod,
      initialCommand: initialCommand ?? this.initialCommand,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'displayName': displayName,
        'host': host,
        'port': port,
        'username': username,
        'authMethod': authMethod.toJson(),
        if (initialCommand != null) 'initialCommand': initialCommand,
      };

  factory ServerProfile.fromJson(Map<String, dynamic> json) {
    return ServerProfile(
      id: json['id'] as String,
      displayName: json['displayName'] as String,
      host: json['host'] as String,
      port: (json['port'] as num?)?.toInt() ?? SSHConfig.defaultPort,
      username: json['username'] as String,
      authMethod: AuthMethod.fromJson(json['authMethod'] as Map<String, dynamic>),
      initialCommand: json['initialCommand'] as String?,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ServerProfile &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          displayName == other.displayName &&
          host == other.host &&
          port == other.port &&
          username == other.username &&
          authMethod == other.authMethod &&
          initialCommand == other.initialCommand;

  @override
  int get hashCode =>
      id.hashCode ^
      displayName.hashCode ^
      host.hashCode ^
      port.hashCode ^
      username.hashCode ^
      authMethod.hashCode ^
      (initialCommand?.hashCode ?? 0);

  @override
  String toString() =>
      'ServerProfile(id: $id, name: $displayName, $username@$host:$port, auth: $authMethod)';
}
