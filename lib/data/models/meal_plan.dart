import 'package:equatable/equatable.dart';
import 'package:shoply/data/models/food_log_entry.dart';
import 'package:shoply/data/models/recipe.dart';

// Wochenplan (Teil B, Konzept 14): rows of the tables meal_plans,
// meal_plan_entries and meal_plan_settings
// (supabase/migrations/20261108002000_b_meal_plan.sql) and the local calendar
// helpers. A plan day is always the person's LOCAL calendar day, never UTC;
// a week runs Monday to Sunday (ISO, W-02).

/// Fewest and most servings a plan entry can have (stepper, check 1..20).
const int kPlanMinServings = 1;
const int kPlanMaxServings = 20;

/// Local midnight of [t]'s calendar day.
DateTime planDay(DateTime t) => DateTime(t.year, t.month, t.day);

/// Monday (local midnight) of the ISO week containing [t].
///
/// Built from calendar fields instead of subtracting `Duration(days: …)`, so a
/// week across a daylight-saving change still starts at 00:00.
DateTime planWeekStart(DateTime t) =>
    DateTime(t.year, t.month, t.day - (t.weekday - DateTime.monday));

/// The seven days (Monday to Sunday) of the week starting at [weekStart].
List<DateTime> planWeekDays(DateTime weekStart) {
  final start = planWeekStart(weekStart);
  return [
    for (var i = 0; i < 7; i++) DateTime(start.year, start.month, start.day + i),
  ];
}

/// [d] shifted by [days] calendar days (DST safe).
DateTime planAddDays(DateTime d, int days) => DateTime(d.year, d.month, d.day + days);

