import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'camera_controller.dart';
import 'camera_model.dart';
import '../gallery/gallery_screen.dart';

class CameraScreen extends StatefulWidget {
  final List<CameraDescription> cameras;

  const CameraScreen({super.key, required this.cameras});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  late CameraControllerHolder _controllerHolder;

  @override
  void initState() {
    super.initState();
    _controllerHolder = CameraControllerHolder(CameraModel());
    _controllerHolder.initCamera(widget.cameras);

    final owner = dotenv.env['GITHUB_OWNER'] ?? 'KAnggara75';
    final repo = dotenv.env['GITHUB_REPO'] ?? 'everyday';
    _controllerHolder.fetchGuideline(token: dotenv.env['GITHUB_PAT'], owner: owner, repo: repo);
  }

  @override
  void dispose() {
    _controllerHolder.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.cameras.isEmpty) {
      return const Scaffold(backgroundColor: Colors.black, body: SizedBox.expand());
    }

    return ListenableBuilder(
      listenable: _controllerHolder,
      builder: (context, child) {
        if (!_controllerHolder.isInit) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;
        final mediaQueryAspectRatio = MediaQuery.of(context).size.aspectRatio;
        final cameraVisualRatio = _controllerHolder.getCameraVisualRatio(mediaQueryAspectRatio, isLandscape);

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
                              width: cameraVisualRatio,
                              height: 1.0,
                              child: CameraPreview(_controllerHolder.controller!),
                            ),
                          ),
                        ),
                      ),
                    ),

                    // Guideline Overlay
                    if (_controllerHolder.showGuideline && _controllerHolder.guidelineBytes != null)
                      Center(
                        child: AspectRatio(
                          aspectRatio: 3 / 2,
                          child: Opacity(
                            opacity: 0.5,
                            child: Image.memory(_controllerHolder.guidelineBytes!, fit: BoxFit.cover),
                          ),
                        ),
                      ),

                    if (_controllerHolder.isLoadingGuideline && _controllerHolder.showGuideline)
                      const Center(
                        child: SizedBox(width: 40, height: 40, child: CircularProgressIndicator(strokeWidth: 2)),
                      ),

                    if (_controllerHolder.previewImagePath != null)
                      Center(
                        child: AspectRatio(
                          aspectRatio: 3 / 2,
                          child: Image.file(File(_controllerHolder.previewImagePath!), fit: BoxFit.cover),
                        ),
                      ),

                    if (_controllerHolder.isProcessing)
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
                        onPressed: _controllerHolder.toggleGuideline,
                        icon: Icon(
                          _controllerHolder.showGuideline ? Icons.visibility : Icons.visibility_off,
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
                    ),

                    // Tombol Capture
                    FloatingActionButton(
                      onPressed: _controllerHolder.isProcessing
                          ? null
                          : () {
                              _controllerHolder.takePicture(
                                onSuccess: (path) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Tersimpan di: $path'),
                                      duration: const Duration(milliseconds: 300),
                                    ),
                                  );
                                },
                                onError: (error) {
                                  ScaffoldMessenger.of(
                                    context,
                                  ).showSnackBar(SnackBar(content: Text('Gagal mengambil selfie: $error')));
                                },
                              );
                            },
                      backgroundColor: Colors.white,
                      child: const Icon(Icons.camera_alt, color: Colors.black),
                    ),

                    // Tombol Galeri
                    IconButton(
                      onPressed: () {
                        Navigator.push(context, MaterialPageRoute(builder: (context) => const GalleryScreen()));
                      },
                      icon: const Icon(Icons.photo_library, color: Colors.white, size: 30),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
