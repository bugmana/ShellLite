import 'package:flutter_test/flutter_test.dart';
import 'package:shell_lite/models/server_telemetry.dart';

void main() {
  test('ServerTelemetry parses standard Linux uptime, free -h, df -h output', () {
    const rawOutput = '''
 19:12:44 up 14 days,  3:22,  2 users,  load average: 0.15, 0.22, 0.18
---MEM---
               total        used        free      shared  buff/cache   available
Mem:           7.7Gi       1.8Gi       4.2Gi       120Mi       1.7Gi       5.6Gi
Swap:          2.0Gi          0B       2.0Gi
---DISK---
Filesystem      Size  Used Avail Use% Mounted on
/dev/nvme0n1p2  234G   45G  178G  21% /
''';

    final telemetry = ServerTelemetry.fromSSHOutput(rawOutput);

    expect(telemetry.cpuLoad, '0.15, 0.22, 0.18');
    expect(telemetry.uptime, '14 days');
    expect(telemetry.memUsage, '1.8Gi / 7.7Gi');
    expect(telemetry.diskUsage, '45G / 234G (21%)');
  });

  test('ServerTelemetry handles empty or malformed output gracefully', () {
    final telemetry = ServerTelemetry.fromSSHOutput('');
    expect(telemetry.cpuLoad, isNull);
    expect(telemetry.memUsage, isNull);
    expect(telemetry.diskUsage, isNull);
  });
}
