import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shoply/core/services/shared_preferences_provider.dart';
import 'package:shoply/data/models/shopping_list_model.dart';
import 'package:shoply/data/repositories/list_repository.dart';
import 'package:shoply/data/services/offline_cache_service.dart';
import 'package:shoply/data/services/purchase_tracking_service.dart';
import 'package:shoply/data/services/widget_service.dart';
import 'package:shoply/presentation/state/auth_provider.dart';

/// List repository provider
final listRepositoryProvider = Provider<ListRepository>((ref) {
  return ListRepository.instance;
});

/// All user lists as a one-shot future, for callers that just need the
/// current lists (Siri, pickers). Derived from [listsNotifierProvider], so
/// it shares its data and realtime updates instead of running its own query.
final userListsProvider = FutureProvider<List<ShoppingListModel>>((ref) async {
  final lists = ref.watch(listsNotifierProvider);
  if (lists.hasValue) return lists.requireValue;
  return ref.read(listRepositoryProvider).getUserLists();
});

/// State notifier for managing lists
class ListsNotifier extends StateNotifier<AsyncValue<List<ShoppingListModel>>> {
  final ListRepository _repository;
  final String? _userId;
  final PurchaseTrackingService _trackingService = PurchaseTrackingService();
  Timer? _realtimeDebounce;

  /// The lists the previous notifier instance loaded, so one re-created by
  /// `ref.invalidate` (or an auth rebuild for the same account) paints the
  /// known lists at once instead of flashing a spinner.
  static List<ShoppingListModel>? _lastKnown;
  static String? _lastKnownUserId;

  /// One reload for a burst of realtime events (a toggle emits an item and
  /// a list event, completing a trip one event per deleted row).
  static const _realtimeDebounceDelay = Duration(milliseconds: 400);

  ListsNotifier(this._repository, this._userId) : super(_seed(_userId)) {
    if (_userId == null) return; // Signed out: nothing to load or watch.
    // Cold start: paint this account's lists from the device right away;
    // the network answer replaces them (Konzept 00: local state first).
    if (state is! AsyncData<List<ShoppingListModel>>) {
      unawaited(_seedFromDisk());
    }
    loadLists();
    _repository.subscribeToItemChanges(_onRemoteChange);
  }

  Future<void> _seedFromDisk() async {
    final cached = await OfflineCacheService.instance.getCachedLists(
      userId: _userId,
    );
    if (!mounted || cached == null || cached.isEmpty) return;
    if (state is AsyncData<List<ShoppingListModel>>) return; // network won
    state = AsyncValue.data(cached);
    unawaited(
      OfflineCacheService.instance.warmListItems([
        for (final l in cached) l.id,
      ]),
    );
  }

  static AsyncValue<List<ShoppingListModel>> _seed(String? userId) {
    if (userId == null) return const AsyncValue.data([]);
    final known = _lastKnownUserId == userId ? _lastKnown : null;
    if (known != null) return AsyncValue.data(known);
    // Cold start: this account's lists from the device, in the first frame.
    final cached = OfflineCacheService.instance.getCachedListsSync(
      userId: userId,
    );
    if (cached == null || cached.isEmpty) return const AsyncValue.loading();
    unawaited(
      OfflineCacheService.instance.warmListItems([
        for (final l in cached) l.id,
      ]),
    );
    return AsyncValue.data(cached);
  }

  void _onRemoteChange() {
    _realtimeDebounce?.cancel();
    _realtimeDebounce = Timer(_realtimeDebounceDelay, () {
      if (mounted) loadLists();
    });
  }

  Future<void> loadLists() async {
    if (_userId == null) return;
    // Only show loading spinner on first load (when no data exists yet)
    if (state is! AsyncData<List<ShoppingListModel>>) {
      state = const AsyncValue.loading();
    }
    try {
      final lists = await _repository.getUserLists();
      if (!mounted) return;
      state = AsyncValue.data(lists);
      _lastKnown = lists;
      _lastKnownUserId = _userId;
      // Cache for offline use
      OfflineCacheService.instance.cacheLists(lists, userId: _userId);
      // Pull each list's cached items into memory while the user is still
      // looking at the overview, so tapping a list can paint its contents in
      // the first frame instead of waiting on SharedPreferences or Supabase.
      unawaited(
        OfflineCacheService.instance.warmListItems([
          for (final l in lists) l.id,
        ]),
      );
      // Update widget with available lists for configuration
      WidgetService.updateAvailableLists([
        for (final l in lists) {'id': l.id, 'name': l.name},
      ]);
      // Refresh the Quick-Add widget's frequently-bought-item suggestions
      unawaited(_updateWidgetRecentItems());
    } catch (error, stackTrace) {
      if (!mounted || state is AsyncData<List<ShoppingListModel>>) return;
      // Try offline cache
      final cached = await OfflineCacheService.instance.getCachedLists(
        userId: _userId,
      );
      if (!mounted) return;
      state = cached != null && cached.isNotEmpty
          ? AsyncValue.data(cached)
          : AsyncValue.error(error, stackTrace);
    }
  }

