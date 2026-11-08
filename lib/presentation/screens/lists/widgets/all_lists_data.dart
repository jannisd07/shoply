import 'package:flutter/widgets.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:shoply/core/localization/localization_helper.dart';
import 'package:shoply/data/models/shopping_list_model.dart';
import 'package:shoply/presentation/state/auth_provider.dart';
import 'package:shoply/presentation/state/avo_nudge_provider.dart';
import 'package:shoply/presentation/state/lists_provider.dart';

/// The lists the overview shows: the local state of [listsNotifierProvider]
/// (cache first, then Supabase). Overridden in tests.
final allListsSourceProvider = Provider<AsyncValue<List<ShoppingListModel>>>(
  (ref) => ref.watch(listsNotifierProvider),
);

// ---------------------------------------------------------------- pinning

/// The pinned list of the signed-in user (Konzept 11 §7 "Anheften", E-10:
/// exactly one). Stored per user on the device, like the last opened list.
@immutable
class PinnedList {
  const PinnedList({required this.loaded, this.listId});

  /// The stored value has been read.
  final bool loaded;
  final String? listId;
}

final pinnedListProvider =
    StateNotifierProvider<PinnedListNotifier, PinnedList>(
      (ref) => PinnedListNotifier(ref.watch(authUserIdProvider)),
    );

class PinnedListNotifier extends StateNotifier<PinnedList> {
  PinnedListNotifier(this._userId) : super(const PinnedList(loaded: false)) {
    _load();
  }

  final String? _userId;

  String get _key => 'pinned_list_$_userId';

  Future<void> _load() async {
    if (_userId == null) {
      state = const PinnedList(loaded: true);
      return;
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      if (mounted) {
        state = PinnedList(loaded: true, listId: prefs.getString(_key));
      }
    } catch (e) {
      debugPrint('⚠️ [ALL_LISTS] Failed to read pinned list: $e');
      if (mounted) state = const PinnedList(loaded: true);
    }
  }

  /// Pins [listId], or unpins with null.
  Future<void> pin(String? listId) async {
    state = PinnedList(loaded: true, listId: listId);
    if (_userId == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (listId == null) {
        await prefs.remove(_key);
      } else {
        await prefs.setString(_key, listId);
      }
    } catch (e) {
      debugPrint('⚠️ [ALL_LISTS] Failed to store pinned list: $e');
    }
  }
}

// ----------------------------------------------------------- quick re-add

/// One "Schnell wieder hinzufügen" tile: an item the person buys regularly
/// that is due again and on none of their lists.
@immutable
class QuickAddSuggestion {
  const QuickAddSuggestion({
    required this.name,
    this.categoryId,
    this.quantity = 1,
  });

  final String name;
  final String? categoryId;
  final double quantity;

  @override
  bool operator ==(Object other) =>
      other is QuickAddSuggestion &&
      other.name == name &&
      other.categoryId == categoryId &&
      other.quantity == quantity;

  @override
  int get hashCode => Object.hash(name, categoryId, quantity);
}

/// The tiles of "Schnell wieder hinzufügen". Today's source is Teil B's
/// restock suggestions (`restockSuggestionsProvider`, the same rhythm
/// items as Avo's "Nachkauf"); it moves to B's per-list contract (E10-09)
/// once that exists. Empty while loading or on errors, so the section is
/// simply not there. Overridden in tests.
final allListsQuickAddProvider = Provider<List<QuickAddSuggestion>>((ref) {
  final restock = ref.watch(restockSuggestionsProvider).valueOrNull;
  if (restock == null) return const [];
  return [
    for (final s in restock)
      QuickAddSuggestion(
        name: s.displayName,
        categoryId: s.preferredCategory,
        quantity: (s.preferredQuantity ?? 1) <= 0 ? 1 : s.preferredQuantity!,
      ),
  ];
});

/// Asks the quick re-add source again (pull to refresh, after an undo).
void refreshAllListsQuickAdd(WidgetRef ref) =>
    ref.invalidate(restockSuggestionsProvider);

