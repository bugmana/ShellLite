import 'package:flutter/foundation.dart';
import '../config/app_config.dart';
import '../models/server_profile.dart';
import '../services/storage_service.dart';

class ServerStore extends ChangeNotifier {
  final StorageService _storageService;
  List<ServerProfile> _profiles = [];
  bool _isLoading = false;

  ServerStore({StorageService? storageService})
      : _storageService = storageService ?? StorageService();

  List<ServerProfile> get profiles => List.unmodifiable(_profiles);
  bool get isLoading => _isLoading;
  bool get isEmpty => _profiles.isEmpty;
  bool get canAddServer => _profiles.length < ServerConfig.maxServers;
  int get maxServers => ServerConfig.maxServers;

  Future<void> load() async {
    _isLoading = true;
    _profiles = await _storageService.loadProfiles();
    _isLoading = false;
    notifyListeners();
  }

  Future<void> addProfile(ServerProfile profile, {required String credential}) async {
    if (!canAddServer) {
      throw StateError('Maximum limit of $maxServers servers reached.');
    }

    await _storageService.saveCredential(profile.authMethod.credentialTag, credential);

    _profiles.insert(0, profile);
    await _storageService.saveProfiles(_profiles);
    notifyListeners();
  }

  Future<void> updateProfile(ServerProfile profile, {String? newCredential}) async {
    final index = _profiles.indexWhere((p) => p.id == profile.id);
    if (index == -1) return;

    if (newCredential != null && newCredential.isNotEmpty) {
      await _storageService.saveCredential(profile.authMethod.credentialTag, newCredential);
    }

    _profiles[index] = profile;
    await _storageService.saveProfiles(_profiles);
    notifyListeners();
  }

  Future<void> deleteProfile(String id) async {
    final index = _profiles.indexWhere((p) => p.id == id);
    if (index == -1) return;

    final profile = _profiles.removeAt(index);
    await _storageService.deleteCredential(profile.authMethod.credentialTag);
    await _storageService.saveProfiles(_profiles);
    notifyListeners();
  }

  Future<String?> getCredential(ServerProfile profile) async {
    return await _storageService.retrieveCredential(profile.authMethod.credentialTag);
  }
}
