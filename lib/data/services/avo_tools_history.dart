part of 'avo_assistant_service.dart';

// History, restocking and cost splitting (Kap. 5.2).
extension AvoHistoryTools on AvoAssistantService {
  Future<Map<String, Object?>> _toolShoppingHistory(
    Map<String, Object?> args,
    WidgetRef ref,
    AvoContext? context,
    List<AvoWidgetPayload> payloads,
  ) async {
    final limit = ((args['limit'] as num?)?.toInt() ?? 5).clamp(1, 30);
    final history = await ShoppingHistoryService().getRecentHistory(
      limit: limit,
    );
    final target = _targetList(ref, context);
    payloads.add(
      AvoWidgetPayload.card(
        AvoTripsCard(history, listId: target?.id, listName: target?.name),
      ),
    );
    return {
      'found': history.length,
      'history': history
          .map(
            (h) => {
              'id': h.id,
              'list_name': h.listName,
              'completed_at': h.completedAt.toIso8601String(),
              'item_count': h.items.length,
              'items': h.items.map((i) => i.name).toList(),
            },
          )
          .toList(),
    };
  }

  Future<Map<String, Object?>> _toolAddHistoryItems(
    Map<String, Object?> args,
    WidgetRef ref,
    List<AvoWidgetPayload> payloads,
  ) async {
    final historyId = args['history_id'] as String?;
    final listId = args['list_id'] as String?;
    if (historyId == null || listId == null) {
      return {'error': 'history_id and list_id are required'};
    }
    final filter = AvoAssistantService._stringList(
      args['item_names'],
    ).map((s) => s.toLowerCase()).toSet();

    final entry = await _findTrip(historyId);
    if (entry == null) return {'error': 'History entry not found'};

    final itemsToAdd = filter.isEmpty
        ? entry.items
        : entry.items
              .where((i) => filter.contains(i.name.toLowerCase()))
              .toList();
    if (itemsToAdd.isEmpty) {
      return {'added': 0, 'note': 'No item of the trip matched.'};
    }

    // One batch (merged like the list screen), so it is all or nothing and
    // "Widerrufen" takes the whole trip back.
    final record = await AvoAssistantService._changes(ref).addBatch(
      tool: 'add_history_items_to_list',
      source: AvoItemsSource.history,
      listId: listId,
      items: [
        for (final i in itemsToAdd)
          NewItem(
            name: i.name,
            quantity: i.quantity,
            unit: i.unit,
            category: i.category,
          ),
      ],
    );
    payloads.add(AvoWidgetPayload.record(record));
    await _afterBulkListChange(ref, listId);
    return {
      'added': record.added,
      if (record.alreadyOn.isNotEmpty)
        'already_on_list': record.alreadyOn.length,
    };
  }

  /// A trip of the person's history by id (the newest 30).
  Future<ShoppingHistory?> _findTrip(String historyId) async {
    final history = await ShoppingHistoryService().getRecentHistory(limit: 30);
    for (final h in history) {
      if (h.id == historyId) return h;
    }
    return null;
  }

  /// The list Avo would put things on: the screen's list, else the newest.
  ShoppingListModel? _targetList(WidgetRef ref, AvoContext? context) {
    final lists = context?.lists ?? const <ShoppingListModel>[];
    final screenId = ref.read(avoScreenContextProvider)?.listId;
    if (screenId != null) {
      final match = lists.where((l) => l.id == screenId).firstOrNull;
      if (match != null) return match;
    }
    if (lists.isEmpty) return null;
    return lists.reduce((a, b) => b.updatedAt.isAfter(a.updatedAt) ? b : a);
  }

