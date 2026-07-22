import 'package:equatable/equatable.dart';

/// One person's share of a completed shopping trip's cost.
///
/// [userId] is set when the participant is an app user (usually a member of
/// the list the trip belongs to); it is left null for a participant added by
/// name only (e.g. a roommate who doesn't use the app).
class ExpenseSplit extends Equatable {
  final String id;
  final String historyId;
  final String? userId;
  final String participantName;
  final double amount;
  final bool isPaid;
  final DateTime? paidAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  const ExpenseSplit({
    required this.id,
    required this.historyId,
    this.userId,
    required this.participantName,
    required this.amount,
    this.isPaid = false,
    this.paidAt,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ExpenseSplit.fromJson(Map<String, dynamic> json) {
    return ExpenseSplit(
      id: json['id'] as String,
      historyId: json['history_id'] as String,
      userId: json['user_id'] as String?,
      participantName: json['participant_name'] as String,
      amount: (json['amount'] as num).toDouble(),
      isPaid: json['is_paid'] as bool? ?? false,
      paidAt: json['paid_at'] != null
          ? DateTime.parse(json['paid_at'] as String)
          : null,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'history_id': historyId,
      'user_id': userId,
      'participant_name': participantName,
      'amount': amount,
      'is_paid': isPaid,
      'paid_at': paidAt?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  /// Fields for a fresh insert — id/timestamps are assigned by the database.
  Map<String, dynamic> toInsertJson() {
    return {
      'history_id': historyId,
      'user_id': userId,
      'participant_name': participantName,
      'amount': amount,
      'is_paid': isPaid,
      if (isPaid) 'paid_at': (paidAt ?? createdAt).toIso8601String(),
    };
  }

  ExpenseSplit copyWith({
    bool? isPaid,
    DateTime? paidAt,
    DateTime? updatedAt,
  }) {
    return ExpenseSplit(
      id: id,
      historyId: historyId,
      userId: userId,
      participantName: participantName,
      amount: amount,
      isPaid: isPaid ?? this.isPaid,
      paidAt: paidAt ?? this.paidAt,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [
        id,
        historyId,
        userId,
        participantName,
        amount,
        isPaid,
        paidAt,
        createdAt,
        updatedAt,
      ];
}

/// A [ShoppingHistory] trip together with its splits, for UI convenience —
/// bundles the "who owes what" view without re-fetching the trip each time.
class TripSplitSummary extends Equatable {
  final String historyId;
  final String listName;
  final DateTime completedAt;
  final double totalCost;
  final String? paidByUserId;
  final String? paidByName;
  final List<ExpenseSplit> splits;

  const TripSplitSummary({
    required this.historyId,
    required this.listName,
    required this.completedAt,
    required this.totalCost,
    this.paidByUserId,
    this.paidByName,
    required this.splits,
  });

  @override
  List<Object?> get props => [
        historyId,
        listName,
        completedAt,
        totalCost,
        paidByUserId,
        paidByName,
        splits,
      ];
}
