/// Voice-search controller and feature flag.
///
/// Disabled on web (speech_to_text is unreliable in browsers).
/// Status: docs/search/status.md.
library;

import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_to_text.dart';

/// False on web; true everywhere else. Callers hide the mic button when false.
const kVoiceSearchEnabled = !kIsWeb;

/// Wraps [SpeechToText] for the search page.
///
/// Usage:
///   final ctrl = VoiceSearchController();
///   await ctrl.init();            // once, e.g. in initState
///   await ctrl.start(localeId: 'en_IN', onResult: …);
///   await ctrl.stop();
///   ctrl.dispose();               // in dispose()
class VoiceSearchController {
  final _stt = SpeechToText();
  bool _available = false;
  bool _listening = false;

  /// Fires whenever [isListening] changes.
  VoidCallback? onStateChanged;

  bool get isListening => _listening;

  /// True after a successful [init] call.
  bool get isAvailable => _available;

  Future<bool> init() async {
    _available = await _stt.initialize(
      onError: (_) => _setListening(false),
      onStatus: (s) {
        if (s == SpeechToText.doneStatus ||
            s == SpeechToText.notListeningStatus) {
          _setListening(false);
        }
      },
    );
    return _available;
  }

  /// Starts listening. [localeId] should be a BCP-47 tag, e.g. `'hi_IN'`.
  /// [onResult] is called with (recognisedWords, isFinal).
  Future<void> start({
    required String localeId,
    required void Function(String text, bool isFinal) onResult,
  }) async {
    if (!_available) return;
    _setListening(true);
    await _stt.listen(
      onResult: (r) {
        onResult(r.recognizedWords, r.finalResult);
        if (r.finalResult) _setListening(false);
      },
      localeId: localeId,
      listenOptions: SpeechListenOptions(
        cancelOnError: true,
        partialResults: true,
      ),
    );
  }

  Future<void> stop() async {
    await _stt.stop();
    _setListening(false);
  }

  void dispose() {
    _stt.cancel();
  }

  void _setListening(bool value) {
    if (_listening == value) return;
    _listening = value;
    onStateChanged?.call();
  }
}
