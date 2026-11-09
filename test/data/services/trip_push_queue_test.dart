import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:shoply/data/services/trip_push_queue.dart';

void main() {
  late List<String> sent;
  late SharedPreferences prefs;

  /// [now]: a fixed clock for the fake-time tests (the timers run on the
  /// test's fake time, so nothing depends on how busy the machine is).
  TripPushQueue queue({DateTime Function()? now}) => TripPushQueue(
    send:
        ({
          required List<String> userIds,
          required String title,
          required String body,
          Map<String, dynamic>? data,
        }) async => sent.add(body),
    prefs: () async => prefs,
    now: now,
  );

  DeferredTripPush push(String trip, Duration wait, {DateTime? from}) =>
      DeferredTripPush(
        tripId: trip,
        userIds: const ['lena'],
        title: 'WG',
        body: 'Jannis hat bei Lidl eingekauft ($trip).',
        data: const {'type': 'shopping_complete'},
        notBefore: (from ?? DateTime.now()).add(wait),
      );

  final t0 = DateTime(2026, 11, 9, 12);

  Future<void> wait(int ms) => Future<void>.delayed(Duration(milliseconds: ms));

  setUp(() async {
    sent = [];
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  // testWidgets for its fake clock: the undo window is two minutes of fake
  // time, advanced with pump; no real timers.
  testWidgets('waits for the undo window, then sends once', (tester) async {
    final q = queue(now: () => t0);
    await q.enqueue(push('t1', const Duration(minutes: 2), from: t0));
    await tester.pump(const Duration(seconds: 119));
    expect(sent, isEmpty);
    expect(prefs.getString(TripPushQueue.storageKey), isNotNull);
    await tester.pump(const Duration(seconds: 1));
    expect(sent, ['Jannis hat bei Lidl eingekauft (t1).']);
    expect(prefs.getString(TripPushQueue.storageKey), isNull);
    await tester.pump(const Duration(minutes: 5));
    expect(sent, hasLength(1), reason: 'sent once');
    q.dispose();
  });

  testWidgets('"Widerrufen" cancels the push', (tester) async {
    final q = queue(now: () => t0);
    await q.enqueue(push('t1', const Duration(minutes: 2), from: t0));
    await q.cancel('t1');
    await tester.pump(const Duration(minutes: 5));
    expect(sent, isEmpty);
    q.dispose();
  });

  test('release sends at once when the toast is gone', () async {
    final q = queue();
    await q.enqueue(push('t1', const Duration(minutes: 2)));
    await q.release('t1');
    await wait(20);
    expect(sent, hasLength(1));
    q.dispose();
  });

  test('a push kept when the app closed goes out at the next start', () async {
    final first = queue();
    await first.enqueue(push('t1', const Duration(milliseconds: 10)));
    first.dispose(); // the app is gone before the timer fires
    expect(prefs.getString(TripPushQueue.storageKey), isNotNull);

    await wait(30);
    final next = queue();
    await next.flushDue();
    await wait(20);
    expect(sent, hasLength(1));
    next.dispose();
  });
}
