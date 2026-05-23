import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'gallery_controller.dart';
import 'gallery_model.dart';

class GalleryScreen extends StatefulWidget {
  const GalleryScreen({super.key});

  @override
  State<GalleryScreen> createState() => _GalleryScreenState();
}

class _GalleryScreenState extends State<GalleryScreen> {
  late GalleryController _controller;

  @override
  void initState() {
    super.initState();
    _controller = GalleryController(GalleryModel());
    _controller.loadImages();
  }

  Future<void> _syncToGithub() async {
    final token = dotenv.env['GITHUB_PAT'];
    final owner = dotenv.env['GITHUB_OWNER'] ?? 'KAnggara75';
    final repo = dotenv.env['GITHUB_REPO'] ?? 'everyday';

    await _controller.syncToGithub(
      token: token,
      owner: owner,
      repo: repo,
      onComplete: () {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sync completed!')));
        }
      },
      onError: (error) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, child) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('Galeri'),
            actions: [
              if (_controller.isSyncing)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Text('${_controller.syncCurrent}/${_controller.syncTotal}'),
                  ),
                ),
              IconButton(
                icon: const Icon(Icons.cloud_upload),
                onPressed: _controller.isSyncing || _controller.images.isEmpty ? null : _syncToGithub,
              ),
            ],
          ),
          body: _controller.isLoading
              ? const Center(child: CircularProgressIndicator())
              : _controller.images.isEmpty
              ? const Center(child: Text('Belum ada gambar'))
              : GridView.builder(
                  padding: const EdgeInsets.all(4),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 5,
                    crossAxisSpacing: 4,
                    mainAxisSpacing: 4,
                  ),
                  itemCount: _controller.images.length,
                  itemBuilder: (context, index) {
                    return GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => FullScreenImage(images: _controller.images, initialIndex: index),
                          ),
                        );
                      },
                      child: Image.file(_controller.images[index], fit: BoxFit.cover),
                    );
                  },
                ),
        );
      },
    );
  }
}

class FullScreenImage extends StatefulWidget {
  final List<File> images;
  final int initialIndex;

  const FullScreenImage({super.key, required this.images, required this.initialIndex});

  @override
  State<FullScreenImage> createState() => _FullScreenImageState();
}

class _FullScreenImageState extends State<FullScreenImage> {
  late PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: PageView.builder(
        controller: _pageController,
        itemCount: widget.images.length,
        itemBuilder: (context, index) {
          return Center(child: InteractiveViewer(child: Image.file(widget.images[index])));
        },
      ),
    );
  }
}
