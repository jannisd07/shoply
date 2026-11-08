import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shoply/data/services/native/accessibility_channel.dart';
import 'package:shoply/presentation/providers/reduce_transparency_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const method = MethodChannel('shoply/accessibility');
  const events = EventChannel('shoply/accessibility/events');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  final calls = <MethodCall>[];

  void answer(Object? Function(MethodCall call) reply) {
    messenger.setMockMethodCallHandler(method, (call) async {
      calls.add(call);
      return reply(call);
    });
  }

  void emit(List<Object?> values) {
    messenger.setMockStreamHandler(
      events,
      MockStreamHandler.inline(
        onListen: (arguments, sink) {
          for (final value in values) {
            sink.success(value);
          }
        },
      ),
    );
  }

  setUp(calls.clear);

  tearDown(() {
    messenger.setMockMethodCallHandler(method, null);
    messenger.setMockStreamHandler(events, null);
  });

  AccessibilityChannel ios() => AccessibilityChannel(isSupported: () => true);

  group('isReduceTransparencyEnabled', () {
    test('returns the native value', () async {
      answer((_) => true);

      expect(await ios().isReduceTransparencyEnabled(), isTrue);
      expect(calls.single.method, 'isReduceTransparencyEnabled');
    });

    test('answers false without a channel call on other platforms', () async {
      answer((_) => true);

      final channel = AccessibilityChannel(isSupported: () => false);

      expect(await channel.isReduceTransparencyEnabled(), isFalse);
      expect(calls, isEmpty);
    });

    test('answers false when the native side is missing', () async {
      expect(await ios().isReduceTransparencyEnabled(), isFalse);
    });

    test('answers false when the native side fails', () async {
      answer((_) => throw PlatformException(code: 'failed'));

      expect(await ios().isReduceTransparencyEnabled(), isFalse);
    });
  });

  group('watchReduceTransparency', () {
    test('starts with the current value and drops repeats', () async {
      answer((_) => false);
      emit([
        {'reduceTransparency': false},
        {'reduceTransparency': true},
        {'reduceTransparency': true},
        {'reduceTransparency': false},
      ]);

      final values = await ios().watchReduceTransparency().take(3).toList();

      expect(values, [false, true, false]);
    });

    test('ignores malformed events', () async {
      answer((_) => false);
      emit([
        'nonsense',
        {'other': true},
        {'reduceTransparency': true},
      ]);

      final values = await ios().watchReduceTransparency().take(2).toList();

      expect(values, [false, true]);
    });

    test('emits false once and ends on other platforms', () async {
      final channel = AccessibilityChannel(isSupported: () => false);

      await expectLater(
        channel.watchReduceTransparency(),
        emitsInOrder([false, emitsDone]),
      );
      expect(calls, isEmpty);
    });
  });

  group('reduceTransparencyProvider', () {
    test('follows the native setting', () async {
      answer((_) => true);
      emit([
        {'reduceTransparency': true},
      ]);
      final container = ProviderContainer(
        overrides: [accessibilityChannelProvider.overrideWithValue(ios())],
      );
      addTearDown(container.dispose);

      final value = await container.read(reduceTransparencyProvider.future);

      expect(value, isTrue);
    });

    test('is false on platforms without the channel', () async {
      final container = ProviderContainer(
        overrides: [
          accessibilityChannelProvider.overrideWithValue(
            AccessibilityChannel(isSupported: () => false),
          ),
        ],
      );
      addTearDown(container.dispose);

      final value = await container.read(reduceTransparencyProvider.future);

      expect(value, isFalse);
    });
  });
}
