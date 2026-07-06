import 'package:equatable/equatable.dart';

/// One logged glass/bottle of water. A day's total is the sum of all
/// entries for that [loggedDate].
class WaterLogEntry extends Equatable {
  final String id;
  final String userId;
  final DateTime loggedDate;
  final int amountMl;
  final DateTime createdAt;

  const WaterLogEntry({
    required this.id,
    required this.userId,
    required this.loggedDate,
    required this.amountMl,
    required this.createdAt,
  });

  factory WaterLogEntry.fromJson(Map<String, dynamic> json) {
    return WaterLogEntry(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      loggedDate: DateTime.parse(json['logged_date'] as String),
      amountMl: json['amount_ml'] as int,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toInsertJson() {
    return {
      'user_id': userId,
      'logged_date':
          '${loggedDate.year.toString().padLeft(4, '0')}-${loggedDate.month.toString().padLeft(2, '0')}-${loggedDate.day.toString().padLeft(2, '0')}',
      'amount_ml': amountMl,
    };
  }

  @override
  List<Object?> get props => [id, userId, loggedDate, amountMl, createdAt];
}
