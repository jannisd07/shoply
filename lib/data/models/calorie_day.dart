import 'dart:async';
import 'dart:io';

import 'package:equatable/equatable.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:shoply/core/utils/number_parsing.dart';
import 'package:shoply/data/models/food_log_entry.dart';
import 'package:shoply/data/models/water_log_entry.dart';
import 'package:shoply/data/models/workout.dart';

// ── Day keys ────────────────────────────────────────────────────────────

String _two(int v) => v.toString().padLeft(2, '0');

/// `YYYY-MM-DD` of [time] in local time (concept 15 2.1). UTC timestamps are
/// converted first, so a meal at 00:30 local time never lands on yesterday.
String calorieDayKey(DateTime time) {
  final local = time.isUtc ? time.toLocal() : time;
  return '${local.year.toString().padLeft(4, '0')}-${_two(local.month)}-${_two(local.day)}';
}

final _dayKeyPattern = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$');

/// Local midnight of [key]. Throws [FormatException] for anything but
/// `YYYY-MM-DD`.
DateTime parseCalorieDayKey(String key) {
  final m = _dayKeyPattern.firstMatch(key);
  if (m == null) throw FormatException('Not a day key', key);
  return DateTime(int.parse(m[1]!), int.parse(m[2]!), int.parse(m[3]!));
}

/// Calendar arithmetic (not 24 h steps), so DST switches never skip a day.
String shiftCalorieDayKey(String key, int days) {
  final d = parseCalorieDayKey(key);
  return calorieDayKey(DateTime(d.year, d.month, d.day + days));
}

/// Monday of the calendar week containing [key] (concept 15 F-K9).
String calorieWeekStartKey(String key) {
  final d = parseCalorieDayKey(key);
  return shiftCalorieDayKey(key, -(d.weekday - DateTime.monday));
}

/// `app_flags` row the B6 migration sets. Until it is there, services send
/// only the columns and source values that exist today.
const calorieSchemaV2FlagKey = 'calories_schema_v2';

// ── Typed errors ────────────────────────────────────────────────────────

enum CalorieErrorCode { notSignedIn, network, rejected, notFound }

/// What calorie services throw instead of returning `null`/`[]` on failure
/// (concept 15 2.1: a network error must never look like "no goal" or
/// "nothing logged"). [messageKey] is a `cal_` translation key.
class CalorieDataException implements Exception {
  final CalorieErrorCode code;
  final Object? cause;

  const CalorieDataException(this.code, {this.cause});

  /// Whether the write queue should try again later.
  bool get retryable => switch (code) {
        CalorieErrorCode.network || CalorieErrorCode.notSignedIn => true,
        CalorieErrorCode.rejected || CalorieErrorCode.notFound => false,
      };

  String get messageKey => switch (code) {
        CalorieErrorCode.notSignedIn => 'cal_err_signed_out',
        CalorieErrorCode.network => 'cal_err_offline',
        CalorieErrorCode.rejected => 'cal_err_not_saved',
        CalorieErrorCode.notFound => 'cal_err_not_found',
      };

  /// Maps any error from Supabase or the network to a typed error.
  /// Postgres data/constraint/permission errors are final (`rejected`);
  /// timeouts, server errors and unknown errors are retried.
  factory CalorieDataException.from(Object error) {
    if (error is CalorieDataException) return error;
    if (error is AuthException) {
      return CalorieDataException(CalorieErrorCode.notSignedIn, cause: error);
    }
    if (error is PostgrestException) {
      final code = error.code ?? '';
      final status = int.tryParse(code);
      final finalError = code.startsWith('22') ||
          code.startsWith('23') ||
          code == '42501' ||
          code == '42703' ||
          code == '42P01' ||
          code == 'PGRST205' ||
          code == 'PGRST204' ||
          (status != null && status >= 400 && status < 500 && status != 408 && status != 429);
      return CalorieDataException(
        finalError ? CalorieErrorCode.rejected : CalorieErrorCode.network,
        cause: error,
      );
    }
    if (error is SocketException || error is TimeoutException || error is HttpException) {
      return CalorieDataException(CalorieErrorCode.network, cause: error);
    }
    return CalorieDataException(CalorieErrorCode.network, cause: error);
  }

  @override
  String toString() => 'CalorieDataException($code${cause == null ? '' : ': $cause'})';
}

// ── Number input ────────────────────────────────────────────────────────

/// Translation key for "Bitte eine Zahl, zum Beispiel 450 oder 450,5".
const calNumberErrorKey = 'cal_err_number';

/// Result of [parseCalorieNumber]: a value, or an error key to show under
/// the field. Never a silent 0 (concept 15 2.2, Inv. 4.4/4.5).
class CalorieNumberInput extends Equatable {
  final double? value;
  final String? errorKey;
  final bool isEmpty;

  const CalorieNumberInput._({this.value, this.errorKey, this.isEmpty = false});

  bool get isValid => value != null;

  @override
  List<Object?> get props => [value, errorKey, isEmpty];
}

final _plainNumber = RegExp(r'^\d+([.,]\d+)?$');
final _groupedNumber = RegExp(r'^\d{1,3}([.,]\d{3})+([.,]\d+)?$');

