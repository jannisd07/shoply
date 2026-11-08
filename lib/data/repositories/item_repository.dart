import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:shoply/data/models/shopping_item_model.dart';
import 'package:shoply/data/repositories/item_batch.dart';
import 'package:shoply/data/services/ai_categorization_service.dart';
import 'package:shoply/data/services/language_detection_service.dart';
import 'package:shoply/data/services/push_notification_service.dart';
import 'package:shoply/data/services/supabase_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

export 'package:shoply/data/repositories/item_batch.dart';

class ItemRepository {
  static final ItemRepository instance = ItemRepository();
  final SupabaseService _supabase;
  final AiCategorizationService _categories = AiCategorizationService.instance;
  final Map<String, RealtimeChannel> _channels = {};

  ItemRepository({SupabaseService? supabase})
    : _supabase = supabase ?? SupabaseService.instance;

  /// Get current user ID
  String? get currentUserId => _supabase.currentUser?.id;

  /// Get the name of a shopping list
  Future<String?> getListName(String listId) async {
    try {
      final response = await _supabase
          .from('shopping_lists')
          .select('name')
          .eq('id', listId)
          .single();
      return response['name'] as String?;
    } catch (e) {
      debugPrint('⚠️ [ITEM_REPO] Failed to get list name: $e');
      return null;
    }
  }

  /// Get all items for a list: manually ordered items first (by
  /// `order_index`), then never-ordered ones in creation order. Sorted in SQL
  /// so the order is total and identical on every reload.
  Future<List<ShoppingItemModel>> getListItems(String listId) async {
    final response = await _supabase
        .from('shopping_items')
        .select()
        .eq('list_id', listId)
        .order('order_index', ascending: true, nullsFirst: false)
        .order('created_at', ascending: true);

    return (response as List)
        .map((json) => ShoppingItemModel.fromJson(json))
        .toList();
  }

  /// All items of several lists in one query (e.g. home-screen candidate
  /// scans), instead of one [getListItems] round trip per list.
  Future<List<ShoppingItemModel>> getItemsForLists(List<String> listIds) async {
    if (listIds.isEmpty) return const [];
    final response = await _supabase
        .from('shopping_items')
        .select()
        .inFilter('list_id', listIds)
        .order('order_index', ascending: true, nullsFirst: false)
        .order('created_at', ascending: true);

    return (response as List)
        .map((json) => ShoppingItemModel.fromJson(json))
        .toList();
  }

