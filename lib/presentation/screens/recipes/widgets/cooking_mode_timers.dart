import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shoply/data/services/notification_service.dart';

/// Local notifications for cooking timers. Overridden in tests.
abstract interface class CookingTimerAlerts {
  /// Plans the notification [id] for [at].
  Future<void> schedule({
    required int id,
    required String title,
    required String body,
    required DateTime at,
  });

  /// Drops the planned notification [id].
  Future<void> cancel(int id);
}

/// [CookingTimerAlerts] through the app's [NotificationService]; failures
/// are logged, never shown (the timer in the screen keeps running).
class NotificationCookingAlerts implements CookingTimerAlerts {
  const NotificationCookingAlerts();

  @override
  Future<void> schedule({
    required int id,
    required String title,
    required String body,
    required DateTime at,
  }) async {
    try {
      await NotificationService.instance.scheduleNotification(
        id: id,
        title: title,
        body: body,
        scheduledFor: at,
      );
    } catch (e) {
      debugPrint('⚠️ [COOKING] Timer notification not planned: $e');
    }
  }

  @override
  Future<void> cancel(int id) async {
    try {
      await NotificationService.instance.cancel(id);
    } catch (e) {
      debugPrint('⚠️ [COOKING] Timer notification not cancelled: $e');
    }
  }
}

/// How the cooking mode plans its timer notifications.
final cookingTimerAlertsProvider = Provider<CookingTimerAlerts>(
  (ref) => const NotificationCookingAlerts(),
);

/// The wall clock of the cooking timers; overridden in tests.
final cookingClockProvider = Provider<DateTime Function()>(
  (ref) => DateTime.now,
);

/// First notification id of the cooking timers; one id per step after it
/// (the old single timer used 700100).
const int kCookingTimerNotificationBase = 700100;

/// Highest step index that gets its own notification id.
const int _maxNotificationStep = 98;

/// The notification id of the timer of step [step] (0-based).
int cookingTimerNotificationId(int step) =>
    kCookingTimerNotificationBase + step.clamp(0, _maxNotificationStep);

/// One step timer. The remaining time is computed from a wall-clock end
/// time, so it stays right while iOS suspends the app.
@immutable
class CookingTimer {
  const CookingTimer({
    required this.step,
    required this.total,
    this.endsAt,
    this.pausedLeft,
  }) : assert((endsAt == null) != (pausedLeft == null));

  /// The step (0-based instruction index) the timer belongs to.
  final int step;

  /// The time it was started with.
  final Duration total;

  /// End on the wall clock while running.
  final DateTime? endsAt;

  /// Time left while paused.
  final Duration? pausedLeft;

  bool get running => endsAt != null;

  /// Time left at [now], never negative.
  Duration left(DateTime now) {
    final end = endsAt;
    if (end == null) return pausedLeft ?? Duration.zero;
    final d = end.difference(now);
    return d.isNegative ? Duration.zero : d;
  }

  /// Ran out (only a running timer can).
  bool finishedAt(DateTime now) {
    final end = endsAt;
    return end != null && !end.isAfter(now);
  }

  Map<String, dynamic> toJson() => {
    'step': step,
    'total': total.inSeconds,
    if (endsAt != null) 'endsAt': endsAt!.toIso8601String(),
    if (pausedLeft != null) 'pausedLeft': pausedLeft!.inSeconds,
  };

  /// Null for a broken entry.
  static CookingTimer? fromJson(Object? json) {
    if (json is! Map) return null;
    final step = json['step'];
    final total = json['total'];
    final endsAt = DateTime.tryParse('${json['endsAt'] ?? ''}');
    final paused = json['pausedLeft'];
    if (step is! int || total is! int) return null;
    if (endsAt == null && paused is! int) return null;
    return CookingTimer(
      step: step,
      total: Duration(seconds: total),
      endsAt: endsAt,
      pausedLeft: endsAt == null ? Duration(seconds: paused as int) : null,
    );
  }
}

/// All timers of one cooking session (several may run at once, Konzept 13
/// §16.3). Ticks once a second while one runs, plans and drops the local
/// notifications, and reports a timer that ran out once through
/// [onFinished]. Finished timers stay until [acknowledge].
class CookingTimers extends ChangeNotifier {
  CookingTimers({
    required this.alerts,
    required this.notificationTitle,
    required this.notificationBody,
    DateTime Function()? clock,
    this.onFinished,
  }) : _clock = clock ?? DateTime.now;

  final CookingTimerAlerts alerts;

  /// Title of the notification for a step ("Ofengemüse mit Feta").
  final String Function(int step) notificationTitle;

  /// Body of the notification for a step ("Schritt 3 fertig.").
  final String Function(int step) notificationBody;

  /// Called once per timer when it runs out while the screen is open.
  void Function(int step)? onFinished;

  final DateTime Function() _clock;
  final Map<int, CookingTimer> _timers = {};
  final Set<int> _announced = {};
  Timer? _ticker;
  bool _disposed = false;

