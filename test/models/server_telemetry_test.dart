import 'package:flutter_test/flutter_test.dart';
import 'package:shell_lite/models/server_telemetry.dart';

void main() {
  test('ServerTelemetry parses standard Linux output with top CPU usage', () {
    const rawOutput = '''
 19:12:44 up 14 days,  3:22,  2 users,  load average: 0.15, 0.22, 0.18
---CPU---
%Cpu(s): 14.0 us,  4.7 sy,  0.0 ni, 81.4 id,  0.0 wa,  0.0 hi,  0.0 si,  0.0 st
---MEM---
               total        used        free      shared  buff/cache   available
Mem:           7.7Gi       1.8Gi       4.2Gi       120Mi       1.7Gi       5.6Gi
Swap:          2.0Gi          0B       2.0Gi
---DISK---
Filesystem      Size  Used Avail Use% Mounted on
/dev/nvme0n1p2  234G   45G  178G  21% /
''';

    final telemetry = ServerTelemetry.fromSSHOutput(rawOutput);

    expect(telemetry.cpuUsage, '18.6%');
    expect(telemetry.cpuLoad, '0.15, 0.22, 0.18');
    expect(telemetry.uptime, '14 days');
    expect(telemetry.memUsage, '1.8Gi / 7.7Gi');
    expect(telemetry.diskUsage, '45G / 234G (21%)');
  });

  test('ServerTelemetry parses Linux output with /proc/stat CPU metrics', () {
    const rawOutput = '''
 19:12:44 up 14 days,  3:22,  2 users,  load average: 0.15, 0.22, 0.18
---CPU---
cpu  400000 0 50000 1550000 0 0 0 0 0 0
---MEM---
Mem:           7.7Gi       1.8Gi       4.2Gi
---DISK---
/dev/sda1      100G   25G   75G  25% /
''';

    final telemetry = ServerTelemetry.fromSSHOutput(rawOutput);

    // total: 2,000,000; busy: 450,000 => 22.5%
    expect(telemetry.cpuUsage, '22.5%');
    expect(telemetry.cpuLoad, '0.15, 0.22, 0.18');
  });

  test('ServerTelemetry falls back to load average when no CPU section is present', () {
    const rawOutput = '''
 19:12:44 up 14 days,  3:22,  2 users,  load average: 0.45, 0.22, 0.18
---MEM---
Mem:           7.7Gi       1.8Gi       4.2Gi
---DISK---
/dev/sda1      100G   25G   75G  25% /
''';

    final telemetry = ServerTelemetry.fromSSHOutput(rawOutput);

    expect(telemetry.cpuUsage, '0.45 load');
    expect(telemetry.cpuLoad, '0.45, 0.22, 0.18');
  });

  test('ServerTelemetry handles empty or malformed output gracefully', () {
    final telemetry = ServerTelemetry.fromSSHOutput('');
    expect(telemetry.cpuUsage, isNull);
    expect(telemetry.cpuLoad, isNull);
    expect(telemetry.memUsage, isNull);
    expect(telemetry.diskUsage, isNull);
  });
}
