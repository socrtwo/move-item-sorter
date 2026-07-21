import 'dart:convert';
import 'package:dio/dio.dart';
import '../core/constants.dart';

/// Wraps OpenAI GPT-4o for item descriptions, price estimation, and title generation.
class AiService {
  final Dio _dio = Dio();

  Future<String?> _chat(String systemPrompt, String userMessage, String apiKey) async {
    if (apiKey.isEmpty) return null;
    try {
      final resp = await _dio.post(
        AppConstants.openAiEndpoint,
        data: {
          'model': AppConstants.openAiModel,
          'messages': [
            {'role': 'system', 'content': systemPrompt},
            {'role': 'user',   'content': userMessage},
          ],
          'max_tokens': 400,
          'temperature': 0.7,
        },
        options: Options(
          headers: {
            'Authorization': 'Bearer $apiKey',
            'Content-Type': 'application/json',
          },
          sendTimeout: const Duration(seconds: 20),
          receiveTimeout: const Duration(seconds: 20),
        ),
      );
      final choices = (resp.data as Map)['choices'] as List?;
      return choices?.isNotEmpty == true
          ? (choices!.first as Map)['message']['content'] as String?
          : null;
    } catch (_) {
      return null;
    }
  }

  /// Generate a marketplace listing description for [itemName].
  /// Returns the description, or null on failure.
  Future<String?> generateDescription({
    required String itemName,
    required String marketplace,
    String? condition,
    String? voiceNotes,
    required String apiKey,
  }) async {
    final condStr = condition != null ? ', condition: $condition' : '';
    final notesStr = voiceNotes != null ? ' Additional notes: $voiceNotes' : '';
    return _chat(
      'You write concise, compelling marketplace listing descriptions. '
      'Use plain text, no markdown. 3–5 sentences max.',
      'Write a listing description for: $itemName (marketplace: $marketplace$condStr).$notesStr',
      apiKey,
    );
  }

  /// Suggest a selling price for [itemName] based on marketplace and condition.
  Future<double?> estimatePrice({
    required String itemName,
    required String marketplace,
    String? condition,
    required String apiKey,
  }) async {
    final condStr = condition != null ? ', condition: $condition' : '';
    final resp = await _chat(
      'You are a pricing expert. Reply with ONLY a number (USD, no \$ sign, no explanation).',
      'What is a reasonable selling price for: $itemName on $marketplace$condStr?',
      apiKey,
    );
    if (resp == null) return null;
    return double.tryParse(resp.trim().replaceAll(RegExp(r'[^\d.]'), ''));
  }

  /// Generate a short, SEO-friendly listing title (max 80 chars).
  Future<String?> generateTitle({
    required String itemName,
    required String marketplace,
    String? condition,
    required String apiKey,
  }) async {
    final condStr = condition != null ? ', $condition condition' : '';
    return _chat(
      'You write short marketplace listing titles. Max 80 characters, no emojis.',
      'Title for: $itemName on $marketplace$condStr',
      apiKey,
    );
  }

  /// Estimate current fair-market value for insurance purposes.
  Future<double?> estimateInsuranceValue({
    required String itemName,
    required String apiKey,
  }) async {
    final resp = await _chat(
      'You are an insurance appraiser. Reply with ONLY a number (USD replacement value, no \$ sign).',
      'Replacement value for: $itemName',
      apiKey,
    );
    if (resp == null) return null;
    return double.tryParse(resp.trim().replaceAll(RegExp(r'[^\d.]'), ''));
  }
}
