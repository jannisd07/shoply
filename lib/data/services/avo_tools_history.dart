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
    final store = ref.read(avoSplitStoreProvider);
    final trip = await store.trip(historyId);
    if (trip == null) return {'error': 'Shopping history entry not found'};
    final existing = await store.splits(historyId);
    final plan = avoSplitGate(
      trip: trip,
      others: AvoAssistantService._stringList(args['participant_names']),
      yourName: await _yourName(ref),
      yourUserId: store.userId,
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

  /// "Teilen" on a split preview ([avoSplitTrip]): checks module, trip,
  /// payer and split again at the tap. Null when the card is out of date.
  Future<AvoSplitRecord?> splitTripForAvo(
    WidgetRef ref,
    AvoSplitPreviewCard card,
  ) => avoSplitTrip(
    ref.read(avoSplitStoreProvider),
    card,
    moduleOn: ref.read(moduleEnabledProvider(AppModule.costSplit)),
  );
}
