import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import 'package:shoply/data/models/calorie_day.dart';

enum QueuedWriteOp { upsert, delete }

/// `pending` = waiting for (another) try; `failed` = the server refused it
/// for good, the row shows "Nicht gespeichert" until the user taps retry.
enum QueuedWriteStatus { pending, failed }

/// One optimistic write waiting for the server. [kind] names the table
/// family (`food`, `water`, `workout`, `weight`, `goal`, `checkin`,
/// `user_food`), [payload] is the full row for an upsert.
class QueuedWrite {
  final String id;
  final String kind;
  final QueuedWriteOp op;
  final String entityId;

  /// Local day the row belongs to (drives the sync marker in the diary);
  /// null for writes without a day (goal).
  final String? dateKey;
  final Map<String, dynamic> payload;

  /// The row did not exist before this write: deleting it before it was
  /// ever sent means nothing has to reach the server.
  final bool isCreate;
  final int attempts;
  final DateTime? nextAttemptAt;
  final QueuedWriteStatus status;
  final CalorieErrorCode? errorCode;

  const QueuedWrite._({
    required this.id,
    required this.kind,
    required this.op,
    required this.entityId,
    required this.dateKey,
    required this.payload,
    required this.isCreate,
    this.attempts = 0,
    this.nextAttemptAt,
    this.status = QueuedWriteStatus.pending,
    this.errorCode,
  });

  factory QueuedWrite.upsert({
    required String kind,
    required String entityId,
    required String? dateKey,
    required Map<String, dynamic> payload,
    bool isCreate = false,
  }) =>
      QueuedWrite._(
        id: const Uuid().v4(),
        kind: kind,
        op: QueuedWriteOp.upsert,
        entityId: entityId,
        dateKey: dateKey,
        payload: payload,
        isCreate: isCreate,
      );

  factory QueuedWrite.delete({
    required String kind,
    required String entityId,
    required String? dateKey,
    Map<String, dynamic> payload = const {},
  }) =>
      QueuedWrite._(
        id: const Uuid().v4(),
        kind: kind,
        op: QueuedWriteOp.delete,
        entityId: entityId,
        dateKey: dateKey,
        payload: payload,
        isCreate: false,
      );

  String get rowKey => '$kind:$entityId';

  QueuedWrite _copy({
    QueuedWriteOp? op,
    Map<String, dynamic>? payload,
    bool? isCreate,
    String? dateKey,
    int? attempts,
    DateTime? nextAttemptAt,
    bool clearNextAttempt = false,
    QueuedWriteStatus? status,
    CalorieErrorCode? errorCode,
    bool clearError = false,
  }) =>
      QueuedWrite._(
        id: id,
        kind: kind,
        op: op ?? this.op,
        entityId: entityId,
        dateKey: dateKey ?? this.dateKey,
        payload: payload ?? this.payload,
        isCreate: isCreate ?? this.isCreate,
        attempts: attempts ?? this.attempts,
        nextAttemptAt: clearNextAttempt ? null : (nextAttemptAt ?? this.nextAttemptAt),
        status: status ?? this.status,
        errorCode: clearError ? null : (errorCode ?? this.errorCode),
      );

  factory QueuedWrite.fromJson(Map<String, dynamic> json) => QueuedWrite._(
        id: json['id'] as String,
        kind: json['kind'] as String,
        op: json['op'] == 'delete' ? QueuedWriteOp.delete : QueuedWriteOp.upsert,
        entityId: json['entity'] as String,
        dateKey: json['day'] as String?,
        payload: (json['payload'] as Map?)?.cast<String, dynamic>() ?? const {},
        isCreate: json['create'] as bool? ?? false,
        attempts: json['attempts'] as int? ?? 0,
        nextAttemptAt:
            json['next'] == null ? null : DateTime.parse(json['next'] as String),
        status: json['status'] == 'failed'
            ? QueuedWriteStatus.failed
            : QueuedWriteStatus.pending,
        errorCode: CalorieErrorCode.values
            .where((c) => c.name == json['error'])
            .firstOrNull,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'kind': kind,
        'op': op.name,
        'entity': entityId,
        'day': dateKey,
        'payload': payload,
        'create': isCreate,
        'attempts': attempts,
        'next': nextAttemptAt?.toIso8601String(),
        'status': status.name,
        'error': errorCode?.name,
      };
}

