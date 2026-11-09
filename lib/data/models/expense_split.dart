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

  /// `equal` or `custom` (L5); `custom` for rows written before.
  final String splitMode;

  /// Order in "Wer teilt?"; the rest cent of an equal split goes to 0.
  final int position;

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
    this.splitMode = 'custom',
    this.position = 0,
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
      splitMode: json['split_mode'] as String? ?? 'custom',
      position: (json['position'] as num?)?.toInt() ?? 0,
    );
  }

  /// [amount] in whole cents.
  int get amountCents => (amount * 100).round();

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
      splitMode: splitMode,
      position: position,
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
        splitMode,
        position,
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

/// One share in "Offene Beträge" (V8, L8): a share the signed-in person
/// still owes, or one others still owe them, plus shares settled in the
/// last 30 days. Amounts in whole cents.
class OpenShare extends Equatable {
  final String splitId;
  final String historyId;

  /// The person who owes this share; null for a name-only person.
  final String? userId;
  final String participantName;
  final int amountCents;
  final bool isPaid;
  final DateTime? paidAt;

  /// Order in "Wer teilt?".
  final int position;
  final String? listId;
  final String listName;
  final DateTime completedAt;
  final int? totalCostCents;
  final String? paidByUserId;
  final String? paidByName;

  /// `StoreChainDirectory` id of the trip's market, or null.
  final String? storeChainId;

  const OpenShare({
    required this.splitId,
    required this.historyId,
    this.userId,
    required this.participantName,
    required this.amountCents,
    required this.isPaid,
    this.paidAt,
    this.position = 0,
    this.listId,
    required this.listName,
    required this.completedAt,
    this.totalCostCents,
    this.paidByUserId,
    this.paidByName,
    this.storeChainId,
  });

  /// A row of the server function `open_split_shares`.
  factory OpenShare.fromRpc(Map<String, dynamic> json) => OpenShare(
    splitId: json['split_id'] as String,
    historyId: json['history_id'] as String,
    userId: json['user_id'] as String?,
    participantName: json['participant_name'] as String? ?? '',
    amountCents: ((json['amount'] as num) * 100).round(),
    isPaid: json['is_paid'] as bool? ?? false,
    paidAt: json['paid_at'] == null
        ? null
        : DateTime.parse(json['paid_at'] as String),
    position: (json['split_position'] as num?)?.toInt() ?? 0,
    listId: json['list_id'] as String?,
    listName: json['list_name'] as String? ?? '',
    completedAt: DateTime.parse(json['completed_at'] as String),
    totalCostCents: json['total_cost'] == null
        ? null
        : ((json['total_cost'] as num) * 100).round(),
    paidByUserId: json['paid_by_user_id'] as String?,
    paidByName: json['paid_by_name'] as String?,
    storeChainId: json['store_chain'] as String?,
  );

  /// The same fields as [OpenShare.fromRpc] reads, for the local cache.
  Map<String, dynamic> toJson() => {
    'split_id': splitId,
    'history_id': historyId,
    'user_id': userId,
    'participant_name': participantName,
    'amount': amountCents / 100,
    'is_paid': isPaid,
    'paid_at': paidAt?.toIso8601String(),
    'split_position': position,
    'list_id': listId,
    'list_name': listName,
    'completed_at': completedAt.toIso8601String(),
    'total_cost': totalCostCents == null ? null : totalCostCents! / 100,
    'paid_by_user_id': paidByUserId,
    'paid_by_name': paidByName,
    'store_chain': storeChainId,
  };

  /// Whether [me] is owed this share (I paid, someone else owes it).
  bool isOwedTo(String me) => paidByUserId == me && userId != me;

  /// Whether [me] owes this share to someone else.
  bool isOwedBy(String me) => userId == me && paidByUserId != me;

  OpenShare copyWith({bool? isPaid, DateTime? paidAt}) => OpenShare(
    splitId: splitId,
    historyId: historyId,
    userId: userId,
    participantName: participantName,
    amountCents: amountCents,
    isPaid: isPaid ?? this.isPaid,
    paidAt: (isPaid ?? this.isPaid) ? (paidAt ?? this.paidAt) : null,
    position: position,
    listId: listId,
    listName: listName,
    completedAt: completedAt,
    totalCostCents: totalCostCents,
    paidByUserId: paidByUserId,
    paidByName: paidByName,
    storeChainId: storeChainId,
  );

  @override
  List<Object?> get props => [
    splitId,
    historyId,
    userId,
    participantName,
    amountCents,
    isPaid,
    paidAt,
    position,
    listId,
    listName,
    completedAt,
    totalCostCents,
    paidByUserId,
    paidByName,
    storeChainId,
  ];
}
