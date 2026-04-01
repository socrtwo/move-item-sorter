import 'package:flutter_tts/flutter_tts.dart';

import '../models/app_settings.dart';

/// Text-to-speech feedback service.
class TtsService {
  final FlutterTts _tts = FlutterTts();
  bool _isReady = false;

  Future<void> initialize(AppSettings settings) async {
    await _tts.setLanguage('en-US');
    await _tts.setSpeechRate(settings.ttsRate);
    await _tts.setVolume(settings.ttsVolume);
    await _tts.setPitch(1.0);
    _isReady = true;
  }

  Future<void> speak(String text, {required AppSettings settings}) async {
    if (!_isReady || !settings.ttsEnabled) return;
    await _tts.stop();
    await _tts.speak(text);
  }

  Future<void> stop() async {
    await _tts.stop();
  }

  Future<void> updateSettings(AppSettings settings) async {
    await _tts.setSpeechRate(settings.ttsRate);
    await _tts.setVolume(settings.ttsVolume);
  }

  // ---- Canned responses ----

  Future<void> sayItemCaptured(String itemName, {required AppSettings s}) =>
      speak('Item captured: $itemName', settings: s);

  Future<void> sayCategorized(String itemName, String category, String? subCat,
      {required AppSettings s}) {
    final sub = subCat != null ? ', $subCat' : '';
    return speak('$itemName categorized as $category$sub', settings: s);
  }

  Future<void> sayQuestion(String question, {required AppSettings s}) =>
      speak(question, settings: s);

  Future<void> sayPrice(double price, {required AppSettings s}) =>
      speak('Suggested price: \$${price.toStringAsFixed(2)}', settings: s);

  Future<void> sayListingCreated(String marketplace, {required AppSettings s}) =>
      speak('Listing created on $marketplace', settings: s);

  Future<void> sayReadyToCapture({required AppSettings s}) =>
      speak('Ready to capture. Say "new item" or take a photo.', settings: s);

  void dispose() {
    _tts.stop();
  }
}