  /// Add a new item to a list.
  ///
  /// Merges into an existing unchecked item with the same name and unit,
  /// categorizes locally at once when [category] is null (Claude refines it
  /// in the background), and parses amount
  /// and unit out of the text (e.g. "2 cups flour") when none were given.
  Future<ShoppingItemModel> addItem({
    required String listId,
    required String name,
    double quantity = 1.0,
    String? unit,
    String? category,
    String? notes,
    bool isDietWarning = false,
    String? barcode,
    double? price,
    String? priceCurrency,
    String? priceRetailer,
    String? priceUnit,
    double? priceOldValue,
    bool autoParse = true,
  }) async {
    debugPrint('🔵 [ITEM_REPO] addItem "$name" → list $listId');

    final userId = _supabase.currentUser?.id;
    if (userId == null) {
      debugPrint('❌ [ITEM_REPO] User not authenticated');
      throw Exception('User not authenticated');
    }

    // 🧠 AUTO-PARSE: only worth an LLM round trip when the text contains a
    // number at all — a plain name like "Milch" has nothing to parse.
    String parsedName = name;
    double parsedQuantity = quantity;
    String? parsedUnit = unit;

    if (autoParse &&
        quantity == 1.0 &&
        unit == null &&
        _containsDigit.hasMatch(name)) {
      try {
        final parsed = await _categories.parseIngredient(name);
        parsedName = parsed['name'] as String? ?? name;
        parsedQuantity = (parsed['amount'] as num?)?.toDouble() ?? 1.0;
        parsedUnit = parsed['unit'] as String?;

        // Convert "pcs" to null for cleaner display
        if (parsedUnit == 'pcs' || parsedUnit == 'pc') {
          parsedUnit = null;
        }

        debugPrint(
          '✅ [ITEM_REPO] Parsed "$name" → name="$parsedName", qty=$parsedQuantity, unit=$parsedUnit',
        );
      } catch (e) {
        debugPrint('⚠️ [ITEM_REPO] Auto-parse failed, using original: $e');
      }
    }

    // 🔍 MERGE: an unchecked item with the same name AND unit absorbs the new
    // quantity ("2 kg" + "500 g" must not become "502 kg").
    try {
      final existingItems = await _supabase
          .from('shopping_items')
          .select()
          .eq('list_id', listId)
          .eq('is_checked', false)
          .ilike('name', _escapeLikePattern(parsedName.trim()));

      final sameUnit = (existingItems as List)
          .map((json) => ShoppingItemModel.fromJson(json))
          .where((i) => _normalizeUnit(i.unit) == _normalizeUnit(parsedUnit));

      if (sameUnit.isNotEmpty) {
        final existingItem = sameUnit.first;
        final newQuantity = existingItem.quantity + parsedQuantity;

        debugPrint(
          '🔄 [ITEM_REPO] Merging into "${existingItem.name}": ${existingItem.quantity} + $parsedQuantity = $newQuantity',
        );

        final updatedResponse = await _supabase
            .from('shopping_items')
            .update({
              'quantity': newQuantity,
              'updated_at': DateTime.now().toIso8601String(),
              if (price != null)
                ..._priceFields(
                  price,
                  priceCurrency,
                  priceRetailer,
                  priceUnit,
                  priceOldValue,
                ),
            })
            .eq('id', existingItem.id)
            .select()
            .single();

        await _touchList(listId);
        return ShoppingItemModel.fromJson(updatedResponse);
      }
    } catch (e) {
      debugPrint(
        '⚠️ [ITEM_REPO] Error checking for existing item: $e - will create new item',
      );
    }

    // Without a category the item gets the local answer at once (never
    // waits for the network); Claude refines it in the background.
    final String finalCategory =
        category ?? _categories.categorizeLocal(parsedName);
    final refine = category == null;

    try {
      final response = await _supabase
          .from('shopping_items')
          .insert({
            'list_id': listId,
            'name': parsedName,
            'quantity': parsedQuantity,
            'unit': parsedUnit,
            'category':
                finalCategory, // Legacy field - kept for backward compatibility
            'category_id': finalCategory,
            'language': LanguageDetectionService.detectLanguage(parsedName),
            'notes': notes,
            'is_diet_warning': isDietWarning,
            'barcode': barcode,
            'added_by': userId,
            if (price != null)
              ..._priceFields(
                price,
                priceCurrency,
                priceRetailer,
                priceUnit,
                priceOldValue,
              ),
          })
          .select()
          .single();

      await _touchList(listId);
      final model = ShoppingItemModel.fromJson(response);
      if (refine) {
        unawaited(_refineInBackground(model.id, parsedName, finalCategory));
      }

      // 🔔 The "item added" notification is sent by the caller
      // (ItemsNotifier.addItem → sendItemAddedNotification), not from here,
      // to avoid duplicates when other addItem() callers exist.
      return model;
    } catch (e) {
      debugPrint('❌ [ITEM_REPO] Database insert failed for "$parsedName": $e');
      rethrow;
    }
  }

