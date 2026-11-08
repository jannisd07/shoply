import 'dart:async';

import 'package:flutter/services.dart';

import 'package:shoply/data/services/native/native_channel_errors.dart';

enum MicrophonePermission { notDetermined, granted, denied }

enum SpeechPermission { notDetermined, authorized, denied, restricted }

class VoicePermissions {
  const VoicePermissions({required this.microphone, required this.speech});

  final MicrophonePermission microphone;
  final SpeechPermission speech;

  /// Voice mode needs both; only one counts as refused (concept 16, ch. 11).
  bool get allGranted =>
      microphone == MicrophonePermission.granted &&
      speech == SpeechPermission.authorized;

  static VoicePermissions fromNative(Object? raw) {
    final map = nativeMap(raw);
    return VoicePermissions(
      microphone: MicrophonePermission.values.firstWhere(
        (p) => p.name == map?['microphone'],
        orElse: () => MicrophonePermission.notDetermined,
      ),
      speech: SpeechPermission.values.firstWhere(
        (p) => p.name == map?['speech'],
        orElse: () => SpeechPermission.notDetermined,
      ),
    );
  }
}

class VoiceRecognitionSupport {
  const VoiceRecognitionSupport({
    required this.available,
    required this.onDevice,
  });

  final bool available;

  /// Recognition runs on the iPhone. Only then is "Deine Stimme wird auf dem
  /// iPhone in Text umgewandelt" true.
  final bool onDevice;
}

enum VoiceSpeakOutcome { finished, cancelled, unavailable }

enum VoiceQuality { standard, enhanced, premium }

class VoiceOption {
  const VoiceOption({
    required this.id,
    required this.name,
    required this.language,
    required this.quality,
  });

  /// `AVSpeechSynthesisVoice.identifier`, passed back to [VoiceChannel.speak].
  final String id;
  final String name;
  final String language;
  final VoiceQuality quality;
}

/// Why listening ended with a [VoiceFinal].
enum VoiceEndReason {
  /// About one second of silence after speech (automatic sentence end).
  silence,

  /// [VoiceChannel.stopListening], e.g. "Zum Senden doppeltippen".
  stopped,

  /// Nothing was said before the no-speech timeout; the text is empty.
  noSpeech,
}

enum VoiceInterruptReason { background, audioInterruption }

/// Events of `shoply/voice/events`.
sealed class VoiceEvent {
  const VoiceEvent();

  static VoiceEvent? fromNative(Object? raw) {
    final map = nativeMap(raw);
    if (map == null) return null;
    final text = map['text'] as String? ?? '';
    return switch (map['type']) {
      'partial' => VoicePartial(text),
      'final' => VoiceFinal(
        text,
        VoiceEndReason.values.firstWhere(
          (r) => r.name == map['reason'],
          orElse: () => VoiceEndReason.stopped,
        ),
      ),
      'speechStart' => const VoiceSpeechStarted(),
      'speechEnd' => VoiceSpeechEnded(
        map['status'] == 'cancelled'
            ? VoiceSpeakOutcome.cancelled
            : VoiceSpeakOutcome.finished,
      ),
      'word' => VoiceWordSpoken(
        (map['location'] as num?)?.toInt() ?? 0,
        (map['length'] as num?)?.toInt() ?? 0,
      ),
      'ttsPaused' => const VoiceTtsPaused(),
      'ttsResumed' => const VoiceTtsResumed(),
      'interrupted' => VoiceInterrupted(
        map['reason'] == 'background'
            ? VoiceInterruptReason.background
            : VoiceInterruptReason.audioInterruption,
      ),
      'error' => VoiceError(
        nativeErrorCodeFrom(map['code'] as String? ?? ''),
        map['message'] as String?,
      ),
      _ => null,
    };
  }
}

/// The transcript so far (replaces the previous partial).
class VoicePartial extends VoiceEvent {
  const VoicePartial(this.text);
  final String text;
}

/// Listening ended; [text] is the full transcript.
class VoiceFinal extends VoiceEvent {
  const VoiceFinal(this.text, this.reason);
  final String text;
  final VoiceEndReason reason;
}

class VoiceSpeechStarted extends VoiceEvent {
  const VoiceSpeechStarted();
}

