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

  Future<void> addProfile(
    ServerProfile profile, {
    required String credential,
    String? keyPassphrase,
  }) async {
    if (!canAddServer) {
      throw StateError('Maximum limit of $maxServers servers reached.');
    }

    await _storageService.saveCredential(profile.authMethod.credentialTag, credential);

    if (profile.authMethod is SSHKeyAuth) {
      final auth = profile.authMethod as SSHKeyAuth;
      if (auth.passphraseTag != null && keyPassphrase != null && keyPassphrase.isNotEmpty) {
        await _storageService.saveCredential(auth.passphraseTag!, keyPassphrase);
      }
    }

    _profiles.insert(0, profile);
    await _storageService.saveProfiles(_profiles);
    notifyListeners();
  }

  Future<void> updateProfile(
    ServerProfile profile, {
    String? newCredential,
    String? newKeyPassphrase,
    bool clearKeyPassphrase = false,
  }) async {
    final index = _profiles.indexWhere((p) => p.id == profile.id);
    if (index == -1) return;

    final oldProfile = _profiles[index];

    if (newCredential != null && newCredential.isNotEmpty) {
      await _storageService.saveCredential(profile.authMethod.credentialTag, newCredential);
    }

    if (profile.authMethod is SSHKeyAuth) {
      final auth = profile.authMethod as SSHKeyAuth;
      if (auth.passphraseTag != null && newKeyPassphrase != null && newKeyPassphrase.isNotEmpty) {
        await _storageService.saveCredential(auth.passphraseTag!, newKeyPassphrase);
      } else if (clearKeyPassphrase || auth.passphraseTag == null) {
        if (oldProfile.authMethod is SSHKeyAuth && (oldProfile.authMethod as SSHKeyAuth).passphraseTag != null) {
          await _storageService.deleteCredential((oldProfile.authMethod as SSHKeyAuth).passphraseTag!);
        }
      }
    } else {
      if (oldProfile.authMethod is SSHKeyAuth && (oldProfile.authMethod as SSHKeyAuth).passphraseTag != null) {
        await _storageService.deleteCredential((oldProfile.authMethod as SSHKeyAuth).passphraseTag!);
      }
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
    if (profile.authMethod is SSHKeyAuth && (profile.authMethod as SSHKeyAuth).passphraseTag != null) {
      await _storageService.deleteCredential((profile.authMethod as SSHKeyAuth).passphraseTag!);
    }
    await _storageService.saveProfiles(_profiles);
    notifyListeners();
  }

  Future<String?> getCredential(ServerProfile profile) async {
    return await _storageService.retrieveCredential(profile.authMethod.credentialTag);
  }

  Future<String?> getKeyPassphrase(ServerProfile profile) async {
    if (profile.authMethod is SSHKeyAuth) {
      final auth = profile.authMethod as SSHKeyAuth;
      if (auth.passphraseTag != null) {
        return await _storageService.retrieveCredential(auth.passphraseTag!);
      }
    }
    return null;
  }
}