typedef QueuedWriteExecutor = Future<void> Function(QueuedWrite write);
typedef QueueTimerFactory = Timer Function(Duration delay, void Function() callback);

/// SharedPreferences key of [userId]'s calorie write queue. Builds before
/// the per-account queue used the plain [legacyCalorieWriteQueueKey].
String calorieWriteQueueKey(String userId) =>
    '${legacyCalorieWriteQueueKey}_$userId';

/// The queue key without an account (old builds, tests).
const String legacyCalorieWriteQueueKey = 'cal_write_queue_v1';

/// Persistent, offline-safe write queue for the calories module (concept
/// 15 2.1 "Optimistisch"). Writes run in order per row; network trouble is
/// retried after 2, 4, 8, 16, 30 s and then every 60 s, a refusal by the
/// server marks the write `failed` until [retry]. Stored as JSON in
/// SharedPreferences (no database package, `pubspec.yaml` comments).
class CalorieWriteQueue {
  CalorieWriteQueue({
    required SharedPreferences prefs,
    required QueuedWriteExecutor executor,
    this.storageKey = legacyCalorieWriteQueueKey,
    DateTime Function()? now,
    QueueTimerFactory? timerFactory,
  })  : _prefs = prefs,
        _executor = executor,
        _now = now ?? DateTime.now,
        _timerFactory = timerFactory ?? Timer.new {
    _load();
    _schedule();
  }

  static const List<int> _backoffSeconds = [2, 4, 8, 16, 30];
  static const Duration maxDelay = Duration(seconds: 60);

  /// Wait after the [attempts]-th failed try.
  static Duration delayAfterAttempt(int attempts) {
    if (attempts < 1) return Duration.zero;
    if (attempts > _backoffSeconds.length) return maxDelay;
    return Duration(seconds: _backoffSeconds[attempts - 1]);
  }

  final SharedPreferences _prefs;
  final QueuedWriteExecutor _executor;
  final String storageKey;
  final DateTime Function() _now;
  final QueueTimerFactory _timerFactory;

  final List<QueuedWrite> _writes = [];
  final _changes = StreamController<List<QueuedWrite>>.broadcast();
  Timer? _timer;
  bool _running = false;
  bool _rerun = false;
  bool _paused = false;
  bool _disposed = false;
  String? _inFlightId;

  List<QueuedWrite> get writes => List.unmodifiable(_writes);

  Stream<List<QueuedWrite>> get changes => _changes.stream;

  bool get isEmpty => _writes.isEmpty;

  /// Pending/failed rows of [dateKey] by entity id (failed wins).
  Map<String, CalorieSyncState> syncStatesFor(String dateKey) {
    final states = <String, CalorieSyncState>{};
    for (final w in _writes) {
      if (w.dateKey != dateKey) continue;
      final s = w.status == QueuedWriteStatus.failed
          ? CalorieSyncState.failed
          : CalorieSyncState.pending;
      if (states[w.entityId] != CalorieSyncState.failed) states[w.entityId] = s;
    }
    return states;
  }

  /// Writes still waiting for [dateKey], oldest first.
  List<QueuedWrite> writesFor(String dateKey) =>
      _writes.where((w) => w.dateKey == dateKey).toList(growable: false);

  /// Adds [write] (merged with earlier writes for the same row), stores the
  /// queue and runs whatever is due.
  Future<void> enqueue(QueuedWrite write) async {
    _merge(write);
    await _persistAndEmit();
    await processDue();
  }

  void _merge(QueuedWrite write) {
    final earlier = <int>[
      for (var i = 0; i < _writes.length; i++)
        if (_writes[i].rowKey == write.rowKey && _writes[i].id != _inFlightId) i,
    ];
    if (earlier.isEmpty) {
      _writes.add(write);
      return;
    }
    final first = _writes[earlier.first];
    if (write.op == QueuedWriteOp.delete &&
        first.isCreate &&
        earlier.every((i) => _writes[i].attempts == 0) &&
        !_writes.any((w) => w.id == _inFlightId && w.rowKey == write.rowKey)) {
      // Never reached the server: forget the row entirely.
      for (final i in earlier.reversed) {
        _writes.removeAt(i);
      }
      return;
    }
    // Keep the first write's place and backoff, carry the newest content.
    final failed = first.status == QueuedWriteStatus.failed;
    _writes[earlier.first] = first._copy(
      op: write.op,
      payload: write.payload,
      dateKey: write.dateKey,
      isCreate: write.op == QueuedWriteOp.upsert && first.isCreate && first.op == QueuedWriteOp.upsert,
      status: QueuedWriteStatus.pending,
      clearNextAttempt: failed,
      clearError: failed,
    );
    for (final i in earlier.skip(1).toList().reversed) {
      _writes.removeAt(i);
    }
  }

