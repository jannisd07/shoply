import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shoply/data/models/meal_plan.dart';
import 'package:shoply/data/repositories/item_repository.dart';
import 'package:shoply/data/services/meal_plan_aggregator.dart';

// Wochenplan (B7): how "Zutaten der Woche" gets onto the target list. The
// plan code only talks to [MealPlanListWriter]; today's adapter uses Teil A's
// batch API (ItemRepository.addItems / undoAddItems, A5) and keeps the plan's
// own amounts per item on the device until the column
// `shopping_items.plan_contributions` exists (E-11).

/// One shopping item the plan wants on the list.
class PlanListWriteItem {
  const PlanListWriteItem({
    required this.lineKey,
    required this.name,
    required this.quantity,
    this.unit,
    this.categoryId,
    this.note,
    this.contributions = const [],
  });

  /// [PlanIngredientLine.key] of the line it comes from.
  final String lineKey;
  final String name;
  final double quantity;

  /// Unit id as items store it (g, kg, ml, l, can, …); null = pieces.
  final String? unit;

  /// Local category id, so nothing waits for the AI.
  final String? categoryId;

  /// "für Chili sin Carne, Gemüse-Curry" (W-12); only new items get it.
  final String? note;

  /// Which entry adds how much (base unit of the line's family).
  final List<PlanContribution> contributions;
}

/// What a batch did.
class PlanListWriteResult {
  const PlanListWriteResult({
    this.token,
    this.writtenLineKeys = const {},
    this.failedNames = const [],
    this.itemIds = const [],
  });

  /// For "Widerrufen"; null when nothing was written.
  final String? token;

  /// Lines that are on the list now.
  final Set<String> writtenLineKeys;

  /// Names that could not be added ("Dill und Koriander").
  final List<String> failedNames;

  /// New and merged item ids.
  final List<String> itemIds;

  int get addedCount => writtenLineKeys.length;

  bool get failed => failedNames.isNotEmpty;
}

/// The plan's way onto a shopping list.
abstract class MealPlanListWriter {
  /// Adds [items] to [listId] in one step (optimistic in the repository,
  /// categories local, AI confirmation later).
  Future<PlanListWriteResult> addItems(String listId, List<PlanListWriteItem> items);

  /// Takes a batch back: new items go, merged quantities return.
  Future<void> undoAddItems(String token);

  /// Item id → amounts the plan put there (W-17).
  Future<Map<String, List<PlanContribution>>> contributionsForList(String listId);

  /// Drops the amounts of items that no longer exist or are checked off.
  Future<void> forgetItemsExcept(String listId, Set<String> liveItemIds);
}

/// The selected lines of [aggregation] as shopping items.
///
/// [selectedKeys] replaces the preselection (the person ticked other lines),
/// [overrides] are amounts from "Menge ändern". [noteFor] builds the item
/// note from the recipe names (texts live with the screens).
List<PlanListWriteItem> planWriteItems(
  PlanAggregation aggregation, {
  required String? Function(List<String> recipeNames) noteFor,
  Set<String>? selectedKeys,
  Map<String, PlanQuantity> overrides = const {},
}) {
  final out = <PlanListWriteItem>[];
  for (final line in aggregation.lines) {
    final picked = selectedKeys?.contains(line.key) ?? line.selected;
    if (!picked) continue;
    final amount = overrides[line.key] ??
        (line.reason == PlanLineReason.alreadyOnList ? line.needed : line.toAdd ?? line.needed) ??
        PlanQuantity(amount: 1, family: line.family);
    final contributions = _split(line, amount.family == PlanUnitFamily.unquantified ? 0 : amount.amount);
    final existing = line.listItem;
    if (existing != null && amount.family == line.family) {
      // Grow the item on the list in its own name and unit ("Kokosmilch"
      // 400 → 675 ml) instead of a second line; its note stays (W-12).
      out.add(PlanListWriteItem(
        lineKey: line.key,
        name: existing.name,
        quantity: _tidy(amount.amount / parsePlanUnit(existing.unit).factor),
        unit: existing.unit,
        categoryId: line.categoryId,
        contributions: contributions,
      ));
      continue;
    }
    final item = amount.toItemQuantity();
    out.add(PlanListWriteItem(
      lineKey: line.key,
      name: line.displayName,
      quantity: item.quantity,
      unit: item.unit,
      categoryId: line.categoryId,
      note: noteFor(line.recipeNames),
      contributions: contributions,
    ));
  }
  return out;
}

/// Spreads [added] over the line's entries: each its own need, the rounding
/// surplus to the last one; when less is added (part was on the list),
/// proportionally less.
List<PlanContribution> _split(PlanIngredientLine line, double added) {
  final raw = <String, double>{};
  for (final s in line.sources) {
    raw[s.entryId] = (raw[s.entryId] ?? 0) + s.baseAmount;
  }
  final total = raw.values.fold<double>(0, (a, b) => a + b);
  final ids = raw.keys.toList();
  return [
    for (var i = 0; i < ids.length; i++)
      PlanContribution(
        entryId: ids[i],
        family: line.family.id,
        baseAmount: _tidy(total <= 0
            ? (i == ids.length - 1 ? added : 0)
            : added >= total
                ? raw[ids[i]]! + (i == ids.length - 1 ? added - total : 0)
                : raw[ids[i]]! * added / total),
      ),
  ];
}

double _tidy(double v) => (v * 1000).roundToDouble() / 1000;

