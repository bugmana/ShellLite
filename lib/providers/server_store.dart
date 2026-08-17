import 'package:flutter/foundation.dart';
import '../config/app_config.dart';
import '../models/auth_method.dart';
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

    final tag = profile.authMethod is PasswordAuth
        ? (profile.authMethod as PasswordAuth).credentialTag
        : (profile.authMethod as SSHKeyAuth).privateKeyTag;

    await _storageService.saveCredential(tag, credential);

    _profiles.insert(0, profile);
    await _storageService.saveProfiles(_profiles);
    notifyListeners();
  }

  Future<void> updateProfile(ServerProfile profile, {String? newCredential}) async {
    final index = _profiles.indexWhere((p) => p.id == profile.id);
    if (index == -1) return;

    if (newCredential != null && newCredential.isNotEmpty) {
      final tag = profile.authMethod is PasswordAuth
          ? (profile.authMethod as PasswordAuth).credentialTag
          : (profile.authMethod as SSHKeyAuth).privateKeyTag;
      await _storageService.saveCredential(tag, newCredential);
    }

    _profiles[index] = profile;
    await _storageService.saveProfiles(_profiles);
    notifyListeners();
  }

  Future<void> deleteProfile(String id) async {
    final index = _profiles.indexWhere((p) => p.id == id);
    if (index == -1) return;

    final profile = _profiles.removeAt(index);
    final tag = profile.authMethod is PasswordAuth
        ? (profile.authMethod as PasswordAuth).credentialTag
        : (profile.authMethod as SSHKeyAuth).privateKeyTag;

    await _storageService.deleteCredential(tag);
    await _storageService.saveProfiles(_profiles);
    notifyListeners();
  }

  Future<String?> getCredential(ServerProfile profile) async {
    final tag = profile.authMethod is PasswordAuth
        ? (profile.authMethod as PasswordAuth).credentialTag
        : (profile.authMethod as SSHKeyAuth).privateKeyTag;
    return await _storageService.retrieveCredential(tag);
  }
}
