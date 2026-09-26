import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

class TtsController extends ChangeNotifier {
  final FlutterTts _tts = FlutterTts();
  bool _enabled = true;
  bool _speaking = false;

  bool get enabled => _enabled;
  bool get isSpeaking => _speaking;

  TtsController() {
    _init();
  }

  Future<void> _init() async {
    try {
      await _tts.setLanguage('en-GB');
      await _tts.setSpeechRate(0.5);
      await _tts.setPitch(0.9);
      if (defaultTargetPlatform == TargetPlatform.iOS) {
        await _tts.setSharedInstance(true);
        await _tts.setIosAudioCategory(
          IosTextToSpeechAudioCategory.playback,
          [IosTextToSpeechAudioCategoryOptions.mixWithOthers],
        );
      }
      _tts.setStartHandler(() => _setSpeaking(true));
      _tts.setCompletionHandler(() => _setSpeaking(false));
      _tts.setCancelHandler(() => _setSpeaking(false));
      _tts.setErrorHandler((_) => _setSpeaking(false));
    } catch (error) {
      debugPrint('TTS init error: $error');
    }
  }

  void _setSpeaking(bool value) {
    if (_speaking == value) return;
    _speaking = value;
    notifyListeners();
  }

  Future<void> speak(String text) async {
    final message = text.trim();
    if (!_enabled || message.isEmpty) return;
    await _tts.stop();
    await _tts.speak(message);
  }

  Future<void> stop() async {
    await _tts.stop();
    _setSpeaking(false);
  }

  void toggle() {
    _enabled = !_enabled;
    if (!_enabled) stop();
    notifyListeners();
  }

  @override
  void dispose() {
    _tts.stop();
    super.dispose();
  }
}
