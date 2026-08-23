enum AuthType { password, sshKey }

/// Represents how ShellLite authenticates with an SSH server.
sealed class AuthMethod {
  const AuthMethod();

  AuthType get type;
  String get credentialTag;

  Map<String, dynamic> toJson();

  factory AuthMethod.fromJson(Map<String, dynamic> json) {
    final type = json['type'] as String;
    switch (type) {
      case 'password':
        return PasswordAuth(credentialTag: json['credentialTag'] as String);
      case 'sshKey':
        return SSHKeyAuth(
          privateKeyTag: json['privateKeyTag'] as String,
          passphraseTag: json['passphraseTag'] as String?,
        );
      default:
        throw ArgumentError('Unknown auth type: $type');
    }
  }
}

class PasswordAuth extends AuthMethod {
  @override
  final String credentialTag;

  const PasswordAuth({required this.credentialTag});

  @override
  AuthType get type => AuthType.password;

  @override
  Map<String, dynamic> toJson() => {
        'type': 'password',
        'credentialTag': credentialTag,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PasswordAuth &&
          runtimeType == other.runtimeType &&
          credentialTag == other.credentialTag;

  @override
  int get hashCode => credentialTag.hashCode;

  @override
  String toString() => 'PasswordAuth(credentialTag: $credentialTag)';
}

class SSHKeyAuth extends AuthMethod {
  final String privateKeyTag;
  final String? passphraseTag;

  const SSHKeyAuth({
    required this.privateKeyTag,
    this.passphraseTag,
  });

  bool get isPassphraseProtected => passphraseTag != null;

  @override
  AuthType get type => AuthType.sshKey;

  @override
  String get credentialTag => privateKeyTag;

  @override
  Map<String, dynamic> toJson() => {
        'type': 'sshKey',
        'privateKeyTag': privateKeyTag,
        if (passphraseTag != null) 'passphraseTag': passphraseTag,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SSHKeyAuth &&
          runtimeType == other.runtimeType &&
          privateKeyTag == other.privateKeyTag &&
          passphraseTag == other.passphraseTag;

  @override
  int get hashCode => Object.hash(privateKeyTag, passphraseTag);

  @override
  String toString() =>
      'SSHKeyAuth(privateKeyTag: $privateKeyTag, passphraseTag: $passphraseTag)';
}
