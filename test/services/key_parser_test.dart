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

    const testEncryptedEd25519PEM = '''
-----BEGIN OPENSSH PRIVATE KEY-----
b3BlbnNzaC1rZXktdjEAAAAACmFlczI1Ni1jdHIAAAAGYmNyeXB0AAAAGAAAABC0l9Iobg
dIkpFRXIVcSMo9AAAAEAAAAAEAAAAzAAAAC3NzaC1lZDI1NTE5AAAAIDl6gJA/mTwGajQU
GysVNxbg5DLxNkxNMr1N6nMqmILLAAAAoAheLDCmikMrd30h6Z3ug4h7WsK8TjBYToUkhO
1fu5qRd6pgCCeQt0C5eeJMkCSNTP+HZyWT9Vc67VCvzaECjFfXYJUsRYdknAXEO4oFc9fg
v8qGMQTFoIajXQk8Gk9QLqGQ0nupn4fZ3BhHhMoDIx7DWLhlvHddSJzgkORIt4bV8ntzh8
AK9jJFzpo0q4FnYkalW4fo/nosGUM/bq5LR2M=
-----END OPENSSH PRIVATE KEY-----
''';
    const testEncryptedEd25519Passphrase = '123456';

    const testEncryptedRsaPEM = '''
-----BEGIN RSA PRIVATE KEY-----
Proc-Type: 4,ENCRYPTED
DEK-Info: AES-128-CBC,FB1AD0F158BF11B3E14A5331C6D14A6D

ZhN5hG0+sEFsrPRD1bZnFIMmHgKvpfWD/OObv3lcPLygQXOETNIRMiiizH8GdAX8
lc6nEZuBMw14A6Ef6Hm2HyTxd9eR6JS4vG9EBTOH4lyTLboO0EqUS3KfOw1RVLs4
aNG7My+KQbIMUevL2ZZwZNojQIgRg8Nu3zTEY/O1zn/ugdJPPvwZmHmbKgqvAcsP
rjvtcPn8CwXNoAsWxk+vhpNE6ths/MjFRdYnUDPKfvONepu9DpP8II+B2JQBP44u
VyESk9JyoAHp2nHfgjCEpc7Bv5D1fgQlI8mrVj2gtw2fr+hlNpezH/YutEdi/syK
Lzd2xyMUsKDtCqSIjT7hILMGoKEeIOv/y2qcJYILLfDGHmrFEyOwLNE2ISu9K4Qk
koZky7keqhnM4piszKjtWoSwTJwLEF/XiwfbJTxDdxFSWDCb4dOIkql4w6gs59Cg
4NucKenMVzjKensvIq5PaDXUZV88zP/m8i4Vn2dmV1J9WdHETawL5x6ny7uAKZCS
JDp7GyPSQU/lvjS78fkVq3wHZA0eSE+oRWt3bcIjrX5ZjHskGUXDjxSuSPXlKiXn
HaQNJ5xdGp6noH30RILTfur2UjgWGXFw+6AYkzcahGMab35pk1+D4uUETyBI0KtX
atKO7/540RAi8ewQ1oo0oTWQRdqaO0KAgzqde1sY+wvA+o5Gd2tvjgfAARSL3sT6
rgHVNY3LKOJb8ulh5VPdV61bNblzHsNU8qMTlxHotFUZw1vZ7ScVNn0xsMSWGKq2
F2sROVgGMhmKPlG5SfewlHLop9W9DyMQPhmvNKM3KFB3aYoulBbYMpAk2imBph+6
Odan7KqxIVoAnironvZEkGdez6Uh6LGDXSh8DQDJcfcqPWgc9XCq2lBkzsFDjRoy
Xrn2htsv0BsaIzyxSH15H60Aawwe7hnhnO1wFJCbV7cL6l6dczZyH4xszHZp53Jq
HLJ7LXjpChw5ZgbG6ISujVIBo+gvpq8LV1MmpX3/B1BEkoYGfXlNQ9R03vz8LFnb
BufSv1lw51KfnaUwms1ma9dhwMePMoiG7CGU7v2rBFzP6jbFyzA/C/Tq66aFbUtx
6ozuVxPhJ7Of2XC0a2L2YXIRI/pvCCzIzOGFlPnLaTJC/+toZPAlET6aicIHpsPO
ihA8RdTLsO/HNLX6q61z5Z22/HaxAMtcGLez5jkAKqSQGlIy+phHSm3uDY7yWX99
OPkPFCbQCgcjXR8iZmOCNf1ThIV/rfLPmuOiBUsj40DOnqdz/w9J21bRC4h9CEDA
dDCRnWEvMJgJzjAMQHti//OW0Elh28p9gbGgsmLQeSAiGiMiseO3SNdY0Y/KKqPu
RETahfSCImfu+upykJAqWUABxUFWuDWEj4H2oU95cV0fpsleFatYrqAycb6dRGGV
w0vDDTBLhD/NVuIaqhzh3D8z25vM5ArbTUOXL07DnRFMtjgJwl/ZVlAMvPUnXocO
yQNiFax2/YOxWZ7KfgDT2Zkh4vipZAaOGkksVEfY6U49M6twUxvbQsq5gp26W819
3P4yyIQE669imnHlnvLgIIR8zMdlE0XJfW+AxNcGBRqoRUnJ6wNTpL1JO059ZIhM
-----END RSA PRIVATE KEY-----
''';
    const testEncryptedRsaPassphrase = 'CustedNG';

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

    test('SSHKeyParser.isEncrypted correctly detects unencrypted vs encrypted keys', () {
      expect(SSHKeyParser.isEncrypted(testEd25519PEM), isFalse);
      expect(SSHKeyParser.isEncrypted(testECDSAP256PEM), isFalse);
      expect(SSHKeyParser.isEncrypted(testEncryptedEd25519PEM), isTrue);
      expect(SSHKeyParser.isEncrypted(testEncryptedRsaPEM), isTrue);
    });

    test('Rejects garbage text with InvalidKeyFormatException', () {
      expect(
        () => SSHKeyParser.parse('not a real key at all'),
        throwsA(isA<InvalidKeyFormatException>()),
      );
    });

    test('Encrypted key without passphrase throws EncryptedKeyException', () {
      expect(
        () => SSHKeyParser.parse(testEncryptedEd25519PEM),
        throwsA(isA<EncryptedKeyException>()),
      );
      expect(
        () => SSHKeyParser.parse(testEncryptedRsaPEM),
        throwsA(isA<EncryptedKeyException>()),
      );
    });

    test('Encrypted key with wrong passphrase throws InvalidKeyPassphraseException', () {
      expect(
        () => SSHKeyParser.parse(testEncryptedEd25519PEM, passphrase: 'incorrect_passphrase'),
        throwsA(isA<InvalidKeyPassphraseException>()),
      );
      expect(
        () => SSHKeyParser.parse(testEncryptedRsaPEM, passphrase: 'wrong_password'),
        throwsA(isA<InvalidKeyPassphraseException>()),
      );
    });

    test('Encrypted OpenSSH Ed25519 key parses successfully with correct passphrase', () {
      final keys = SSHKeyParser.parse(
        testEncryptedEd25519PEM,
        passphrase: testEncryptedEd25519Passphrase,
      );
      expect(keys, isNotEmpty);
    });

    test('Encrypted RSA key parses successfully with correct passphrase', () {
      final keys = SSHKeyParser.parse(
        testEncryptedRsaPEM,
        passphrase: testEncryptedRsaPassphrase,
      );
      expect(keys, isNotEmpty);
    });
  });
}
