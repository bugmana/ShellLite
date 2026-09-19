import 'package:flutter/foundation.dart';
import '../models/server_profile.dart';
import '../models/server_telemetry.dart';
import '../services/storage_service.dart';
import '../services/telemetry_service.dart';

class TelemetryStore extends ChangeNotifier {
  final StorageService _storageService;
  final Map<String, ServerTelemetry> _telemetryMap = {};
  final Map<String, bool> _loadingMap = {};
  final Set<String> _attempted = {};
  final Set<String> _failed = {};
  bool _autoFetchEnabled = false;

  TelemetryStore({StorageService? storageService})
      : _storageService = storageService ?? StorageService();

  bool get autoFetchEnabled => _autoFetchEnabled;
  set autoFetchEnabled(bool enabled) {
    _autoFetchEnabled = enabled;
    notifyListeners();
  }

  ServerTelemetry? getTelemetry(String profileId) => _telemetryMap[profileId];
  bool isLoading(String profileId) => _loadingMap[profileId] ?? false;
  bool hasAttempted(String profileId) => _attempted.contains(profileId);
  bool hasFailed(String profileId) => _failed.contains(profileId);

  Future<void> refresh(ServerProfile profile, {bool isManual = false}) async {
    // Only execute background telemetry if host key has already been verified interactively (SEC-NET-03)
    if (!isManual) {
      final knownFp = await _storageService.getKnownHostFingerprint(profile.host, profile.port);
      if (knownFp == null) {
        debugPrint('TelemetryStore: Skipping background telemetry for unverified host ${profile.host}');
        return;
      }
    }

    _attempted.add(profile.id);
    _loadingMap[profile.id] = true;
    notifyListeners();

    try {
      final result = await TelemetryService.fetchTelemetry(
        profile,
        storageService: _storageService,
      );

      if (result != null) {
        _telemetryMap[profile.id] = result;
        _failed.remove(profile.id);
      } else {
        _failed.add(profile.id);
      }
    } catch (_) {
      _failed.add(profile.id);
    } finally {
      _loadingMap[profile.id] = false;
      notifyListeners();
    }
  }

  @visibleForTesting
  void setTelemetry(String profileId, ServerTelemetry telemetry) {
    _telemetryMap[profileId] = telemetry;
    _attempted.add(profileId);
    _failed.remove(profileId);
    notifyListeners();
  }
}
