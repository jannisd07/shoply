import 'dart:async';
import 'dart:developer' show Timeline, TimelineTask;

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

/// One piece of start-up work, shown as `post:<name>` in the timeline.
@immutable
class StartupTask {
  const StartupTask(this.name, this.run);

  final String name;
  final FutureOr<void> Function() run;
}

/// Tasks that start together, [after] the first frame was rasterized.
@immutable
class StartupPhase {
  const StartupPhase({
    required this.name,
    required this.after,
    required this.tasks,
  });

  final String name;

  /// Offset from the first rasterized frame (not from the previous phase).
  final Duration after;

  final List<StartupTask> tasks;
}

/// Called when a start-up task throws. The task's siblings and the later
/// phases keep running.
typedef StartupErrorHandler =
    void Function(String task, Object error, StackTrace stack);

/// Runs everything that is not needed for the first frame, staggered after
/// it (Kap. 20 §2.2).
///
/// A phase starts at its offset whether or not the tasks of earlier phases
/// have finished, so one slow task (StoreKit, a hanging request) never
/// holds back the others. Tasks that depend on each other share a future
/// instead. [run] completes when every task has finished.
///
/// On a background launch iOS draws no frame, so nothing here runs until
/// the app comes to the foreground.
class StartupScheduler {
  StartupScheduler(
    List<StartupPhase> phases, {
    Future<void> Function()? firstFrame,
    StartupErrorHandler? onError,
  }) : _phases = List.unmodifiable(phases),
       _firstFrame =
           firstFrame ??
           (() => WidgetsBinding.instance.waitUntilFirstFrameRasterized),
       _onError = onError {
    var previous = Duration.zero;
    for (final phase in _phases) {
      if (phase.after < previous) {
        throw ArgumentError.value(
          phase.name,
          'phases',
          'must be ordered by their offset; ${phase.name} starts before the '
              'phase in front of it',
        );
      }
      previous = phase.after;
    }
  }

  final List<StartupPhase> _phases;
  final Future<void> Function() _firstFrame;
  final StartupErrorHandler? _onError;
  bool _started = false;

  Future<void> run() async {
    if (_started) throw StateError('StartupScheduler.run() was already called');
    _started = true;

    await _firstFrame();
    Timeline.instantSync('boot:firstFrameRasterized');

    final running = <Future<void>>[];
    var elapsed = Duration.zero;
    for (final phase in _phases) {
      final wait = phase.after - elapsed;
      if (wait > Duration.zero) await Future<void>.delayed(wait);
      elapsed = phase.after;
      Timeline.instantSync('post:${phase.name}');
      running.addAll(phase.tasks.map(_runTask));
    }
    await Future.wait(running);
  }

  Future<void> _runTask(StartupTask task) async {
    final span = TimelineTask()..start('post:${task.name}');
    try {
      await task.run();
    } catch (error, stack) {
      debugPrint('⚠️ [BOOT] ${task.name} failed: $error');
      _onError?.call(task.name, error, stack);
    } finally {
      span.finish();
    }
  }
}

/// What an Avo start does after the first frame, one callback per task of
/// [appStartupPhases]. main.dart passes the real services, tests pass fakes.
/// Nothing runs while the plan is built.
@immutable
class AppStartupWork {
  const AppStartupWork({
    required this.auth,
    required this.connectivity,
    required this.notifications,
    required this.firebase,
    required this.subscription,
    required this.recipeCache,
    required this.appFlags,
    required this.reminders,
    required this.appReview,
  });

  /// Auth listener: widget credentials, FCM token, reminders on sign-in.
  final FutureOr<void> Function() auth;
  final FutureOr<void> Function() connectivity;

  /// Notification plugin without a prompt; routes a launch tap.
  final FutureOr<void> Function() notifications;

  /// Firebase core, Analytics, then FCM.
  final FutureOr<void> Function() firebase;

  /// Cached Pro status, StoreKit and the server status.
  final FutureOr<void> Function() subscription;
  final FutureOr<void> Function() recipeCache;

  /// Remote kill switches (`app_flags`).
  final FutureOr<void> Function() appFlags;

  /// Re-arms Avo's reminders for the next start.
  final FutureOr<void> Function() reminders;
  final FutureOr<void> Function() appReview;
}

