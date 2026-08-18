import 'dart:convert';
import 'dart:typed_data';
import 'package:dartssh2/dartssh2.dart';

/// Exceptions thrown during SSH private key parsing and validation.
sealed class SSHKeyException implements Exception {
  final String message;
  const SSHKeyException(this.message);

  @override
  String toString() => 'SSHKeyException: $message';
}

class InvalidKeyFormatException extends SSHKeyException {
  const InvalidKeyFormatException([super.message = 'Invalid or corrupted SSH private key format.']);
}

class EncryptedKeyException extends SSHKeyException {
  const EncryptedKeyException([
    super.message = 'Passphrase-protected/encrypted SSH keys are not supported. Please use an unencrypted key.',
  ]);
}

/// Helper service for validating and parsing OpenSSH and PEM private keys.
class SSHKeyParser {
  /// Validates and parses an unencrypted OpenSSH / PEM private key string.
  /// Returns decoded [SSHKeyPair]s for authentication.
  static List<SSHKeyPair> parse(String pem) {
    final trimmed = pem.trim();
    if (!trimmed.startsWith('-----BEGIN') || !trimmed.contains('PRIVATE KEY-----')) {
      throw const InvalidKeyFormatException('Key must be wrapped in PEM headers (e.g. -----BEGIN OPENSSH PRIVATE KEY-----)');
    }

    if (trimmed.contains('ENCRYPTED') || trimmed.contains('Proc-Type: 4,ENCRYPTED')) {
      throw const EncryptedKeyException();
    }

    // Check OpenSSH binary header for cipher/kdf encryption
    if (trimmed.contains('BEGIN OPENSSH PRIVATE KEY')) {
      _checkOpenSSHEncryption(trimmed);
    }

    try {
      final keyPairs = SSHKeyPair.fromPem(trimmed);
      if (keyPairs.isEmpty) {
        throw const InvalidKeyFormatException('No valid SSH keys found in PEM content.');
      }
      return keyPairs;
    } on SSHKeyException {
      rethrow;
    } catch (e) {
      throw InvalidKeyFormatException('Failed to parse key: $e');
    }
  }

  static void _checkOpenSSHEncryption(String pem) {
    try {
      final lines = pem
          .split('\n')
          .map((l) => l.trim())
          .where((l) => !l.startsWith('-----') && l.isNotEmpty)
          .join();
      final bytes = Uint8List.fromList(base64.decode(lines));
      final buffer = ByteData.sublistView(bytes);

      const magic = 'openssh-key-v1\x00';
      if (bytes.length < magic.length) {
        throw const InvalidKeyFormatException('Key file too short.');
      }

      final header = utf8.decode(bytes.sublist(0, magic.length), allowMalformed: true);
      if (header != magic) {
        throw const InvalidKeyFormatException('Invalid OpenSSH magic header.');
      }

      var offset = magic.length;

      // Read cipher name string
      if (offset + 4 > bytes.length) throw const InvalidKeyFormatException();
      final cipherLen = buffer.getUint32(offset);
      offset += 4;
      if (offset + cipherLen > bytes.length) throw const InvalidKeyFormatException();
      final cipher = utf8.decode(bytes.sublist(offset, offset + cipherLen));
      offset += cipherLen;

      if (cipher != 'none') {
        throw const EncryptedKeyException();
      }

      // Read kdf name string
      if (offset + 4 > bytes.length) throw const InvalidKeyFormatException();
      final kdfLen = buffer.getUint32(offset);
      offset += 4;
      if (offset + kdfLen > bytes.length) throw const InvalidKeyFormatException();
      final kdf = utf8.decode(bytes.sublist(offset, offset + kdfLen));
      offset += kdfLen;

      if (kdf != 'none') {
        throw const EncryptedKeyException();
      }
    } on SSHKeyException {
      rethrow;
    } catch (_) {
      // If manual wire header check fails, let SSHKeyPair.fromPem do the final parsing
    }
  }
}
