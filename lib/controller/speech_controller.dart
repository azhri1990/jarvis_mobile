import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart';

class SpeechController extends ChangeNotifier {
  final SpeechToText _speechToText = SpeechToText();
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

  void _endSession() {
    if (!_sessionActive) {
      notifyListeners();
      return;
    }
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
        _lastWords = result.recognizedWords;
        notifyListeners();

        if (result.finalResult) {
          final command = _lastWords.trim();
          if (command.isNotEmpty) {
            _heardCommand = true;
            onFinalCommand?.call(command);
          }
          notifyListeners();
        }
      },
    );
    await Future.delayed(const Duration(milliseconds: 100));
    notifyListeners();
  }

  Future<void> stopListening() async {
    await _speechToText.stop();
    notifyListeners();
  }

  Future<void> cancelListening() async {
    _sessionActive = false;
    await _speechToText.cancel();
    notifyListeners();
  }
}