  /// Runs every write whose time has come, oldest first, one row at a time.
  Future<void> processDue() async {
    if (_disposed || _paused) return;
    if (_running) {
      _rerun = true;
      return;
    }
    _running = true;
    try {
      do {
        _rerun = false;
        await _runPass();
      } while (_rerun && !_disposed && !_paused);
    } finally {
      _running = false;
      _schedule();
    }
  }

  Future<void> _runPass() async {
    final blocked = <String>{};
    for (final write in List.of(_writes)) {
      if (_disposed || _paused) return;
      if (!_writes.any((w) => w.id == write.id)) continue;
      final current = _writes.firstWhere((w) => w.id == write.id);
      final due = current.nextAttemptAt == null || !current.nextAttemptAt!.isAfter(_now());
      if (blocked.contains(current.rowKey) ||
          current.status == QueuedWriteStatus.failed ||
          !due) {
        blocked.add(current.rowKey);
        continue;
      }
      _inFlightId = current.id;
      try {
        await _executor(current);
        _inFlightId = null;
        _writes.removeWhere((w) => w.id == current.id);
      } catch (e) {
        _inFlightId = null;
        final error = CalorieDataException.from(e);
        final index = _writes.indexWhere((w) => w.id == current.id);
        if (index < 0) continue;
        final attempts = current.attempts + 1;
        debugPrint('⚠️ [CalorieQueue] ${current.kind} ${current.op.name} failed '
            '(attempt $attempts, ${error.code.name})');
        _writes[index] = error.retryable
            ? current._copy(
                attempts: attempts,
                nextAttemptAt: _now().add(delayAfterAttempt(attempts)),
                errorCode: error.code,
              )
            : current._copy(
                attempts: attempts,
                status: QueuedWriteStatus.failed,
                errorCode: error.code,
                clearNextAttempt: true,
              );
        blocked.add(current.rowKey);
      }
      await _persistAndEmit();
    }
  }

  /// User tapped a "Nicht gespeichert" row.
  Future<void> retry(String writeId) async {
    final i = _writes.indexWhere((w) => w.id == writeId);
    if (i < 0) return;
    _writes[i] = _writes[i]._copy(
      status: QueuedWriteStatus.pending,
      clearNextAttempt: true,
      clearError: true,
    );
    await _persistAndEmit();
    await processDue();
  }

  /// Connection is back: waiting writes are due now (failed ones stay).
  Future<void> retryAll() async {
    for (var i = 0; i < _writes.length; i++) {
      if (_writes[i].status == QueuedWriteStatus.pending) {
        _writes[i] = _writes[i]._copy(clearNextAttempt: true);
      }
    }
    await processDue();
  }

  void pause() {
    _paused = true;
    _timer?.cancel();
  }

  void resume() {
    _paused = false;
    _schedule();
  }

  void _schedule() {
    _timer?.cancel();
    _timer = null;
    if (_disposed || _paused) return;
    DateTime? next;
    for (final w in _writes) {
      if (w.status != QueuedWriteStatus.pending) continue;
      final at = w.nextAttemptAt ?? _now();
      if (next == null || at.isBefore(next)) next = at;
    }
    if (next == null) return;
    var delay = next.difference(_now());
    if (delay.isNegative) delay = Duration.zero;
    _timer = _timerFactory(delay, () => unawaited(processDue()));
  }

  void _load() {
    final raw = _prefs.getString(storageKey);
    if (raw == null) return;
    try {
      final list = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
      _writes.addAll(list.map(QueuedWrite.fromJson));
    } catch (e) {
      debugPrint('❌ [CalorieQueue] Stored queue unreadable, starting empty: ${e.runtimeType}');
    }
  }

  Future<void> _persistAndEmit() async {
    if (_disposed) return;
    await _prefs.setString(
      storageKey,
      jsonEncode(_writes.map((w) => w.toJson()).toList()),
    );
    if (!_changes.isClosed) _changes.add(writes);
  }

  void dispose() {
    _disposed = true;
    _timer?.cancel();
    _changes.close();
  }
}
