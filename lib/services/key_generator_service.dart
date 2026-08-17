import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:pinenacl/ed25519.dart' as ed25519;

class GeneratedSSHKey {
  final String privateKeyPem;
  final String publicKeyOpenSSH;
  final String keyType;
  final String comment;
  final String fingerprint;

  const GeneratedSSHKey({
    required this.privateKeyPem,
    required this.publicKeyOpenSSH,
    required this.keyType,
    required this.comment,
    required this.fingerprint,
  });
}

class SSHKeyGeneratorService {
  /// Generates a new unencrypted OpenSSH Ed25519 key pair.
  static GeneratedSSHKey generateEd25519({String comment = 'shell-lite'}) {
    final signingKey = ed25519.SigningKey.generate();
    final privateKeyBytes = signingKey.asTypedList;
    final publicKeyBytes = signingKey.verifyKey.asTypedList;

    // 1. Compose OpenSSH public key wire blob: [string "ssh-ed25519"][string pubkey_bytes]
    final pubBuf = _OpenSSHBuffer();
    pubBuf.writeUtf8('ssh-ed25519');
    pubBuf.writeString(publicKeyBytes);
    final pubBlob = pubBuf.takeBytes();

    final pubOpenSSH = 'ssh-ed25519 ${base64.encode(pubBlob)} $comment';

    // 2. Compose OpenSSH private key unencrypted blob
    final checkInt = Random.secure().nextInt(0xFFFFFFFF);
    final privBuf = _OpenSSHBuffer();
    privBuf.writeUint32(checkInt);
    privBuf.writeUint32(checkInt);
    privBuf.writeUtf8('ssh-ed25519');
    privBuf.writeString(publicKeyBytes);
    privBuf.writeString(privateKeyBytes);
    privBuf.writeUtf8(comment);

    // OpenSSH padding: 1, 2, 3... to multiple of block size 8
    var pad = 1;
    while (privBuf.length % 8 != 0) {
      privBuf.writeUint8(pad++);
    }
    final privBlob = privBuf.takeBytes();

    // 3. Compose top-level OpenSSH key file container
    final fileBuf = _OpenSSHBuffer();
    fileBuf.writeBytes(Uint8List.fromList('openssh-key-v1\x00'.codeUnits));
    fileBuf.writeUtf8('none'); // cipherName
    fileBuf.writeUtf8('none'); // kdfName
    fileBuf.writeString(Uint8List(0)); // kdfOptions
    fileBuf.writeUint32(1); // num keys
    fileBuf.writeString(pubBlob); // pubkey
    fileBuf.writeString(privBlob); // private key blob

    final privateKeyPem = _formatPem('OPENSSH PRIVATE KEY', fileBuf.takeBytes());

    // Fingerprint calculation (SHA256 of public key wire blob)
    final digest = sha256.convert(pubBlob);
    final fingerprint = 'SHA256:${base64.encode(digest.bytes).replaceAll('=', '')}';

    return GeneratedSSHKey(
      privateKeyPem: privateKeyPem,
      publicKeyOpenSSH: pubOpenSSH,
      keyType: 'ED25519 (256-bit)',
      comment: comment,
      fingerprint: fingerprint,
    );
  }

  static String _formatPem(String label, Uint8List bytes) {
    final b64 = base64.encode(bytes);
    final buffer = StringBuffer();
    buffer.writeln('-----BEGIN $label-----');
    for (int i = 0; i < b64.length; i += 70) {
      final end = (i + 70 < b64.length) ? i + 70 : b64.length;
      buffer.writeln(b64.substring(i, end));
    }
    buffer.write('-----END $label-----');
    return buffer.toString();
  }
}

class _OpenSSHBuffer {
  final BytesBuilder _builder = BytesBuilder();

  int get length => _builder.length;

  void writeUint32(int value) {
    final b = ByteData(4)..setUint32(0, value);
    _builder.add(b.buffer.asUint8List());
  }

  void writeUint8(int value) {
    _builder.addByte(value);
  }

  void writeBytes(List<int> bytes) {
    _builder.add(bytes);
  }

  void writeString(List<int> bytes) {
    writeUint32(bytes.length);
    _builder.add(bytes);
  }

  void writeUtf8(String str) {
    final bytes = utf8.encode(str);
    writeUint32(bytes.length);
    _builder.add(bytes);
  }

  Uint8List takeBytes() => _builder.takeBytes();
}