/// Parses a field that accepts "450", "450,5" and "450.5". With both
/// separators ("1.250,5" / "1,250.5") the last one is the decimal mark. In
/// [integer] fields (kcal) "1.250" means 1250 and the value is rounded.
CalorieNumberInput parseCalorieNumber(
  String input, {
  bool integer = false,
  bool required = false,
  double min = 0,
  double? max,
}) {
  final text = input.trim();
  if (text.isEmpty) {
    return CalorieNumberInput._(
      isEmpty: true,
      errorKey: required ? calNumberErrorKey : null,
    );
  }
  const invalid = CalorieNumberInput._(errorKey: calNumberErrorKey);

  double? value;
  final hasPoint = text.contains('.');
  final hasComma = text.contains(',');
  if (hasPoint && hasComma) {
    if (!_groupedNumber.hasMatch(text)) return invalid;
    final decimal = text.lastIndexOf('.') > text.lastIndexOf(',') ? '.' : ',';
    final group = decimal == '.' ? ',' : '.';
    final groups = text.split(decimal);
    if (groups.length != 2) return invalid;
    value = double.tryParse('${groups[0].replaceAll(group, '')}.${groups[1]}');
  } else if (integer && hasPoint && RegExp(r'^\d{1,3}(\.\d{3})+$').hasMatch(text)) {
    value = double.tryParse(text.replaceAll('.', ''));
  } else if (_plainNumber.hasMatch(text)) {
    value = parseLocaleDouble(text);
  }

  if (value == null || !value.isFinite || value < min || (max != null && value > max)) {
    return invalid;
  }
  return CalorieNumberInput._(value: integer ? value.roundToDouble() : value);
}

// ── Day state ───────────────────────────────────────────────────────────

/// Sync state of one optimistic row. Rows without a state are synced.
enum CalorieSyncState { synced, pending, failed }

/// Today's numbers against the goal (concept 15 2.2).
class CalorieBudget extends Equatable {
  final int? goalKcal;
  final int eatenKcal;

  /// Workout kcal added to the budget; 0 unless "Verbrauch durch Workouts
  /// gutschreiben" is on.
  final int workoutCreditKcal;

  const CalorieBudget({
    required this.goalKcal,
    required this.eatenKcal,
    this.workoutCreditKcal = 0,
  });

  /// Goal − eaten (+ credited workouts). Negative when over the goal; null
  /// without a goal.
  int? get remainingKcal =>
      goalKcal == null ? null : goalKcal! - eatenKcal + workoutCreditKcal;

  bool get isOverGoal => (remainingKcal ?? 0) < 0;

  int get overByKcal => isOverGoal ? -remainingKcal! : 0;

  /// Ring fill 0…1 (full when over the goal); null without a goal.
  double? get progress {
    final goal = goalKcal;
    if (goal == null || goal <= 0) return null;
    return (eatenKcal / (goal + workoutCreditKcal)).clamp(0.0, 1.0);
  }

  @override
  List<Object?> get props => [goalKcal, eatenKcal, workoutCreditKcal];
}

/// Everything logged on one local calendar day: the unit the local store
/// keeps, the diary shows and one change invalidates (concept 15 2.1).
class CalorieDay extends Equatable {
  final String dateKey;
  final List<FoodLogEntry> entries;
  final List<WaterLogEntry> water;
  final List<Workout> workouts;

  /// Optimistic rows by id; missing ids are synced.
  final Map<String, CalorieSyncState> syncStates;

  /// Last time this day was merged with the server; null = local only.
  final DateTime? syncedAt;

  const CalorieDay({
    required this.dateKey,
    this.entries = const [],
    this.water = const [],
    this.workouts = const [],
    this.syncStates = const {},
    this.syncedAt,
  });

  DateTime get date => parseCalorieDayKey(dateKey);

  bool get hasFoodEntries => entries.isNotEmpty;

  DailyNutritionTotals get totals => DailyNutritionTotals.fromEntries(entries);

  /// Eaten kcal, or null when nothing was logged: an unlogged day is
  /// unknown, never 0 kcal (charts stay empty, averages skip it).
  int? get eatenKcal => hasFoodEntries ? totals.calories : null;

  int get waterMl => water.fold(0, (sum, w) => sum + w.amountMl);

  int get workoutKcal => workouts.fold(0, (sum, w) => sum + (w.calories ?? 0));

  int get workoutMinutes => workouts.fold(0, (sum, w) => sum + w.durationMin);

  CalorieSyncState syncStateOf(String id) => syncStates[id] ?? CalorieSyncState.synced;

  bool get hasUnsyncedRows => syncStates.isNotEmpty;

  CalorieBudget budget({required int? goalKcal, bool creditWorkouts = false}) {
    return CalorieBudget(
      goalKcal: goalKcal,
      eatenKcal: totals.calories,
      workoutCreditKcal: creditWorkouts ? workoutKcal : 0,
    );
  }