// --------------------------------------------------------------- ordering

/// When a list was last used: last opened, else last changed.
DateTime listUsedAt(ShoppingListModel list) =>
    list.lastAccessedAt ?? list.updatedAt;

/// The list for the big card (owner decision 07.11.2026): the pinned one,
/// else the one opened last on this device, else the one used last.
ShoppingListModel? pickHeroList(
  List<ShoppingListModel> lists, {
  String? pinnedId,
  String? lastOpenedId,
}) {
  if (lists.isEmpty) return null;
  for (final id in [pinnedId, lastOpenedId]) {
    if (id == null) continue;
    for (final l in lists) {
      if (l.id == id) return l;
    }
  }
  return lists.reduce((a, b) => listUsedAt(b).isAfter(listUsedAt(a)) ? b : a);
}

/// A snapshot of "last changed" per list, taken when the page opens, so the
/// rows are sorted once and never jump while realtime updates come in
/// (Konzept 11 §7).
Map<String, DateTime> listOrderSnapshot(List<ShoppingListModel> lists) => {
  for (final l in lists) l.id: l.updatedAt,
};

/// [lists] sorted by the [snapshot], newest first; lists the snapshot does
/// not know yet (just created or joined) come first.
List<ShoppingListModel> sortBySnapshot(
  List<ShoppingListModel> lists,
  Map<String, DateTime> snapshot,
) {
  final far = DateTime(9999);
  return [...lists]..sort((a, b) {
    final byTime = (snapshot[b.id] ?? far).compareTo(snapshot[a.id] ?? far);
    return byTime != 0 ? byTime : a.name.compareTo(b.name);
  });
}

/// How many items are open on all [lists] ("3 Listen · 11 offen").
int openItemCount(List<ShoppingListModel> lists) =>
    lists.fold(0, (sum, l) => sum + (l.uncheckedCount ?? 0));

/// Lists whose name contains [query] (case-insensitive).
List<ShoppingListModel> filterLists(
  List<ShoppingListModel> lists,
  String query,
) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return lists;
  return [
    for (final l in lists)
      if (l.name.toLowerCase().contains(q)) l,
  ];
}

/// The search field appears from this many lists on (Konzept 11 §7).
const int kAllListsSearchFrom = 7;

// ------------------------------------------------------------------- text

/// "vor 12 Min.", "vor 2 Std.", "gestern", "vor 3 Tagen", "12. Okt."
String relativeListTime(BuildContext context, DateTime time, DateTime now) {
  final local = time.toLocal();
  final diff = now.difference(local);
  if (diff.inMinutes < 1) return context.tr('list_ov_time_now');
  if (diff.inMinutes < 60) {
    return context.tr(
      'list_ov_time_minutes',
      params: {'n': '${diff.inMinutes}'},
    );
  }
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(local.year, local.month, local.day);
  final days = today.difference(day).inDays;
  if (days == 0) {
    return context.tr('list_ov_time_hours', params: {'n': '${diff.inHours}'});
  }
  if (days == 1) return context.tr('list_ov_time_yesterday');
  if (days < 7) {
    return context.tr('list_ov_time_days', params: {'n': '$days'});
  }
  final locale = Localizations.localeOf(context).toLanguageTag();
  return DateFormat.MMMd(locale).format(local);
}

/// "12 Artikel" / "1 Artikel".
String itemCountLabel(BuildContext context, int n) => n == 1
    ? context.tr('list_ov_items_one')
    : context.tr('list_ov_items', params: {'n': '$n'});

/// "3 Listen · 11 offen".
String allListsSummary(BuildContext context, List<ShoppingListModel> lists) {
  final open = '${openItemCount(lists)}';
  return lists.length == 1
      ? context.tr('list_ov_summary_one', params: {'open': open})
      : context.tr(
          'list_ov_summary',
          params: {'lists': '${lists.length}', 'open': open},
        );
}
