import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shoply/core/localization/app_translations.dart';
import 'package:shoply/data/models/shopping_item_model.dart';
import 'package:shoply/data/services/tip_service.dart';

/// A clock the test moves by hand.
class _Clock {
  _Clock(this.now);
  DateTime now;
  DateTime call() => now;
  void nextDay([int days = 1]) => now = now.add(Duration(days: days));
}

const _list = TipFacts(openItems: 0, hasCheckedItem: false, shared: false);

/// Facts that let T2 start (3 open items, nothing checked).
const _threeOpen = TipFacts(openItems: 3, hasCheckedItem: false, shared: false);

Future<(TipService, SharedPreferences, _Clock)> _service({
  Map<String, Object> stored = const {},
  DateTime? now,
}) async {
  SharedPreferences.setMockInitialValues(stored);
  final prefs = await SharedPreferences.getInstance();
  final clock = _Clock(now ?? DateTime(2026, 11, 8, 10));
  final service = TipService(clock: clock.call)..attach(prefs);
  return (service, prefs, clock);
}

ShoppingItemModel _item(
  String name, {
  double quantity = 1,
  String? unit,
  bool checked = false,
  DateTime? at,
}) {
  final created = at ?? DateTime(2026, 11, 8);
  return ShoppingItemModel(
    id: name,
    listId: 'l1',
    name: name,
    quantity: quantity,
    unit: unit,
    isChecked: checked,
    createdAt: created,
    updatedAt: created,
  );
}

