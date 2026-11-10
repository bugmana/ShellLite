import 'package:flutter_test/flutter_test.dart';
import 'package:shell_lite/services/ssh_service.dart';

void main() {
  test(
      'tmux startup quotes sanitized names, enables mouse, and has a shell fallback',
      () {
    final command = SSHService.buildTmuxCommand(' my session; rm -rf / ');
    expect(command, contains('-s "my_session__rm_-rf__"'));
    expect(command, contains('tmux set -g mouse on'));
    expect(command, contains('command -v tmux'));
    expect(command, contains('else'));
    expect(SSHService.buildTmuxCommand('   '), contains('-s "shelllite"'));
  });
}
