import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:camera/camera.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:image/image.dart' as img;
import 'package:intl/intl.dart';
import 'gallery_screen.dart';

class CameraScreen extends StatefulWidget {
  final List<CameraDescription> cameras;

  const CameraScreen({super.key, required this.cameras});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  late CameraController _controller;
  bool _isInit = false;
  bool _isProcessing = false;
  bool _showGuideline = true;
  String? _previewImagePath;
  Uint8List? _guidelineBytes;
  bool _isLoadingGuideline = false;

  @override
  void initState() {
    super.initState();
    _initCamera();
    _fetchGuidelineImage();
  }

  Future<void> _fetchGuidelineImage() async {
    String? token = dotenv.env['GITHUB_PAT'];
    if (token == null || token.isEmpty) return;

    setState(() => _isLoadingGuideline = true);

    try {
      final owner = dotenv.env['GITHUB_OWNER'] ?? 'KAnggara75';
      final repo = dotenv.env['GITHUB_REPO'] ?? 'everyday';
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      const targetPath = 'timelapse/last.jpg';
      final url = Uri.parse(
        'https://api.github.com/repos/$owner/$repo/contents/$targetPath?v=$timestamp',
      );

      final response = await http.get(
        url,
        headers: {
          'Authorization': 'token $token',
          'Accept': 'application/vnd.github.v3.raw',
        },
      );

      if (response.statusCode == 200) {
        setState(() {
          _guidelineBytes = response.bodyBytes;
        });
      }
    } catch (e) {
      debugPrint('Error fetching guideline: $e');
    } finally {
      setState(() => _isLoadingGuideline = false);
    }
  }

