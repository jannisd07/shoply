import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Keys of the rows in `public.app_flags`
/// (migration `supabase/migrations/20261108000000_b_app_flags.sql`).
abstract final class AppFlagKeys {
  /// Kill switch for everything offers: no request, no widget pixel when off.
  static const offersEnabled = 'offers_enabled';

  /// Kill switch for the Claude features (Avo chat, photos, refinement).
  static const aiEnabled = 'ai_enabled';

  /// Daily AI limits per person: `{"free": {...}, "pro": {...}}`.
  static const aiLimits = 'ai_limits';
}

/// Where an [AppFlags] snapshot comes from.
enum AppFlagsSource {
  /// Nothing read yet ([AppFlags.empty]): the cache read has not finished.
  none,

  /// The cache was read but held no flags (first start, broken entry).
  defaults,

  /// The device cache, written by the last successful refresh.
  cache,

  /// A successful refresh in this session. Flags built by hand (tests,
  /// overrides) count as this too.
  server,
}

/// Snapshot of the remote flags. Unknown keys answer with a fallback, so a
/// missing row never switches a feature off. Kill switches that must stay
/// shut until the real value is there check [isKnown] or [isLoaded] first.
@immutable
class AppFlags {
  const AppFlags({
    this.enabled = const {},
    this.values = const {},
    this.source = AppFlagsSource.server,
  });

  /// `app_flags.enabled` per key.
  final Map<String, bool> enabled;

  /// `app_flags.value` per key, only for rows whose value is not null.
  final Map<String, dynamic> values;

  final AppFlagsSource source;

  /// No flags known yet, and the cache has not been read.
  static const AppFlags empty = AppFlags(source: AppFlagsSource.none);

  /// The cache read has finished (with or without flags), or a refresh
  /// succeeded.
  bool get isLoaded => source != AppFlagsSource.none;

  /// The flags are real values from the server, fresh or cached.
  bool get isKnown =>
      source == AppFlagsSource.cache || source == AppFlagsSource.server;

  bool isEnabled(String key, {bool fallback = true}) =>
      enabled[key] ?? fallback;

  /// Rows as returned by `select key, enabled, value from app_flags`.
  /// Rows without a string key are skipped.
  factory AppFlags.fromRows(List<Map<String, dynamic>> rows) {
    final enabled = <String, bool>{};
    final values = <String, dynamic>{};
    for (final row in rows) {
      final key = row['key'];
      if (key is! String) continue;
      final on = row['enabled'];
      if (on is bool) enabled[key] = on;
      final value = row['value'];
      if (value != null) values[key] = value;
    }
    return AppFlags(enabled: enabled, values: values);
  }

  factory AppFlags.fromJson(Map<String, dynamic> json) {
    final enabled = json['enabled'];
    final values = json['values'];
    return AppFlags(
      source: AppFlagsSource.cache,
      enabled: enabled is Map
          ? {
              for (final e in enabled.entries)
                if (e.key is String && e.value is bool)
                  e.key as String: e.value as bool,
            }
          : const {},
      values: values is Map ? values.cast<String, dynamic>() : const {},
    );
  }

  Map<String, dynamic> toJson() => {'enabled': enabled, 'values': values};
}

/// Reads the rows of `public.app_flags`.
typedef FlagsFetcher = Future<List<Map<String, dynamic>>> Function();

/// Remote kill switches and limits, cached on the device.
///
/// [current] is synchronous: [AppFlags.empty] until [loadCache] finished
/// (await it before `runApp`), then the cached flags, and the fresh ones after
/// a successful [refresh]. A failing refresh keeps what is there, so offline
/// starts behave like the last online start.
class AppFlagsService {
  AppFlagsService({FlagsFetcher? fetcher, DateTime Function()? clock})
    : _fetcher = fetcher ?? _fetchFromSupabase,
      _clock = clock ?? DateTime.now;

  static final AppFlagsService instance = AppFlagsService();

  /// SharedPreferences key of the cached flags.
  static const cacheKey = 'app_flags_v1';

  /// A refresh within this time after a successful one is skipped.
  static const refreshInterval = Duration(minutes: 30);

  static const _fetchTimeout = Duration(seconds: 8);

  final FlagsFetcher _fetcher;
  final DateTime Function() _clock;
  final _changes = StreamController<AppFlags>.broadcast();

  AppFlags _current = AppFlags.empty;
  DateTime? _lastSuccess;
  Future<void>? _cacheLoad;
  Future<AppFlags>? _inFlight;

  AppFlags get current => _current;

  /// Emits every time [current] changes.
  Stream<AppFlags> get changes => _changes.stream;

  static Future<List<Map<String, dynamic>>> _fetchFromSupabase() => Supabase
      .instance
      .client
      .from('app_flags')
      .select('key, enabled, value')
      .timeout(_fetchTimeout);

  /// Reads the cached flags; without any, [current] turns into
  /// [AppFlagsSource.defaults]. Safe to call more than once; never
  /// overwrites flags that a refresh already brought.
  Future<void> loadCache() => _cacheLoad ??= _readCache();

  Future<void> _readCache() async {
    var flags = const AppFlags(source: AppFlagsSource.defaults);
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(cacheKey);
      final json = raw == null ? null : jsonDecode(raw);
      if (json is Map) {
        final cached = AppFlags.fromJson(json.cast<String, dynamic>());
        if (cached.enabled.isNotEmpty) flags = cached;
      }
    } catch (e) {
      debugPrint('⚠️ [AppFlags] Ignoring unreadable cache: $e');
    }
    if (_lastSuccess == null) _set(flags);
  }

  /// Fetches the flags and caches them. Skipped when the last success is
  /// less than [refreshInterval] ago, unless [force] is set. On any error,
  /// and on an answer without flags (the table always has seeded rows, so an
  /// empty answer means a broken policy), the current flags stay and are
  /// returned.
  Future<AppFlags> refresh({bool force = false}) {
    final last = _lastSuccess;
    if (!force && last != null) {
      final age = _clock().difference(last);
      // A clock that went back counts as expired, not as fresh.
      if (!age.isNegative && age < refreshInterval) {
        return Future.value(_current);
      }
    }
    return _inFlight ??= _fetch().whenComplete(() => _inFlight = null);
  }

  Future<AppFlags> _fetch() async {
    try {
      final flags = AppFlags.fromRows(await _fetcher());
      if (flags.enabled.isEmpty) {
        debugPrint('⚠️ [AppFlags] Refresh returned no flags, keeping current');
        return _current;
      }
      _lastSuccess = _clock();
      _set(flags);
      debugPrint('✅ [AppFlags] Refreshed ${flags.enabled.length} flags');
      await _writeCache(flags);
    } catch (e) {
      debugPrint('⚠️ [AppFlags] Refresh failed, keeping current flags: $e');
    }
    return _current;
  }

  Future<void> _writeCache(AppFlags flags) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(cacheKey, jsonEncode(flags.toJson()));
    } catch (e) {
      debugPrint('⚠️ [AppFlags] Writing cache failed: $e');
    }
  }

  void _set(AppFlags flags) {
    _current = flags;
    _changes.add(flags);
  }
}
