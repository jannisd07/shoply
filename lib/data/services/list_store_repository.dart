import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shoply/data/services/store_chain_directory.dart';
import 'package:shoply/data/services/store_detection_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Server side of "Markt pro Liste": the table `list_store_assignments_b`
/// (migration `supabase/migrations/20261108000300_b_list_store.sql`) and the
/// trip history the learned market comes from.
abstract interface class ListStoreRemote {
  /// Chain id the person picked for [listId] (row with source `user`), or
  /// null when nobody picked one.
  Future<String?> fetchUserChainId(String listId);

  /// Stores [chainId] as the picked market of [listId] (source `user`).
  Future<void> saveUserChainId(String listId, String chainId);

  /// Removes the market of [listId].
  Future<void> deleteAssignment(String listId);

  /// Retailer names of the items of the newest [limit] completed trips of
  /// [listId], newest trip first. Items without a retailer are left out.
  Future<List<List<String>>> recentTripRetailers(String listId, {int limit});
}

class SupabaseListStoreRemote implements ListStoreRemote {
  SupabaseListStoreRemote([SupabaseClient? client]) : _clientOverride = client;

  static const table = 'list_store_assignments_b';

  final SupabaseClient? _clientOverride;
  SupabaseClient get _client => _clientOverride ?? Supabase.instance.client;

  @override
  Future<String?> fetchUserChainId(String listId) async {
    final row = await _client
        .from(table)
        .select('chain_id')
        .eq('list_id', listId)
        .eq('source', 'user')
        .maybeSingle();
    return row?['chain_id'] as String?;
  }

  @override
  Future<void> saveUserChainId(String listId, String chainId) async {
    await _client.from(table).upsert(
      {'list_id': listId, 'chain_id': chainId, 'source': 'user'},
      onConflict: 'list_id',
    );
  }

  @override
  Future<void> deleteAssignment(String listId) async {
    await _client.from(table).delete().eq('list_id', listId);
  }

  @override
  Future<List<List<String>>> recentTripRetailers(
    String listId, {
    int limit = 3,
  }) async {
    final rows = await _client
        .from('shopping_history')
        .select('items:shopping_history_items(price_retailer)')
        .eq('list_id', listId)
        .order('completed_at', ascending: false)
        .limit(limit);
    return retailersOfTrips(rows);
  }

  /// Retailer names per trip from `shopping_history` rows with their
  /// embedded `items`, in row order. Blank retailers are left out.
  @visibleForTesting
  static List<List<String>> retailersOfTrips(
    List<Map<String, dynamic>> rows,
  ) =>
      [
        for (final row in rows)
          [
            for (final item in (row['items'] as List? ?? const []))
              if (item case {'price_retailer': final String retailer}
                  when retailer.trim().isNotEmpty)
                retailer,
          ],
      ];
}

/// The market of each list: the person's choice in the table, plus the last
/// answer of `storeGuessForListProvider` cached on the device, so a list shows
/// its market in the first frame and offline.
///
/// Writes are optimistic: the cache changes at once and [changes] fires,
/// then the table is written. A failed write rethrows, so the caller can
/// tell the person, and the list shows the newest choice that did not fail,
/// or the value from before the writes when all of them failed.
///
/// The cache belongs to one account. It is dropped when another account
/// (or none) is signed in, and [reset] drops it on sign-out.
class ListStoreRepository {
  ListStoreRepository({
    required ListStoreRemote remote,
    required String? Function() currentUserId,
  })  : _remote = remote,
        _currentUserId = currentUserId;

  static final ListStoreRepository instance = ListStoreRepository(
    remote: SupabaseListStoreRemote(),
    currentUserId: _signedInUserId,
  ).._resetOnSignOut();

  /// SharedPreferences key: `{user, lists: {list id -> last answer}}`, with
  /// `null` for "no market".
  static const cacheKey = 'list_store_guess_v1';

  /// How many of a list's newest trips the learned market looks at.
  static const recentTripCount = 3;

  final ListStoreRemote _remote;
  final String? Function() _currentUserId;
  final Map<String, StoreGuess?> _cache = {};
  final Map<String, int> _versions = {};
  final Map<String, List<_Write>> _writes = {};
  final Map<String, _Entry> _beforeWrites = {};
  final StreamController<String> _changes = StreamController.broadcast();

  /// The account [_cache] belongs to; set on the first access.
  String? _cacheUserId;
  bool _bound = false;

  /// Raised by every reset above every version handed out before, so an
  /// answer computed for the previous account is never cached.
  int _generation = 0;
  Future<void>? _loading;
  bool _loaded = false;

  /// Ids of lists whose market the person just changed, that rolled back or
  /// that were dropped by a reset. Detected answers do not fire.
  Stream<String> get changes => _changes.stream;

