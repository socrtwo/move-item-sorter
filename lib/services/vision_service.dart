import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../core/constants.dart';

/// Result from image recognition.
class VisionResult {
  /// Best guessed item name/description.
  final String? itemLabel;
  /// Confidence score 0–1.
  final double? confidence;
  /// Raw label list from the API.
  final List<String> allLabels;
  /// Detected text in the image (OCR).
  final String? detectedText;
  /// If a barcode was found, its value.
  final String? barcodeValue;
  /// Product name from barcode lookup (if available).
  final String? barcodeProductName;
  /// Suggested price range from web knowledge (if available).
  final String? suggestedPriceRange;
  final String? error;

  const VisionResult({
    this.itemLabel,
    this.confidence,
    this.allLabels = const [],
    this.detectedText,
    this.barcodeValue,
    this.barcodeProductName,
    this.suggestedPriceRange,
    this.error,
  });

  bool get hasResult => itemLabel != null || barcodeProductName != null;

  String get bestName => barcodeProductName ?? itemLabel ?? 'Unknown item';
}

/// Calls the Google Cloud Vision API to identify items from photos.
class VisionService {
  final Dio _dio;

  VisionService() : _dio = Dio();

  /// Analyse [imageFile] using Google Vision. Returns a [VisionResult].
  Future<VisionResult> identifyItem(File imageFile, String apiKey) async {
    if (apiKey.isEmpty) {
      return const VisionResult(error: 'Google Vision API key not configured.');
    }

    try {
      final bytes = await imageFile.readAsBytes();
      final base64Image = base64Encode(bytes);

      final response = await _dio.post(
        '${AppConstants.googleVisionEndpoint}?key=$apiKey',
        data: {
          'requests': [
            {
              'image': {'content': base64Image},
              'features': [
                {'type': 'LABEL_DETECTION', 'maxResults': 10},
                {'type': 'OBJECT_LOCALIZATION', 'maxResults': 5},
                {'type': 'TEXT_DETECTION', 'maxResults': 1},
                {'type': 'WEB_DETECTION', 'maxResults': 5},
              ],
            }
          ]
        },
        options: Options(
          headers: {'Content-Type': 'application/json'},
          sendTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 15),
        ),
      );

      return _parseResponse(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      return VisionResult(error: 'Network error: ${e.message}');
    } catch (e) {
      return VisionResult(error: 'Vision API error: $e');
    }
  }

  VisionResult _parseResponse(Map<String, dynamic> data) {
    final responses = data['responses'] as List?;
    if (responses == null || responses.isEmpty) {
      return const VisionResult(error: 'Empty response from Vision API');
    }

    final r = responses.first as Map<String, dynamic>;

    // Labels
    final labelAnnotations = r['labelAnnotations'] as List? ?? [];
    final allLabels = labelAnnotations
        .map((l) => (l as Map)['description'] as String)
        .toList();

    // Best label (highest score)
    String? topLabel;
    double? topScore;
    if (labelAnnotations.isNotEmpty) {
      final first = labelAnnotations.first as Map;
      topLabel = first['description'] as String?;
      topScore = (first['score'] as num?)?.toDouble();
    }

    // Object localisation (often more specific than labels)
    final objects = r['localizedObjectAnnotations'] as List? ?? [];
    if (objects.isNotEmpty) {
      final obj = objects.first as Map;
      final objName = obj['name'] as String?;
      final objScore = (obj['score'] as num?)?.toDouble() ?? 0;
      if (objName != null && (topScore == null || objScore > topScore)) {
        topLabel = objName;
        topScore = objScore;
      }
    }

    // OCR text
    final textAnnotations = r['textAnnotations'] as List? ?? [];
    final detectedText = textAnnotations.isNotEmpty
        ? (textAnnotations.first as Map)['description'] as String?
        : null;

    // Web detection — best guess label
    final webDetection = r['webDetection'] as Map?;
    final bestGuess = (webDetection?['bestGuessLabels'] as List?)?.firstOrNull;
    final webLabel = bestGuess != null ? (bestGuess as Map)['label'] as String? : null;
    if (webLabel != null && webLabel.isNotEmpty) {
      topLabel = webLabel; // web guess is usually most accurate
    }

    return VisionResult(
      itemLabel: topLabel,
      confidence: topScore,
      allLabels: allLabels,
      detectedText: detectedText,
    );
  }

  /// Estimate price for an identified item via a simple web search heuristic.
  /// In production this would call a pricing API (e.g. eBay Finding API).
  Future<double?> estimatePrice(String itemName, String? openAiApiKey) async {
    if (openAiApiKey == null || openAiApiKey.isEmpty) return null;
    // Delegate to AI service — see AiService.estimatePrice
    return null;
  }
}
