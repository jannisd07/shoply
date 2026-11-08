// Wochenplan (B7): the plan store. Local first (SharedPreferences cache of
// this and next week), optimistic upserts by client uuid, an outbox for
// offline changes and undo for every change.
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shoply/data/models/food_log_entry.dart';
import 'package:shoply/data/models/meal_plan.dart';
import 'package:shoply/data/models/recipe.dart';
import 'package:shoply/data/services/meal_plan_repository.dart';

import 'meal_plan_fakes.dart';

const _chili = PlanRecipeSnapshot(
  name: 'Chili sin Carne',
  defaultServings: 4,
  kcalPerServing: 480,
  ingredients: [Ingredient(name: 'Zwiebel', amount: 2, unit: '')],
);
const _curry = PlanRecipeSnapshot(name: 'Gemüse-Curry', defaultServings: 3);

// Wednesday, 11.11.2026, 10:00 — week 9.–15. Nov.
DateTime _now() => DateTime(2026, 11, 11, 10);

void main() {
  late FakeMealPlanRemote remote;
  var ids = 0;

  MealPlanRepository repo({MealPlanRemote? withRemote, bool noRemote = false}) => MealPlanRepository(
        userId: 'u1',
        remote: noRemote ? null : (withRemote ?? remote),
        now: _now,
        newId: () => 'id-${ids++}',
      );

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    remote = FakeMealPlanRemote();
    ids = 0;
  });

  test('an added recipe is there at once, appended to its day', () async {
    final r = repo();
    await r.load();
    final first = await r.addEntry(recipeId: 'chili', snapshot: _chili, day: DateTime(2026, 11, 11, 18), servings: 4);
    final second = await r.addEntry(recipeId: 'curry', snapshot: _curry, day: DateTime(2026, 11, 11), servings: 2);

    final today = r.snapshot.entriesForDay(DateTime(2026, 11, 11));
    expect(today.map((e) => e.id), ['id-0', 'id-1']);
    expect(today.map((e) => e.position), [0, 1]);
    expect(first.entry.planDate, DateTime(2026, 11, 11));
    expect(second.entry.userId, 'u1');

    await r.flush();
    expect(remote.entries.keys, ['id-0', 'id-1']);
    expect(remote.entries['id-0']!['plan_date'], '2026-11-11');
    expect(r.snapshot.pendingChanges, 0);
  });

  test('offline changes wait in the outbox and survive a restart', () async {
    remote.offline = true;
    final r = repo();
    await r.load();
    await r.addEntry(recipeId: 'chili', snapshot: _chili, day: DateTime(2026, 11, 12), servings: 2);
    await r.flush();
    expect(r.snapshot.entriesForDay(DateTime(2026, 11, 12)), hasLength(1));
    expect(r.snapshot.pendingChanges, 1);
    r.dispose();

    remote.offline = false;
    final again = repo();
    await again.load();
    expect(again.snapshot.entriesForDay(DateTime(2026, 11, 12)), hasLength(1),
        reason: 'from the device cache, before any network');
    await again.sync();
    expect(remote.entries.keys, ['id-0']);
    expect(again.snapshot.pendingChanges, 0);
  });

  test('a change the database refuses is dropped, the rest still syncs', () async {
    final r = repo();
    await r.load();
    remote.refused.add('id-0');
    await r.addEntry(recipeId: 'a', snapshot: _curry, day: DateTime(2026, 11, 12), servings: 2);
    await r.addEntry(recipeId: 'b', snapshot: _chili, day: DateTime(2026, 11, 13), servings: 2);
    await r.flush();
    expect(remote.entries.keys, ['id-1']);
    expect(r.snapshot.pendingChanges, 0, reason: 'a refused change must not block the outbox forever');
  });

  test('remove and undo bring back the same entry (same id)', () async {
    final r = repo();
    await r.load();
    final added = await r.addEntry(recipeId: 'chili', snapshot: _chili, day: DateTime(2026, 11, 13), servings: 2);
    await r.flush();

    final undo = await r.removeEntries([added.entry.id]);
    expect(r.snapshot.entries, isEmpty);
    await r.flush();
    expect(remote.entries, isEmpty);

    await r.undo(undo);
    expect(r.snapshot.entries.values.single, added.entry);
    await r.flush();
    expect(remote.entries.keys, [added.entry.id]);
  });

  test('a refresh takes the server state but keeps unsent local changes', () async {
    final r = repo();
    await r.load();
    final stale = await r.addEntry(recipeId: 'old', snapshot: _curry, day: DateTime(2026, 11, 10), servings: 2);
    await r.flush();
    remote.entries.remove(stale.entry.id); // deleted on the other Mac
    remote.entries['remote'] = MealPlanEntry(
      id: 'remote',
      userId: 'u1',
      planDate: DateTime(2026, 11, 14),
      recipeId: 'curry',
      snapshot: _curry,
      servings: 3,
      createdAt: DateTime(2026, 11, 1),
      updatedAt: DateTime(2026, 11, 1),
    ).toRow();

    remote.offline = true;
    final local = await r.addEntry(recipeId: 'chili', snapshot: _chili, day: DateTime(2026, 11, 12), servings: 2);
    remote.offline = false;
    await r.refreshWeek(DateTime(2026, 11, 9));

    expect(r.snapshot.entries.keys, unorderedEquals(['remote', local.entry.id]));
  });

  test('the device cache holds this and next week only', () async {
    final r = repo(noRemote: true);
    await r.load();
    for (final day in [DateTime(2026, 11, 4), DateTime(2026, 11, 11), DateTime(2026, 11, 20), DateTime(2026, 11, 25)]) {
      await r.addEntry(recipeId: 'chili', snapshot: _chili, day: day, servings: 2);
    }
    r.dispose();

    final again = repo(noRemote: true);
    await again.load();
    expect(again.snapshot.entries.values.map((e) => e.planDate),
        unorderedEquals([DateTime(2026, 11, 11), DateTime(2026, 11, 20)]));
  });

  test('sending marks the entries, the first send of a week is noticed, undo resets', () async {
    final r = repo();
    await r.load();
    final chili = await r.addEntry(recipeId: 'chili', snapshot: _chili, day: DateTime(2026, 11, 11), servings: 4);
    final curry = await r.addEntry(recipeId: 'curry', snapshot: _curry, day: DateTime(2026, 11, 14), servings: 3);

    final sent = await r.markEntriesSent(servingsById: {chili.entry.id: 4}, listId: 'list-1');
    expect(sent.firstSend, isTrue);
    final e = r.snapshot.entries[chili.entry.id]!;
    expect((e.sentListId, e.sentServings), ('list-1', 4));
    expect(e.sentAt, isNotNull);
    expect(r.snapshot.week(DateTime(2026, 11, 9))!.firstSentAt, isNotNull);

    final again = await r.markEntriesSent(servingsById: {curry.entry.id: 3}, listId: 'list-1');
    expect(again.firstSend, isFalse);

    await r.undo(again.undo);
    await r.undo(sent.undo);
    expect(r.snapshot.entries[chili.entry.id]!.isSent, isFalse);
    expect(r.snapshot.week(DateTime(2026, 11, 9))?.firstSentAt, isNull);
    final third = await r.markEntriesSent(servingsById: {curry.entry.id: 3}, listId: 'list-1');
    expect(third.firstSend, isTrue, reason: 'after undoing the first send, the next one is first again');

    await r.flush();
    expect(remote.weeks['2026-11-09']!['first_sent_at'], isNotNull);
  });

  test('servings stay within 1..20 and undo restores them', () async {
    final r = repo();
    await r.load();
    final added = await r.addEntry(recipeId: 'chili', snapshot: _chili, day: DateTime(2026, 11, 11), servings: 2);
    final undo = await r.setServings(added.entry.id, 25);
    expect(r.snapshot.entries[added.entry.id]!.servings, 20);
    await r.undo(undo);
    expect(r.snapshot.entries[added.entry.id]!.servings, 2);
  });

  test('moving puts the entry at the end of the new day', () async {
    final r = repo();
    await r.load();
    await r.addEntry(recipeId: 'a', snapshot: _curry, day: DateTime(2026, 11, 12), servings: 2);
    final moved = await r.addEntry(recipeId: 'b', snapshot: _chili, day: DateTime(2026, 11, 11), servings: 2);
    await r.moveEntry(moved.entry.id, DateTime(2026, 11, 12));
    final thursday = r.snapshot.entriesForDay(DateTime(2026, 11, 12));
    expect(thursday.map((e) => e.recipeId), ['a', 'b']);
    expect(thursday.last.position, 1);
  });

  test('meal type can be set and cleared', () async {
    final r = repo();
    await r.load();
    final added = await r.addEntry(recipeId: 'a', snapshot: _curry, day: DateTime(2026, 11, 12), servings: 2);
    await r.setMealType(added.entry.id, MealType.lunch);
    expect(r.snapshot.entries[added.entry.id]!.mealType, MealType.lunch);
    await r.setMealType(added.entry.id, null);
    expect(r.snapshot.entries[added.entry.id]!.mealType, isNull);
  });

  test('clearing a week only touches that week, with undo', () async {
    final r = repo();
    await r.load();
    await r.addEntry(recipeId: 'a', snapshot: _curry, day: DateTime(2026, 11, 10), servings: 2);
    await r.addEntry(recipeId: 'b', snapshot: _chili, day: DateTime(2026, 11, 15), servings: 2);
    await r.addEntry(recipeId: 'c', snapshot: _chili, day: DateTime(2026, 11, 16), servings: 2);
    final undo = await r.clearWeek(DateTime(2026, 11, 11));
    expect(r.snapshot.entries.values.map((e) => e.recipeId), ['c']);
    await r.undo(undo);
    expect(r.snapshot.entries, hasLength(3));
  });

  test("copying last week's recipes keeps days and servings, not the sent state", () async {
    final r = repo();
    await r.load();
    await r.addEntry(recipeId: 'a', snapshot: _curry, day: DateTime(2026, 11, 3), servings: 3);
    final sent = await r.addEntry(recipeId: 'b', snapshot: _chili, day: DateTime(2026, 11, 8), servings: 2);
    await r.markEntriesSent(servingsById: {sent.entry.id: 2}, listId: 'list-1');

    final undo = await r.copyPreviousWeek(DateTime(2026, 11, 16));
    expect(undo.entries, isEmpty, reason: 'week 9.–15. Nov. was empty, nothing to copy');

    await r.copyPreviousWeek(DateTime(2026, 11, 9));
    final copied = r.snapshot.entriesForWeek(DateTime(2026, 11, 9));
    expect(copied.map((e) => (e.recipeId, e.planDate, e.servings, e.isSent)), [
      ('a', DateTime(2026, 11, 10), 3, false),
      ('b', DateTime(2026, 11, 15), 2, false),
    ]);
  });

  test('settings are local first and sent to the account', () async {
    final r = repo();
    await r.load();
    expect(r.snapshot.settings, MealPlanSettings.defaults);
    await r.updateSettings(r.snapshot.settings.copyWith(defaultServings: 3, pantry: ['Salz']));
    expect(r.snapshot.settings.defaultServings, 3);
    await r.flush();
    expect(remote.settings!['default_servings'], 3);
    expect(remote.settings!['user_id'], 'u1');

    final again = repo(noRemote: true);
    await again.load();
    expect(again.snapshot.settings.pantry, ['Salz']);
  });

  test('the account settings arrive with sync', () async {
    remote.settings = MealPlanSettings.defaults.copyWith(defaultServings: 4).toRow('u1');
    final r = repo();
    await r.load();
    await r.sync();
    expect(r.snapshot.settings.defaultServings, 4);
  });

  test('every change is published', () async {
    final r = repo();
    await r.load();
    final seen = <int>[];
    final sub = r.changes.listen((s) => seen.add(s.entries.length));
    await r.addEntry(recipeId: 'a', snapshot: _curry, day: DateTime(2026, 11, 12), servings: 2);
    await Future<void>.delayed(Duration.zero);
    expect(seen, contains(1));
    await sub.cancel();
  });
}
