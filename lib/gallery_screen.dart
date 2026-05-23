import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'github_sync_service.dart';

class GalleryScreen extends StatefulWidget {
  const GalleryScreen({super.key});

  @override
  State<GalleryScreen> createState() => _GalleryScreenState();
}

class _GalleryScreenState extends State<GalleryScreen> {
  List<File> _images = [];
  bool _isLoading = true;
  bool _isSyncing = false;
  int _syncTotal = 0;
  int _syncCurrent = 0;

  @override
  void initState() {
    super.initState();
    _loadImages();
  }

  Future<void> _loadImages() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final files = directory.listSync();

      List<File> images = [];
      for (var file in files) {
        if (file.path.endsWith('.jpg')) {
          images.add(File(file.path));
        }
      }

      // Sort by modified date descending
      images.sort(
        (a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()),
      );

      setState(() {
        _images = images;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading images: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _syncToGithub() async {
    if (_images.isEmpty) return;
    String? token = dotenv.env['GITHUB_PAT'];
    if (token == null || token.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('GITHUB_PAT not found in .env')),
      );
      return;
    }

    setState(() {
      _isSyncing = true;
      _syncTotal = _images.length;
      _syncCurrent = 0;
    });

    final owner = dotenv.env['GITHUB_OWNER'] ?? 'KAnggara75';
    final repo = dotenv.env['GITHUB_REPO'] ?? 'everyday';

    final syncService = GithubSyncService(
      token: token,
      owner: owner,
      repo: repo,
    );
    await syncService.syncFiles(_images, (current, total) {
      if (mounted) {
        setState(() {
          _syncCurrent = current;
          _syncTotal = total;
        });
      }
    });

    if (mounted) {
      setState(() {
        _isSyncing = false;
      });
      _loadImages(); // Refresh local list as files are deleted
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sync completed!')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Galeri'),
        actions: [
          if (_isSyncing)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Text('$_syncCurrent/$_syncTotal'),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.cloud_upload),
            onPressed: _isSyncing ? null : _syncToGithub,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _images.isEmpty
          ? const Center(child: Text('Belum ada gambar'))
          : GridView.builder(
              padding: const EdgeInsets.all(4),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 5,
                crossAxisSpacing: 4,
                mainAxisSpacing: 4,
              ),
              itemCount: _images.length,
              itemBuilder: (context, index) {
                return GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => FullScreenImage(
                          images: _images,
                          initialIndex: index,
                        ),
                      ),
                    );
                  },
                  child: Image.file(_images[index], fit: BoxFit.cover),
                );
              },
            ),
    );
  }
}

class FullScreenImage extends StatefulWidget {
  final List<File> images;
  final int initialIndex;

  const FullScreenImage({
    super.key,
    required this.images,
    required this.initialIndex,
  });

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
          return Center(
            child: InteractiveViewer(child: Image.file(widget.images[index])),
          );
        },
      ),
    );
  }
}