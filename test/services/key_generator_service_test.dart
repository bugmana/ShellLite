import 'package:flutter_test/flutter_test.dart';
import 'package:shell_lite/services/key_generator_service.dart';
import 'package:shell_lite/services/key_parser.dart';

void main() {
  test('SSHKeyGeneratorService generates valid parseable Ed25519 key pair', () {
    final generated = SSHKeyGeneratorService.generateEd25519(comment: 'test-key');

    expect(generated.publicKeyOpenSSH, startsWith('ssh-ed25519 '));
    expect(generated.publicKeyOpenSSH, endsWith(' test-key'));
    expect(generated.privateKeyPem, contains('-----BEGIN OPENSSH PRIVATE KEY-----'));
    expect(generated.privateKeyPem, contains('-----END OPENSSH PRIVATE KEY-----'));
    expect(generated.fingerprint, startsWith('SHA256:'));

    // Verify key parser parses it successfully
    final keypairs = SSHKeyParser.parse(generated.privateKeyPem);
    expect(keypairs.length, 1);
    expect(keypairs.first.type, 'ssh-ed25519');
  });
}
