import 'package:equatable/equatable.dart';

/// One weigh-in for a user on a given day (unique per user/day server-side —
/// re-logging the same day overwrites via upsert).
class WeightLogEntry extends Equatable {
  final String id;
  final String userId;
  final DateTime loggedDate;
  final double weightKg;
  final String? note;
  final DateTime createdAt;

  const WeightLogEntry({
    required this.id,
    required this.userId,
    required this.loggedDate,
    required this.weightKg,
    this.note,
    required this.createdAt,
  });

  factory WeightLogEntry.fromJson(Map<String, dynamic> json) {
    return WeightLogEntry(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      loggedDate: DateTime.parse(json['logged_date'] as String),
      weightKg: (json['weight_kg'] as num).toDouble(),
      note: json['note'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toUpsertJson() {
    return {
      'user_id': userId,
      'logged_date':
          '${loggedDate.year.toString().padLeft(4, '0')}-${loggedDate.month.toString().padLeft(2, '0')}-${loggedDate.day.toString().padLeft(2, '0')}',
      'weight_kg': weightKg,
      'note': note,
    };
  }

  @override
  List<Object?> get props => [id, userId, loggedDate, weightKg, note, createdAt];
}
