import 'dart:async';
import 'dart:ui' show FrameTiming;

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:shoply/core/localization/app_translations.dart';
import 'package:shoply/core/services/startup_scheduler.dart';
import 'package:shoply/data/services/avo_nudge_service.dart';
import 'package:shoply/data/services/fcm_service.dart';
import 'package:shoply/data/services/mascot_notification_service.dart';
import 'package:shoply/data/services/notification_permission_service.dart';
import 'package:shoply/data/services/notification_service.dart';

StartupTask _log(List<String> log, String name) =>
    StartupTask(name, () => log.add(name));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('StartupScheduler', () {
    testWidgets('waits for the first frame, then starts each phase at its '
        'offset', (tester) async {
      final firstFrame = Completer<void>();
      final log = <String>[];
      var finished = false;
      unawaited(
        StartupScheduler(
          [
            StartupPhase(
              name: 'now',
              after: Duration.zero,
              tasks: [_log(log, 'firebase')],
            ),
            StartupPhase(
              name: 'flags',
              after: const Duration(seconds: 2),
              tasks: [_log(log, 'flags'), _log(log, 'subscription')],
            ),
            StartupPhase(
              name: 'reminders',
              after: const Duration(seconds: 3),
              tasks: [_log(log, 'reminders')],
            ),
          ],
          firstFrame: () => firstFrame.future,
        ).run().then((_) => finished = true),
      );

      await tester.pump(const Duration(seconds: 10));
      expect(log, isEmpty, reason: 'nothing may run before the first frame');

      firstFrame.complete();
      await tester.pump();
      expect(log, ['firebase']);

      await tester.pump(const Duration(milliseconds: 1999));
      expect(log, ['firebase']);
      await tester.pump(const Duration(milliseconds: 1));
      expect(log, ['firebase', 'flags', 'subscription']);

      await tester.pump(const Duration(milliseconds: 999));
      expect(log, ['firebase', 'flags', 'subscription']);
      await tester.pump(const Duration(milliseconds: 1));
      expect(log, ['firebase', 'flags', 'subscription', 'reminders']);
      expect(finished, isTrue);
    });

    testWidgets('a slow task does not hold back the next phase', (
      tester,
    ) async {
      final slow = Completer<void>();
      final log = <String>[];
      var finished = false;
      unawaited(
        StartupScheduler(
          [
            StartupPhase(
              name: 'now',
              after: Duration.zero,
              tasks: [StartupTask('slow', () => slow.future)],
            ),
            StartupPhase(
              name: 'later',
              after: const Duration(seconds: 1),
              tasks: [_log(log, 'later')],
            ),
          ],
          firstFrame: () async {},
        ).run().then((_) => finished = true),
      );

      await tester.pump(const Duration(seconds: 1));
      expect(log, ['later']);
      expect(finished, isFalse, reason: 'run() waits for every task');

      slow.complete();
      await tester.pump();
      expect(finished, isTrue);
    });

    testWidgets('a failing task does not stop the other tasks', (
      tester,
    ) async {
      final log = <String>[];
      final failures = <String>[];
      var finished = false;
      unawaited(
        StartupScheduler(
          [
            StartupPhase(
              name: 'now',
              after: Duration.zero,
              tasks: [
                StartupTask('throwsSync', () => throw StateError('sync')),
                StartupTask('throwsAsync', () async {
                  await Future<void>.delayed(Duration.zero);
                  throw StateError('async');
                }),
                _log(log, 'sibling'),
              ],
            ),
            StartupPhase(
              name: 'later',
              after: const Duration(seconds: 2),
              tasks: [_log(log, 'later')],
            ),
          ],
          firstFrame: () async {},
          onError: (task, error, stack) => failures.add(task),
        ).run().then((_) => finished = true),
      );

      await tester.pump();
      await tester.pump(const Duration(seconds: 2));
      expect(log, ['sibling', 'later']);
      expect(failures, unorderedEquals(['throwsSync', 'throwsAsync']));
      expect(finished, isTrue);
    });

    test('rejects phases that are not ordered by their offset', () {
      expect(
        () => StartupScheduler(const [
          StartupPhase(
            name: 'late',
            after: Duration(seconds: 3),
            tasks: [],
          ),
          StartupPhase(name: 'early', after: Duration.zero, tasks: []),
        ]),
        throwsArgumentError,
      );
    });

    test('runs only once', () async {
      final scheduler = StartupScheduler(const [], firstFrame: () async {});
      await scheduler.run();
      expect(scheduler.run, throwsStateError);
    });
  });

  group('App start plan', () {
    AppStartupWork work(List<String> log) => AppStartupWork(
      auth: () => log.add('auth'),
      connectivity: () => log.add('connectivity'),
      notifications: () => log.add('notifications'),
      firebase: () => log.add('firebase'),
      subscription: () => log.add('subscription'),
      recipeCache: () => log.add('recipeCache'),
      appFlags: () => log.add('appFlags'),
      reminders: () => log.add('reminders'),
      appReview: () => log.add('appReview'),
    );

    Map<String, List<String>> plan(List<StartupPhase> phases) => {
      for (final p in phases)
        '${p.name}@${p.after.inSeconds}s': [for (final t in p.tasks) t.name],
    };

    test('on a phone: Firebase and the cached Pro status right after the '
        'first frame, flags at 2 s, reminders at 3 s', () {
      expect(plan(appStartupPhases(work([]), isMobile: true)), {
        'firstFrame@0s': [
          'auth',
          'connectivity',
          'notifications',
          'firebase',
          'subscription',
        ],
        'warm@1s': ['recipeCache'],
        'remote@2s': ['appFlags'],
        'nextStart@3s': ['reminders', 'appReview'],
      });
    });

    test('without a phone platform no push, store or reminder work', () {
      expect(plan(appStartupPhases(work([]), isMobile: false)), {
        'firstFrame@0s': ['auth', 'connectivity'],
        'warm@1s': ['recipeCache'],
        'remote@2s': ['appFlags'],
        'nextStart@3s': <String>[],
      });
    });

    test('every task runs the work it is named after', () async {
      final log = <String>[];
      final phases = appStartupPhases(work(log), isMobile: true);
      expect(log, isEmpty, reason: 'building the plan starts nothing');

      final names = <String>[];
      for (final phase in phases) {
        for (final task in phase.tasks) {
          names.add(task.name);
          await task.run();
        }
      }
      expect(log, names);
    });

    testWidgets('nothing of the plan runs before the first frame', (
      tester,
    ) async {
      final firstFrame = Completer<void>();
      final log = <String>[];
      unawaited(
        StartupScheduler(
          appStartupPhases(work(log), isMobile: true),
          firstFrame: () => firstFrame.future,
        ).run(),
      );

      await tester.pump(const Duration(seconds: 10));
      expect(log, isEmpty);

      firstFrame.complete();
      await tester.pump();
      expect(log, [
        'auth',
        'connectivity',
        'notifications',
        'firebase',
        'subscription',
      ]);
      await tester.pump(const Duration(seconds: 3));
      expect(log.skip(5), ['recipeCache', 'appFlags', 'reminders', 'appReview']);
    });
  });

  group('StartupFrameSummary', () {
    FrameTiming frame(int ms) => FrameTiming(
      vsyncStart: 0,
      buildStart: 0,
      buildFinish: ms * 1000,
      rasterStart: ms * 1000,
      rasterFinish: ms * 3000,
      rasterFinishWallTime: ms * 3000,
    );

    test('reports p90 build and raster times and frames over 16 ms', () {
      final summary = StartupFrameSummary.of([
        for (var ms = 1; ms <= 10; ms++) frame(ms),
      ]);

      expect(summary.frames, 10);
      expect(summary.p90Build, const Duration(milliseconds: 9));
      expect(summary.p90Raster, const Duration(milliseconds: 18));
      expect(summary.worstFrame, const Duration(milliseconds: 30));
      expect(summary.framesOver16ms, 5);
    });

    test('an empty list reports zeros', () {
      final summary = StartupFrameSummary.of(const []);
      expect(summary.frames, 0);
      expect(summary.p90Build, Duration.zero);
      expect(summary.framesOver16ms, 0);
    });
  });

  group('No notification prompt at start', () {
    test('the iOS init settings request no permission', () {
      const settings = NotificationService.darwinSettings;
      expect(settings.requestAlertPermission, isFalse);
      expect(settings.requestBadgePermission, isFalse);
      expect(settings.requestSoundPermission, isFalse);
      expect(settings.requestProvisionalPermission, isFalse);
      expect(settings.requestCriticalPermission, isFalse);
    });

    test('tap payloads decode to a map or nothing', () {
      expect(
        NotificationService.payloadData('{"type":"avo_restock"}'),
        {'type': 'avo_restock'},
      );
      expect(NotificationService.payloadData(null), isNull);
      expect(NotificationService.payloadData(''), isNull);
      expect(NotificationService.payloadData('not json'), isNull);
      expect(NotificationService.payloadData('[1, 2]'), isNull);
    });
  });

  group('NotificationPermissionService', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('asks once, later calls only read the decision', () async {
      var prompts = 0;
      var granted = false;
      final service = NotificationPermissionService(
        isSupported: true,
        prompt: () async {
          prompts++;
          granted = true;
          return true;
        },
        isGranted: () async => granted,
        onGranted: () async {},
      );

      expect(await service.requestIfUseful('list_shared'), isTrue);
      expect(await service.requestIfUseful('reminder_on'), isTrue);
      expect(prompts, 1);

      // The next app start remembers that the prompt was shown.
      final nextStart = NotificationPermissionService(
        isSupported: true,
        prompt: () async {
          prompts++;
          return true;
        },
        isGranted: () async => false,
        onGranted: () async {},
      );
      expect(await nextStart.requestIfUseful('reminder_on'), isFalse);
      expect(prompts, 1);
    });

    test('calls at the same time share one prompt', () async {
      var prompts = 0;
      final answer = Completer<bool>();
      final service = NotificationPermissionService(
        isSupported: true,
        prompt: () {
          prompts++;
          return answer.future;
        },
        isGranted: () async => true,
        onGranted: () async {},
      );

      final first = service.requestIfUseful('list_shared');
      final second = service.requestIfUseful('reminder_on');
      answer.complete(true);

      expect(await first, isTrue);
      expect(await second, isTrue);
      expect(prompts, 1);
    });

    test('only a grant starts push registration', () async {
      var registrations = 0;
      Future<void> register() async => registrations++;

      final denied = NotificationPermissionService(
        isSupported: true,
        prompt: () async => false,
        isGranted: () async => false,
        onGranted: register,
      );
      expect(await denied.requestIfUseful('list_shared'), isFalse);
      expect(registrations, 0);

      SharedPreferences.setMockInitialValues({});
      final granted = NotificationPermissionService(
        isSupported: true,
        prompt: () async => true,
        isGranted: () async => true,
        onGranted: register,
      );
      expect(await granted.requestIfUseful('list_shared'), isTrue);
      expect(registrations, 1);
    });

    test('never asks on a platform without notifications', () async {
      var prompts = 0;
      final service = NotificationPermissionService(
        isSupported: false,
        prompt: () async {
          prompts++;
          return true;
        },
        isGranted: () async => true,
        onGranted: () async {},
      );
      expect(await service.requestIfUseful('list_shared'), isFalse);
      expect(prompts, 0);
    });
  });

  group('FCM token sync', () {
    const user = 'user-1';

    test('writes only when the server holds another value', () async {
      final store = _FakeTokenStore();
      final sync = FcmTokenSync(store);

      expect(await sync.save(user, 'token-a'), isTrue);
      expect(store.writes, 1);

      expect(await sync.save(user, 'token-a'), isTrue);
      expect(store.writes, 1, reason: 'unchanged token, no write');

      store.stored = 'token-other';
      expect(await sync.save(user, 'token-a'), isTrue);
      expect(store.writes, 2, reason: 'another device took the column over');

      store.stored = null;
      expect(await sync.save(user, 'token-a'), isTrue);
      expect(store.writes, 3, reason: 'the master switch was turned off elsewhere');
      expect(store.stored, 'token-a');
    });

    test('a write that matched no row is not taken as saved', () async {
      final store = _FakeTokenStore()..rowExists = false;
      final sync = FcmTokenSync(store);

      expect(await sync.save(user, 'token-a'), isFalse);

      store.rowExists = true;
      expect(await sync.save(user, 'token-a'), isTrue);
      expect(store.writes, 2, reason: 'the next save tries again');
    });

    test('saves of the same token at the same time share one round trip', () async {
      final gate = Completer<void>();
      final store = _FakeTokenStore()..readGate = gate.future;
      final sync = FcmTokenSync(store);

      final fromRefresh = sync.save(user, 'token-a');
      final fromRetry = sync.save(user, 'token-a');
      gate.complete();

      expect(await fromRefresh, isTrue);
      expect(await fromRetry, isTrue);
      expect(store.reads, 1);
      expect(store.writes, 1);
    });

    test('release clears the column only while it holds this token', () async {
      final store = _FakeTokenStore()..stored = 'token-a';
      final sync = FcmTokenSync(store);

      await sync.release(user, 'token-a');
      expect(store.stored, isNull);

      store.stored = 'token-b';
      await sync.release(user, 'token-a');
      expect(store.stored, 'token-b', reason: 'a newer device keeps its pushes');
    });
  });

  group('Reminder re-arm', () {
    test('calls before the launch re-arm do nothing', () async {
      final service = MascotNotificationService.forTesting();
      var checks = 0;
      service.notificationsAllowed = () async {
        checks++;
        return false;
      };

      await service.rearmRestockReminder(force: true);
      await service.rearmDinnerIdeasReminder(force: true);
      expect(checks, 0);

      await service.rearmAfterLaunch();
      expect(checks, 2);
    });

    test('without notification permission it only cancels, no account '
        'or network work', () async {
      final service = MascotNotificationService.forTesting();
      final log = <String>[];
      final previousPrint = debugPrint;
      debugPrint = (message, {wrapWidth}) => log.add('$message');
      service.notificationsAllowed = () async => false;
      try {
        await service.rearmAfterLaunch();
      } finally {
        debugPrint = previousPrint;
      }

      expect(
        log.where((l) => l.contains('Notifications not allowed')),
        hasLength(2),
        reason: 'restock and dinner reminder both stop at the gate',
      );
      expect(
        log.where((l) => l.contains('Failed to re-arm')),
        isEmpty,
        reason: 'reading the account (Supabase) would fail in a test',
      );
    });
  });

  group('Restock reminder text', () {
    RestockSuggestion due(String name, {int days = 6}) => RestockSuggestion(
      itemName: name.toLowerCase(),
      displayName: name,
      averageDays: days,
      daysSince: days + 1,
      overdueRatio: 1.2,
    );

    for (final lang in ['de', 'en']) {
      test('names the due items and never an offer ($lang)', () {
        final one = MascotNotificationService.restockReminderBody([
          due('Milch'),
        ], lang);
        expect(
          one,
          AppTranslations.get(
            'restock_notification_body_one',
            lang,
            params: {'item': 'Milch', 'days': '6'},
          ),
        );

        final many = MascotNotificationService.restockReminderBody([
          due('Milch'),
          due('Butter'),
          due('Eier'),
        ], lang);
        expect(
          many,
          AppTranslations.get(
            'restock_notification_body_many',
            lang,
            params: {'item': 'Milch', 'count': '2'},
          ),
        );

        for (final body in [one, many]) {
          expect(body, isNot(contains('€')));
          expect(body.toLowerCase(), isNot(contains('angebot')));
          expect(body.toLowerCase(), isNot(contains('offer')));
        }
      });
    }
  });
}

class _FakeTokenStore implements FcmTokenStore {
  String? stored;
  bool rowExists = true;
  int reads = 0;
  int writes = 0;
  Future<void>? readGate;

  @override
  Future<String?> read(String userId) async {
    reads++;
    if (readGate != null) await readGate;
    return stored;
  }

  @override
  Future<bool> write(String userId, String token) async {
    writes++;
    if (!rowExists) return false;
    stored = token;
    return true;
  }

  @override
  Future<void> clear(String userId, String token) async {
    if (stored == token) stored = null;
  }
}
