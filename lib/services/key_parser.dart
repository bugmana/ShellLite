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
    super.message = 'Passphrase required for encrypted SSH key.',
  ]);
}

class InvalidKeyPassphraseException extends SSHKeyException {
  const InvalidKeyPassphraseException([
    super.message = 'Incorrect passphrase for SSH key.',
  ]);
}

/// Helper service for validating and parsing OpenSSH and PEM private keys.
class SSHKeyParser {
  /// Checks whether a PEM private key is passphrase-protected/encrypted.
  static bool isEncrypted(String pem) {
    final trimmed = pem.trim();
    if (trimmed.contains('ENCRYPTED') || trimmed.contains('Proc-Type: 4,ENCRYPTED')) {
      return true;
    }
    try {
      return SSHKeyPair.isEncryptedPem(trimmed);
    } catch (_) {
      return _checkOpenSSHIsEncrypted(trimmed);
    }
  }

  /// Validates and parses an OpenSSH / PEM private key string.
  /// If the key is encrypted, [passphrase] must be provided to decrypt.
  /// Returns decoded [SSHKeyPair]s for authentication.
  static List<SSHKeyPair> parse(String pem, {String? passphrase}) {
    final trimmed = pem.trim();
    if (!trimmed.startsWith('-----BEGIN') || !trimmed.contains('PRIVATE KEY-----')) {
      throw const InvalidKeyFormatException('Key must be wrapped in PEM headers (e.g. -----BEGIN OPENSSH PRIVATE KEY-----)');
    }

    final encrypted = isEncrypted(trimmed);

    if (encrypted) {
      if (passphrase == null || passphrase.isEmpty) {
        throw const EncryptedKeyException('Passphrase required for encrypted SSH key.');
      }
      try {
        final keyPairs = SSHKeyPair.fromPem(trimmed, passphrase);
        if (keyPairs.isEmpty) {
          throw const InvalidKeyFormatException('No valid SSH keys found in PEM content.');
        }
        return keyPairs;
      } on SSHKeyException {
        rethrow;
      } on SSHKeyDecryptError {
        throw const InvalidKeyPassphraseException('Incorrect passphrase for SSH key.');
      } catch (_) {
        throw const InvalidKeyPassphraseException('Incorrect passphrase for SSH key.');
      }
    } else {
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
  }

  static bool _checkOpenSSHIsEncrypted(String pem) {
    try {
      final lines = pem
          .split('\n')
          .map((l) => l.trim())
          .where((l) => !l.startsWith('-----') && l.isNotEmpty)
          .join();
      final bytes = Uint8List.fromList(base64.decode(lines));
      final buffer = ByteData.sublistView(bytes);

      const magic = 'openssh-key-v1\x00';
      if (bytes.length < magic.length) return false;

      final header = utf8.decode(bytes.sublist(0, magic.length), allowMalformed: true);
      if (header != magic) return false;

      var offset = magic.length;

      // Read cipher name string
      if (offset + 4 > bytes.length) return false;
      final cipherLen = buffer.getUint32(offset);
      offset += 4;
      if (offset + cipherLen > bytes.length) return false;
      final cipher = utf8.decode(bytes.sublist(offset, offset + cipherLen));
      offset += cipherLen;

      if (cipher != 'none') return true;

      // Read kdf name string
      if (offset + 4 > bytes.length) return false;
      final kdfLen = buffer.getUint32(offset);
      offset += 4;
      if (offset + kdfLen > bytes.length) return false;
      final kdf = utf8.decode(bytes.sublist(offset, offset + kdfLen));

      return kdf != 'none';
    } catch (_) {
      return false;
    }
  }
}
