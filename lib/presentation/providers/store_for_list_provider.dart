import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show StringCharacters;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shoply/data/models/store_info.dart';
import 'package:shoply/data/services/list_store_repository.dart';
import 'package:shoply/data/services/offline_cache_service.dart';
import 'package:shoply/data/services/store_chain_directory.dart';
import 'package:shoply/data/services/store_detection_service.dart';
import 'package:shoply/presentation/state/items_provider.dart';
import 'package:shoply/presentation/state/lists_provider.dart';

/// Where the list name and the open items for the market guess come from.
abstract interface class StoreSignalSource {
  Future<String?> listName(String listId);

  /// Names of the items of [listId] that are not checked off.
  Future<List<String>> openItemNames(String listId);
}

/// Everything the market decision of one list is made from. The nearby
/// store is not part of it: location is only used when the person asks.
@immutable
class StoreSignals {
  const StoreSignals({
    this.explicitChainId,
    this.nameChainId,
    this.recentTripChains = const [],
    this.privateLabelHits = const {},
  });

  final String? explicitChainId;
  final String? nameChainId;

  /// Chains of the list's newest trips, newest first (at most three).
  final List<String> recentTripChains;
  final Map<String, int> privateLabelHits;

  StoreGuess? resolve() => resolveStoreForList(
        explicitChainId: explicitChainId,
        nameChainId: nameChainId,
        recentTripChains: recentTripChains,
        privateLabelHits: privateLabelHits,
      );
}

/// Collects the signals for [listId]. Never throws: a signal that cannot be
/// read is simply missing.
Future<StoreSignals> gatherStoreSignals(
  ListStoreRepository repo,
  StoreSignalSource source,
  String listId,
) async {
  final (explicit, name, trips, items) = await (
    repo.explicitChainId(listId),
    _orElse(source.listName(listId), null, 'list name'),
    repo.recentTripChains(listId),
    _orElse(source.openItemNames(listId), const <String>[], 'items'),
  ).wait;
  return StoreSignals(
    explicitChainId: explicit,
    nameChainId: name == null ? null : matchChain(name),
    recentTripChains: trips,
    privateLabelHits: privateLabelHits(items),
  );
}

Future<T> _orElse<T>(Future<T> future, T fallback, String what) async {
  try {
    return await future;
  } catch (e) {
    debugPrint('⚠️ [STORE] No $what for the market guess: $e');
    return fallback;
  }
}

final listStoreRepositoryProvider =
    Provider<ListStoreRepository>((ref) => ListStoreRepository.instance);

final storeSignalSourceProvider =
    Provider<StoreSignalSource>(_AppStoreSignalSource.new);

/// The market guess of a list with its source and whether it is confirmed
/// (Kap. 12, E-13); null when nothing points to one. Screens read
/// [storeForListProvider] instead.
///
/// A cached answer comes back synchronously, so the first frame shows it;
/// the fresh answer replaces it as soon as it differs. A choice made with
/// [setStoreForList] or [clearStoreForList] shows at once, and a sign-out
/// asks again. The answer is not recomputed when the list is renamed, items
/// change or another member picks a market: invalidate it then.
final storeGuessForListProvider =
    FutureProvider.family<StoreGuess?, String>((ref, listId) {
  final repo = ref.watch(listStoreRepositoryProvider);
  final source = ref.watch(storeSignalSourceProvider);

  var current = true;
  final changes = repo.changes
      .where((id) => id == listId)
      .listen((_) => ref.invalidateSelf());
  ref.onDispose(() {
    current = false;
    changes.cancel();
  });

  Future<StoreGuess?> fresh() async {
    final version = repo.version(listId);
    final guess = (await gatherStoreSignals(repo, source, listId)).resolve();
    await repo.rememberGuess(listId, guess, version: version);
    return guess;
  }

  FutureOr<StoreGuess?> answer() {
    if (!repo.hasCachedGuess(listId)) return fresh();
    final cached = repo.cachedGuess(listId);
    unawaited(() async {
      try {
        final guess = await fresh();
        if (current && guess != cached) ref.state = AsyncData(guess);
      } catch (e) {
        debugPrint('⚠️ [STORE] Market guess not refreshed: $e');
      }
    }());
    return cached;
  }

  return repo.isCacheLoaded ? answer() : repo.loadCache().then((_) => answer());
});

/// The market of [listId] for the StoreChip, shopping mode, presence text and
/// aisle order (contract `b_slots.dart`); null while unknown, still loading
/// or only a suggestion. Synchronous, so the first frame never waits: the
/// cached guess comes back at once.
final storeForListProvider = Provider.family<StoreInfo?, String>((ref, listId) {
  final guess = ref.watch(storeGuessForListProvider(listId)).valueOrNull;
  if (guess == null || !guess.confirmed) return null;
  return storeInfoForChain(guess.chainId);
});

/// [StoreInfo] of a chain id from the directory; null for an unknown id.
StoreInfo? storeInfoForChain(String chainId) {
  final chain = StoreChainDirectory.byId(chainId);
  if (chain == null) return null;
  return StoreInfo(
    id: chain.id,
    name: chain.displayName,
    shortLabel: storeShortLabel(chain.displayName),
    brandColor: chain.brandColor,
  );
}

/// Letters for the D2 tile: the first letter of each of the first two words
/// ("Aldi Süd" -> "AS", "Lidl" -> "L", "REWE" -> "R").
String storeShortLabel(String name) {
  final words = name
      .split(RegExp(r'[\s\-/]+'))
      .where((w) => w.isNotEmpty)
      .take(2)
      .toList();
  if (words.isEmpty) return '';
  return words.map((w) => w.characters.first.toUpperCase()).join();
}

/// The person picks [chainId] as the market of [listId]. Shows at once;
/// a failed write rolls back and rethrows. From a widget:
/// `ref.read(listStoreRepositoryProvider).setExplicit(listId, chainId)`.
Future<void> setStoreForList(Ref ref, String listId, String chainId) =>
    ref.read(listStoreRepositoryProvider).setExplicit(listId, chainId);

/// "Kein fester Markt": takes the market off [listId]. Same rules as
/// [setStoreForList].
Future<void> clearStoreForList(Ref ref, String listId) =>
    ref.read(listStoreRepositoryProvider).clearExplicit(listId);

/// Reads what the app already has before asking the server: the loaded
/// lists and items, then the offline cache.
class _AppStoreSignalSource implements StoreSignalSource {
  _AppStoreSignalSource(this._ref);

  final Ref _ref;

  @override
  Future<String?> listName(String listId) async {
    if (_ref.exists(listsNotifierProvider)) {
      final lists = _ref.read(listsNotifierProvider).valueOrNull;
      final known = lists?.where((l) => l.id == listId).firstOrNull;
      if (known != null) return known.name;
    }
    return _ref.read(itemRepositoryProvider).getListName(listId);
  }

  @override
  Future<List<String>> openItemNames(String listId) async {
    final live = _ref.exists(itemsNotifierProvider(listId))
        ? _ref.read(itemsNotifierProvider(listId)).valueOrNull
        : null;
    final items = live ??
        OfflineCacheService.instance.getCachedListItemsSync(listId) ??
        await _ref.read(itemRepositoryProvider).getListItems(listId);
    return [
      for (final item in items)
        if (!item.isChecked) item.name,
    ];
  }
}
