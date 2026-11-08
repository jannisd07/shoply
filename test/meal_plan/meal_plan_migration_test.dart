// Wochenplan (B7): the migration can only run against a database the owner
// picks, so this test pins the parts of the schema the app relies on.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shoply/data/models/meal_plan.dart';

void main() {
  final sql = File('supabase/migrations/20261108002000_b_meal_plan.sql')
      .readAsStringSync()
      .toLowerCase()
      .replaceAll(RegExp(r'\s+'), ' ');

  test('three tables, created idempotently', () {
    for (final t in ['meal_plans', 'meal_plan_entries', 'meal_plan_settings']) {
      expect(sql, contains('create table if not exists public.$t ('), reason: t);
      expect(sql, contains('alter table public.$t enable row level security'), reason: t);
      expect(sql, contains('revoke all on table public.$t from anon, authenticated'), reason: t);
    }
    expect(sql, isNot(contains('drop table')));
  });

  test('a week starts on Monday and exists once per account', () {
    expect(sql, contains('check (extract(isodow from week_start) = 1)'));
    expect(sql, contains('unique (user_id, week_start)'));
  });

  test('entries: client id, local day, text recipe id, limits', () {
    expect(sql, contains('id uuid primary key,'));
    expect(sql, contains('plan_date date not null'));
    expect(sql, contains('recipe_id text'));
    expect(sql, contains('check (servings between $kPlanMinServings and $kPlanMaxServings)'));
    expect(sql, contains("check (meal_type in ('breakfast', 'lunch', 'dinner', 'snack'))"));
    expect(sql, contains('on public.meal_plan_entries (user_id, plan_date)'));
  });

  test('settings defaults match MealPlanSettings.defaults', () {
    const d = MealPlanSettings.defaults;
    expect(sql, contains('default_servings int not null default ${d.defaultServings}'));
    expect(sql, contains("default '{${d.pantry.join(',')}}'".toLowerCase()));
    expect(sql, contains('show_today_hint boolean not null default true'));
    expect(sql, contains('reminder_enabled boolean not null default false'));
    expect(sql, contains('reminder_weekday int not null default ${d.reminderWeekday}'));
    expect(sql, contains("reminder_time time not null default '18:00'"));
  });

  test('own rows only, and only lists the person owns or is a member of', () {
    expect(RegExp(r'using \(user_id = \(select auth\.uid\(\)\)\)').allMatches(sql).length, greaterThanOrEqualTo(9));
    expect(sql, contains('create or replace function public.meal_plan_b_can_use_list(target_list_id uuid)'));
    expect(sql, contains('from public.list_members'));
    expect(sql, contains('sl.owner_id = (select auth.uid())'));
    for (final column in ['new.target_list_id', 'new.sent_list_id']) {
      expect(sql, contains('public.meal_plan_b_can_use_list($column)'), reason: column);
    }
  });
}
