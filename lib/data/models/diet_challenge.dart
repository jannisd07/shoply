import 'package:equatable/equatable.dart';

/// Which built-in diet challenge a row tracks. `custom` exists in the DB
/// check constraint for future use but has no dedicated UI yet.
enum ChallengeType { fasting16_8, noSugar30, custom }

extension ChallengeTypeX on ChallengeType {
  String get dbValue => switch (this) {
        ChallengeType.fasting16_8 => 'fasting_16_8',
        ChallengeType.noSugar30 => 'no_sugar_30',
        ChallengeType.custom => 'custom',
      };

  static ChallengeType fromDb(String value) => switch (value) {
        'fasting_16_8' => ChallengeType.fasting16_8,
        'no_sugar_30' => ChallengeType.noSugar30,
        _ => ChallengeType.custom,
      };

  /// Fixed-length challenges auto-complete at their target end date.
  /// `fasting_16_8` is an ongoing daily habit with no fixed finish line —
  /// the user ends it themselves (completed or abandoned) whenever they like.
  int? get fixedDurationDays => switch (this) {
        ChallengeType.noSugar30 => 30,
        ChallengeType.fasting16_8 => null,
        ChallengeType.custom => null,
      };
}

enum ChallengeStatus { active, completed, abandoned }

extension ChallengeStatusX on ChallengeStatus {
  String get dbValue => switch (this) {
        ChallengeStatus.active => 'active',
        ChallengeStatus.completed => 'completed',
        ChallengeStatus.abandoned => 'abandoned',
      };

  static ChallengeStatus fromDb(String value) => switch (value) {
        'completed' => ChallengeStatus.completed,
        'abandoned' => ChallengeStatus.abandoned,
        _ => ChallengeStatus.active,
      };
}

String challengeDateKey(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

/// A user's participation in one diet challenge (e.g. 16:8 fasting, 30-day
/// no sugar), with a per-day self check-in log ("kept it today?").
class DietChallenge extends Equatable {
  final String id;
  final String userId;
  final ChallengeType type;
  final ChallengeStatus status;
  final DateTime startedAt;
  final DateTime? targetEndAt;
  final DateTime? completedAt;
  final DateTime createdAt;

  /// `'yyyy-MM-dd' -> kept?`. A day with no entry is unmarked (not assumed
  /// success or failure) — only rendered as "missed" once it's in the past.
  final Map<String, bool> dailyCheckins;

  const DietChallenge({
    required this.id,
    required this.userId,
    required this.type,
    this.status = ChallengeStatus.active,
    required this.startedAt,
    this.targetEndAt,
    this.completedAt,
    required this.createdAt,
    this.dailyCheckins = const {},
  });

  factory DietChallenge.fromJson(Map<String, dynamic> json) {
    final rawCheckins = json['daily_checkins'] as Map<String, dynamic>? ?? const {};
    return DietChallenge(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      type: ChallengeTypeX.fromDb(json['challenge_type'] as String),
      status: ChallengeStatusX.fromDb(json['status'] as String? ?? 'active'),
      startedAt: DateTime.parse(json['started_at'] as String),
      targetEndAt:
          json['target_end_at'] != null ? DateTime.parse(json['target_end_at'] as String) : null,
      completedAt:
          json['completed_at'] != null ? DateTime.parse(json['completed_at'] as String) : null,
      createdAt: DateTime.parse(json['created_at'] as String),
      dailyCheckins: rawCheckins.map((key, value) => MapEntry(key, value as bool)),
    );
  }

  Map<String, dynamic> toInsertJson() {
    return {
      'user_id': userId,
      'challenge_type': type.dbValue,
      'status': status.dbValue,
      'started_at': startedAt.toIso8601String(),
      'target_end_at': targetEndAt?.toIso8601String(),
    };
  }

  bool get isCheckedInToday => dailyCheckins.containsKey(challengeDateKey(DateTime.now()));

  bool? checkinFor(DateTime date) => dailyCheckins[challengeDateKey(date)];

  int get totalCheckins => dailyCheckins.length;

  int get keptCount => dailyCheckins.values.where((kept) => kept).length;

  /// Consecutive kept days counting back from the most recent check-in.
  /// An explicit "not today" check-in ends the streak at 0 immediately; an
  /// unmarked today falls back to yesterday so the streak still shows while
  /// today hasn't been checked in yet. A gap of 2+ unmarked days breaks it.
  int get currentStreak {
    final today = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
    final todayKey = challengeDateKey(today);
    DateTime cursor;
    if (!dailyCheckins.containsKey(todayKey)) {
      cursor = today.subtract(const Duration(days: 1));
    } else if (dailyCheckins[todayKey] == true) {
      cursor = today;
    } else {
      return 0;
    }
    int streak = 0;
    while (dailyCheckins[challengeDateKey(cursor)] == true) {
      streak++;
      cursor = cursor.subtract(const Duration(days: 1));
    }
    return streak;
  }

  int get daysElapsed =>
      DateTime.now().difference(DateTime(startedAt.year, startedAt.month, startedAt.day)).inDays +
      1;

  int? get fixedDurationDays => type.fixedDurationDays;

  /// Days remaining until a fixed-length challenge's target end (null for
  /// open-ended challenges like 16:8, or once the challenge is no longer
  /// active).
  int? get daysRemaining {
    final end = targetEndAt;
    if (end == null || status != ChallengeStatus.active) return null;
    final endDay = DateTime(end.year, end.month, end.day);
    final today = DateTime.now();
    final todayDay = DateTime(today.year, today.month, today.day);
    return endDay.difference(todayDay).inDays.clamp(0, 1 << 30);
  }

  /// A fixed-length challenge is ready to auto-complete once its target end
  /// date has passed (still active in the DB until the app closes it out).
  bool get isPastTargetEnd {
    final end = targetEndAt;
    if (end == null || status != ChallengeStatus.active) return false;
    return !DateTime.now().isBefore(end);
  }

  double get adherenceRate => totalCheckins == 0 ? 0 : keptCount / totalCheckins;

  DietChallenge copyWith({
    ChallengeStatus? status,
    DateTime? completedAt,
    Map<String, bool>? dailyCheckins,
  }) {
    return DietChallenge(
      id: id,
      userId: userId,
      type: type,
      status: status ?? this.status,
      startedAt: startedAt,
      targetEndAt: targetEndAt,
      completedAt: completedAt ?? this.completedAt,
      createdAt: createdAt,
      dailyCheckins: dailyCheckins ?? this.dailyCheckins,
    );
  }

  @override
  List<Object?> get props =>
      [id, userId, type, status, startedAt, targetEndAt, completedAt, createdAt, dailyCheckins];
}
