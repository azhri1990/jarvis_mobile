import 'dart:async';

import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart';

class SpeechController extends ChangeNotifier {
  final SpeechToText _speechToText = SpeechToText();
  static const _silenceTimeout = Duration(milliseconds: 1200);
  // Android often reports `notListening` before delivering the final words,
  // so the session stays open briefly to catch that late result.
  static const _lateResultGrace = Duration(milliseconds: 1200);

  Timer? _silenceTimer;
  Timer? _endTimer;
  bool _speechEnabled = false;
  String _lastWords = '';
  int _sessionId = 0;
  bool _sessionOpen = false;
  bool _submitted = false;

  Future<void> Function(String command)? onFinalCommand;

  /// Called once when a listening session ends. [heardCommand] is false when
  /// the session ended without recognizing any words.
  void Function(bool heardCommand)? onSessionEnded;

  bool get speechEnabled => _speechEnabled;
  String get lastWords => _lastWords;
  bool get isListening => _speechToText.isListening;

  SpeechController() {
    _initSpeech();
  }

  Future<void> _initSpeech() async {
    try {
      _speechEnabled = await _speechToText.initialize(
        onStatus: (status) {
          debugPrint('Speech status: $status');
          if (status == 'done' || status == 'notListening') {
            _scheduleSessionEnd();
          }
          notifyListeners();
        },
        onError: (error) {
          debugPrint('Speech error: ${error.errorMsg}');
          _scheduleSessionEnd();
          notifyListeners();
        },
      );
    } catch (e) {
      debugPrint('Error in initialization $e');
    }
    notifyListeners();
  }

  void _submit() {
    _silenceTimer?.cancel();
    if (!_sessionOpen || _submitted) return;
    final command = _lastWords.trim();
    if (command.isEmpty) return;
    _submitted = true;
    _lastWords = '';
    notifyListeners();
    onFinalCommand?.call(command);
    _finishSession();
  }

  void _scheduleSessionEnd() {
    if (!_sessionOpen || _submitted) return;
    if (_lastWords.trim().isNotEmpty) {
      _submit();
      return;
    }
    final id = _sessionId;
    _endTimer?.cancel();
    _endTimer = Timer(_lateResultGrace, () {
      if (id == _sessionId) _finishSession();
    });
  }

  void _finishSession() {
    if (!_sessionOpen) return;
    _endTimer?.cancel();
    _silenceTimer?.cancel();
    _sessionOpen = false;
    final heard = _submitted;
    notifyListeners();
    onSessionEnded?.call(heard);
  }

  void _handleResult(int id, String words, bool isFinal) {
    if (id != _sessionId || !_sessionOpen || _submitted) return;
    _lastWords = words;
    notifyListeners();
    if (words.trim().isEmpty) return;

    if (isFinal || !_speechToText.isListening) {
      _submit();
      return;
    }
    // Some recognizers never emit a final result; treat a short pause as the
    // end of the user's turn.
    _silenceTimer?.cancel();
    _silenceTimer = Timer(_silenceTimeout, () {
      if (id != _sessionId) return;
      _submit();
      _speechToText.stop();
    });
  }

  Future<void> startListening() async {
    if (!_speechEnabled || _speechToText.isListening) return;
    _endTimer?.cancel();
    _silenceTimer?.cancel();
    final id = ++_sessionId;
    _lastWords = '';
    _submitted = false;
    _sessionOpen = true;
    notifyListeners();
    await _speechToText.listen(
      listenFor: const Duration(seconds: 30),
      pauseFor: const Duration(seconds: 3),
      listenOptions: SpeechListenOptions(
        partialResults: true,
        cancelOnError: false,
        listenMode: ListenMode.dictation,
      ),
      onResult: (result) =>
          _handleResult(id, result.recognizedWords, result.finalResult),
    );
    await Future.delayed(const Duration(milliseconds: 100));
    notifyListeners();
  }

  Future<void> stopListening() async {
    await _speechToText.stop();
    _submit();
    _scheduleSessionEnd();
    notifyListeners();
  }

  Future<void> cancelListening() async {
    _sessionId++;
    _silenceTimer?.cancel();
    _endTimer?.cancel();
    _sessionOpen = false;
    _lastWords = '';
    await _speechToText.cancel();
    notifyListeners();
  }
}
