import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shoply/data/services/native/native_channel_errors.dart';
import 'package:shoply/data/services/native/voice_channel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const method = MethodChannel('shoply/voice');
  const eventChannel = EventChannel('shoply/voice/events');
  const levelChannel = EventChannel('shoply/voice/levels');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  final calls = <MethodCall>[];

  void answer(Object? Function(MethodCall call) reply) {
    messenger.setMockMethodCallHandler(method, (call) async {
      calls.add(call);
      return reply(call);
    });
  }

  void emit(
    EventChannel channel,
    void Function(MockStreamHandlerEventSink sink) send,
  ) {
    messenger.setMockStreamHandler(
      channel,
      MockStreamHandler.inline(onListen: (arguments, sink) => send(sink)),
    );
  }

  setUp(calls.clear);

  tearDown(() {
    messenger.setMockMethodCallHandler(method, null);
    messenger.setMockStreamHandler(eventChannel, null);
    messenger.setMockStreamHandler(levelChannel, null);
  });

  VoiceChannel ios() => VoiceChannel(isSupported: () => true);
  VoiceChannel other() => VoiceChannel(isSupported: () => false);

  group('permissions', () {
    test('parses both permissions', () async {
      answer((_) => {'microphone': 'granted', 'speech': 'authorized'});

      final permissions = await ios().permissions();

      expect(calls.single.method, 'permissions');
      expect(permissions.microphone, MicrophonePermission.granted);
      expect(permissions.speech, SpeechPermission.authorized);
      expect(permissions.allGranted, isTrue);
    });

    test('only one permission counts as not granted', () async {
      answer((_) => {'microphone': 'granted', 'speech': 'denied'});

      final permissions = await ios().requestPermissions();

      expect(calls.single.method, 'requestPermissions');
      expect(permissions.speech, SpeechPermission.denied);
      expect(permissions.allGranted, isFalse);
    });

    test('unknown values count as not determined', () async {
      answer((_) => {'microphone': 'maybe'});

      final permissions = await ios().permissions();

      expect(permissions.microphone, MicrophonePermission.notDetermined);
      expect(permissions.speech, SpeechPermission.notDetermined);
    });

    test('is denied without a channel call on other platforms', () async {
      answer((_) => {'microphone': 'granted', 'speech': 'authorized'});

      final permissions = await other().requestPermissions();

      expect(permissions.allGranted, isFalse);
      expect(permissions.microphone, MicrophonePermission.denied);
      expect(permissions.speech, SpeechPermission.restricted);
      expect(calls, isEmpty);
    });
  });

  group('recognitionSupport', () {
    test('sends the locale and parses the answer', () async {
      answer((_) => {'available': true, 'onDevice': true});

      final support = await ios().recognitionSupport('de-DE');

      expect(calls.single.method, 'recognitionSupport');
      expect(calls.single.arguments, {'locale': 'de-DE'});
      expect(support.available, isTrue);
      expect(support.onDevice, isTrue);
    });

    test('is unavailable when the native side is missing', () async {
      final support = await ios().recognitionSupport('de-DE');

      expect(support.available, isFalse);
      expect(support.onDevice, isFalse);
    });
  });

  group('listening', () {
    test('startListening sends locale, silence and on-device settings', () async {
      answer((_) => true);

      final started = await ios().startListening(locale: 'de-DE');

      expect(started, isTrue);
      expect(calls.single.method, 'startListening');
      expect(calls.single.arguments, {
        'locale': 'de-DE',
        'silenceMs': 1000,
        'autoEndOnSilence': true,
        'requireOnDevice': true,
        'noSpeechTimeoutMs': 8000,
      });
    });

    test('VoiceOver mode turns the automatic sentence end off', () async {
      answer((_) => true);

      await ios().startListening(
        locale: 'en-US',
        autoEndOnSilence: false,
        silence: const Duration(milliseconds: 1200),
      );

      expect(calls.single.arguments, containsPair('autoEndOnSilence', false));
      expect(calls.single.arguments, containsPair('silenceMs', 1200));
    });

    test('startListening is false when recognition is unavailable', () async {
      answer((_) => throw PlatformException(code: 'unavailable'));

      expect(await ios().startListening(locale: 'de-DE'), isFalse);
    });

    test('startListening throws permissionDenied without permission', () async {
      answer((_) => throw PlatformException(code: 'permission_denied'));

      await expectLater(
        ios().startListening(locale: 'de-DE'),
        throwsA(
          isA<NativeChannelException>().having(
            (e) => e.code,
            'code',
            NativeErrorCode.permissionDenied,
          ),
        ),
      );
    });

    test('stop and cancel use their own methods', () async {
      answer((_) => null);

      await ios().stopListening();
      await ios().cancelListening();

      expect(calls.map((c) => c.method), ['stopListening', 'cancelListening']);
    });
  });

  group('speaking', () {
    test('speak sends text, voice and rate and waits for the end', () async {
      answer((_) => 'finished');

      final outcome = await ios().speak(
        'Ich habe drei Rezepte gefunden.',
        voiceId: 'com.apple.voice.premium.de-DE.Anna',
        locale: 'de-DE',
        rate: 1.1,
      );

      expect(outcome, VoiceSpeakOutcome.finished);
      expect(calls.single.method, 'speak');
      expect(calls.single.arguments, {
        'text': 'Ich habe drei Rezepte gefunden.',
        'voiceId': 'com.apple.voice.premium.de-DE.Anna',
        'locale': 'de-DE',
        'rate': 1.1,
      });
    });

    test('an interrupted answer is cancelled', () async {
      answer((_) => 'cancelled');

      expect(await ios().speak('Hallo'), VoiceSpeakOutcome.cancelled);
      expect(calls.single.arguments, {'text': 'Hallo'});
    });

    test('speak is unavailable on other platforms', () async {
      expect(await other().speak('Hallo'), VoiceSpeakOutcome.unavailable);
      expect(calls, isEmpty);
    });

    test('voices parses the installed voices', () async {
      answer(
        (_) => [
          {
            'id': 'com.apple.voice.premium.de-DE.Anna',
            'name': 'Anna',
            'language': 'de-DE',
            'quality': 'premium',
          },
          {'id': 'x', 'name': 'Y', 'language': 'de-AT', 'quality': 'odd'},
          {'name': 'no id'},
        ],
      );

      final voices = await ios().voices(language: 'de');

      expect(calls.single.arguments, {'language': 'de'});
      expect(voices, hasLength(2));
      expect(voices.first.quality, VoiceQuality.premium);
      expect(voices.last.quality, VoiceQuality.standard);
    });

    test('session helpers call native', () async {
      answer((_) => null);

      await ios().stopSpeaking();
      await ios().pauseSpeaking();
      await ios().resumeSpeaking();
      await ios().setKeepScreenOn(true);
      await ios().endSession();

      expect(calls.map((c) => c.method), [
        'stopSpeaking',
        'pauseSpeaking',
        'resumeSpeaking',
        'setKeepScreenOn',
        'endSession',
      ]);
      expect(calls[3].arguments, {'on': true});
    });

    test('session helpers are silent when the native side is missing', () async {
      await ios().endSession();
      await other().setKeepScreenOn(true);
    });
  });

  group('events', () {
    test('parses every event type and skips unknown ones', () async {
      emit(eventChannel, (sink) {
        sink.success({'type': 'partial', 'text': 'Setz Milch'});
        sink.success({'type': 'mystery'});
        sink.success({
          'type': 'final',
          'text': 'Setz Milch auf die Liste.',
          'reason': 'silence',
        });
        sink.success({'type': 'speechStart'});
        sink.success({'type': 'word', 'location': 4, 'length': 5});
        sink.success({'type': 'ttsPaused', 'reason': 'voiceOver'});
        sink.success({'type': 'ttsResumed'});
        sink.success({'type': 'speechEnd', 'status': 'cancelled'});
        sink.success({'type': 'interrupted', 'reason': 'background'});
        sink.success({'type': 'error', 'code': 'failed', 'message': 'x'});
      });

      final events = await ios().events.take(9).toList();

      expect(events[0], isA<VoicePartial>().having((e) => e.text, 'text', 'Setz Milch'));
      expect(
        events[1],
        isA<VoiceFinal>()
            .having((e) => e.text, 'text', 'Setz Milch auf die Liste.')
            .having((e) => e.reason, 'reason', VoiceEndReason.silence),
      );
      expect(events[2], isA<VoiceSpeechStarted>());
      expect(
        events[3],
        isA<VoiceWordSpoken>()
            .having((e) => e.location, 'location', 4)
            .having((e) => e.length, 'length', 5),
      );
      expect(events[4], isA<VoiceTtsPaused>());
      expect(events[5], isA<VoiceTtsResumed>());
      expect(
        events[6],
        isA<VoiceSpeechEnded>().having(
          (e) => e.outcome,
          'outcome',
          VoiceSpeakOutcome.cancelled,
        ),
      );
      expect(
        events[7],
        isA<VoiceInterrupted>().having(
          (e) => e.reason,
          'reason',
          VoiceInterruptReason.background,
        ),
      );
      expect(
        events[8],
        isA<VoiceError>().having((e) => e.code, 'code', NativeErrorCode.failed),
      );
    });

    test('no speech ends with an empty final transcript', () async {
      emit(eventChannel, (sink) {
        sink.success({'type': 'final', 'text': '', 'reason': 'noSpeech'});
      });

      final event = await ios().events.first;

      expect(
        event,
        isA<VoiceFinal>()
            .having((e) => e.text, 'text', '')
            .having((e) => e.reason, 'reason', VoiceEndReason.noSpeech),
      );
    });

    test('a stream error becomes a VoiceError event', () async {
      emit(eventChannel, (sink) {
        sink.error(code: 'permission_denied', message: 'mic');
      });

      final event = await ios().events.first;

      expect(
        event,
        isA<VoiceError>().having(
          (e) => e.code,
          'code',
          NativeErrorCode.permissionDenied,
        ),
      );
    });

    test('levels are clamped and malformed ones skipped', () async {
      emit(levelChannel, (sink) {
        sink.success({'source': 'mic', 'level': 0.5});
        sink.success({'source': 'tts', 'level': 1.7});
        sink.success({'source': 'mic'});
        sink.success({'source': 'mic', 'level': -1});
      });

      final levels = await ios().levels.take(3).toList();

      expect(levels.map((l) => l.source), [
        VoiceLevelSource.mic,
        VoiceLevelSource.tts,
        VoiceLevelSource.mic,
      ]);
      expect(levels.map((l) => l.level), [0.5, 1.0, 0.0]);
    });

    test('streams are empty on other platforms', () async {
      await expectLater(other().events, emitsDone);
      await expectLater(other().levels, emitsDone);
    });
  });
}
