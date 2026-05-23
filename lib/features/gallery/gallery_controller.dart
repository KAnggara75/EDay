import 'dart:io';
import 'package:flutter/foundation.dart';
import 'gallery_model.dart';

class GalleryController extends ChangeNotifier {
  final GalleryModel _model;

  GalleryController(this._model);

  List<File> _images = [];
  bool _isLoading = true;
  bool _isSyncing = false;
  int _syncTotal = 0;
  int _syncCurrent = 0;

  // Getters
  List<File> get images => _images;
  bool get isLoading => _isLoading;
  bool get isSyncing => _isSyncing;
  int get syncTotal => _syncTotal;
  int get syncCurrent => _syncCurrent;

  Future<void> loadImages() async {
    _isLoading = true;

    notifyListeners();

    try {
      _images = await _model.getLocalImages();
    } catch (e) {
      debugPrint('Error loading images in controller: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> syncToGithub({
    required String? token,
    required String owner,
    required String repo,
    required VoidCallback onComplete,
    required Function(String error) onError,
  }) async {
    if (_images.isEmpty) return;
    if (token == null || token.isEmpty) {
      onError('GITHUB_PAT not found in .env');
      return;
    }

    _isSyncing = true;
    _syncTotal = _images.length;
    _syncCurrent = 0;
    notifyListeners();

    try {
      await _model.syncImages(
        _images,
        token: token,
        owner: owner,
        repo: repo,
        onProgress: (current, total) {
          _syncCurrent = current;
          _syncTotal = total;
          notifyListeners();
        },
      );
      onComplete();
    } catch (e) {
      onError('Sync failed: $e');
    } finally {
      _isSyncing = false;
      notifyListeners();
      // Reload images because local files are deleted after successful sync
      await loadImages();
    }
  }
}
