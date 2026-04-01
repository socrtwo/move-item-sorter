import 'dart:io';
import 'dart:math' as math;
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../core/constants.dart';

/// Handles photo storage, enhancement, and background removal.
class PhotoService {
  static const _uuid = Uuid();

  /// Save [sourceFile] into the app's dedicated photos directory.
  /// Returns the final stored path.
  Future<String> savePhoto(File sourceFile) async {
    final dir = await _photosDir();
    final ext = p.extension(sourceFile.path).isNotEmpty
        ? p.extension(sourceFile.path)
        : '.jpg';
    final dest = p.join(dir.path, '${_uuid.v4()}$ext');
    await sourceFile.copy(dest);
    return dest;
  }

  /// Save raw bytes (e.g. from camera plugin) as a JPEG.
  Future<String> saveBytes(List<int> bytes) async {
    final dir = await _photosDir();
    final dest = p.join(dir.path, '${_uuid.v4()}.jpg');
    await File(dest).writeAsBytes(bytes);
    return dest;
  }

  /// Auto-enhance: adjust brightness, contrast, and sharpen the image.
  /// Saves a new file next to the original and returns its path.
  Future<String?> enhancePhoto(String sourcePath) async {
    try {
      final bytes = await File(sourcePath).readAsBytes();
      img.Image? image = img.decodeImage(bytes);
      if (image == null) return null;

      // Auto-level brightness
      image = img.adjustColor(image, brightness: 1.05, contrast: 1.1, saturation: 1.05);
      // Sharpen slightly
      image = img.convolution(image, filter: [
        0, -1,  0,
       -1,  5, -1,
        0, -1,  0,
      ], div: 1, offset: 0);

      final dir = await _photosDir();
      final name = p.basenameWithoutExtension(sourcePath);
      final dest = p.join(dir.path, '${name}_enhanced.jpg');
      await File(dest).writeAsBytes(img.encodeJpg(image, quality: 90));
      return dest;
    } catch (_) {
      return null;
    }
  }

  /// Simple background removal via chroma/threshold masking.
  /// For production quality, delegate to Remove.bg API or similar.
  Future<String?> removeBackground(String sourcePath) async {
    try {
      final bytes = await File(sourcePath).readAsBytes();
      img.Image? image = img.decodeImage(bytes);
      if (image == null) return null;

      // Sample background colour from the four corners
      final corners = [
        image.getPixel(0, 0),
        image.getPixel(image.width - 1, 0),
        image.getPixel(0, image.height - 1),
        image.getPixel(image.width - 1, image.height - 1),
      ];
      // Average corner colour
      final avgR = corners.map((p) => p.r.toInt()).reduce((a, b) => a + b) ~/ 4;
      final avgG = corners.map((p) => p.g.toInt()).reduce((a, b) => a + b) ~/ 4;
      final avgB = corners.map((p) => p.b.toInt()).reduce((a, b) => a + b) ~/ 4;

      // Replace pixels within threshold of background colour with transparent
      const threshold = 40;
      final result = img.Image(width: image.width, height: image.height,
          numChannels: 4, backgroundColor: img.ColorUint8.rgba(255, 255, 255, 0));
      for (int y = 0; y < image.height; y++) {
        for (int x = 0; x < image.width; x++) {
          final px = image.getPixel(x, y);
          final dr = (px.r.toInt() - avgR).abs();
          final dg = (px.g.toInt() - avgG).abs();
          final db = (px.b.toInt() - avgB).abs();
          if (dr + dg + db < threshold * 3) {
            result.setPixelRgba(x, y, 255, 255, 255, 0);
          } else {
            result.setPixelRgba(x, y, px.r.toInt(), px.g.toInt(), px.b.toInt(), 255);
          }
        }
      }

      final dir = await _photosDir();
      final name = p.basenameWithoutExtension(sourcePath);
      final dest = p.join(dir.path, '${name}_nobg.png');
      await File(dest).writeAsBytes(img.encodePng(result));
      return dest;
    } catch (_) {
      return null;
    }
  }

  /// Compute a perceptual hash for duplicate detection.
  /// Returns a 64-bit hash as an integer.
  Future<int?> perceptualHash(String imagePath) async {
    try {
      final bytes = await File(imagePath).readAsBytes();
      img.Image? image = img.decodeImage(bytes);
      if (image == null) return null;

      // Resize to 9×8, convert to greyscale
      final small = img.copyResize(image, width: 9, height: 8);
      final grey = img.grayscale(small);

      // Compute row differences (dHash)
      int hash = 0;
      for (int y = 0; y < 8; y++) {
        for (int x = 0; x < 8; x++) {
          final left  = grey.getPixel(x,     y).r.toInt();
          final right = grey.getPixel(x + 1, y).r.toInt();
          hash = (hash << 1) | (left > right ? 1 : 0);
        }
      }
      return hash;
    } catch (_) {
      return null;
    }
  }

  /// Hamming distance between two hashes (lower = more similar).
  static int hammingDistance(int a, int b) {
    int xor = a ^ b;
    int dist = 0;
    while (xor != 0) {
      dist += xor & 1;
      xor >>= 1;
    }
    return dist;
  }

  /// Similarity 0–1 (1 = identical) from two perceptual hashes.
  static double similarity(int a, int b) =>
      1.0 - hammingDistance(a, b) / 64.0;

  Future<Directory> _photosDir() async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(base.path, AppConstants.photosSubDir));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  Future<void> deletePhoto(String path) async {
    final f = File(path);
    if (await f.exists()) await f.delete();
  }
}