  Future<Map<String, Object?>> _toolRestockSuggestions(
    Map<String, Object?> args,
    WidgetRef ref,
    AvoContext? context,
    List<AvoWidgetPayload> payloads,
  ) async {
    final limit = (args['limit'] as num?)?.toInt() ?? 5;
    final suggestions = await AvoNudgeService.instance.getRestockSuggestions(
      limit: limit.clamp(1, 10),
    );
    if (suggestions.isNotEmpty) {
      final target = _targetList(ref, context);
      payloads.add(
        AvoWidgetPayload.card(
          AvoRestockCard(
            [
              for (final s in suggestions)
                (
                  name: s.displayName,
                  everyDays: s.averageDays,
                  quantity: s.preferredQuantity,
                  category: s.preferredCategory,
                ),
            ],
            listId: target?.id,
            listName: target?.name,
          ),
        ),
      );
    }
    if (suggestions.isEmpty) {
      return {
        'found': 0,
        'note':
            'Nothing seems due right now — either everything was bought '
            'recently, or there is not enough purchase history yet (an item '
            'needs 3+ tracked purchases).',
      };
    }
    const weekdayNames = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    return {
      'found': suggestions.length,
      'suggestions': suggestions
          .map(
            (s) => {
              'item': s.displayName,
              'buys_about_every_days': s.averageDays,
              'last_bought_days_ago': s.daysSince,
              if (s.usualWeekday != null)
                'usually_bought_on': weekdayNames[s.usualWeekday! - 1],
            },
          )
          .toList(),
    };
  }

  /// `split_trip_cost` only shows the split (Kap. 5.2); "Teilen" on the
  /// card saves it ([splitTripForAvo]). The model can find a trip on its
  /// own, so text in a shared list must never split or replace anything.
  Future<Map<String, Object?>> _toolSplitTripCost(
    Map<String, Object?> args,
    WidgetRef ref,
    List<AvoWidgetPayload> payloads,
  ) async {
    if (!ref.read(moduleEnabledProvider(AppModule.costSplit))) {
      payloads.add(AvoWidgetPayload.moduleOff(AppModule.costSplit));
      return {
        'not_available': true,
        'error': 'The module Kosten teilen is off.',
      };
    }
    final historyId = args['history_id'] as String?;
    if (historyId == null || historyId.isEmpty) {
      return {
        'error': 'history_id is required — call get_shopping_history first',
      };
    }
    final trip = await _findTrip(historyId);
    if (trip == null) return {'error': 'Shopping history entry not found'};
    final existing = await ExpenseSplitService.instance.getSplitsForHistory(
      historyId,
    );
    final plan = avoSplitGate(
      trip: trip,
      others: AvoAssistantService._stringList(args['participant_names']),
      yourName: await _yourName(ref),
      yourUserId: _supabase.auth.currentUser?.id,
      existing: existing,
      modelTotal: (args['total_cost'] as num?)?.toDouble(),
    );
    final gate = plan.gate;
    if (gate == null) return plan.error!;
    payloads.add(gate.card);
    return gate.result;
  }

  /// The person's display name for their share ("du" on the card).
  Future<String> _yourName(WidgetRef ref) async {
    try {
      final user = await ref.read(currentUserProvider.future);
      final name = user?.displayName?.trim();
      if (name != null && name.isNotEmpty) return name;
    } catch (_) {}
    return AvoAssistantService._t(ref, 'avo_you');
  }

  /// "Teilen" on a split preview: reads the trip and its split again and
  /// saves only when both are as the card showed them (a total recorded
  /// meanwhile, or a share paid meanwhile, means the card is out of date).
  /// Null when the card is out of date. There is no way back yet (L9); the
  /// card said what it replaces before the tap.
  Future<AvoSplitRecord?> splitTripForAvo(
    WidgetRef ref,
    AvoSplitPreviewCard card,
  ) async {
    final trip = await _findTrip(card.historyId);
    if (trip == null) return null;
    final tripTotal = trip.totalCost;
    final hasTotal = tripTotal != null && tripTotal > 0;
    if (hasTotal != card.totalFromTrip ||
        (hasTotal && (tripTotal - card.total).abs() > 0.005)) {
      return null;
    }
    final existing = await ExpenseSplitService.instance.getSplitsForHistory(
      card.historyId,
    );
    final now = [
      for (final s in existing) (name: s.participantName, paid: s.isPaid),
    ];
    if (now.length != card.replaces.length ||
        !now.every(card.replaces.contains)) {
      return null;
    }
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null || userId != card.yourUserId) return null;
    final you = card.shares.firstWhere((s) => s.isYou);
    await ExpenseSplitService.instance.createSplits(
      historyId: card.historyId,
      totalCost: card.total,
      shares: [
        for (final s in card.shares)
          SplitShare(
            userId: s.isYou ? userId : null,
            participantName: s.name,
            amount: s.amount,
          ),
      ],
      paidByUserId: userId,
      paidByName: you.name,
    );
    return AvoSplitRecord(
      tool: 'split_trip_cost',
      tripDate: card.tripDate,
      shares: card.shares,
    );
  }
}