  /// The current time, for widgets that show the remaining time.
  DateTime get now => _clock();

  /// All timers, the one that ends first first (finished ones lead).
  List<CookingTimer> get timers {
    final now = _clock();
    final list = _timers.values.toList()
      ..sort((a, b) => a.left(now).compareTo(b.left(now)));
    return list;
  }

  bool get isEmpty => _timers.isEmpty;

  /// Any timer still counting down.
  bool get anyRunning {
    final now = _clock();
    return _timers.values.any((t) => t.running && !t.finishedAt(now));
  }

  /// The timer of [step], if any.
  CookingTimer? forStep(int step) => _timers[step];

  /// Whether the timer of [step] ran out.
  bool isFinished(int step) => _timers[step]?.finishedAt(_clock()) ?? false;

  /// Starts a timer of [duration] for [step]. Does nothing while that step
  /// already has one (no second start).
  void start(int step, Duration duration) {
    if (_timers.containsKey(step) || duration <= Duration.zero) return;
    final endsAt = _clock().add(duration);
    _timers[step] = CookingTimer(step: step, total: duration, endsAt: endsAt);
    _announced.remove(step);
    _plan(step, endsAt);
    _changed();
  }

  void pause(int step) {
    final t = _timers[step];
    if (t == null || !t.running || t.finishedAt(_clock())) return;
    _timers[step] = CookingTimer(
      step: step,
      total: t.total,
      pausedLeft: t.left(_clock()),
    );
    unawaited(alerts.cancel(cookingTimerNotificationId(step)));
    _changed();
  }

  void resume(int step) {
    final t = _timers[step];
    if (t == null || t.running) return;
    final endsAt = _clock().add(t.pausedLeft ?? Duration.zero);
    _timers[step] = CookingTimer(step: step, total: t.total, endsAt: endsAt);
    _plan(step, endsAt);
    _changed();
  }

  /// One more minute; a finished timer starts again with one minute.
  void addMinute(int step) {
    final t = _timers[step];
    if (t == null) return;
    const minute = Duration(minutes: 1);
    final now = _clock();
    final CookingTimer next;
    if (t.running) {
      final base = t.finishedAt(now) ? now : t.endsAt!;
      next = CookingTimer(
        step: step,
        total: t.total + minute,
        endsAt: base.add(minute),
      );
      _plan(step, next.endsAt!);
    } else {
      next = CookingTimer(
        step: step,
        total: t.total + minute,
        pausedLeft: (t.pausedLeft ?? Duration.zero) + minute,
      );
    }
    _announced.remove(step);
    _timers[step] = next;
    _changed();
  }

  /// Stops and removes the timer of [step] and its notification.
  void stop(int step) {
    if (_timers.remove(step) == null) return;
    _announced.remove(step);
    unawaited(alerts.cancel(cookingTimerNotificationId(step)));
    _changed();
  }

  /// Removes a finished timer ("Schritt 3 fertig" tapped away).
  void acknowledge(int step) {
    if (!isFinished(step)) return;
    _timers.remove(step);
    _announced.remove(step);
    _changed();
  }

  /// Stops every timer (cooking finished or started over).
  void stopAll() {
    for (final step in _timers.keys.toList()) {
      unawaited(alerts.cancel(cookingTimerNotificationId(step)));
    }
    _timers.clear();
    _announced.clear();
    _changed();
  }

  /// Takes over saved timers (reopening the cooking mode). Their
  /// notifications are still planned.
  void restore(Iterable<CookingTimer> saved) {
    for (final t in saved) {
      _timers[t.step] = t;
      // Timers that ran out while the screen was closed are not announced
      // again; their capsule says so.
      if (t.finishedAt(_clock())) _announced.add(t.step);
    }
    _changed();
  }

  /// Checks for timers that ran out (also called on resume from the
  /// background).
  void tick() {
    if (_disposed) return;
    final now = _clock();
    for (final t in _timers.values) {
      if (t.finishedAt(now) && _announced.add(t.step)) {
        onFinished?.call(t.step);
      }
    }
    notifyListeners();
    _syncTicker();
  }

  void _plan(int step, DateTime at) {
    unawaited(
      alerts.schedule(
        id: cookingTimerNotificationId(step),
        title: notificationTitle(step),
        body: notificationBody(step),
        at: at,
      ),
    );
  }

  void _changed() {
    if (_disposed) return;
    notifyListeners();
    _syncTicker();
  }

  /// Ticks only while a timer counts down.
  void _syncTicker() {
    final needed = anyRunning;
    if (needed && _ticker == null) {
      _ticker = Timer.periodic(const Duration(seconds: 1), (_) => tick());
    } else if (!needed && _ticker != null) {
      _ticker!.cancel();
      _ticker = null;
    }
  }

  @override
  void dispose() {
    // Notifications stay planned: timers run on after the screen closed
    // (Konzept 13 §19.2) and come back with the saved progress.
    _disposed = true;
    _ticker?.cancel();
    _ticker = null;
    super.dispose();
  }
}