  /// Puts several items on [listId] at once, in one insert plus one update
  /// per merged item (Wochenplan, "Zutaten auf die Liste", import).
  ///
  /// Items with the same name and unit as an unchecked item on the list are
  /// merged into it; the batch itself is combined first. Missing categories
  /// are set in the background, so the call returns as soon as the rows are
  /// written. Keep the returned token to offer "Widerrufen".
  Future<AddItemsResult> addItems(String listId, List<NewItem> items) async {
    final userId = _supabase.currentUser?.id;
    if (userId == null) throw Exception('User not authenticated');

    final existing = await _supabase
        .from('shopping_items')
        .select()
        .eq('list_id', listId)
        .eq('is_checked', false);
    final existingItems = (existing as List)
        .map((json) => ShoppingItemModel.fromJson(json))
        .toList();
    final plan = AddItemsPlan.of(existingItems, items);

    final changed = <ShoppingItemModel>[];
    final previousQuantities = <String, double>{};
    for (final entry in plan.merges.entries) {
      final item = existingItems.firstWhere((i) => i.id == entry.key);
      previousQuantities[item.id] = item.quantity;
      final updated = await _supabase
          .from('shopping_items')
          .update({
            'quantity': item.quantity + entry.value,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', item.id)
          .select()
          .single();
      changed.add(ShoppingItemModel.fromJson(updated));
    }

    final insertedIds = <String>[];
    if (plan.inserts.isNotEmpty) {
      final rows = await _supabase.from('shopping_items').insert([
        for (final item in plan.inserts)
          {
            'list_id': listId,
            'name': item.name,
            'quantity': item.quantity,
            'unit': item.unit,
            'category': item.category ?? _categories.categorizeLocal(item.name),
            'category_id':
                item.category ?? _categories.categorizeLocal(item.name),
            'language': LanguageDetectionService.detectLanguage(item.name),
            'notes': item.notes,
            'added_by': userId,
          },
      ]).select();
      for (final json in rows as List) {
        final model = ShoppingItemModel.fromJson(json);
        insertedIds.add(model.id);
        changed.add(model);
      }
    }
    await _touchList(listId);

    final token =
        '${DateTime.now().microsecondsSinceEpoch}-${insertedIds.length}';
    _batches[token] = _AddBatch(listId, insertedIds, previousQuantities);
    while (_batches.length > _maxUndoBatches) {
      _batches.remove(_batches.keys.first);
    }

    final uncategorized = [
      for (final m in changed)
        if (insertedIds.contains(m.id) &&
            plan.inserts.any((i) => i.name == m.name && i.category == null))
          m,
    ];
    if (uncategorized.isNotEmpty) {
      unawaited(_categorizeInBackground(uncategorized));
    }
    return AddItemsResult(token: token, items: changed);
  }

  /// Takes back a batch from [addItems]: deletes its new rows and restores
  /// merged quantities. Does nothing for an unknown or already used token.
  Future<void> undoAddItems(String token) async {
    final batch = _batches.remove(token);
    if (batch == null) return;
    if (batch.insertedIds.isNotEmpty) {
      await _supabase
          .from('shopping_items')
          .delete()
          .inFilter('id', batch.insertedIds);
    }
    for (final entry in batch.previousQuantities.entries) {
      await _supabase
          .from('shopping_items')
          .update({
            'quantity': entry.value,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', entry.key);
    }
    await _touchList(batch.listId);
  }

  static const _maxUndoBatches = 10;
  static final Map<String, _AddBatch> _batches = {};

  Future<void> _categorizeInBackground(List<ShoppingItemModel> items) async {
    final categories = await _categories.categorizeBatch([
      for (final item in items) item.name,
    ]);
    for (final item in items) {
      final category = categories[item.name];
      if (category == null || category == item.category) continue;
      await _saveCategory(item.id, item.name, category);
    }
  }

  /// Stores Claude's better answer for one item when it differs from the
  /// local one the item was saved with.
  Future<void> _refineInBackground(
    String itemId,
    String name,
    String localCategory,
  ) async {
    final refined = await _categories.refineCategory(name);
    if (refined == null || refined == localCategory) return;
    await _saveCategory(itemId, name, refined);
  }

  Future<void> _saveCategory(
    String itemId,
    String name,
    String category,
  ) async {
    try {
      await _supabase
          .from('shopping_items')
          .update({'category': category, 'category_id': category})
          .eq('id', itemId);
    } catch (e) {
      debugPrint('⚠️ [ITEM_REPO] Background category failed for "$name": $e');
    }
  }

  static final _containsDigit = RegExp(r'\d');

  static String _normalizeUnit(String? unit) =>
      (unit ?? '').trim().toLowerCase();

  /// `ilike` treats `%` and `_` as wildcards; escape them so a name is
  /// matched literally (still case-insensitively).
  static String _escapeLikePattern(String value) =>
      value.replaceAllMapped(RegExp(r'[\\%_]'), (m) => '\\${m[0]}');

  static Map<String, dynamic> _priceFields(
    double price,
    String? currency,
    String? retailer,
    String? unit,
    double? oldValue,
  ) => {
    'price': price,
    'price_currency': currency ?? 'EUR',
    'price_retailer': retailer,
    'price_unit': unit,
    'price_updated_at': DateTime.now().toIso8601String(),
    'price_old_value': oldValue,
  };

  /// Update an item
  Future<ShoppingItemModel> updateItem(
    String itemId,
    Map<String, dynamic> updates,
  ) async {
    final response = await _supabase
        .from('shopping_items')
        .update(updates)
        .eq('id', itemId)
        .select()
        .single();

    final item = ShoppingItemModel.fromJson(response);
    await _touchList(item.listId);
    return item;
  }

  /// Toggle item checked status. Other list members are notified in the
  /// background; the caller never waits on the push fan-out.
  Future<ShoppingItemModel> toggleItemChecked(
    String itemId,
    bool isChecked,
  ) async {
    final updatedItem = await updateItem(itemId, {
      'is_checked': isChecked,
      'checked_at': isChecked ? DateTime.now().toIso8601String() : null,
    });

    final action = isChecked ? 'checked off' : 'unchecked';
    _notifyListMembers(
      listId: updatedItem.listId,
      body: (actor) => '$actor $action "${updatedItem.name}"',
      data: {
        'type': 'item_toggled',
        'listId': updatedItem.listId,
        'isChecked': isChecked,
      },
    );
    return updatedItem;
  }

  /// Delete an item. One round trip returns the deleted row's list and name
  /// for the list timestamp and the (background) member notification.
  Future<void> deleteItem(String itemId) async {
    final deleted = await _supabase
        .from('shopping_items')
        .delete()
        .eq('id', itemId)
        .select('list_id, name')
        .maybeSingle();
    // Already gone (e.g. removed by another member).
    if (deleted == null) return;

    final listId = deleted['list_id'] as String;
    final itemName = deleted['name'] as String;
    await _touchList(listId);

    _notifyListMembers(
      listId: listId,
      body: (actor) => '$actor removed "$itemName"',
      data: {'type': 'item_deleted', 'listId': listId},
    );
  }

  /// Persist new `order_index` values ({itemId: index}) concurrently, then
  /// touch the list once. Callers pass only the rows whose index changed.
  Future<void> updateOrderIndexes(
    String listId,
    Map<String, int> orderById,
  ) async {
    if (orderById.isEmpty) return;
    await Future.wait([
      for (final entry in orderById.entries)
        _supabase
            .from('shopping_items')
            .update({'order_index': entry.value})
            .eq('id', entry.key),
    ]);
    await _touchList(listId);
  }

  /// Updates the updated_at timestamp of the list
  Future<void> _touchList(String listId) async {
    try {
      await _supabase
          .from('shopping_lists')
          .update({'updated_at': DateTime.now().toUtc().toIso8601String()})
          .eq('id', listId);
    } catch (e) {
      debugPrint('⚠️ [ITEM_REPO] Failed to touch list: $e');
    }
  }

  /// Subscribe to item changes for a specific list
  void subscribeToItemChanges(String listId, void Function() onUpdate) {
    // Don't create duplicate subscriptions
    if (_channels.containsKey(listId)) return;

    _channels[listId] = _supabase.client
        .channel('shopping_items_$listId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'shopping_items',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'list_id',
            value: listId,
          ),
          callback: (_) => onUpdate(),
        )
        .subscribe();
    debugPrint('✅ [ITEM_REPO] Realtime subscription opened for list $listId');
  }

  /// Unsubscribe from item changes for a specific list
  void unsubscribeFromItemChanges(String listId) {
    final channel = _channels.remove(listId);
    if (channel != null) {
      channel.unsubscribe();
      debugPrint(
        '🔵 [ITEM_REPO] Realtime subscription closed for list $listId',
      );
    }
  }

  /// Notify the other list members that an item was added. Fire-and-forget.
  void sendItemAddedNotification({
    required String listId,
    required String itemName,
  }) {
    _notifyListMembers(
      listId: listId,
      body: (actor) => '$actor added "$itemName"',
      data: {'type': 'list_update', 'listId': listId},
    );
  }

  /// Push "[actor] did X" to every member of [listId] except the current
  /// user, titled with the list name. Runs in the background and never
  /// throws: a failed notification must not fail or delay the item write.
  void _notifyListMembers({
    required String listId,
    required String Function(String actorName) body,
    required Map<String, dynamic> data,
  }) {
    if (!(Platform.isIOS || Platform.isAndroid)) return;
    final userId = currentUserId;
    if (userId == null) return;

    unawaited(() async {
      try {
        final results = await Future.wait([
          _supabase
              .from('shopping_lists')
              .select('name')
              .eq('id', listId)
              .single(),
          _supabase
              .from('users')
              .select('display_name')
              .eq('id', userId)
              .maybeSingle(),
        ]);
        final listName = results[0]!['name'] as String;
        final actorName = results[1]?['display_name'] as String? ?? 'Someone';

        await PushNotificationService.instance.sendToListMembers(
          listId: listId,
          excludeUserId: userId,
          title: listName,
          body: body(actorName),
          data: data,
        );
      } catch (e) {
        debugPrint('❌ [ITEM_REPO] Failed to notify list members: $e');
      }
    }());
  }
}

class _AddBatch {
  _AddBatch(this.listId, this.insertedIds, this.previousQuantities);

  final String listId;
  final List<String> insertedIds;
  final Map<String, double> previousQuantities;
}
