import 'dart:io';
import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';

class CameraModel {
  Future<Uint8List?> fetchGuideline({required String token, required String owner, required String repo}) async {
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      const targetPath = 'timelapse/last.jpg';
      final url = Uri.parse('https://api.github.com/repos/$owner/$repo/contents/$targetPath?v=$timestamp');

      final response = await http.get(
        url,
        headers: {'Authorization': 'token $token', 'Accept': 'application/vnd.github.v3.raw'},
      );

      if (response.statusCode == 200) {
        return response.bodyBytes;
      }
      return null;
    } catch (e) {
      throw Exception('Failed to fetch guideline: $e');
    }
  }

  Future<String> processAndSaveImage({required XFile rawFile, required CameraLensDirection lensDirection}) async {
    final File file = File(rawFile.path);
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
    if (lensDirection == CameraLensDirection.front) {
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
        finalImage = img.copyCrop(capturedImage, x: offsetX, y: 0, width: newWidth, height: srcHeight);
      } else {
        // Source is taller than target. Crop height.
        int newHeight = (srcWidth / targetRatio).round();
        int offsetY = (srcHeight - newHeight) ~/ 2;
        finalImage = img.copyCrop(capturedImage, x: 0, y: offsetY, width: srcWidth, height: newHeight);
      }
    } else {
      finalImage = capturedImage;
    }

    // Generate path with intl (yymmddhhMMss.jpg)
    final directory = await getApplicationDocumentsDirectory();
    String filename = "${DateFormat('yyMMddHHmmss').format(DateTime.now())}.jpg";
    String savePath = "${directory.path}/$filename";

    // Save to local storage
    final savedFile = File(savePath);
    await savedFile.writeAsBytes(img.encodeJpg(finalImage));

    return savePath;
  }
}