class VoiceSpeechEnded extends VoiceEvent {
  const VoiceSpeechEnded(this.outcome);
  final VoiceSpeakOutcome outcome;
}

/// The word Avo is saying now, as a UTF-16 range of the spoken text.
class VoiceWordSpoken extends VoiceEvent {
  const VoiceWordSpoken(this.location, this.length);
  final int location;
  final int length;
}

/// Avo's voice paused because VoiceOver started speaking.
class VoiceTtsPaused extends VoiceEvent {
  const VoiceTtsPaused();
}

class VoiceTtsResumed extends VoiceEvent {
  const VoiceTtsResumed();
}

/// Listening and speaking stopped (app went to the background, phone call).
class VoiceInterrupted extends VoiceEvent {
  const VoiceInterrupted(this.reason);
  final VoiceInterruptReason reason;
}

class VoiceError extends VoiceEvent {
  const VoiceError(this.code, [this.message]);
  final NativeErrorCode code;
  final String? message;
}

enum VoiceLevelSource { mic, tts }

/// One level value (0…1), about 30 per second, for the level bars.
class VoiceLevel {
  const VoiceLevel(this.source, this.level);

  final VoiceLevelSource source;
  final double level;

  static VoiceLevel? fromNative(Object? raw) {
    final map = nativeMap(raw);
    final level = map?['level'];
    if (level is! num) return null;
    return VoiceLevel(
      map?['source'] == 'tts' ? VoiceLevelSource.tts : VoiceLevelSource.mic,
      level.toDouble().clamp(0.0, 1.0),
    );
  }
}

/// Voice mode over `shoply/voice` (`VoiceChannel.swift`): Apple speech
/// recognition on the device, `AVSpeechSynthesizer` with ducking, level
/// meters and a pause while VoiceOver speaks. No network, no package.
///
/// Permissions are only asked in [requestPermissions] (after the "Sprich mit
/// Avo" screen), never by the other methods.
class VoiceChannel {
  VoiceChannel({
    MethodChannel channel = const MethodChannel('shoply/voice'),
    EventChannel events = const EventChannel('shoply/voice/events'),
    EventChannel levels = const EventChannel('shoply/voice/levels'),
    bool Function()? isSupported,
  }) : _channel = channel,
       _events = events,
       _levels = levels,
       _isSupported = isSupported ?? isIOSPlatform;

  static final VoiceChannel instance = VoiceChannel();

  static const _tag = 'VOICE';

  static const _refused = VoicePermissions(
    microphone: MicrophonePermission.denied,
    speech: SpeechPermission.restricted,
  );

  final MethodChannel _channel;
  final EventChannel _events;
  final EventChannel _levels;
  final bool Function() _isSupported;

  Future<T> _guard<T>(T fallback, Future<T> Function() call) =>
      guardNativeCall(
        supported: _isSupported(),
        fallback: fallback,
        tag: _tag,
        call: call,
      );

  Future<void> _invoke(String method, [Map<String, Object?>? args]) =>
      _guard<void>(null, () => _channel.invokeMethod<void>(method, args));

  Future<VoicePermissions> permissions() => _permissions('permissions');

  /// Asks for the microphone, then (only if granted) for speech recognition.
  Future<VoicePermissions> requestPermissions() =>
      _permissions('requestPermissions');

  Future<VoicePermissions> _permissions(String method) async {
    if (!_isSupported()) return _refused;
    final raw = await _guard<Object?>(
      _refused,
      () => _channel.invokeMethod<Object?>(method),
    );
    return raw is VoicePermissions ? raw : VoicePermissions.fromNative(raw);
  }

  /// Whether [locale] (e.g. `de-DE`) can be recognised, and on the device.
  Future<VoiceRecognitionSupport> recognitionSupport(String locale) async {
    final map = nativeMap(
      await _guard<Object?>(
        null,
        () => _channel.invokeMethod<Object?>('recognitionSupport', {
          'locale': locale,
        }),
      ),
    );
    return VoiceRecognitionSupport(
      available: map?['available'] == true,
      onDevice: map?['onDevice'] == true,
    );
  }

