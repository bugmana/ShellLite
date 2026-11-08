import 'package:flutter_test/flutter_test.dart';
import 'package:shell_lite/services/terminal_link.dart';

void main() {
  test('preserves authentication queries and fragments', () {
    const url = 'https://example.com:8443/login?code=a%2Bb&state=123#done';
    expect(terminalLink(url).toString(), url);
  });
  test('rejects commands, multiple links and non-web schemes', () {
    for (final text in [
      'echo https://example.com',
      'javascript:alert(1)',
      'https://a.com https://b.com',
      'https://'
    ]) {
      expect(terminalLink(text), isNull);
    }
  });
}