/// `YYYY-MM-DD` of [d]'s local calendar day (the `date` column format).
String planDateKey(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

/// The local day of a `date` column value. Only the `YYYY-MM-DD` part counts,
/// so a value with a time or zone suffix never shifts the day.
DateTime parsePlanDate(String value) {
  final parts = value.trim().substring(0, 10).split('-');
  return DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
}

int _clampServings(int servings) =>
    servings.clamp(kPlanMinServings, kPlanMaxServings);

int? _asInt(Object? v) => switch (v) {
      int i => i,
      num n => n.toInt(),
      String s => int.tryParse(s.trim()),
      _ => null,
    };

double _asDouble(Object? v) => switch (v) {
      num n => n.toDouble(),
      String s => double.tryParse(s.trim().replaceAll(',', '.')) ?? 0,
      _ => 0,
    };

DateTime? _asTime(Object? v) => v is String ? DateTime.tryParse(v) : null;

/// The parts of a recipe a plan entry keeps for itself: enough to render the
/// row and to sum ingredients offline or after the recipe was deleted
/// (`meal_plan_entries.recipe_snapshot`).
class PlanRecipeSnapshot extends Equatable {
  const PlanRecipeSnapshot({
    required this.name,
    this.imageUrl,
    this.photoColor,
    this.kcalPerServing,
    this.totalMinutes,
    required this.defaultServings,
    this.language = 'de',
    this.ingredients = const [],
  });

  factory PlanRecipeSnapshot.fromRecipe(Recipe recipe) => PlanRecipeSnapshot(
        name: recipe.name,
        imageUrl: recipe.imageUrl.isEmpty ? null : recipe.imageUrl,
        kcalPerServing: recipe.nutrition?.calories,
        totalMinutes: recipe.totalTimeMinutes,
        defaultServings: recipe.defaultServings,
        language: recipe.language,
        ingredients: recipe.ingredients,
      );

  /// Tolerant: missing or wrongly typed fields fall back to empty values,
  /// broken ingredients are skipped.
  factory PlanRecipeSnapshot.fromJson(Map<String, dynamic> json) {
    final raw = json['ingredients'];
    return PlanRecipeSnapshot(
      name: json['name'] is String ? json['name'] as String : '',
      imageUrl: json['image_url'] is String ? json['image_url'] as String : null,
      photoColor: json['photo_color'] is String ? json['photo_color'] as String : null,
      kcalPerServing: _asInt(json['kcal_per_serving']),
      totalMinutes: _asInt(json['total_minutes']),
      defaultServings: _asInt(json['default_servings']) ?? 0,
      language: json['language'] is String ? json['language'] as String : 'de',
      ingredients: [
        if (raw is List)
          for (final i in raw)
            if (i is Map && i['name'] is String)
              Ingredient(
                name: i['name'] as String,
                amount: _asDouble(i['amount']),
                unit: i['unit'] is String ? i['unit'] as String : '',
              ),
      ],
    );
  }

  final String name;
  final String? imageUrl;

  /// Placeholder colour while the photo loads (hex, optional).
  final String? photoColor;

  /// kcal of ONE serving, the number the plan shows per person.
  final int? kcalPerServing;
  final int? totalMinutes;

  /// The servings the ingredient amounts are written for.
  final int defaultServings;
  final String language;
  final List<Ingredient> ingredients;

  Map<String, dynamic> toJson() => {
        'name': name,
        'image_url': imageUrl,
        'photo_color': photoColor,
        'kcal_per_serving': kcalPerServing,
        'total_minutes': totalMinutes,
        'default_servings': defaultServings,
        'language': language,
        'ingredients': [for (final i in ingredients) i.toJson()],
      };

  @override
  List<Object?> get props => [
        name,
        imageUrl,
        photoColor,
        kcalPerServing,
        totalMinutes,
        defaultServings,
        language,
        ingredients,
      ];
}

/// One recipe on one day of the plan (`meal_plan_entries`). The id is made
/// on the device, so offline adds, undo (re-insert with the same id) and
/// retried upserts are idempotent.
class MealPlanEntry extends Equatable {
  MealPlanEntry({
    required this.id,
    required this.userId,
    required DateTime planDate,
    required this.recipeId,
    required this.snapshot,
    required int servings,
    this.mealType,
    this.position = 0,
    this.sentListId,
    this.sentServings,
    this.sentAt,
    required this.createdAt,
    required this.updatedAt,
  })  : planDate = planDay(planDate),
        servings = _clampServings(servings);

  factory MealPlanEntry.fromRow(Map<String, dynamic> row) {
    final snapshot = row['recipe_snapshot'];
    final mealType = row['meal_type'];
    final now = DateTime.now();
    return MealPlanEntry(
      id: row['id'] as String,
      userId: row['user_id'] as String? ?? '',
      planDate: parsePlanDate(row['plan_date'] as String),
      recipeId: row['recipe_id'] as String?,
      snapshot: PlanRecipeSnapshot.fromJson(
        snapshot is Map ? snapshot.cast<String, dynamic>() : const {},
      ),
      servings: _asInt(row['servings']) ?? kPlanMinServings,
      mealType: mealType is String ? MealTypeX.fromDb(mealType) : null,
      position: _asInt(row['position']) ?? 0,
      sentListId: row['sent_list_id'] as String?,
      sentServings: _asInt(row['sent_servings']),
      sentAt: _asTime(row['sent_at']),
      createdAt: _asTime(row['created_at']) ?? now,
      updatedAt: _asTime(row['updated_at']) ?? now,
    );
  }

  final String id;
  final String userId;

  /// Local calendar day (midnight).
  final DateTime planDate;

  /// Null when the recipe was deleted; then only [snapshot] is left and the
  /// ingredients no longer count ("Rezept nicht mehr verfügbar").
  final String? recipeId;
  final PlanRecipeSnapshot snapshot;

  /// 1..20.
  final int servings;

  /// Null means dinner for "Ins Tagebuch".
  final MealType? mealType;

  /// Order within the day.
  final int position;

  /// Where and for how many servings the ingredients went (W-05).
  final String? sentListId;
  final int? sentServings;
  final DateTime? sentAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get isSent => sentAt != null;

  /// Servings whose ingredients still have to go on a list: all of them
  /// before sending, afterwards only an increase (fewer servings never take
  /// anything off a list, FW-04).
  int get openServings {
    final open = isSent ? servings - (sentServings ?? 0) : servings;
    return open > 0 ? open : 0;
  }

  /// Servings planned since sending (negative = fewer), 0 when not sent.
  int get servingsChangeSinceSent => isSent ? servings - (sentServings ?? 0) : 0;

  MealPlanEntry copyWith({
    DateTime? planDate,
    String? recipeId,
    PlanRecipeSnapshot? snapshot,
    int? servings,
    MealType? mealType,
    int? position,
    String? sentListId,
    int? sentServings,
    DateTime? sentAt,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) =>
      MealPlanEntry(
        id: id,
        userId: userId,
        planDate: planDate ?? this.planDate,
        recipeId: recipeId ?? this.recipeId,
        snapshot: snapshot ?? this.snapshot,
        servings: servings ?? this.servings,
        mealType: mealType ?? this.mealType,
        position: position ?? this.position,
        sentListId: sentListId ?? this.sentListId,
        sentServings: sentServings ?? this.sentServings,
        sentAt: sentAt ?? this.sentAt,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );

  /// The entry as never sent (undo of a send).
  MealPlanEntry clearSent() => MealPlanEntry(
        id: id,
        userId: userId,
        planDate: planDate,
        recipeId: recipeId,
        snapshot: snapshot,
        servings: servings,
        mealType: mealType,
        position: position,
        createdAt: createdAt,
        updatedAt: updatedAt,
      );

  /// Columns for an upsert. created_at and updated_at are set by the
  /// database (default and trigger).
  Map<String, dynamic> toRow() => {
        'id': id,
        'user_id': userId,
        'plan_date': planDateKey(planDate),
        'recipe_id': recipeId,
        'recipe_snapshot': snapshot.toJson(),
        'servings': servings,
        'meal_type': mealType?.dbValue,
        'position': position,
        'sent_list_id': sentListId,
        'sent_servings': sentServings,
        'sent_at': sentAt?.toUtc().toIso8601String(),
      };

  /// [toRow] plus the timestamps, for the device cache.
  Map<String, dynamic> toCacheJson() => {
        ...toRow(),
        'created_at': createdAt.toUtc().toIso8601String(),
        'updated_at': updatedAt.toUtc().toIso8601String(),
      };

  @override
  List<Object?> get props => [
        id,
        userId,
        planDate,
        recipeId,
        snapshot,
        servings,
        mealType,
        position,
        sentListId,
        sentServings,
        sentAt?.toUtc(),
        createdAt.toUtc(),
        updatedAt.toUtc(),
      ];
}

/// One week of one account (`meal_plans`), only stored when it differs from
/// the defaults: its own target list, or the time of the first send (the
/// success moment shows only then, W-13/E-15).
class MealPlanWeek extends Equatable {
  MealPlanWeek({
    required DateTime weekStart,
    this.targetListId,
    this.firstSentAt,
  }) : weekStart = planWeekStart(weekStart);

  factory MealPlanWeek.fromRow(Map<String, dynamic> row) => MealPlanWeek(
        weekStart: parsePlanDate(row['week_start'] as String),
        targetListId: row['target_list_id'] as String?,
        firstSentAt: _asTime(row['first_sent_at']),
      );

  final DateTime weekStart;
  final String? targetListId;
  final DateTime? firstSentAt;

  MealPlanWeek copyWith({String? targetListId, DateTime? firstSentAt}) => MealPlanWeek(
        weekStart: weekStart,
        targetListId: targetListId ?? this.targetListId,
        firstSentAt: firstSentAt ?? this.firstSentAt,
      );

  MealPlanWeek withoutFirstSent() =>
      MealPlanWeek(weekStart: weekStart, targetListId: targetListId);

  Map<String, dynamic> toRow(String userId) => {
        'user_id': userId,
        'week_start': planDateKey(weekStart),
        'target_list_id': targetListId,
        'first_sent_at': firstSentAt?.toUtc().toIso8601String(),
      };

  @override
  List<Object?> get props => [weekStart, targetListId, firstSentAt?.toUtc()];
}

/// The person's plan settings (`meal_plan_settings`, one row per account).
class MealPlanSettings extends Equatable {
  const MealPlanSettings({
    this.defaultServings = 2,
    this.targetListId,
    this.pantry = defaultPantry,
    this.showTodayHint = true,
    this.reminderEnabled = false,
    this.reminderWeekday = DateTime.sunday,
    this.reminderHour = 18,
    this.reminderMinute = 0,
  });

  factory MealPlanSettings.fromRow(Map<String, dynamic> row) {
    final time = (row['reminder_time'] as String? ?? '18:00').split(':');
    final pantry = row['pantry'];
    return MealPlanSettings(
      defaultServings: _clampServings(_asInt(row['default_servings']) ?? 2),
      targetListId: row['target_list_id'] as String?,
      pantry: pantry is List ? [for (final p in pantry) if (p is String) p] : defaultPantry,
      showTodayHint: row['show_today_hint'] as bool? ?? true,
      reminderEnabled: row['reminder_enabled'] as bool? ?? false,
      reminderWeekday: (_asInt(row['reminder_weekday']) ?? DateTime.sunday).clamp(1, 7),
      reminderHour: (int.tryParse(time.first) ?? 18).clamp(0, 23),
      reminderMinute: (time.length > 1 ? int.tryParse(time[1]) ?? 0 : 0).clamp(0, 59),
    );
  }

  /// "Hast du meist da" start values (FW-06). "Öl" also covers "Olivenöl".
  static const List<String> defaultPantry = ['Salz', 'Pfeffer', 'Wasser', 'Öl', 'Zucker', 'Mehl'];

  static const MealPlanSettings defaults = MealPlanSettings();

  final int defaultServings;

  /// Null: the list opened last ("Liste von heute").
  final String? targetListId;
  final List<String> pantry;
  final bool showTodayHint;
  final bool reminderEnabled;

  /// ISO weekday, 7 = Sunday.
  final int reminderWeekday;
  final int reminderHour;
  final int reminderMinute;

  MealPlanSettings copyWith({
    int? defaultServings,
    String? targetListId,
    List<String>? pantry,
    bool? showTodayHint,
    bool? reminderEnabled,
    int? reminderWeekday,
    int? reminderHour,
    int? reminderMinute,
  }) =>
      MealPlanSettings(
        defaultServings: _clampServings(defaultServings ?? this.defaultServings),
        targetListId: targetListId ?? this.targetListId,
        pantry: pantry ?? this.pantry,
        showTodayHint: showTodayHint ?? this.showTodayHint,
        reminderEnabled: reminderEnabled ?? this.reminderEnabled,
        reminderWeekday: reminderWeekday ?? this.reminderWeekday,
        reminderHour: reminderHour ?? this.reminderHour,
        reminderMinute: reminderMinute ?? this.reminderMinute,
      );

  /// Back to "Liste von heute".
  MealPlanSettings withoutTargetList() => MealPlanSettings(
        defaultServings: defaultServings,
        pantry: pantry,
        showTodayHint: showTodayHint,
        reminderEnabled: reminderEnabled,
        reminderWeekday: reminderWeekday,
        reminderHour: reminderHour,
        reminderMinute: reminderMinute,
      );

  Map<String, dynamic> toRow(String userId) => {
        'user_id': userId,
        'default_servings': defaultServings,
        'target_list_id': targetListId,
        'pantry': pantry,
        'show_today_hint': showTodayHint,
        'reminder_enabled': reminderEnabled,
        'reminder_weekday': reminderWeekday,
        'reminder_time': '${reminderHour.toString().padLeft(2, '0')}:'
            '${reminderMinute.toString().padLeft(2, '0')}:00',
      };

  @override
  List<Object?> get props => [
        defaultServings,
        targetListId,
        pantry,
        showTodayHint,
        reminderEnabled,
        reminderWeekday,
        reminderHour,
        reminderMinute,
      ];
}

/// How much of a shopping item came from which plan entry (W-17: the plan's
/// own amounts never count as "already on the list"). Same shape as the
/// planned column `shopping_items.plan_contributions` (Teil A, E-11).
class PlanContribution extends Equatable {
  const PlanContribution({
    required this.entryId,
    required this.family,
    required this.baseAmount,
    this.undoToken,
  });

  factory PlanContribution.fromJson(Map<String, dynamic> json) => PlanContribution(
        entryId: json['entry_id'] as String? ?? '',
        family: json['family'] as String? ?? '',
        baseAmount: _asDouble(json['base_amount']),
        undoToken: json['undo_token'] as String?,
      );

  final String entryId;

  /// Unit family id (see `PlanUnitFamily.id` in meal_plan_aggregator.dart).
  final String family;

  /// Amount in the family's base unit (g, ml, pieces, cans, …).
  final double baseAmount;

  /// The send that added it, so undo removes exactly these amounts.
  final String? undoToken;

  Map<String, dynamic> toJson() => {
        'entry_id': entryId,
        'family': family,
        'base_amount': baseAmount,
        if (undoToken != null) 'undo_token': undoToken,
      };

  @override
  List<Object?> get props => [entryId, family, baseAmount, undoToken];
}
