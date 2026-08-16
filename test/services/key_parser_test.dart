import 'package:flutter_test/flutter_test.dart';
import 'package:shell_lite/services/key_parser.dart';

void main() {
  group('SSHKeyParser', () {
    const testEd25519PEM = '''
-----BEGIN OPENSSH PRIVATE KEY-----
b3BlbnNzaC1rZXktdjEAAAAABG5vbmUAAAAEbm9uZQAAAAAAAAABAAAAMwAAAAtzc2gtZW
QyNTUxOQAAACBPXQGAbXHSgfDJV7lkQyU1/hMOlIPvUH4WuwDtPzudkAAAAIhs52H5bOdh
+QAAAAtzc2gtZWQyNTUxOQAAACBPXQGAbXHSgfDJV7lkQyU1/hMOlIPvUH4WuwDtPzudkA
AAAECorqSPSmXNhJGOv2v5e0tkhVv+2pxMExFBgGbVT1xMEE9dAYBtcdKB8MlXuWRDJTX+
Ew6Ug+9Qfha7AO0/O52QAAAABHRlc3QB
-----END OPENSSH PRIVATE KEY-----
''';

    const testECDSAP256PEM = '''
-----BEGIN OPENSSH PRIVATE KEY-----
b3BlbnNzaC1rZXktdjEAAAAABG5vbmUAAAAEbm9uZQAAAAAAAAABAAAAaAAAABNlY2RzYS
1zaGEyLW5pc3RwMjU2AAAACG5pc3RwMjU2AAAAQQS+fpetpDWB6T5HyZqzW4D7UxOL+dr7
pejwWAfQ4nwIm0XsfcTG1Mxa3HhyQcOenHv2w/ILGlwVki0RyHZpI28IAAAAoKb2/d2m9v
3dAAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBL5+l62kNYHpPkfJ
mrNbgPtTE4v52vul6PBYB9DifAibRex9xMbUzFrceHJBw56ce/bD8gsaXBWSLRHIdmkjbw
gAAAAgQqEPWJ1HsRw5du+HWalcIf9T2vd/zQotfqgw6/ysm9YAAAAEdGVzdAECAwQ=
-----END OPENSSH PRIVATE KEY-----
''';

    const testECDSAP384PEM = '''
-----BEGIN OPENSSH PRIVATE KEY-----
b3BlbnNzaC1rZXktdjEAAAAABG5vbmUAAAAEbm9uZQAAAAAAAAABAAAAiAAAABNlY2RzYS
1zaGEyLW5pc3RwMzg0AAAACG5pc3RwMzg0AAAAYQS2q9lBtjUzLoZnsxDKotVHUDFExG77
GviR+D9+9+1TNDPMAk9QYvM0Fzy+mT4SelIY+f3mPiLDTmCCJV7cvG3SISjpV61NOsyfwg
rhiFoOFNq5A003KcoTa1mssc+BIksAAADQCoXn/AqF5/wAAAATZWNkc2Etc2hhMi1uaXN0
cDM4NAAAAAhuaXN0cDM4NAAAAGEEtqvZQbY1My6GZ7MQyqLVR1AxRMRu+xr4kfg/fvftUz
QzzAJPUGLzNBc8vpk+EnpSGPn95j4iw05ggiVe3Lxt0iEo6VetTTrMn8IK4YhaDhTauQNN
NynKE2tZrLHPgSJLAAAAME1Ch1Lbmlxei0gM6x5VXAlO/oXDZ+JHmR0Sqt4u/W6GdBFUMq
2qbjMtLF2RE+9hnwAAAAR0ZXN0AQIDBA==
-----END OPENSSH PRIVATE KEY-----
''';

    const testECDSAP521PEM = '''
-----BEGIN OPENSSH PRIVATE KEY-----
b3BlbnNzaC1rZXktdjEAAAAABG5vbmUAAAAEbm9uZQAAAAAAAAABAAAArAAAABNlY2RzYS
1zaGEyLW5pc3RwNTIxAAAACG5pc3RwNTIxAAAAhQQA6TJoPBwoHb/NGzgJRdAHyGraUpNh
k+tpaR3QTOqNbm/NurStWg+5LLF2qSnH9TJRPDW734VW3oWahL+cHxgkYD8A2U+Gmk0Hc/
kQTpRu9fIdIOCuM8t1/Yx31erb55dyF35p5UxdG/ZFxXgAiPg5YGiTuaLbDVYbOok41z9H
9L38qcsAAAEIO0GqaztBqmsAAAATZWNkc2Etc2hhMi1uaXN0cDUyMQAAAAhuaXN0cDUyMQ
AAAIUEAOkyaDwcKB2/zRs4CUXQB8hq2lKTYZPraWkd0EzqjW5vzbq0rVoPuSyxdqkpx/Uy
UTw1u9+FVt6FmoS/nB8YJGA/ANlPhppNB3P5EE6UbvXyHSDgrjPLdf2Md9Xq2+eXchd+ae
VMXRv2RcV4AIj4OWBok7mi2w1WGzqJONc/R/S9/KnLAAAAQgH45YZl4Oj+1yQd8zLCBzAY
o2B15B0RxJnIHWGKjewNGM86n43Q5PM7ff0lSSeiOZhJRk7bhz5TExhl+hEKJNDaRwAAAA
R0ZXN0AQIDBAUG
-----END OPENSSH PRIVATE KEY-----
''';

    test('Parses valid Ed25519 private key', () {
      final keys = SSHKeyParser.parse(testEd25519PEM);
      expect(keys, isNotEmpty);
    });

    test('Parses valid ECDSA P-256 private key', () {
      final keys = SSHKeyParser.parse(testECDSAP256PEM);
      expect(keys, isNotEmpty);
    });

    test('Parses valid ECDSA P-384 private key', () {
      final keys = SSHKeyParser.parse(testECDSAP384PEM);
      expect(keys, isNotEmpty);
    });

    test('Parses valid ECDSA P-521 private key', () {
      final keys = SSHKeyParser.parse(testECDSAP521PEM);
      expect(keys, isNotEmpty);
    });

    test('Rejects garbage text with InvalidKeyFormatException', () {
      expect(
        () => SSHKeyParser.parse('not a real key at all'),
        throwsA(isA<InvalidKeyFormatException>()),
      );
    });

    test('Rejects encrypted key with EncryptedKeyException', () {
      const encryptedPem = '''
-----BEGIN RSA PRIVATE KEY-----
Proc-Type: 4,ENCRYPTED
DEK-Info: AES-128-CBC,2D5E06981446DCAC

K9j+D9W3X4/j
-----END RSA PRIVATE KEY-----
''';
      expect(
        () => SSHKeyParser.parse(encryptedPem),
        throwsA(isA<EncryptedKeyException>()),
      );
    });
  });
}