/// The start plan (Kap. 20 §2.2), offsets from the first rasterized frame:
///
/// - 0 s: auth listener and connectivity; on a phone also the notification
///   plugin, Firebase and the subscription. The subscription runs here
///   because its cached Pro status must be there for the first frames; its
///   StoreKit and server part come along until `SubscriptionService` loads
///   the cache on its own (then that part moves to 2 s).
/// - 1 s: offline recipe cache.
/// - 2 s: remote flags.
/// - 3 s: reminders for the next start and the app review counter.
///
/// Categorisation, Claude, photos, voice, Health and location start on first
/// use. No task shows a permission prompt.
List<StartupPhase> appStartupPhases(
  AppStartupWork work, {
  required bool isMobile,
}) => [
  StartupPhase(
    name: 'firstFrame',
    after: Duration.zero,
    tasks: [
      StartupTask('auth', work.auth),
      StartupTask('connectivity', work.connectivity),
      if (isMobile) ...[
        StartupTask('notifications', work.notifications),
        StartupTask('firebase', work.firebase),
        StartupTask('subscription', work.subscription),
      ],
    ],
  ),
  StartupPhase(
    name: 'warm',
    after: const Duration(seconds: 1),
    tasks: [StartupTask('recipeCache', work.recipeCache)],
  ),
  StartupPhase(
    name: 'remote',
    after: const Duration(seconds: 2),
    tasks: [StartupTask('appFlags', work.appFlags)],
  ),
  StartupPhase(
    name: 'nextStart',
    after: const Duration(seconds: 3),
    tasks: [
      if (isMobile) ...[
        StartupTask('reminders', work.reminders),
        StartupTask('appReview', work.appReview),
      ],
    ],
  ),
];

/// Build and raster times of the first frames after launch (Kap. 20 §5.1:
/// p90 ≤ 8.3 ms, no frame over 16 ms).
@immutable
class StartupFrameSummary {
  const StartupFrameSummary({
    required this.frames,
    required this.p90Build,
    required this.p90Raster,
    required this.worstFrame,
    required this.framesOver16ms,
  });

  factory StartupFrameSummary.of(List<FrameTiming> timings) {
    if (timings.isEmpty) {
      return const StartupFrameSummary(
        frames: 0,
        p90Build: Duration.zero,
        p90Raster: Duration.zero,
        worstFrame: Duration.zero,
        framesOver16ms: 0,
      );
    }
    final totals = [for (final t in timings) t.totalSpan];
    return StartupFrameSummary(
      frames: timings.length,
      p90Build: _p90([for (final t in timings) t.buildDuration]),
      p90Raster: _p90([for (final t in timings) t.rasterDuration]),
      worstFrame: totals.reduce((a, b) => a > b ? a : b),
      framesOver16ms: totals.where((d) => d > _frameBudget).length,
    );
  }

  static const _frameBudget = Duration(milliseconds: 16);

  final int frames;
  final Duration p90Build;
  final Duration p90Raster;
  final Duration worstFrame;
  final int framesOver16ms;

  /// Nearest-rank 90th percentile.
  static Duration _p90(List<Duration> values) {
    values.sort();
    return values[(values.length * 0.9).ceil() - 1];
  }

  @override
  String toString() =>
      '$frames frames, p90 build ${_ms(p90Build)}, p90 raster '
      '${_ms(p90Raster)}, worst ${_ms(worstFrame)}, '
      '$framesOver16ms over 16 ms';

  static String _ms(Duration d) =>
      '${(d.inMicroseconds / 1000).toStringAsFixed(1)} ms';
}

/// Logs a [StartupFrameSummary] of the first [frameCount] frames once, in
/// debug and profile builds (numbers only mean something in profile mode on
/// a device).
void reportStartupFrames({int frameCount = 120}) {
  if (kReleaseMode) return;
  final timings = <FrameTiming>[];
  late final TimingsCallback collect;
  collect = (batch) {
    timings.addAll(batch);
    if (timings.length < frameCount) return;
    SchedulerBinding.instance.removeTimingsCallback(collect);
    final summary = StartupFrameSummary.of(timings.take(frameCount).toList());
    debugPrint('🔵 [BOOT] First $summary');
  };
  SchedulerBinding.instance.addTimingsCallback(collect);
}