  CalorieDay copyWith({
    List<FoodLogEntry>? entries,
    List<WaterLogEntry>? water,
    List<Workout>? workouts,
    Map<String, CalorieSyncState>? syncStates,
    DateTime? syncedAt,
  }) {
    return CalorieDay(
      dateKey: dateKey,
      entries: entries ?? this.entries,
      water: water ?? this.water,
      workouts: workouts ?? this.workouts,
      syncStates: syncStates ?? this.syncStates,
      syncedAt: syncedAt ?? this.syncedAt,
    );
  }

  factory CalorieDay.fromJson(Map<String, dynamic> json) {
    List<Map<String, dynamic>> rows(String key) =>
        ((json[key] as List?) ?? const []).cast<Map<String, dynamic>>();
    final states = (json['sync'] as Map?)?.cast<String, String>() ?? const {};
    return CalorieDay(
      dateKey: json['date'] as String,
      entries: rows('entries').map(FoodLogEntry.fromJson).toList(),
      water: rows('water').map(WaterLogEntry.fromJson).toList(),
      workouts: rows('workouts').map(Workout.fromJson).toList(),
      syncStates: {
        for (final e in states.entries)
          e.key: CalorieSyncState.values.firstWhere(
            (s) => s.name == e.value,
            orElse: () => CalorieSyncState.pending,
          ),
      },
      syncedAt: json['synced_at'] == null
          ? null
          : DateTime.parse(json['synced_at'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
        'date': dateKey,
        'entries': entries.map((e) => e.toJson()).toList(),
        'water': water.map(waterEntryToJson).toList(),
        'workouts': workouts.map((w) => w.toJson()).toList(),
        'sync': syncStates.map((id, s) => MapEntry(id, s.name)),
        'synced_at': syncedAt?.toIso8601String(),
      };

  @override
  List<Object?> get props => [dateKey, entries, water, workouts, syncStates, syncedAt];
}

/// Full local snapshot of a water row (the model only has an insert shape).
Map<String, dynamic> waterEntryToJson(WaterLogEntry w) => {
      'id': w.id,
      'user_id': w.userId,
      'logged_date': calorieDayKey(w.loggedDate),
      'amount_ml': w.amountMl,
      'created_at': w.createdAt.toIso8601String(),
    };

// ── Week ────────────────────────────────────────────────────────────────

/// One bar of the week chart. [kcal] null = nothing logged (unknown).
class CalorieWeekDay extends Equatable {
  final String dateKey;
  final DailyNutritionTotals? totals;
  final int waterMl;
  final bool isToday;
  final bool isFuture;

  const CalorieWeekDay({
    required this.dateKey,
    required this.totals,
    required this.waterMl,
    required this.isToday,
    required this.isFuture,
  });

  int? get kcal => totals?.calories;

  @override
  List<Object?> get props => [dateKey, totals, waterMl, isToday, isFuture];
}

/// A calendar week Monday to Sunday (concept 15 3.15, F-K9). Averages and
/// "im Ziel" count only finished days with entries: today counts from
/// tomorrow, unlogged days never count as 0.
class CalorieWeek extends Equatable {
  final String weekStartKey;
  final List<CalorieWeekDay> days;

  const CalorieWeek({required this.weekStartKey, required this.days});

  CalorieWeekDay? dayOf(String dateKey) =>
      days.where((d) => d.dateKey == dateKey).firstOrNull;

  Iterable<CalorieWeekDay> get _finishedLogged =>
      days.where((d) => !d.isToday && !d.isFuture && d.kcal != null);

  int get completedLoggedDays => _finishedLogged.length;

  int? get averageKcal {
    final list = _finishedLogged.toList();
    if (list.isEmpty) return null;
    return (list.fold<int>(0, (s, d) => s + d.kcal!) / list.length).round();
  }

  /// Finished logged days with at most 105 % of [goalKcal].
  int daysInGoal(int goalKcal) =>
      _finishedLogged.where((d) => d.kcal! <= goalKcal * 1.05).length;

  int? get averageWaterMl {
    final list = days.where((d) => !d.isFuture && d.waterMl > 0).toList();
    if (list.isEmpty) return null;
    return (list.fold<int>(0, (s, d) => s + d.waterMl) / list.length).round();
  }

  @override
  List<Object?> get props => [weekStartKey, days];
}

/// Combines server sums with local days (which include waiting writes and
/// win where present).
CalorieWeek buildCalorieWeek({
  required String weekStartKey,
  required String todayKey,
  required Map<String, DailyNutritionTotals> serverFood,
  required Map<String, int> serverWater,
  required Map<String, CalorieDay> localDays,
}) {
  final days = <CalorieWeekDay>[];
  for (var i = 0; i < 7; i++) {
    final key = shiftCalorieDayKey(weekStartKey, i);
    final local = localDays[key];
    days.add(CalorieWeekDay(
      dateKey: key,
      totals: local != null
          ? (local.hasFoodEntries ? local.totals : null)
          : serverFood[key],
      waterMl: local != null ? local.waterMl : (serverWater[key] ?? 0),
      isToday: key == todayKey,
      isFuture: key.compareTo(todayKey) > 0,
    ));
  }
  return CalorieWeek(weekStartKey: weekStartKey, days: days);
}
