import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:camera/camera.dart';
import 'camera_model.dart';

class CameraControllerHolder extends ChangeNotifier {
  final CameraModel _model;

  CameraControllerHolder(this._model);

  CameraController? _controller;
  bool _isInit = false;
  bool _isProcessing = false;
  bool _showGuideline = true;
  String? _previewImagePath;
  Uint8List? _guidelineBytes;
  bool _isLoadingGuideline = false;

  // Getters
  CameraController? get controller => _controller;
  bool get isInit => _isInit;
  bool get isProcessing => _isProcessing;
  bool get showGuideline => _showGuideline;
  String? get previewImagePath => _previewImagePath;
  Uint8List? get guidelineBytes => _guidelineBytes;
  bool get isLoadingGuideline => _isLoadingGuideline;

  Future<void> initCamera(List<CameraDescription> cameras) async {
    if (cameras.isEmpty) {
      debugPrint('No cameras available');
      return;
    }

    // Find front camera
    CameraDescription? frontCamera;
    for (var camera in cameras) {
      if (camera.lensDirection == CameraLensDirection.front) {
        frontCamera = camera;
        break;
      }
    }

    // Fallback to first camera if no front camera found
    frontCamera ??= cameras.first;

    _controller = CameraController(frontCamera, ResolutionPreset.veryHigh, enableAudio: false);

    try {
      await _controller!.initialize();
      // Kunci orientasi tangkapan ke mode lanskap agar preview dan hasil tidak menjadi potret
      try {
        await _controller!.lockCaptureOrientation(DeviceOrientation.landscapeLeft);
      } catch (_) {} // Ignore if locking fails on some devices

      _isInit = true;
      notifyListeners();
    } catch (e) {
      debugPrint('Error initializing camera: $e');
    }
  }

  Future<void> fetchGuideline({required String? token, required String owner, required String repo}) async {
    if (token == null || token.isEmpty) return;

    _isLoadingGuideline = true;
    notifyListeners();

    try {
      final bytes = await _model.fetchGuideline(token: token, owner: owner, repo: repo);
      if (bytes != null) {
        _guidelineBytes = bytes;
      }
    } catch (e) {
      debugPrint('Error fetching guideline: $e');
    } finally {
      _isLoadingGuideline = false;
      notifyListeners();
    }
  }

  void toggleGuideline() {
    _showGuideline = !_showGuideline;
    notifyListeners();
  }

  Future<void> takePicture({required Function(String path) onSuccess, required Function(String error) onError}) async {
    if (_controller == null || !_controller!.value.isInitialized || _isProcessing) {
      return;
    }

    _isProcessing = true;
    notifyListeners();

    try {
      // 1. Capture the image
      final XFile imageFile = await _controller!.takePicture();

      // 2. Process and save
      final savePath = await _model.processAndSaveImage(
        rawFile: imageFile,
        lensDirection: _controller!.description.lensDirection,
      );

      _previewImagePath = savePath;
      notifyListeners();

      onSuccess(savePath);

      // Clear preview after 1 second
      Future.delayed(const Duration(seconds: 1), () {
        _previewImagePath = null;
        notifyListeners();
      });
    } catch (e) {
      onError(e.toString());
    } finally {
      _isProcessing = false;
      notifyListeners();
    }
  }

  double getCameraVisualRatio(double mediaQueryAspectRatio, bool isLandscape) {
    if (_controller == null || !_controller!.value.isInitialized) return 1.0;
    double ratio = _controller!.value.aspectRatio;
    if (isLandscape && ratio < 1) return 1 / ratio;
    if (!isLandscape && ratio > 1) return 1 / ratio;
    return ratio;
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }
}