  bool get isCacheLoaded {
    _followAccount();
    return _loaded;
  }

  /// Reads the device cache once; later calls return the same future.
  Future<void> loadCache() {
    _followAccount();
    return _loading ??= _readCache(_cacheUserId);
  }

  /// True when an answer for [listId] is cached, even "no market".
  bool hasCachedGuess(String listId) {
    _followAccount();
    return _cache.containsKey(listId);
  }

  StoreGuess? cachedGuess(String listId) {
    _followAccount();
    return _cache[listId];
  }

  /// Changes with every choice the person makes for [listId] and with every
  /// reset. An answer computed under an older version is out of date.
  int version(String listId) {
    _followAccount();
    return _generation + (_versions[listId] ?? 0);
  }

  /// Caches a computed answer, unless the person changed the market since
  /// [version] was read.
  Future<void> rememberGuess(
    String listId,
    StoreGuess? guess, {
    required int version,
  }) async {
    await loadCache();
    if (version != this.version(listId)) return;
    if (_cache.containsKey(listId) && _cache[listId] == guess) return;
    _cache[listId] = guess;
    await _persist();
  }

  /// The market the person picked for [listId]. While a write is in flight
  /// or the table cannot be read, the cached choice answers. A chain id the
  /// app does not know counts as no choice.
  Future<String?> explicitChainId(String listId) async {
    await loadCache();
    if (_writes.containsKey(listId)) return _cachedChoice(listId);
    try {
      return _knownChain(await _remote.fetchUserChainId(listId));
    } catch (e) {
      debugPrint('⚠️ [STORE] Market of list not readable, using cache: $e');
      return _cachedChoice(listId);
    }
  }

  /// Chains of the newest [recentTripCount] trips of [listId], newest
  /// first. A trip without a clear market drops out, so the result can be
  /// shorter. Empty when the history cannot be read.
  Future<List<String>> recentTripChains(String listId) async {
    try {
      final trips = await _remote.recentTripRetailers(
        listId,
        limit: recentTripCount,
      );
      return [
        for (final retailers in trips)
          if (dominantChain(retailers) case final chainId?) chainId,
      ];
    } catch (e) {
      debugPrint('⚠️ [STORE] Trip history not readable: $e');
      return const [];
    }
  }

  /// The person picks [chainId], a [StoreChainDirectory] id, for [listId].
  Future<void> setExplicit(String listId, String chainId) async {
    final id = chainId.trim();
    if (StoreChainDirectory.byId(id) == null) {
      throw ArgumentError.value(chainId, 'chainId', 'is no known chain');
    }
    await _write(
      listId,
      StoreGuess(id, StoreSource.user, confirmed: true),
      () => _remote.saveUserChainId(listId, id),
    );
  }

  /// The person takes the market off [listId] ("Kein fester Markt").
  Future<void> clearExplicit(String listId) =>
      _write(listId, null, () => _remote.deleteAssignment(listId));

  /// Forgets every cached market, in memory and on the device, and fires
  /// [changes] for each list that had one. Called on sign-out.
  Future<void> reset() {
    _bound = true;
    _cacheUserId = _currentUserId();
    return _forget();
  }

  Future<void> _write(
    String listId,
    StoreGuess? next,
    Future<void> Function() send,
  ) async {
    await loadCache();
    final writes = _writes[listId] ??= [];
    if (writes.isEmpty) _beforeWrites[listId] = _entryOf(listId);
    final write = _Write((present: true, guess: next));
    writes.add(write);
    final saved = _apply(listId, write.entry);
    try {
      await send();
      await saved;
      debugPrint('✅ [STORE] Market of list saved: ${next?.chainId ?? 'none'}');
    } catch (e) {
      write.failed = true;
      debugPrint('❌ [STORE] Saving market of list failed: $e');
      rethrow;
    } finally {
      write.done = true;
      await _settle(listId, write);
    }
  }

  /// After [write] finished: shows the newest write of [listId] that did not
  /// fail (still in flight or saved), or the value from before the writes
  /// when all failed. Forgets the writes once none is in flight. A write
  /// from before a reset changes nothing.
  Future<void> _settle(String listId, _Write write) async {
    final writes = _writes[listId];
    if (writes == null || !writes.contains(write)) return;
    final standing = writes.reversed.where((w) => !w.failed).firstOrNull;
    final entry = standing?.entry ?? _beforeWrites[listId]!;
    if (writes.every((w) => w.done)) {
      _writes.remove(listId);
      _beforeWrites.remove(listId);
    }
    if (entry != _entryOf(listId)) await _apply(listId, entry);
  }

