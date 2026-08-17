class ServerTelemetry {
  final String? cpuLoad;
  final String? memUsage;
  final String? diskUsage;
  final String? uptime;
  final DateTime fetchedAt;

  const ServerTelemetry({
    this.cpuLoad,
    this.memUsage,
    this.diskUsage,
    this.uptime,
    required this.fetchedAt,
  });

  factory ServerTelemetry.fromSSHOutput(String output) {
    String? cpu;
    String? mem;
    String? disk;
    String? upt;

    final lines = output.split('\n').map((l) => l.trim()).toList();
    final memMarker = lines.indexOf('---MEM---');
    final diskMarker = lines.indexOf('---DISK---');

    // Parse Uptime & Load
    if (lines.isNotEmpty && lines.first.contains('load average')) {
      final line = lines.first;
      final loadIndex = line.indexOf('load average:');
      if (loadIndex != -1) {
        cpu = line.substring(loadIndex + 'load average:'.length).trim();
      }
      final upIndex = line.indexOf('up ');
      if (upIndex != -1 && loadIndex != -1) {
        upt = line.substring(upIndex + 3, line.indexOf(',', upIndex)).trim();
      }
    }

    // Parse Memory
    if (memMarker != -1 && memMarker + 2 < lines.length) {
      final memLine = lines[memMarker + 2];
      final parts = memLine.split(RegExp(r'\s+'));
      if (parts.length >= 3) {
        // e.g. "Mem: 7.7Gi 1.2Gi ..." -> "1.2Gi / 7.7Gi"
        final total = parts[1];
        final used = parts[2];
        mem = '$used / $total';
      }
    }

    // Parse Disk (df -h /)
    if (diskMarker != -1 && diskMarker + 2 < lines.length) {
      final diskLine = lines[diskMarker + 2];
      final parts = diskLine.split(RegExp(r'\s+'));
      if (parts.length >= 5) {
        // e.g. "/dev/sda1 78G 24G 50G 33% /" -> "24G / 78G (33%)"
        final total = parts[1];
        final used = parts[2];
        final pct = parts[4];
        disk = '$used / $total ($pct)';
      }
    }

    return ServerTelemetry(
      cpuLoad: cpu,
      memUsage: mem,
      diskUsage: disk,
      uptime: upt,
      fetchedAt: DateTime.now(),
    );
  }
}
