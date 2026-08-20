import 'package:flutter/foundation.dart';
import '../config/app_config.dart';
import '../models/snippet.dart';
import '../services/storage_service.dart';

class SnippetStore extends ChangeNotifier {
  final StorageService _storageService;

  List<Snippet> _snippets = [];
  bool _isLoading = false;

  SnippetStore({StorageService? storageService})
      : _storageService = storageService ?? StorageService();

  List<Snippet> get snippets => List.unmodifiable(_snippets);
  bool get isLoading => _isLoading;
  bool get isEmpty => _snippets.isEmpty;
  bool get canAddSnippet => _snippets.length < SnippetConfig.maxSnippets;
  int get maxSnippets => SnippetConfig.maxSnippets;

  Future<void> load() async {
    _isLoading = true;
    notifyListeners();

    _snippets = await _storageService.loadSnippets();
    _isLoading = false;
    notifyListeners();
  }

  Future<void> addSnippet(Snippet snippet) async {
    if (!canAddSnippet) {
      throw StateError('Maximum limit of $maxSnippets snippets reached.');
    }
    _snippets.insert(0, snippet);
    await _storageService.saveSnippets(_snippets);
    notifyListeners();
  }

  Future<void> updateSnippet(Snippet updated) async {
    final index = _snippets.indexWhere((s) => s.id == updated.id);
    if (index != -1) {
      _snippets[index] = updated;
      await _storageService.saveSnippets(_snippets);
      notifyListeners();
    }
  }

  Future<void> deleteSnippet(String id) async {
    _snippets.removeWhere((s) => s.id == id);
    await _storageService.saveSnippets(_snippets);
    notifyListeners();
  }

  Future<void> resetToDefaults() async {
    _snippets = List.from(DefaultSnippets.defaults);
    await _storageService.saveSnippets(_snippets);
    notifyListeners();
  }
}
