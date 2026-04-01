import '../models/item.dart';
import 'photo_service.dart';

/// Detects potential duplicate items by comparing perceptual image hashes.
class DuplicateDetectionService {
  final PhotoService _photoService;

  DuplicateDetectionService(this._photoService);

  /// Returns all [existingItems] whose primary photo is visually similar
  /// to [newImagePath] above [threshold] (0–1).
  Future<List<Item>> findDuplicates({
    required String newImagePath,
    required List<Item> existingItems,
    double threshold = 0.85,
  }) async {
    final newHash = await _photoService.perceptualHash(newImagePath);
    if (newHash == null) return [];

    final duplicates = <Item>[];
    for (final item in existingItems) {
      final primary = item.primaryPhotoPath;
      if (primary == null) continue;
      final existingHash = await _photoService.perceptualHash(primary);
      if (existingHash == null) continue;
      final sim = PhotoService.similarity(newHash, existingHash);
      if (sim >= threshold) duplicates.add(item);
    }
    return duplicates;
  }

  /// Same as [findDuplicates] but also compares name similarity as a fallback.
  Future<List<Item>> findDuplicatesByNameOrPhoto({
    required String newImagePath,
    required String newName,
    required List<Item> existingItems,
    double photoThreshold = 0.85,
    double nameThreshold = 0.8,
  }) async {
    final byPhoto = await findDuplicates(
      newImagePath: newImagePath,
      existingItems: existingItems,
      threshold: photoThreshold,
    );
    final byName = existingItems.where((item) {
      final sim = _nameSimilarity(newName.toLowerCase(), item.displayName.toLowerCase());
      return sim >= nameThreshold;
    }).toList();

    // Union of both lists, deduplicated
    final ids = <String>{};
    final result = <Item>[];
    for (final item in [...byPhoto, ...byName]) {
      if (ids.add(item.id)) result.add(item);
    }
    return result;
  }

  /// Simple Dice coefficient for string similarity.
  double _nameSimilarity(String a, String b) {
    if (a == b) return 1.0;
    if (a.length < 2 || b.length < 2) return 0.0;
    final aBigrams = _bigrams(a);
    final bBigrams = _bigrams(b);
    int intersection = 0;
    final bCopy = List<String>.from(bBigrams);
    for (final bg in aBigrams) {
      final idx = bCopy.indexOf(bg);
      if (idx >= 0) {
        intersection++;
        bCopy.removeAt(idx);
      }
    }
    return (2.0 * intersection) / (aBigrams.length + bBigrams.length);
  }

  List<String> _bigrams(String s) {
    final result = <String>[];
    for (int i = 0; i < s.length - 1; i++) {
      result.add(s.substring(i, i + 2));
    }
    return result;
  }
}