  /// Pushes the user's most frequently bought items to the App Group so the
  /// Quick-Add widget can offer one-tap suggestions. Best-effort: purchase
  /// stats are a nice-to-have for the widget, never worth failing list load
  /// over.
  Future<void> _updateWidgetRecentItems() async {
    try {
      final stats = await _trackingService.getFrequentItems(limit: 8);
      final items = stats
          .map(
            (s) => WidgetRecentItem(
              name: _titleCase(s.itemName),
              category: s.preferredCategory,
              quantity: s.preferredQuantity ?? 1.0,
            ),
          )
          .toList();
      await WidgetService.updateRecentItems(items);
    } catch (e) {
      debugPrint('⚠️ [Widget] Failed to refresh recent-items suggestions: $e');
    }
  }

  String _titleCase(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return trimmed;
    return trimmed
        .split(' ')
        .map(
          (word) => word.isEmpty
              ? word
              : '${word[0].toUpperCase()}${word.substring(1)}',
        )
        .join(' ');
  }

  @override
  void dispose() {
    _realtimeDebounce?.cancel();
    if (_userId != null) _repository.unsubscribeFromItemChanges();
    super.dispose();
  }

  Future<ShoppingListModel> createList(String name) async {
    final newList = await _repository.createList(name);
    await loadLists();
    return newList;
  }

  Future<void> updateList(String listId, Map<String, dynamic> updates) async {
    await _repository.updateList(listId, updates);
    await loadLists();
  }

  Future<void> deleteList(String listId) async {
    await _repository.deleteList(listId);
    await loadLists();
  }

  Future<String> generateShareCode(String listId) async {
    final code = await _repository.generateShareCode(listId);
    await loadLists();
    return code;
  }

  Future<ShoppingListModel?> joinListWithCode(String shareCode) async {
    final list = await _repository.joinListWithCode(shareCode);
    await loadLists();
    return list;
  }

  Future<ShoppingListModel?> joinListWithLink(String shareLink) async {
    final list = await _repository.joinListWithLink(shareLink);
    await loadLists();
    return list;
  }

  Future<String?> getShareLink(String listId) {
    return _repository.getShareLink(listId);
  }

  /// Save background for a list (Prompt 5 - unified method)
  Future<void> saveBackground(
    String listId,
    String backgroundType,
    String? backgroundValue,
    String? imageUrl,
  ) async {
    await _repository.saveBackground(
      listId,
      backgroundType,
      backgroundValue,
      imageUrl,
    );
    await loadLists();
  }

  Future<void> reorderLists(int oldIndex, int newIndex) async {
    final current = state.valueOrNull;
    if (current == null) return;

    final lists = List<ShoppingListModel>.of(current);
    if (oldIndex < newIndex) newIndex -= 1;
    lists.insert(newIndex, lists.removeAt(oldIndex));

    // Update state immediately for smooth UI
    state = AsyncValue.data(lists);

    // Persist only the positions that changed, concurrently.
    try {
      await Future.wait([
        for (int i = 0; i < lists.length; i++)
          if (lists[i].orderIndex != i)
            _repository.updateList(lists[i].id, {'order_index': i}),
      ]);
    } catch (error) {
      // Reload if update fails
      await loadLists();
      rethrow;
    }
  }
}

/// Lists state notifier provider. Rebuilt per signed-in account, so the
/// next user never sees the previous user's lists.
final listsNotifierProvider =
    StateNotifierProvider<ListsNotifier, AsyncValue<List<ShoppingListModel>>>((
      ref,
    ) {
      // The preferences main() loaded before runApp: lets the notifier
      // paint the cached lists in the first frame.
      final prefs = ref.read(sharedPreferencesProvider).valueOrNull;
      if (prefs != null) OfflineCacheService.instance.attachPreferences(prefs);
      return ListsNotifier(
        ref.watch(listRepositoryProvider),
        ref.watch(authUserIdProvider),
      );
    });

/// A running shopping mode: which list and since when (A-C3, "Einkaufsmodus
/// aktiv"). Value equality on both fields.
@immutable
class ShoppingModeSession {
  /// Creates a session.
  const ShoppingModeSession({required this.listId, required this.startedAt});

  /// The list that is being shopped.
  final String listId;

  /// When the shopping mode was opened.
  final DateTime startedAt;

  @override
  bool operator ==(Object other) =>
      other is ShoppingModeSession &&
      other.listId == listId &&
      other.startedAt == startedAt;

  @override
  int get hashCode => Object.hash(listId, startedAt);
}

/// The open shopping mode, or null. Set by `ShoppingModeScreen` when it
/// opens and cleared when it closes; screens read it to show "Einkaufsmodus
/// aktiv" for that list.
final shoppingModeSessionProvider = StateProvider<ShoppingModeSession?>(
  (ref) => null,
);
