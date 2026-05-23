import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:path/path.dart' as path;

class GithubSyncService {
  final String owner;
  final String repo;
  final String token;

  GithubSyncService({
    required this.token,
    this.owner = 'KAnggara75',
    this.repo = 'everyday',
  });

  Future<void> syncFiles(
    List<File> localFiles,
    Function(int, int) onProgress,
  ) async {
    int total = localFiles.length;
    int current = 0;

    // Sort local files by modified date ascending (oldest to newest)
    localFiles.sort(
      (a, b) => a.lastModifiedSync().compareTo(b.lastModifiedSync()),
    );

    for (var file in localFiles) {
      if (!file.path.endsWith('.jpg')) continue;

      String filename = path.basename(file.path);
      // format from intl DateFormat('yyMMddHHmmss').jpg
      String yearStr = '20${filename.substring(0, 2)}';

      String targetPath = '$yearStr/$filename';

      // Read bytes before potential deletion
      final bytes = await file.readAsBytes();

      bool success = await _uploadFileWithBytes(bytes, targetPath);
      if (success) {
        current++;
        onProgress(current, total);

        // Delete local file after successful upload
        try {
          await file.delete();
        } catch (e) {
          debugPrint('Failed to delete local file ${file.path}: $e');
        }
      }

      // Delay to avoid abuse mechanism
      await Future.delayed(const Duration(milliseconds: 500));
    }
  }

  Future<bool> _uploadFileWithBytes(
    Uint8List bytes,
    String targetPath, {
    bool forceOverwrite = false,
  }) async {
    final url = Uri.parse(
      'https://api.github.com/repos/$owner/$repo/contents/$targetPath',
    );

    String? sha;

    final checkRes = await http.get(
      url,
      headers: {
        'Authorization': 'token $token',
        'Accept': 'application/vnd.github.v3+json',
      },
    );

    if (checkRes.statusCode == 200) {
      if (!forceOverwrite) {
        return true; // Don't upload if it already exists
      }
      final data = jsonDecode(checkRes.body);
      sha = data['sha'];
    }

    final base64Content = base64Encode(bytes);

    final now = DateTime.now();
    final timestamp =
        '${DateFormat('E MMM d HH:mm:ss', 'en_US').format(now)} WIB ${DateFormat('yyyy', 'en_US').format(now)}';

    final body = {
      'message': 'Updated: $timestamp [APP]',
      'content': base64Content,
    };

    if (sha != null) {
      body['sha'] = sha;
    }

    final putRes = await http.put(
      url,
      headers: {
        'Authorization': 'token $token',
        'Accept': 'application/vnd.github.v3+json',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(body),
    );

    if (putRes.statusCode == 201 || putRes.statusCode == 200) {
      return true;
    } else {
      debugPrint('Failed to upload $targetPath: ${putRes.body}');
      return false;
    }
  }
}