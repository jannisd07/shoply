import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shoply/data/models/recipe.dart';
import 'package:shoply/presentation/screens/recipes/widgets/cooking_mode_logic.dart';
import 'package:shoply/presentation/screens/recipes/widgets/cooking_mode_progress.dart';
import 'package:shoply/presentation/screens/recipes/widgets/cooking_mode_timers.dart';

class _Alerts implements CookingTimerAlerts {
  final scheduled = <int, DateTime>{};
  final cancelled = <int>[];

  @override
  Future<void> schedule({
    required int id,
    required String title,
    required String body,
    required DateTime at,
  }) async => scheduled[id] = at;

  @override
  Future<void> cancel(int id) async {
    cancelled.add(id);
    scheduled.remove(id);
  }
}

void main() {
  group('detectStepTimes', () {
    Duration first(String text) => detectStepTimes(text).first.duration;

    test('minutes, hours, seconds in German and English', () {
      expect(first('15 Minuten backen'), const Duration(minutes: 15));
      expect(first('15 Min. ruhen lassen'), const Duration(minutes: 15));
      expect(first('Bake for 20 minutes'), const Duration(minutes: 20));
      expect(first('1,5 Std. schmoren'), const Duration(minutes: 90));
      expect(first('simmer 2 hours'), const Duration(hours: 2));
      expect(first('30 Sekunden mixen'), const Duration(seconds: 30));
      expect(first('45 sec'), const Duration(seconds: 45));
    });

    test('ranges keep both ends', () {
      final t = detectStepTimes('10–15 Minuten garen').single;
      expect(t.duration, const Duration(minutes: 10));
      expect(t.upper, const Duration(minutes: 15));
      final en = detectStepTimes('cook 10-12 min').single;
      expect(en.upper, const Duration(minutes: 12));
    });

    test('hours followed by minutes are one time', () {
      final t = detectStepTimes('1 Std. 10 Min im Ofen').single;
      expect(t.duration, const Duration(minutes: 70));
      expect(t.start, 0);
    });

    test('no false hits', () {
      expect(detectStepTimes('2 Minzblätter und 200 g Mehl'), isEmpty);
      expect(detectStepTimes('2 Hähnchenbrustfilets'), isEmpty);
      expect(detectStepTimes('Bei 180 Grad'), isEmpty);
    });

    test('positions mark the time in the text', () {
      const text = 'Alles 15 Minuten backen';
      final t = detectStepTimes(text).single;
      expect(text.substring(t.start, t.end), '15 Minuten');
    });
  });

  test('formatTimerClock', () {
    expect(formatTimerClock(const Duration(minutes: 12, seconds: 47)), '12:47');
    expect(formatTimerClock(const Duration(hours: 1, seconds: 3)), '1:00:03');
    expect(formatTimerClock(const Duration(seconds: -4)), '00:00');
  });

  test('formatDurationLabel', () {
    expect(formatDurationLabel(const Duration(minutes: 15), 'de'), '15 Min');
    expect(
      formatDurationLabel(const Duration(minutes: 70), 'de'),
      '1 Std. 10 Min',
    );
    expect(formatDurationLabel(const Duration(hours: 2), 'en'), '2 hr');
    expect(formatDurationLabel(const Duration(seconds: 30), 'de'), '30 Sek.');
  });

  group('ingredients', () {
    const ingredients = [
      Ingredient(name: 'Kartoffeln, festkochend', amount: 500, unit: 'g'),
      Ingredient(name: 'Olivenöl', amount: 3, unit: 'EL'),
      Ingredient(name: 'Salz nach Geschmack', amount: 0, unit: ''),
      Ingredient(name: 'Eier', amount: 3, unit: ''),
    ];

    test('ingredientsInStep finds plural and singular, ignores descriptors', () {
      expect(
        ingredientsInStep(ingredients, 'Die Kartoffel mit Olivenöl mischen.'),
        [0, 1],
      );
      expect(ingredientsInStep(ingredients, 'Nach 10 Minuten salzen'), [2]);
      expect(ingredientsInStep(ingredients, 'Ofen vorheizen.'), isEmpty);
    });

    test('scaleIngredient follows the rounding rules', () {
      expect(scaleIngredient(ingredients[0], 4, 3).amount, 375);
      expect(
        scaleIngredient(
          const Ingredient(name: 'Butter', amount: 12, unit: 'g'),
          4,
          3,
        ).amount,
        9,
      );
      expect(scaleIngredient(ingredients[3], 4, 3).amount, 3); // eggs up
      expect(
        scaleIngredient(
          const Ingredient(name: 'Zwiebel', amount: 1, unit: ''),
          4,
          6,
        ).amount,
        1.5,
      );
      expect(
        scaleIngredient(
          const Ingredient(name: 'Muskat', amount: 1, unit: 'Prise'),
          2,
          8,
        ).amount,
        1,
      );
      expect(scaleIngredient(ingredients[2], 2, 4).amount, 0);
    });

    test('formatIngredientAmount never shows 0 and uses fractions', () {
      expect(formatIngredientAmount(ingredients[2], 'de'), isNull);
      expect(formatIngredientAmount(ingredients[0], 'de'), '500 g');
      expect(formatIngredientAmount(ingredients[3], 'de'), '3');
      expect(
        formatIngredientAmount(
          const Ingredient(name: 'Kreuzkümmel', amount: 0.5, unit: 'TL'),
          'de',
        ),
        '½ TL',
      );
      expect(
        formatIngredientAmount(
          const Ingredient(name: 'Brühe', amount: 1.5, unit: 'l'),
          'de',
        ),
        startsWith('1,5'),
      );
      expect(
        formatIngredientLine(ingredients[1], 'de'),
        '3 EL Olivenöl',
      );
      expect(formatIngredientLine(ingredients[2], 'de'), 'Salz nach Geschmack');
    });
  });

  group('CookingTimers', () {
    late DateTime now;
    late _Alerts alerts;
    late CookingTimers timers;
    final finished = <int>[];

    setUp(() {
      now = DateTime(2026, 11, 8, 18);
      alerts = _Alerts();
      finished.clear();
      timers = CookingTimers(
        alerts: alerts,
        notificationTitle: (_) => 'Ofengemüse',
        notificationBody: (s) => 'Schritt ${s + 1} fertig.',
        clock: () => now,
        onFinished: finished.add,
      );
    });

    tearDown(() => timers.dispose());

    test('start plans one notification per step; no second start', () {
      timers.start(2, const Duration(minutes: 15));
      timers.start(2, const Duration(minutes: 5));
      timers.start(0, const Duration(minutes: 5));
      expect(timers.timers.map((t) => t.step), [0, 2]); // ends first first
      expect(alerts.scheduled.keys, containsAll([700100, 700102]));
      expect(
        alerts.scheduled[700102],
        now.add(const Duration(minutes: 15)),
      );
    });

    test('pause, resume, +1 min and stop follow the wall clock', () {
      timers.start(1, const Duration(minutes: 10));
      now = now.add(const Duration(minutes: 4));
      timers.pause(1);
      expect(alerts.scheduled.containsKey(700101), isFalse);
      now = now.add(const Duration(minutes: 30));
      expect(timers.forStep(1)!.left(now), const Duration(minutes: 6));
      timers.resume(1);
      expect(alerts.scheduled[700101], now.add(const Duration(minutes: 6)));
      timers.addMinute(1);
      expect(timers.forStep(1)!.left(now), const Duration(minutes: 7));
      timers.stop(1);
      expect(timers.isEmpty, isTrue);
      expect(alerts.cancelled, contains(700101));
    });

    test('a finished timer is reported once and stays until acknowledged', () {
      timers.start(0, const Duration(minutes: 1));
      now = now.add(const Duration(minutes: 2));
      timers.tick();
      timers.tick();
      expect(finished, [0]);
      expect(timers.isFinished(0), isTrue);
      expect(timers.anyRunning, isFalse);
      timers.acknowledge(0);
      expect(timers.isEmpty, isTrue);
    });

    test('restored timers that ran out are not announced again', () {
      timers.restore([
        CookingTimer(
          step: 3,
          total: const Duration(minutes: 5),
          endsAt: now.subtract(const Duration(minutes: 1)),
        ),
      ]);
      timers.tick();
      expect(finished, isEmpty);
      expect(timers.isFinished(3), isTrue);
    });
  });

  group('CookingProgressStore', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('saves, loads and drops progress after 24 h', () async {
      final saved = DateTime(2026, 11, 8, 18);
      await CookingProgressStore.save(
        CookingProgress(
          recipeId: 'r1',
          page: 3,
          servings: 4,
          checked: const {0, 2},
          visited: const {0, 1, 2, 3},
          timers: [
            CookingTimer(
              step: 2,
              total: const Duration(minutes: 15),
              endsAt: saved.add(const Duration(minutes: 12)),
            ),
            const CookingTimer(
              step: 0,
              total: Duration(minutes: 5),
              pausedLeft: Duration(minutes: 2),
            ),
          ],
          savedAt: saved,
        ),
      );
      final back = await CookingProgressStore.load(
        'r1',
        now: saved.add(const Duration(hours: 2)),
      );
      expect(back!.page, 3);
      expect(back.stepNumber, 3);
      expect(back.servings, 4);
      expect(back.checked, {0, 2});
      expect(back.timers, hasLength(2));
      expect(back.timers.last.pausedLeft, const Duration(minutes: 2));

      final old = await CookingProgressStore.load(
        'r1',
        now: saved.add(const Duration(hours: 25)),
      );
      expect(old, isNull);
      expect(await CookingProgressStore.load('r1', now: saved), isNull);
    });

    test('nothing for an empty id or a broken entry', () async {
      SharedPreferences.setMockInitialValues({
        'cooking_progress_r2': '{"page": "x"}',
      });
      expect(await CookingProgressStore.load(''), isNull);
      expect(await CookingProgressStore.load('r2'), isNull);
    });
  });
}