  /// Starts listening; transcripts arrive as [VoicePartial] / [VoiceFinal] on
  /// [events]. With [autoEndOnSilence] false (VoiceOver) only
  /// [stopListening] ends it. False when recognition is unavailable.
  Future<bool> startListening({
    required String locale,
    Duration silence = const Duration(seconds: 1),
    bool autoEndOnSilence = true,
    bool requireOnDevice = true,
    Duration noSpeechTimeout = const Duration(seconds: 8),
  }) => _guard(
    false,
    () async =>
        await _channel.invokeMethod<bool>('startListening', {
          'locale': locale,
          'silenceMs': silence.inMilliseconds,
          'autoEndOnSilence': autoEndOnSilence,
          'requireOnDevice': requireOnDevice,
          'noSpeechTimeoutMs': noSpeechTimeout.inMilliseconds,
        }) ??
        false,
  );

  /// Ends listening; the final transcript follows as [VoiceFinal].
  Future<void> stopListening() => _invoke('stopListening');

  /// Ends listening without a final transcript.
  Future<void> cancelListening() => _invoke('cancelListening');

  /// Speaks [text] and completes when it is finished or interrupted. Stops
  /// listening first, so Avo never hears itself. [rate] multiplies the
  /// default speaking rate.
  Future<VoiceSpeakOutcome> speak(
    String text, {
    String? voiceId,
    String? locale,
    double? rate,
  }) async {
    final raw = await _guard<String?>(
      'unavailable',
      () => _channel.invokeMethod<String>('speak', {
        'text': text,
        'voiceId': ?voiceId,
        'locale': ?locale,
        'rate': ?rate,
      }),
    );
    return switch (raw) {
      'finished' => VoiceSpeakOutcome.finished,
      'cancelled' => VoiceSpeakOutcome.cancelled,
      _ => VoiceSpeakOutcome.unavailable,
    };
  }

  /// Interrupts Avo's voice (tap on the figure).
  Future<void> stopSpeaking() => _invoke('stopSpeaking');

  /// Pauses Avo's voice, e.g. while the app posts a VoiceOver announcement.
  Future<void> pauseSpeaking() => _invoke('pauseSpeaking');

  Future<void> resumeSpeaking() => _invoke('resumeSpeaking');

  /// Installed voices for the Avo settings, optionally for one [language]
  /// (`de`, `en`).
  Future<List<VoiceOption>> voices({String? language}) async {
    final raw = await _guard<List<Object?>?>(
      null,
      () => _channel.invokeMethod<List<Object?>>('voices', {
        'language': ?language,
      }),
    );
    return [
      for (final entry in raw ?? const <Object?>[])
        if (nativeMap(entry) case final map?
            when map['id'] is String && map['name'] is String)
          VoiceOption(
            id: map['id'] as String,
            name: map['name'] as String,
            language: map['language'] as String? ?? '',
            quality: VoiceQuality.values.firstWhere(
              (q) => q.name == map['quality'],
              orElse: () => VoiceQuality.standard,
            ),
          ),
    ];
  }

  /// Keeps the screen on while voice mode is open.
  Future<void> setKeepScreenOn(bool on) =>
      _invoke('setKeepScreenOn', {'on': on});

  /// Leaving voice mode: stops everything, lets other audio return to full
  /// volume and allows the screen to sleep again.
  Future<void> endSession() => _invoke('endSession');

  /// Recognition and speech events. Empty on other platforms.
  Stream<VoiceEvent> get events {
    if (!_isSupported()) return const Stream.empty();
    return _events
        .receiveBroadcastStream()
        .map(VoiceEvent.fromNative)
        .transform(_platformErrorsAsEvents)
        .where((event) => event != null)
        .cast<VoiceEvent>();
  }

  /// Microphone and speech levels, about 30 per second. Empty on other
  /// platforms.
  Stream<VoiceLevel> get levels {
    if (!_isSupported()) return const Stream.empty();
    return _levels
        .receiveBroadcastStream()
        .handleError((Object _) {})
        .map(VoiceLevel.fromNative)
        .where((level) => level != null)
        .cast<VoiceLevel>();
  }

  static final _platformErrorsAsEvents =
      StreamTransformer<VoiceEvent?, VoiceEvent?>.fromHandlers(
        handleError: (error, stackTrace, sink) {
          if (error is PlatformException) {
            sink.add(VoiceError(nativeErrorCodeFrom(error.code), error.message));
          } else {
            sink.addError(error, stackTrace);
          }
        },
      );
}
