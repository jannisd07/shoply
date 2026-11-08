import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shoply/data/services/native/app_badge_channel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const method = MethodChannel('shoply/app');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final calls = <MethodCall>[];

  void answer(Object? Function(MethodCall call) reply) {
    messenger.setMockMethodCallHandler(method, (call) async {
      calls.add(call);
      return reply(call);
    });
  }

  setUp(calls.clear);
  tearDown(() => messenger.setMockMethodCallHandler(method, null));

  test('asks the native side to clear the badge', () async {
    answer((_) => null);

    await AppBadge(isSupported: () => true).clearBadge();

    expect(calls.map((c) => c.method), ['clearBadge']);
  });

  test('does nothing off iOS', () async {
    answer((_) => null);

    await AppBadge(isSupported: () => false).clearBadge();

    expect(calls, isEmpty);
  });

  test('swallows a missing channel and native errors', () async {
    await AppBadge(isSupported: () => true).clearBadge();

    answer((_) => throw PlatformException(code: 'failed'));
    await AppBadge(isSupported: () => true).clearBadge();

    expect(calls.map((c) => c.method), ['clearBadge']);
  });
}