void main() {
  group('attach and storage', () {
    test('without preferences nothing shows; calls wait for attach', () async {
      final service = TipService();
      expect(service.pick(TipPlace.list, _threeOpen), isNull);
      service.markDone(TipId.voice);
      service.note(TipEvent.avoTextMessage);

      SharedPreferences.setMockInitialValues({});
      service.attach(await SharedPreferences.getInstance());
      expect(service.isFinished(TipId.voice), isTrue);
      expect(service.count(TipEvent.avoTextMessage), 1);
    });

    test('a fresh install keeps all tips', () async {
      final (service, prefs, _) = await _service();
      for (final id in TipId.values) {
        expect(service.isFinished(id), isFalse, reason: id.id);
      }
      // The state is written at once, so a later onboarding does not look
      // like an update.
      expect(prefs.getString(kTipStateKey), isNotNull);
    });

    test(
      'an update (onboarding done before tips) counts T1–T7 as shown',
      () async {
        final (service, _, _) = await _service(
          stored: {'onboarding_complete_v1': true},
        );
        for (final id in TipId.values) {
          expect(
            service.isFinished(id),
            id.forNewPeople,
            reason: '${id.id} after an update',
          );
        }
        // T8 and T9 are new functions: still possible.
        expect(service.pick(TipPlace.plan, const TipFacts()), TipId.mealPlan);
      },
    );

    test('state survives a restart', () async {
      final (service, prefs, clock) = await _service();
      service.startArrivalTip(TipId.quantity);
      service.note(TipEvent.shoppingStarted);
      await Future<void>.delayed(Duration.zero);

      final again = TipService(clock: clock.call)..attach(prefs);
      expect(again.active, TipId.quantity);
      expect(again.count(TipEvent.shoppingStarted), 1);
      expect(again.isFinished(TipId.shoppingMode), isTrue);
    });

    test('an unreadable state starts fresh', () async {
      final (service, _, _) = await _service(
        stored: {kTipStateKey: '{not json'},
      );
      expect(service.active, isNull);
      expect(
        service.pick(TipPlace.recipes, const TipFacts()),
        TipId.recipeToList,
      );
    });

    test('stored ids are the stable t1–t9', () async {
      final (service, prefs, _) = await _service();
      service.startArrivalTip(TipId.joined);
      final map = jsonDecode(prefs.getString(kTipStateKey)!) as Map;
      expect(map['active'], 't5');
      expect(
        [for (final t in TipId.values) t.id],
        [
          't1', 't2', 't3', 't4', 't5', 't6', 't7', 't8', 't9', //
        ],
      );
    });
  });

  group('one at a time, one new per day, never again', () {
    test('an active tip blocks every other tip', () async {
      final (service, _, _) = await _service();
      service.startArrivalTip(TipId.quantity);
      expect(service.pick(TipPlace.list, _threeOpen), TipId.quantity);
      // T2 would fit Home, but T1 is active.
      expect(service.pick(TipPlace.home, _threeOpen), isNull);
      expect(service.pick(TipPlace.recipes, const TipFacts()), isNull);
    });

    test('after a tip ends, the next one waits for the next day', () async {
      final (service, _, clock) = await _service();
      service.startArrivalTip(TipId.quantity);
      service.dismiss(TipId.quantity);
      expect(service.pick(TipPlace.list, _threeOpen), isNull);

      clock.nextDay();
      expect(service.pick(TipPlace.list, _threeOpen), TipId.shoppingMode);
    });

    test('a tip shown on one day does not come back the next', () async {
      final (service, _, clock) = await _service();
      expect(service.pick(TipPlace.list, _threeOpen), TipId.shoppingMode);
      // Same day: the same tip again (screens come back to it).
      expect(service.pick(TipPlace.list, _threeOpen), TipId.shoppingMode);

      clock.nextDay();
      expect(service.isFinished(TipId.shoppingMode), isTrue);
      expect(service.pick(TipPlace.list, _threeOpen), isNull);
      expect(
        service.pick(TipPlace.recipes, const TipFacts()),
        TipId.recipeToList,
      );
    });

    test('T5 stays three days, then never again', () async {
      final (service, _, clock) = await _service();
      service.startArrivalTip(TipId.joined);
      const shared = TipFacts(openItems: 4, shared: true);
      for (var day = 0; day < 3; day++) {
        expect(service.isShowing(TipId.joined, TipPlace.list, shared), isTrue);
        clock.nextDay();
      }
      expect(service.isShowing(TipId.joined, TipPlace.list, shared), isFalse);
      expect(service.isFinished(TipId.joined), isTrue);
    });

    test('reset brings every tip back, today', () async {
      final (service, _, _) = await _service(
        stored: {'onboarding_complete_v1': true},
      );
      service.pick(TipPlace.plan, const TipFacts());
      service.reset();
      expect(service.active, isNull);
      expect(service.isFinished(TipId.quantity), isFalse);
      expect(
        service.pick(TipPlace.recipes, const TipFacts()),
        TipId.recipeToList,
      );
    });

    test('only the tips a place can draw start there', () async {
      final (service, _, _) = await _service();
      expect(
        service.pick(
          TipPlace.recipes,
          const TipFacts(dietSet: false),
          only: const {TipId.diet},
        ),
        isNull,
      );
      // T6 was not used up.
      expect(service.isFinished(TipId.recipeToList), isFalse);
    });

    test('facts not ready: nothing starts', () async {
      final (service, _, _) = await _service();
      expect(
        service.pick(TipPlace.list, const TipFacts(ready: false, openItems: 9)),
        isNull,
      );
      expect(service.active, isNull);
    });
  });

  group('T1–T9 conditions and done', () {
    test(
      'T1 only on arrival; done by the first item with a quantity',
      () async {
        final (service, _, _) = await _service();
        expect(service.pick(TipPlace.list, _list), isNull);
        service.startArrivalTip(TipId.quantity);
        expect(service.pick(TipPlace.list, _list), TipId.quantity);

        final plain = TipFacts.forList([_item('Milch')]);
        service.observe(TipPlace.list, plain);
        expect(service.isShowing(TipId.quantity, TipPlace.list, plain), isTrue);

        final withQuantity = TipFacts.forList([_item('Milch', quantity: 2)]);
        service.observe(TipPlace.list, withQuantity);
        expect(service.isFinished(TipId.quantity), isTrue);
        expect(
          service.isShowing(TipId.quantity, TipPlace.list, withQuantity),
          isFalse,
        );
      },
    );

    test('a unit counts as a quantity ("500 g Mehl")', () {
      final facts = TipFacts.forList([_item('Mehl', unit: 'g', quantity: 500)]);
      expect(facts.hasItemWithQuantity, isTrue);
      expect(TipFacts.forList([_item('Brot')]).hasItemWithQuantity, isFalse);
    });

    test(
      'T2 needs 3 open items and no shopping yet; shopping ends it',
      () async {
        final (service, _, _) = await _service();
        expect(
          service.pick(
            TipPlace.list,
            const TipFacts(openItems: 2, shared: false),
          ),
          isNull,
        );
        expect(service.pick(TipPlace.list, _threeOpen), TipId.shoppingMode);
        service.note(TipEvent.shoppingStarted);
        expect(
          service.isShowing(TipId.shoppingMode, TipPlace.list, _threeOpen),
          isFalse,
        );
        expect(service.isFinished(TipId.shoppingMode), isTrue);
      },
    );

    test('T2 never starts for someone who already shopped', () async {
      final (service, _, _) = await _service();
      service.note(TipEvent.tripCompleted);
      expect(
        service.pick(TipPlace.list, _threeOpen),
        isNot(TipId.shoppingMode),
      );
    });

    test('T3 after 24 h with 5 open items and nothing checked off', () async {
      final now = DateTime(2026, 11, 8, 10);
      final (service, _, _) = await _service(now: now);
      service.note(TipEvent.shoppingStarted); // keeps T2 out of the way
      final fresh = TipFacts.forList([
        for (var i = 0; i < 5; i++) _item('a$i', at: now),
      ], shared: true);
      expect(service.pick(TipPlace.list, fresh), isNull);

      final (later, _, _) = await _service(now: now);
      later.note(TipEvent.shoppingStarted);
      final old = TipFacts.forList([
        for (var i = 0; i < 5; i++)
          _item('a$i', at: now.subtract(const Duration(hours: 25))),
      ], shared: true);
      expect(later.pick(TipPlace.list, old), TipId.checkOff);

      final checked = TipFacts.forList([
        _item('a', checked: true),
        _item('b'),
      ], shared: true);
      later.observe(TipPlace.list, checked);
      expect(later.isFinished(TipId.checkOff), isTrue);
    });

    test(
      'T4 after the first shopping, in an unshared list; sharing ends it',
      () async {
        final (service, _, _) = await _service();
        expect(service.pick(TipPlace.list, _list), isNull);
        service.note(TipEvent.shoppingStarted);
        expect(service.pick(TipPlace.list, _list), TipId.share);
        // Home shows it too, on the same day.
        expect(
          service.pick(
            TipPlace.home,
            const TipFacts(openItems: 1, shared: false),
          ),
          TipId.share,
        );
        const shared = TipFacts(openItems: 1, shared: true);
        service.observe(TipPlace.list, shared);
        expect(service.isFinished(TipId.share), isTrue);
      },
    );

    test('T5 only in shared lists (unknown counts as shared)', () async {
      final (service, _, _) = await _service();
      service.startArrivalTip(TipId.joined);
      expect(service.pick(TipPlace.list, const TipFacts()), TipId.joined);
      expect(service.pick(TipPlace.list, _list), isNull);
    });

    test('T6 at the first visit of Rezepte', () async {
      final (service, _, _) = await _service();
      service.visit(TipPlace.recipes);
      expect(
        service.pick(TipPlace.recipes, const TipFacts()),
        TipId.recipeToList,
      );
      service.markDone(TipId.recipeToList);
      expect(
        service.isShowing(
          TipId.recipeToList,
          TipPlace.recipes,
          const TipFacts(),
        ),
        isFalse,
      );
    });

    test(
      'T7 from the second visit without a diet; saving one ends it',
      () async {
        final (service, _, clock) = await _service();
        const noDiet = TipFacts(dietSet: false);
        service.visit(TipPlace.recipes);
        expect(
          service.pick(TipPlace.recipes, noDiet, only: const {TipId.diet}),
          isNull,
        );
        clock.nextDay();
        service.visit(TipPlace.recipes);
        expect(
          service.pick(TipPlace.recipes, noDiet, only: const {TipId.diet}),
          TipId.diet,
        );
        const withDiet = TipFacts(dietSet: true);
        service.observe(TipPlace.recipes, withDiet);
        expect(service.isFinished(TipId.diet), isTrue);
      },
    );

    test('T7 does not start while the diet is unknown', () async {
      final (service, _, _) = await _service();
      service
        ..visit(TipPlace.recipes)
        ..visit(TipPlace.recipes);
      expect(
        service.pick(
          TipPlace.recipes,
          const TipFacts(),
          only: const {TipId.diet},
        ),
        isNull,
      );
    });

    test('T8 after three typed Avo messages with the Avo module on', () async {
      final (service, _, _) = await _service();
      service.note(TipEvent.shoppingStarted); // T2 done, T4 needs shared
      const facts = TipFacts(openItems: 1, shared: true, avoOn: true);
      service
        ..note(TipEvent.avoTextMessage)
        ..note(TipEvent.avoTextMessage);
      expect(service.pick(TipPlace.list, facts), isNull);
      service.note(TipEvent.avoTextMessage);
      expect(service.pick(TipPlace.list, facts), TipId.voice);
      // Avo switched off: not shown.
      expect(
        service.isShowing(
          TipId.voice,
          TipPlace.list,
          const TipFacts(openItems: 1, shared: true, avoOn: false),
        ),
        isFalse,
      );
      service.markDone(TipId.voice);
      expect(service.isFinished(TipId.voice), isTrue);
    });

    test('T9 at the first visit of the Wochenplan', () async {
      final (service, _, _) = await _service();
      expect(service.pick(TipPlace.plan, const TipFacts()), TipId.mealPlan);
      service.markDone(TipId.mealPlan);
      expect(service.active, isNull);
    });
  });

  group('arrival and listeners', () {
    test(
      'an existing account: T1–T7 count as shown, T1 cannot start',
      () async {
        final (service, _, _) = await _service();
        service.markNewPeopleTipsSeen();
        service.startArrivalTip(TipId.quantity);
        expect(service.active, isNull);
        expect(service.isFinished(TipId.diet), isTrue);
        expect(service.isFinished(TipId.voice), isFalse);
      },
    );

    test('an arrival acts once per run', () async {
      final (service, _, _) = await _service();
      expect(service.consumeArrival('l1:new'), isTrue);
      expect(service.consumeArrival('l1:new'), isFalse);
      expect(service.consumeArrival('l2:new'), isTrue);
    });

    test('changes notify after the current work, once', () async {
      final (service, _, _) = await _service();
      var calls = 0;
      service.addListener(() => calls++);
      service
        ..dismiss(TipId.share)
        ..markDone(TipId.voice);
      expect(calls, 0);
      await Future<void>.delayed(Duration.zero);
      expect(calls, 1);
    });
  });

  test('every tip has a German and an English text without "Shoply"', () {
    final keys = [
      for (final t in TipId.values) 'tip_${t.id}',
      'tip_t7_action',
      'tip_hide',
      'tip_section_today',
      'tip_arrival_existing',
      'tip_arrival_existing_anonymous',
      'tip_reset',
      'tip_reset_done',
    ];
    for (final key in keys) {
      for (final lang in ['de', 'en']) {
        final text = AppTranslations.get(key, lang);
        expect(text, isNot(key), reason: '$key ($lang) missing');
        expect(text.toLowerCase(), isNot(contains('shoply')), reason: key);
        expect(text, isNot(contains('\n')), reason: key);
      }
    }
    expect(AppTranslations.get('tip_t1', 'de'), startsWith('Tipp: '));
    expect(AppTranslations.get('tip_t1', 'en'), startsWith('Tip: '));
  });
}
