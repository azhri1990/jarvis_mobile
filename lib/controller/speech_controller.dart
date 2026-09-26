import 'dart:async';

import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart';

class SpeechController extends ChangeNotifier {
  final SpeechToText _speechToText = SpeechToText();
  static const _silenceTimeout = Duration(milliseconds: 1500);
  Timer? _silenceTimer;
  bool _speechEnabled = false;
  String _lastWords = '';
  bool _sessionActive = false;
  bool _heardCommand = false;

  Future<void> Function(String command)? onFinalCommand;

  /// Called once when a listening session ends. [heardCommand] is false when
  /// the session timed out without recognizing any words.
  void Function(bool heardCommand)? onSessionEnded;

  bool get speechEnabled => _speechEnabled;
  String get lastWords => _lastWords;
  bool get isListening => _speechToText.isListening;

  SpeechController() {
    _initSpeech();
  }

  Future _initSpeech() async {
    try {
      _speechEnabled = await _speechToText.initialize(
        onStatus: (status) {
          debugPrint('Speech status: $status');
          if (status == 'done' || status == 'notListening') {
            _endSession();
          }
        },
        onError: (error) {
          debugPrint('Speech error: ${error.errorMsg}');
          _endSession();
        },
      );
    } catch (e) {
      debugPrint('Error in initialization $e');
    }

    notifyListeners();
  }

  /// Some Android recognizers never emit a `finalResult`, so a short silence
  /// after partial words is also treated as the end of the user's turn.
  void _scheduleSilenceSubmit() {
    _silenceTimer?.cancel();
    _silenceTimer = Timer(_silenceTimeout, () {
      _submitHeardWords();
      _speechToText.stop();
    });
  }

  void _submitHeardWords() {
    _silenceTimer?.cancel();
    if (_heardCommand || !_sessionActive) return;
    final command = _lastWords.trim();
    if (command.isEmpty) return;
    _heardCommand = true;
    onFinalCommand?.call(command);
    notifyListeners();
  }

  void _endSession() {
    if (!_sessionActive) {
      notifyListeners();
      return;
    }
    _submitHeardWords();
    _sessionActive = false;
    final heard = _heardCommand;
    notifyListeners();
    onSessionEnded?.call(heard);
  }

  Future<void> startListening() async {
    if (!_speechEnabled || _speechToText.isListening) return;
    _lastWords = '';
    _heardCommand = false;
    _sessionActive = true;
    await _speechToText.listen(
      listenFor: const Duration(seconds: 30),
      pauseFor: const Duration(seconds: 3),
      onResult: (result) {
        if (_heardCommand) return;
        _lastWords = result.recognizedWords;
        notifyListeners();

        if (result.finalResult) {
          _submitHeardWords();
        } else if (_lastWords.trim().isNotEmpty) {
          _scheduleSilenceSubmit();
        }
      },
    );
    await Future.delayed(const Duration(milliseconds: 100));
    notifyListeners();
  }

  Future<void> stopListening() async {
    _submitHeardWords();
    await _speechToText.stop();
    notifyListeners();
  }

  Future<void> cancelListening() async {
    _silenceTimer?.cancel();
    _sessionActive = false;
    await _speechToText.cancel();
    notifyListeners();
  }
}
