import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shoply/data/models/calorie_day.dart';
import 'package:shoply/data/services/calorie_write_queue.dart';

class _Clock {
  DateTime now = DateTime.utc(2026, 11, 7, 12);
  void advance(Duration d) => now = now.add(d);
}

/// Records every timer the queue asks for instead of waiting.
class _Timers {
  final List<Duration> requested = [];
  Timer call(Duration d, void Function() _) {
    requested.add(d);
    return Timer(const Duration(days: 365), () {});
  }
}

/// Executor that fails with [errors] in order, then succeeds.
class _Server {
  _Server([List<Object>? errors]) : errors = errors ?? [];
  final List<Object> errors;
  final List<String> calls = [];

  Future<void> call(QueuedWrite w) async {
    calls.add('${w.op.name}:${w.kind}:${w.entityId}');
    if (errors.isNotEmpty) throw errors.removeAt(0);
  }
}

QueuedWrite _upsert(String id, {String day = '2026-11-07', bool create = true}) => QueuedWrite.upsert(
      kind: 'food',
      entityId: id,
      dateKey: day,
      payload: {'id': id, 'calories': 300},
      isCreate: create,
    );

const _offline = CalorieDataException(CalorieErrorCode.network);
const _rejected = CalorieDataException(CalorieErrorCode.rejected);

void main() {
  late SharedPreferences prefs;
  late _Clock clock;
  late _Timers timers;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    clock = _Clock();
    timers = _Timers();
  });

  CalorieWriteQueue queue(_Server server) => CalorieWriteQueue(
        prefs: prefs,
        storageKey: 'q_test',
        executor: server.call,
        now: () => clock.now,
        timerFactory: timers.call,
      );

  test('backoff is 2, 4, 8, 16, 30 s and then every 60 s', () {
    expect(
      [for (var a = 1; a <= 8; a++) CalorieWriteQueue.delayAfterAttempt(a).inSeconds],
      [2, 4, 8, 16, 30, 60, 60, 60],
    );
  });

  test('a write that succeeds leaves the queue', () async {
    final server = _Server();
    final q = queue(server);
    await q.enqueue(_upsert('a'));
    expect(server.calls, ['upsert:food:a']);
    expect(q.writes, isEmpty);
  });

  test('offline writes are retried on the backoff schedule with a fake clock', () async {
    final server = _Server([_offline, _offline, _offline]);
    final q = queue(server);

    await q.enqueue(_upsert('a'));
    expect(server.calls.length, 1);
    expect(q.writes.single.status, QueuedWriteStatus.pending);
    expect(q.writes.single.attempts, 1);
    expect(timers.requested.last, const Duration(seconds: 2));

    // Not due yet: nothing happens.
    clock.advance(const Duration(seconds: 1));
    await q.processDue();
    expect(server.calls.length, 1);

    clock.advance(const Duration(seconds: 1));
    await q.processDue();
    expect(server.calls.length, 2);
    expect(timers.requested.last, const Duration(seconds: 4));

    clock.advance(const Duration(seconds: 4));
    await q.processDue();
    expect(server.calls.length, 3);
    expect(timers.requested.last, const Duration(seconds: 8));

    clock.advance(const Duration(seconds: 8));
    await q.processDue();
    expect(server.calls.length, 4);
    expect(q.writes, isEmpty);
  });

  test('after the fifth failure it keeps trying every 60 s and stays pending', () async {
    final server = _Server(List.filled(7, _offline));
    final q = queue(server);
    await q.enqueue(_upsert('a'));
    for (final s in [2, 4, 8, 16, 30, 60]) {
      clock.advance(Duration(seconds: s));
      await q.processDue();
    }
    expect(server.calls.length, 7);
    expect(q.writes.single.status, QueuedWriteStatus.pending);
    expect(timers.requested.last, const Duration(seconds: 60));
  });

  test('a rejected write fails for good and only retries when asked', () async {
    final server = _Server([_rejected]);
    final q = queue(server);
    await q.enqueue(_upsert('a'));
    expect(q.writes.single.status, QueuedWriteStatus.failed);
    expect(q.writes.single.errorCode, CalorieErrorCode.rejected);

    clock.advance(const Duration(minutes: 10));
    await q.processDue();
    expect(server.calls.length, 1);

    await q.retry(q.writes.single.id);
    expect(server.calls.length, 2);
    expect(q.writes, isEmpty);
  });

  test('writes for the same row keep their order behind a waiting one', () async {
    final server = _Server([_offline]);
    final q = queue(server);
    await q.enqueue(_upsert('a'));
    await q.enqueue(_upsert('b'));
    await q.enqueue(QueuedWrite.delete(kind: 'food', entityId: 'a', dateKey: '2026-11-07'));
    // b goes through, a waits for its backoff, the delete waits behind a.
    expect(server.calls, ['upsert:food:a', 'upsert:food:b']);
    clock.advance(const Duration(seconds: 2));
    await q.processDue();
    expect(server.calls, ['upsert:food:a', 'upsert:food:b', 'delete:food:a']);
    expect(q.writes, isEmpty);
  });

  test('deleting a row that never reached the server sends nothing', () async {
    final server = _Server();
    final q = queue(server)..pause();
    await q.enqueue(_upsert('a'));
    await q.enqueue(QueuedWrite.delete(kind: 'food', entityId: 'a', dateKey: '2026-11-07'));
    expect(q.writes, isEmpty);
    q.resume();
    await q.processDue();
    expect(server.calls, isEmpty);
  });

  test('a newer upsert replaces an older one for the same row', () async {
    final server = _Server();
    final q = queue(server)..pause();
    await q.enqueue(_upsert('a'));
    await q.enqueue(QueuedWrite.upsert(
      kind: 'food',
      entityId: 'a',
      dateKey: '2026-11-07',
      payload: {'id': 'a', 'calories': 450},
    ));
    expect(q.writes.single.payload['calories'], 450);
    expect(q.writes.single.isCreate, isTrue);
  });

  test('the queue survives a restart', () async {
    final first = queue(_Server([_offline]));
    await first.enqueue(_upsert('a'));
    first.dispose();

    final server = _Server();
    final second = queue(server);
    expect(second.writes.single.entityId, 'a');
    expect(second.writes.single.attempts, 1);
    clock.advance(const Duration(seconds: 2));
    await second.processDue();
    expect(server.calls, ['upsert:food:a']);
    expect(second.writes, isEmpty);
    expect(prefs.getString('q_test'), '[]');
  });

  test('retryAll makes waiting writes due now (connection is back)', () async {
    final server = _Server([_offline]);
    final q = queue(server);
    await q.enqueue(_upsert('a'));
    await q.retryAll();
    expect(server.calls.length, 2);
    expect(q.writes, isEmpty);
  });

  test('reports which rows of a day are pending or failed', () async {
    final server = _Server([_offline, _rejected]);
    final q = queue(server);
    await q.enqueue(_upsert('a'));
    await q.enqueue(_upsert('b'));
    await q.enqueue(_upsert('c', day: '2026-11-06'));
    expect(q.syncStatesFor('2026-11-07'), {
      'a': CalorieSyncState.pending,
      'b': CalorieSyncState.failed,
    });
    expect(q.syncStatesFor('2026-11-06'), isEmpty);
  });

  test('emits the queue on every change', () async {
    final q = queue(_Server());
    final seen = <int>[];
    final sub = q.changes.listen((w) => seen.add(w.length));
    await q.enqueue(_upsert('a'));
    await Future<void>.delayed(Duration.zero);
    await sub.cancel();
    expect(seen, [1, 0]);
  });
}