  /// Changes the cache, bumps the version and fires [changes] at once; the
  /// returned future completes when the cache is on disk.
  Future<void> _apply(String listId, _Entry entry) {
    if (entry.present) {
      _cache[listId] = entry.guess;
    } else {
      _cache.remove(listId);
    }
    _versions[listId] = (_versions[listId] ?? 0) + 1;
    _changes.add(listId);
    return _persist();
  }

  _Entry _entryOf(String listId) =>
      (present: _cache.containsKey(listId), guess: _cache[listId]);

  String? _cachedChoice(String listId) {
    final cached = _cache[listId];
    return cached != null && cached.source == StoreSource.user
        ? cached.chainId
        : null;
  }

  static String? _knownChain(String? chainId) {
    if (chainId == null || StoreChainDirectory.byId(chainId) != null) {
      return chainId;
    }
    debugPrint('⚠️ [STORE] Unknown market id in the table, ignored');
    return null;
  }

  /// Binds the cache to the signed-in account on the first access and drops
  /// it when the account changes.
  void _followAccount() {
    final userId = _currentUserId();
    if (_bound && userId == _cacheUserId) return;
    final switched = _bound;
    _bound = true;
    _cacheUserId = userId;
    if (switched) unawaited(_forget());
  }

  Future<void> _forget() {
    final listIds = {..._cache.keys, ..._writes.keys};
    _generation += 1 + _versions.values.fold(0, math.max);
    _cache.clear();
    _versions.clear();
    _writes.clear();
    _beforeWrites.clear();
    // The device holds one account's cache, so the next account has none.
    _loading = Future<void>.value();
    _loaded = true;
    listIds.forEach(_changes.add);
    debugPrint('🔵 [STORE] Market cache cleared for another account');
    return _removeFromDisk();
  }

  Future<void> _readCache(String? userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (userId != _cacheUserId) return;
      final raw = prefs.getString(cacheKey);
      if (raw == null) return;
      final json = jsonDecode(raw);
      if (json is! Map ||
          userId == null ||
          json['user'] != userId ||
          json['lists'] is! Map) {
        await prefs.remove(cacheKey);
        return;
      }
      for (final MapEntry(:key, :value) in (json['lists'] as Map).entries) {
        if (key is! String) continue;
        if (value == null) {
          _cache.putIfAbsent(key, () => null);
        } else if (_guessFromJson(value) case final guess?) {
          _cache.putIfAbsent(key, () => guess);
        }
      }
    } catch (e) {
      debugPrint('⚠️ [STORE] Market cache unreadable, starting empty: $e');
    } finally {
      _loaded = true;
    }
  }

  /// Saves [_cache] for [_cacheUserId]. Without an account nothing stays on
  /// the device.
  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = _cacheUserId;
      if (userId == null) {
        await prefs.remove(cacheKey);
        return;
      }
      await prefs.setString(cacheKey, jsonEncode({
        'user': userId,
        'lists': {
          for (final MapEntry(:key, :value) in _cache.entries)
            key: value == null ? null : _guessToJson(value),
        },
      }));
    } catch (e) {
      debugPrint('⚠️ [STORE] Market cache not saved: $e');
    }
  }

  Future<void> _removeFromDisk() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(cacheKey);
    } catch (e) {
      debugPrint('⚠️ [STORE] Market cache not removed: $e');
    }
  }

  void _resetOnSignOut() {
    try {
      Supabase.instance.client.auth.onAuthStateChange.listen(
        (data) {
          if (data.event == AuthChangeEvent.signedOut) unawaited(reset());
        },
        onError: (Object e) =>
            debugPrint('⚠️ [STORE] Auth events not readable: $e'),
      );
    } catch (e) {
      debugPrint('⚠️ [STORE] Sign-out not followed, Supabase not ready: $e');
    }
  }

  static String? _signedInUserId() {
    try {
      return Supabase.instance.client.auth.currentUser?.id;
    } catch (_) {
      return null;
    }
  }

  static Map<String, Object> _guessToJson(StoreGuess guess) => {
        'chain': guess.chainId,
        'source': guess.source.name,
        'confirmed': guess.confirmed,
      };

  static StoreGuess? _guessFromJson(Object value) {
    if (value is! Map) return null;
    final chain = value['chain'];
    final source = StoreSource.values.asNameMap()[value['source']];
    final confirmed = value['confirmed'];
    if (chain is! String || StoreChainDirectory.byId(chain) == null) {
      return null;
    }
    if (source == null || confirmed is! bool) return null;
    return StoreGuess(chain, source, confirmed: confirmed);
  }
}

/// One cache value: [present] false means "nothing cached".
typedef _Entry = ({bool present, StoreGuess? guess});

/// One optimistic write of a list's market.
class _Write {
  _Write(this.entry);

  final _Entry entry;
  bool failed = false;
  bool done = false;
}
