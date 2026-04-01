import 'dart:async';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../models/app_settings.dart';
import '../utils/keyword_matcher.dart';

enum SpeechState {
  idle,
  initializing,
  listening,
  processing,
  unavailable,
}

/// Wraps [SpeechToText] and continuously listens, emitting [VoiceCommandResult]s.
class SpeechService {
  final SpeechToText _stt = SpeechToText();
  final AppSettings _settings;

  SpeechState _state = SpeechState.idle;
  SpeechState get state => _state;

  // Streams
  final _commandController = StreamController<VoiceCommandResult>.broadcast();
  Stream<VoiceCommandResult> get commandStream => _commandController.stream;

  final _rawTranscriptController = StreamController<String>.broadcast();
  Stream<String> get rawTranscriptStream => _rawTranscriptController.stream;

  final _stateController = StreamController<SpeechState>.broadcast();
  Stream<SpeechState> get stateStream => _stateController.stream;

  bool _isAvailable = false;

  SpeechService(this._settings);

  Future<bool> initialize() async {
    _setState(SpeechState.initializing);
    _isAvailable = await _stt.initialize(
      onError: _onError,
      onStatus: _onStatus,
    );
    _setState(_isAvailable ? SpeechState.idle : SpeechState.unavailable);
    return _isAvailable;
  }

  /// Start continuous listening. Emits commands to [commandStream].
  Future<void> startListening() async {
    if (!_isAvailable || _state == SpeechState.listening) return;
    _setState(SpeechState.listening);

    await _stt.listen(
      onResult: _onResult,
      listenFor: Duration(seconds: _settings.speechListenTimeoutSeconds),
      pauseFor: const Duration(seconds: 3),
      partialResults: true,
      cancelOnError: false,
      listenMode: ListenMode.dictation,
    );
  }

  Future<void> stopListening() async {
    await _stt.stop();
    _setState(SpeechState.idle);
  }

  Future<void> cancelListening() async {
    await _stt.cancel();
    _setState(SpeechState.idle);
  }

  /// Listen for a single response, returning the first final result.
  Future<String?> listenOnce({int timeoutSeconds = 8}) async {
    if (!_isAvailable) return null;
    final completer = Completer<String?>();

    await _stt.listen(
      onResult: (result) {
        if (result.finalResult && !completer.isCompleted) {
          completer.complete(result.recognizedWords);
        }
      },
      listenFor: Duration(seconds: timeoutSeconds),
      pauseFor: const Duration(seconds: 3),
      partialResults: false,
      cancelOnError: true,
      listenMode: ListenMode.confirmation,
    );

    // Timeout
    Future.delayed(Duration(seconds: timeoutSeconds + 1), () {
      if (!completer.isCompleted) completer.complete(null);
    });

    return completer.future;
  }

  void _onResult(SpeechRecognitionResult result) {
    _rawTranscriptController.add(result.recognizedWords);

    if (result.finalResult) {
      _setState(SpeechState.processing);
      final matcher = KeywordMatcher(_settings);
      final command = matcher.match(result.recognizedWords);
      _commandController.add(command);
      // Resume listening after a short delay
      Future.delayed(const Duration(milliseconds: 500), () {
        if (_state != SpeechState.unavailable) {
          startListening();
        }
      });
    }
  }

  void _onError(SpeechRecognitionError error) {
    // Transient errors (no match, timeout) — restart listening.
    if (error.errorMsg == 'error_no_match' || error.errorMsg == 'error_speech_timeout') {
      Future.delayed(const Duration(milliseconds: 300), startListening);
    } else {
      _setState(SpeechState.unavailable);
    }
  }

  void _onStatus(String status) {
    if (status == 'done' && _state == SpeechState.listening) {
      // Auto-restart for continuous mode
      Future.delayed(const Duration(milliseconds: 200), startListening);
    }
  }

  void _setState(SpeechState state) {
    _state = state;
    _stateController.add(state);
  }

  void dispose() {
    _stt.cancel();
    _commandController.close();
    _rawTranscriptController.close();
    _stateController.close();
  }
}
