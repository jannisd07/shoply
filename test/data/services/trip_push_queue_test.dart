import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:shoply/data/services/trip_push_queue.dart';

void main() {
  late List<String> sent;
  late SharedPreferences prefs;

  TripPushQueue queue() => TripPushQueue(
    send:
        ({
          required List<String> userIds,
          required String title,
          required String body,
          Map<String, dynamic>? data,
        }) async => sent.add(body),
    prefs: () async => prefs,
  );

  DeferredTripPush push(String trip, Duration wait) => DeferredTripPush(
    tripId: trip,
    userIds: const ['lena'],
    title: 'WG',
    body: 'Jannis hat bei Lidl eingekauft ($trip).',
    data: const {'type': 'shopping_complete'},
    notBefore: DateTime.now().add(wait),
  );

  Future<void> wait(int ms) => Future<void>.delayed(Duration(milliseconds: ms));

  setUp(() async {
    sent = [];
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  test('waits for the undo window, then sends once', () async {
    final q = queue();
    await q.enqueue(push('t1', const Duration(milliseconds: 120)));
    await wait(30);
    expect(sent, isEmpty);
    await wait(200);
    expect(sent, ['Jannis hat bei Lidl eingekauft (t1).']);
    expect(prefs.getString(TripPushQueue.storageKey), isNull);
    q.dispose();
  });

  test('"Widerrufen" cancels the push', () async {
    final q = queue();
    await q.enqueue(push('t1', const Duration(milliseconds: 80)));
    await q.cancel('t1');
    await wait(150);
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