/// Same item key as Teil A's AddItemsPlan: name ignoring case, "pcs" = none.
String _itemKey(String name, String? unit) {
  final u = (unit ?? '').trim().toLowerCase();
  return '${name.trim().toLowerCase()}|${u == 'pcs' ? '' : u}';
}

/// Plan amounts per item on this device (SharedPreferences), until
/// `shopping_items.plan_contributions` exists.
class PlanContributionLedger {
  PlanContributionLedger({Future<SharedPreferences> Function()? prefs})
      : _prefs = prefs ?? SharedPreferences.getInstance;

  final Future<SharedPreferences> Function() _prefs;

  static const _prefix = 'meal_plan_contributions_v1_';

  /// Bound per list; the oldest items are dropped first.
  static const maxItemsPerList = 500;

  Future<Map<String, List<PlanContribution>>> read(String listId) async {
    try {
      final raw = (await _prefs()).getString('$_prefix$listId');
      if (raw == null) return {};
      final json = jsonDecode(raw) as Map<String, dynamic>;
      return {
        for (final e in json.entries)
          e.key: [
            for (final c in e.value as List) PlanContribution.fromJson((c as Map).cast<String, dynamic>()),
          ],
      };
    } catch (e) {
      debugPrint('⚠️ [MEAL_PLAN] Contribution ledger unreadable, starting empty: $e');
      return {};
    }
  }

  Future<void> _write(String listId, Map<String, List<PlanContribution>> byItem) async {
    final prefs = await _prefs();
    final kept = byItem.entries.where((e) => e.value.isNotEmpty).toList();
    final bounded = kept.length > maxItemsPerList ? kept.sublist(kept.length - maxItemsPerList) : kept;
    if (bounded.isEmpty) {
      await prefs.remove('$_prefix$listId');
      return;
    }
    await prefs.setString('$_prefix$listId', jsonEncode({
      for (final e in bounded) e.key: [for (final c in e.value) c.toJson()],
    }));
  }

  Future<void> add(String listId, Map<String, List<PlanContribution>> byItem) async {
    final current = await read(listId);
    for (final e in byItem.entries) {
      (current[e.key] ??= []).addAll(e.value);
    }
    await _write(listId, current);
  }

  Future<void> removeToken(String listId, String token) async {
    final current = await read(listId);
    await _write(listId, {
      for (final e in current.entries) e.key: [for (final c in e.value) if (c.undoToken != token) c],
    });
  }

  Future<void> keepOnly(String listId, Set<String> itemIds) async {
    final current = await read(listId);
    await _write(listId, {
      for (final e in current.entries)
        if (itemIds.contains(e.key)) e.key: e.value,
    });
  }
}

/// [MealPlanListWriter] on top of [ItemRepository.addItems] (Teil A5).
class ItemRepositoryPlanListWriter implements MealPlanListWriter {
  ItemRepositoryPlanListWriter({
    Future<AddItemsResult> Function(String listId, List<NewItem> items)? addItems,
    Future<void> Function(String token)? undoAddItems,
    PlanContributionLedger? ledger,
  })  : _addItems = addItems ?? ItemRepository.instance.addItems,
        _undoAddItems = undoAddItems ?? ItemRepository.instance.undoAddItems,
        _ledger = ledger ?? PlanContributionLedger();

  final Future<AddItemsResult> Function(String, List<NewItem>) _addItems;
  final Future<void> Function(String) _undoAddItems;
  final PlanContributionLedger _ledger;

  /// Undo token → list, for batches of this app run.
  final Map<String, String> _listOfToken = {};

  @override
  Future<PlanListWriteResult> addItems(String listId, List<PlanListWriteItem> items) async {
    if (items.isEmpty) return const PlanListWriteResult();
    final AddItemsResult result;
    try {
      result = await _addItems(listId, [
        for (final i in items)
          NewItem(name: i.name, quantity: i.quantity, unit: i.unit, category: i.categoryId, notes: i.note),
      ]);
    } catch (e) {
      debugPrint('❌ [MEAL_PLAN] Adding ${items.length} ingredients to $listId failed: $e');
      return PlanListWriteResult(failedNames: [for (final i in items) i.name]);
    }

    final rowByKey = {for (final row in result.items) _itemKey(row.name, row.unit): row.id};
    final byItem = <String, List<PlanContribution>>{};
    final written = <String>{};
    for (final item in items) {
      final id = rowByKey[_itemKey(item.name, item.unit)];
      if (id == null) {
        debugPrint('⚠️ [MEAL_PLAN] No row came back for "${item.name}"');
        continue;
      }
      written.add(item.lineKey);
      (byItem[id] ??= []).addAll([
        for (final c in item.contributions)
          PlanContribution(entryId: c.entryId, family: c.family, baseAmount: c.baseAmount, undoToken: result.token),
      ]);
    }
    await _ledger.add(listId, byItem);
    _listOfToken[result.token] = listId;
    debugPrint('✅ [MEAL_PLAN] ${written.length} ingredients on list $listId');
    return PlanListWriteResult(
      token: result.token,
      writtenLineKeys: written,
      failedNames: [for (final i in items) if (!written.contains(i.lineKey)) i.name],
      itemIds: [for (final row in result.items) row.id],
    );
  }

  @override
  Future<void> undoAddItems(String token) async {
    await _undoAddItems(token);
    final listId = _listOfToken.remove(token);
    if (listId != null) await _ledger.removeToken(listId, token);
  }

  @override
  Future<Map<String, List<PlanContribution>>> contributionsForList(String listId) => _ledger.read(listId);

  @override
  Future<void> forgetItemsExcept(String listId, Set<String> liveItemIds) => _ledger.keepOnly(listId, liveItemIds);
}
