class ServerTelemetry {
  final String? cpuUsage;
  final String? cpuLoad;
  final String? memUsage;
  final String? diskUsage;
  final String? uptime;
  final DateTime fetchedAt;

  const ServerTelemetry({
    this.cpuUsage,
    this.cpuLoad,
    this.memUsage,
    this.diskUsage,
    this.uptime,
    required this.fetchedAt,
  });

  factory ServerTelemetry.fromSSHOutput(String output) {
    String? cpuUsg;
    String? cpuLd;
    String? mem;
    String? disk;
    String? upt;

    final lines = output.split('\n').map((l) => l.trim()).toList();
    final cpuMarker = lines.indexOf('---CPU---');
    final memMarker = lines.indexOf('---MEM---');
    final diskMarker = lines.indexOf('---DISK---');

    // Parse Uptime & Load
    if (lines.isNotEmpty && lines.first.contains('load average')) {
      final line = lines.first;
      final loadIndex = line.indexOf('load average:');
      if (loadIndex != -1) {
        cpuLd = line.substring(loadIndex + 'load average:'.length).trim();
      }
      final upIndex = line.indexOf('up ');
      if (upIndex != -1 && loadIndex != -1) {
        upt = line.substring(upIndex + 3, line.indexOf(',', upIndex)).trim();
      }
    }

    // Parse CPU Usage from ---CPU--- section (top or /proc/stat)
    if (cpuMarker != -1 && (memMarker == -1 || cpuMarker < memMarker)) {
      final endIdx = memMarker != -1 ? memMarker : lines.length;
      for (int i = cpuMarker + 1; i < endIdx; i++) {
        final line = lines[i];
        if (line.isEmpty) continue;

        // 1. Try parsing top output: e.g. "%Cpu(s): 14.0 us, 4.7 sy, 0.0 ni, 81.4 id"
        final topIdleMatch = RegExp(r'([\d.]+)\s*%\s*id|([\d.]+)\s*id', caseSensitive: false).firstMatch(line);
        if (topIdleMatch != null) {
          final idleStr = topIdleMatch.group(1) ?? topIdleMatch.group(2);
          final idle = double.tryParse(idleStr ?? '');
          if (idle != null && idle >= 0 && idle <= 100) {
            final used = (100.0 - idle).clamp(0.0, 100.0);
            cpuUsg = '${used.toStringAsFixed(1)}%';
            break;
          }
        }

        // 2. Try parsing /proc/stat: "cpu 409952 0 50581 1935624 996 0 17840 0 0 0"
        if (line.startsWith('cpu ') || line.startsWith('cpu\t')) {
          final parts = line.split(RegExp(r'\s+')).where((s) => s.isNotEmpty).toList();
          if (parts.length >= 5) {
            final values = parts.sublist(1).map((v) => double.tryParse(v) ?? 0.0).toList();
            if (values.length >= 4) {
              final user = values[0];
              final nice = values[1];
              final system = values[2];
              final idle = values[3];
              final iowait = values.length > 4 ? values[4] : 0.0;
              final irq = values.length > 5 ? values[5] : 0.0;
              final softirq = values.length > 6 ? values[6] : 0.0;
              final steal = values.length > 7 ? values[7] : 0.0;

              final total = user + nice + system + idle + iowait + irq + softirq + steal;
              final busy = total - (idle + iowait);
              if (total > 0) {
                final pct = ((busy / total) * 100.0).clamp(0.0, 100.0);
                cpuUsg = '${pct.toStringAsFixed(1)}%';
                break;
              }
            }
          }
        }
      }
    }

    // Fallback: If no percentage parsed, use 1-minute load average
    if (cpuUsg == null && cpuLd != null) {
      final firstLoad = cpuLd.split(',').first.trim();
      if (firstLoad.isNotEmpty) {
        cpuUsg = '$firstLoad load';
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
      cpuUsage: cpuUsg,
      cpuLoad: cpuLd,
      memUsage: mem,
      diskUsage: disk,
      uptime: upt,
      fetchedAt: DateTime.now(),
    );
  }
}
