import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:shell_lite/config/app_config.dart';
import 'package:shell_lite/services/ssh_service.dart';

void main() {
  group('SSHService Terminal Dimensions & Resize', () {
    test('initializes with default dimensions', () {
      final service = SSHService();
      expect(service.terminalWidth, TerminalConfig.defaultWidth);
      expect(service.terminalHeight, TerminalConfig.defaultHeight);
      expect(service.isConnected, isFalse);
    });

    test('resizeTerminal updates width and height before connection is established', () {
      final service = SSHService();
      service.resizeTerminal(120, 40, 1200, 800);

      expect(service.terminalWidth, 120);
      expect(service.terminalHeight, 40);
    });

    test('resizeTerminal ignores non-positive width and height values', () {
      final service = SSHService();
      service.resizeTerminal(100, 30);
      service.resizeTerminal(0, -5);

      expect(service.terminalWidth, 100);
      expect(service.terminalHeight, 30);
    });
  });

  group('Stateful UTF-8 Stream Decoding', () {
    test('decodes multibyte characters split across chunk boundaries without corruption', () async {
      final controller = StreamController<Uint8List>();
      final receivedChunks = <String>[];

      final subscription = controller.stream
          .cast<List<int>>()
          .transform(const Utf8Decoder(allowMalformed: true))
          .listen((text) {
        receivedChunks.add(text);
      });

      // Sample multibyte string with box drawing and unicode: "┌─ ➜ ShellLite ─┐"
      // '┌' is 3 bytes: 0xE2 0x94 0x8C
      // '─' is 3 bytes: 0xE2 0x94 0x80
      // '➜' is 3 bytes: 0xE2 0x9E 0x9C
      final fullBytes = utf8.encode('┌── ➜ Server ShellLite ──┐\r\n');

      // Split intentionally at arbitrary byte boundaries (e.g. 1-2 bytes per chunk)
      for (int i = 0; i < fullBytes.length; i += 2) {
        final end = (i + 2 < fullBytes.length) ? i + 2 : fullBytes.length;
        controller.add(Uint8List.fromList(fullBytes.sublist(i, end)));
        await Future.delayed(Duration.zero);
      }

      await controller.close();
      await subscription.cancel();

      final fullDecoded = receivedChunks.join();
      expect(fullDecoded, '┌── ➜ Server ShellLite ──┐\r\n');
      expect(fullDecoded.contains('\uFFFD'), isFalse,
          reason: 'Split chunks should not produce Unicode replacement characters');
    });

    test('decodes large multi-byte sequences without dropping data or desynchronizing', () async {
      final controller = StreamController<Uint8List>();
      final receivedChunks = <String>[];

      final subscription = controller.stream
          .cast<List<int>>()
          .transform(const Utf8Decoder(allowMalformed: true))
          .listen((text) {
        receivedChunks.add(text);
      });

      // Simulate a large TUI or log output chunked in arbitrary packet sizes (e.g. 7 bytes)
      const sampleTuiLine = '│ 100% [████████████████████] CPU Usage 42.5% │\n';
      final fullData = sampleTuiLine * 50;
      final fullBytes = utf8.encode(fullData);

      const chunkSize = 7;
      for (int i = 0; i < fullBytes.length; i += chunkSize) {
        final end = (i + chunkSize < fullBytes.length) ? i + chunkSize : fullBytes.length;
        controller.add(Uint8List.fromList(fullBytes.sublist(i, end)));
        await Future.delayed(Duration.zero);
      }

      await controller.close();
      await subscription.cancel();

      final fullDecoded = receivedChunks.join();
      expect(fullDecoded, fullData);
      expect(fullDecoded.contains('\uFFFD'), isFalse);
    });
  });

  group('SSHService Persistent Tmux Command Construction', () {
    test('buildTmuxCommand enables mouse mode both globally and upon session creation', () {
      final cmd = SSHService.buildTmuxCommand('work-session');
      // Verifies mouse mode is set before new-session to configure tmux server
      expect(cmd, contains('tmux set -g mouse on 2>/dev/null;'));
      // Verifies mouse mode is attached to the new-session execution
      expect(cmd, contains('exec tmux new-session -A -s "work-session" \\; set -g mouse on;'));
      // Verifies graceful notice if tmux binary is missing
      expect(cmd, contains('Notice: tmux is not installed on this host'));
    });

    test('buildTmuxCommand sanitizes unsafe characters and defaults empty session names', () {
      // Spaces, shell metacharacters, semicolons should be sanitized to '_'
      final sanitizedCmd = SSHService.buildTmuxCommand('my session; rm -rf / && hack!');
      expect(sanitizedCmd, contains('-s "my_session__rm_-rf______hack_"'));
      expect(sanitizedCmd, contains('\\; set -g mouse on;'));

      // Empty or null session name defaults to 'shelllite'
      final nullCmd = SSHService.buildTmuxCommand(null);
      expect(nullCmd, contains('-s "shelllite" \\; set -g mouse on;'));

      final emptyCmd = SSHService.buildTmuxCommand('   ');
      expect(emptyCmd, contains('-s "shelllite" \\; set -g mouse on;'));
    });
  });
}

