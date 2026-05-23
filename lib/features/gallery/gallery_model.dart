import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../../services/github_sync_service.dart';

class GalleryModel {
  Future<List<File>> getLocalImages() async {
    final directory = await getApplicationDocumentsDirectory();
    final files = directory.listSync();

    List<File> images = [];
    for (var file in files) {
      if (file.path.endsWith('.jpg')) {
        images.add(File(file.path));
      }
    }

    // Sort by modified date descending
    images.sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));

    return images;
  }

  Future<void> syncImages(
    List<File> images, {
    required String token,
    required String owner,
    required String repo,
    required Function(int current, int total) onProgress,
  }) async {
    final syncService = GithubSyncService(token: token, owner: owner, repo: repo);
    await syncService.syncFiles(images, onProgress);
  }
}