  Future<void> _initCamera() async {
    if (widget.cameras.isEmpty) {
      debugPrint('No cameras available');
      return;
    }

    // Find front camera
    CameraDescription? frontCamera;
    for (var camera in widget.cameras) {
      if (camera.lensDirection == CameraLensDirection.front) {
        frontCamera = camera;
        break;
      }
    }

    // Fallback to first camera if no front camera found
    frontCamera ??= widget.cameras.first;

    _controller = CameraController(
      frontCamera,
      ResolutionPreset.veryHigh,
      enableAudio: false,
    );

    try {
      await _controller.initialize();
      // Kunci orientasi tangkapan ke mode lanskap agar preview dan hasil tidak menjadi potret
      try {
        await _controller.lockCaptureOrientation(
          DeviceOrientation.landscapeLeft,
        );
      } catch (_) {} // Ignore if locking fails on some devices

      setState(() {
        _isInit = true;
      });
    } catch (e) {
      debugPrint('Error initializing camera: $e');
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  double get _cameraVisualRatio {
    if (!_controller.value.isInitialized) return 1.0;
    double ratio = _controller.value.aspectRatio;
    bool isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;
    if (isLandscape && ratio < 1) return 1 / ratio;
    if (!isLandscape && ratio > 1) return 1 / ratio;
    return ratio;
  }

  Future<void> _takePicture() async {
    if (!_controller.value.isInitialized || _isProcessing) {
      return;
    }

    setState(() {
      _isProcessing = true;
    });

    try {
      // 1. Capture the image
      final XFile imageFile = await _controller.takePicture();

      // 2. Process image (Decode, Crop, Resize)
      final File file = File(imageFile.path);
      final bytes = await file.readAsBytes();

      // Decode image
      img.Image? capturedImage = img.decodeImage(bytes);
      if (capturedImage == null) throw Exception("Failed to decode image");

      // Pastikan orientasi EXIF bawaan kamera diterapkan
      capturedImage = img.bakeOrientation(capturedImage);

      // Jika karena suatu hal gambar masih portrait (tinggi > lebar), paksa putar
      if (capturedImage.width < capturedImage.height) {
        capturedImage = img.copyRotate(capturedImage, angle: -90);
      }

      // Sesuaikan kamera depan agar hasil foto tidak terbalik (sama dengan preview)
      if (_controller.description.lensDirection == CameraLensDirection.front) {
        capturedImage = img.flipHorizontal(capturedImage);
      }

      // Target aspect ratio is 3:2
      const double targetRatio = 3 / 2;

      int srcWidth = capturedImage.width;
      int srcHeight = capturedImage.height;
      double srcRatio = srcWidth / srcHeight;

      img.Image finalImage;

      if (srcRatio.toStringAsFixed(3) != targetRatio.toStringAsFixed(3)) {
        if (srcRatio > targetRatio) {
          // Source is wider than target. Crop width.
          int newWidth = (srcHeight * targetRatio).round();
          int offsetX = (srcWidth - newWidth) ~/ 2;
          finalImage = img.copyCrop(
            capturedImage,
            x: offsetX,
            y: 0,
            width: newWidth,
            height: srcHeight,
          );
        } else {
          // Source is taller than target. Crop height.
          int newHeight = (srcWidth / targetRatio).round();
          int offsetY = (srcHeight - newHeight) ~/ 2;
          finalImage = img.copyCrop(
            capturedImage,
            x: 0,
            y: offsetY,
            width: srcWidth,
            height: newHeight,
          );
        }
      } else {
        finalImage = capturedImage;
      }

      // 3. Generate path with intl (yymmddhhMMss.jpg)
      final directory = await getApplicationDocumentsDirectory();
      String filename =
          "${DateFormat('yyMMddHHmmss').format(DateTime.now())}.jpg";
      String savePath = "${directory.path}/$filename";

      // 4. Save to local storage
      final savedFile = File(savePath);
      await savedFile.writeAsBytes(img.encodeJpg(finalImage));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Tersimpan di: $savePath'),
            duration: const Duration(milliseconds: 300),
          ),
        );

        setState(() {
          _previewImagePath = savePath;
        });

        Future.delayed(const Duration(seconds: 1), () {
          if (mounted) {
            setState(() {
              _previewImagePath = null;
            });
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Gagal mengambil selfie: $e')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.cameras.isEmpty) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: SizedBox.expand(),
      );
    }

    if (!_isInit) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Row(
        children: [
          // Kiri: Layer Kamera dan Preview
          Expanded(
            child: Stack(
              children: [
                // Camera Preview
                Center(
                  child: AspectRatio(
                    aspectRatio: 3 / 2,
                    child: ClipRect(
                      child: FittedBox(
                        fit: BoxFit.cover,
                        child: SizedBox(
                          width: _cameraVisualRatio,
                          height: 1.0,
                          child: CameraPreview(_controller),
                        ),
                      ),
                    ),
                  ),
                ),

                // Guideline Overlay
                if (_showGuideline && _guidelineBytes != null)
                  Center(
                    child: AspectRatio(
                      aspectRatio: 3 / 2,
                      child: Opacity(
                        opacity: 0.5,
                        child: Image.memory(
                          _guidelineBytes!,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  ),

                if (_isLoadingGuideline && _showGuideline)
                  const Center(
                    child: SizedBox(
                      width: 40,
                      height: 40,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),

                if (_previewImagePath != null)
                  Center(
                    child: AspectRatio(
                      aspectRatio: 3 / 2,
                      child: Image.file(
                        File(_previewImagePath!),
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),

                if (_isProcessing)
                  Container(
                    color: Colors.black54,
                    child: const Center(child: CircularProgressIndicator()),
                  ),
              ],
            ),
          ),

          // Kanan: Panel Tombol
          Container(
            width: 100,
            color: Colors.black,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // Spacer top & Guideline toggle
                Padding(
                  padding: const EdgeInsets.only(top: 24.0),
                  child: IconButton(
                    onPressed: () {
                      setState(() {
                        _showGuideline = !_showGuideline;
                      });
                    },
                    icon: Icon(
                      _showGuideline ? Icons.visibility : Icons.visibility_off,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                ),

                // Tombol Capture
                FloatingActionButton(
                  onPressed: _isProcessing ? null : _takePicture,
                  backgroundColor: Colors.white,
                  child: const Icon(Icons.camera_alt, color: Colors.black),
                ),

                // Tombol Galeri
                IconButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const GalleryScreen(),
                      ),
                    );
                  },
                  icon: const Icon(
                    Icons.photo_library,
                    color: Colors.white,
                    size: 30,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}