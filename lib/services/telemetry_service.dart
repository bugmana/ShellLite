import 'dart:convert';
import 'package:dartssh2/dartssh2.dart';
import 'package:flutter/foundation.dart';
import '../models/auth_method.dart';
import '../models/server_profile.dart';
import '../models/server_telemetry.dart';
import '../services/key_parser.dart';
import '../services/storage_service.dart';

class TelemetryService {
  static const Duration connectTimeout = Duration(milliseconds: 2500);
  static const Duration commandTimeout = Duration(milliseconds: 2500);
  static const Duration totalTimeout = Duration(milliseconds: 3500);

  static Future<ServerTelemetry?> fetchTelemetry(
    ServerProfile profile, {
    StorageService? storageService,
  }) async {
    return _fetchWithTimeout(profile, storageService).timeout(
      totalTimeout,
      onTimeout: () {
        debugPrint('TelemetryService: Quick timeout reached for ${profile.host}');
        return null;
      },
    );
  }

  static Future<ServerTelemetry?> _fetchWithTimeout(
    ServerProfile profile,
    StorageService? storageService,
  ) async {
    SSHClient? client;
    SSHSocket? socket;
    try {
      final storage = storageService ?? StorageService();
      String? credential;

      if (profile.authMethod is PasswordAuth) {
        credential = await storage.retrieveCredential(
          (profile.authMethod as PasswordAuth).credentialTag,
        );
      } else if (profile.authMethod is SSHKeyAuth) {
        credential = await storage.retrieveCredential(
          (profile.authMethod as SSHKeyAuth).privateKeyTag,
        );
      }

      socket = await SSHSocket.connect(
        profile.host,
        profile.port,
        timeout: connectTimeout,
      );

      List<SSHKeyPair>? keyPairs;
      if (profile.authMethod is SSHKeyAuth && credential != null && credential.isNotEmpty) {
        try {
          keyPairs = SSHKeyParser.parse(credential);
        } catch (e) {
          debugPrint('TelemetryService key parse error: $e');
        }
      }

      client = SSHClient(
        socket,
        username: profile.username,
        onPasswordRequest: () {
          if (profile.authMethod is PasswordAuth && credential != null) {
            return credential;
          }
          return null;
        },
        onUserInfoRequest: (request) {
          final responses = <String>[];
          for (final _ in request.prompts) {
            if (profile.authMethod is PasswordAuth && credential != null) {
              responses.add(credential);
            } else {
              responses.add('');
            }
          }
          return responses;
        },
        identities: keyPairs,
      );

      final result = await client.run(
        'uptime && echo "---MEM---" && free -h && echo "---DISK---" && df -h /',
      ).timeout(commandTimeout);

      final output = utf8.decode(result);
      return ServerTelemetry.fromSSHOutput(output);
    } catch (e) {
      debugPrint('TelemetryService error for ${profile.host}: $e');
      return null;
    } finally {
      try {
        client?.close();
      } catch (_) {}
      try {
        socket?.close();
      } catch (_) {}
    }
  }
}
