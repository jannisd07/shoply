import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:shoply/core/constants/categories.dart';
import 'package:shoply/core/utils/item_input_parser.dart';
import 'package:shoply/core/utils/product_name_normalizer.dart';
import 'package:shoply/data/services/claude_service.dart';
import 'package:shoply/data/services/smart_categorization_service.dart';

/// Item categories, local first, refined by Claude (task `categorize`, via
/// [ClaudeService]); plus list recommendations (task `recommend`) and the
/// on-device item parser.
///
/// Adding an item never has to wait: [categorizeLocal] answers at once from
/// learned choices, earlier Claude answers, keywords and the knowledge base.
/// [refineCategory] asks Claude only when that answer is a guess. Claude
/// answers are kept in an LRU cache keyed by the normalized name (no
/// language), loaded from storage on first use, not at app start, and
/// forgotten when the account signs out. Quota and throttling live in the
/// edge function; this service only stops asking for a while when it says
/// so.
class AiCategorizationService {
  AiCategorizationService._({
    ClaudeService? claude,
    SmartCategorizationService? local,
    int cacheCapacity = defaultCacheCapacity,
    Stream<void>? signedOut,
  })  : _claudeOverride = claude,
        _local = local ?? SmartCategorizationService.instance,
        _cacheCapacity = cacheCapacity {
    (signedOut ?? _supabaseAccountEnds()).listen(
      (_) => _forgetAccount(),
      onError: (Object e) =>
          debugPrint('⚠️ [AI_CATEGORY] Auth events unavailable: $e'),
    );
  }

  static final AiCategorizationService _instance = AiCategorizationService._();
  static AiCategorizationService get instance => _instance;
  factory AiCategorizationService() => _instance;

  /// [signedOut] fires whenever the signed-in account ends; by default the
  /// Supabase auth events.
  @visibleForTesting
  factory AiCategorizationService.forTesting({
    required ClaudeService claude,
    required SmartCategorizationService local,
    int cacheCapacity = defaultCacheCapacity,
    Stream<void>? signedOut,
  }) =>
      AiCategorizationService._(
        claude: claude,
        local: local,
        cacheCapacity: cacheCapacity,
        signedOut: signedOut ?? const Stream<void>.empty(),
      );

  static const int defaultCacheCapacity = 2000;

  /// Most names per `categorize` call (the edge function's limit).
  static const int batchSize = 60;

  /// Longest name the edge function accepts; longer names are cut to it.
  static const int maxNameChars = 500;

  static const Duration categorizeTimeout = Duration(seconds: 8);
  static const Duration recommendTimeout = Duration(seconds: 10);

  /// Limits of task `recommend`.
  static const int _maxRecommendItems = 100;
  static const int _maxFrequentItems = 15;
  static const int _recommendLimit = 5;

  /// A suggestion is a plain item name: short, a few words, no links.
  static const int _maxSuggestionChars = 49;
  static const int _maxSuggestionWords = 5;
  static final RegExp _lineBreaksAndControls =
      RegExp(r'[\x00-\x1F\x7F-\x9F\u2028\u2029]');
  static final RegExp _invisible =
      RegExp(r'[\u200B-\u200F\u202A-\u202E\u2060-\u2064\u2066-\u2069\uFEFF]');
  static final RegExp _spaces = RegExp(r'\s+');
  static final RegExp _linkLike = RegExp(
    r'https?:|www\.|@|\b[a-z0-9-]+\.(?:com|de|net|org|io|app|ly|me|info|test)\b',
    caseSensitive: false,
  );
  static final RegExp _letter = RegExp(r'[^\W\d_]', unicode: true);

  static const String _cacheKey = 'ai_category_cache_v1';

  /// `language_name → id` answers of the removed Gemini service; taken over
  /// once, then deleted.
  static const String _legacyGeminiCacheKey = 'category_cache';
  static final RegExp _legacyCategoryEntry = RegExp(r'^(?:de|en)_(.+)$');

  final ClaudeService? _claudeOverride;
  final SmartCategorizationService _local;
  final int _cacheCapacity;

  ClaudeService get _claude => _claudeOverride ?? ClaudeService.instance;

  /// Normalized name → category id, least recently used first.
  final LinkedHashMap<String, String> _cache = LinkedHashMap();
  Future<void>? _cacheLoading;
  bool _cacheLoaded = false;

  /// Storage writes, one after the other, so a removal never comes before
  /// an older write.
  Future<void> _saving = Future.value();

  /// Bumped whenever the answers are dropped; a load or an answer that
  /// started before is thrown away.
  int _epoch = 0;

  /// One request per name in flight, however often it is asked.
  final Map<String, Future<String?>> _inFlight = {};

  /// After `quota_exceeded` or `ai_disabled` a task is not asked again
  /// before this time. The server counts both per task, so a used-up
  /// `recommend` never stops `categorize`.
  final Map<String, DateTime> _taskPausedUntil = {};

  /// After `rate_limited` (the provider is overloaded) no task is asked.
  DateTime? _allPausedUntil;

  final StreamController<void> _accountReset = StreamController.broadcast();

  /// Fires after a sign-out has made this service forget the account's
  /// answers, so others that remember Claude answers forget them too.
  Stream<void> get accountReset => _accountReset.stream;

  /// The language Claude answers in (`de` or `en`, the app language).
  String get locale => _claude.locale;

  /// The category id for [name] right now, without waiting: the user's own
  /// choice, an earlier Claude answer, keywords, the knowledge base or
  /// 'other'. The first call also starts loading the stored answers.
  String categorizeLocal(String name) {
    _warmUp();
    return _answer(name).id;
  }

  /// The better category for [name] once the stored answers are loaded: the
  /// user's own choice or an earlier Claude answer (which [categorizeLocal]
  /// may not have had yet right after start), otherwise Claude's answer when
  /// the local one is only a guess (from one `categorize` call of at most
  /// [categorizeTimeout]). Null when an exact keyword decides or Claude
  /// cannot help. Never throws.
  Future<String?> refineCategory(String name) async {
    try {
      await _ensureLoaded();
      final answer = _answer(name);
      if (answer.stored) return answer.id;
      if (!answer.guess) return null;
      return await _askOne(name);
    } catch (e) {
      debugPrint('⚠️ [AI_CATEGORY] Refinement failed: ${e.runtimeType}');
      return null;
    }
  }

  /// Category id for [itemName], waiting for Claude only when the local
  /// answer is a guess. [languageCode] says which keywords to try first.
  /// Never throws.
  Future<String> categorizeItem(String itemName, [String? languageCode]) async {
    await _ensureLoadedQuietly();
    final answer = _answer(itemName, languageCode: languageCode);
    if (answer.stored || !answer.guess) return answer.id;
    return await _askOne(itemName) ?? answer.id;
  }

  /// Category ids for all [names] (keys as given). Guesses are refined in
  /// calls of at most [batchSize] names; anything Claude cannot answer keeps
  /// its local id. Never throws.
  Future<Map<String, String>> categorizeBatch(List<String> names) async {
    await _ensureLoadedQuietly();
    final result = <String, String>{};
    final unsure = <String, String>{}; // key → first name seen, in order
    for (final name in names) {
      final answer = _answer(name);
      result[name] = answer.id;
      final key = _keyFor(name);
      if (answer.guess && !answer.stored && key.isNotEmpty) {
        unsure.putIfAbsent(key, () => name);
      }
    }

    final keys = unsure.keys.toList();
    for (var start = 0; start < keys.length; start += batchSize) {
      final chunk = keys.sublist(start, math.min(start + batchSize, keys.length));
      final answers = await _ask([for (final key in chunk) unsure[key]!]);
      if (answers.isEmpty) continue;
      for (final name in names) {
        final refined = answers[_keyFor(name)];
        if (refined != null) result[name] = refined;
      }
    }
    return result;
  }

  /// 3–5 items that would complete [currentItems], in the app language
  /// (task `recommend`). Empty when the list is empty or Claude fails.
  Future<List<String>> getSmartRecommendations(
    List<String> currentItems, {
    List<String>? frequentItems,
  }) async =>
      await recommendItems(currentItems, frequentItems: frequentItems) ?? [];

  /// Like [getSmartRecommendations], but null when Claude could not answer
  /// (offline, quota, error), so a caller can remember a real empty answer
  /// without remembering a failure. Blank names are left out and long ones
  /// cut to [maxNameChars]; the suggestions are cleaned (one line, no
  /// links, at most a few words) and never repeat what is on the list.
  Future<List<String>?> recommendItems(
    List<String> currentItems, {
    List<String>? frequentItems,
  }) async {
    final items = _sendable(currentItems, _maxRecommendItems);
    if (items.isEmpty) return const [];
    if (_isPaused('recommend')) return null;
    try {
      final result = await _claude.run(
        'recommend',
        {
          'items': items,
          'frequent_items':
              _sendable(frequentItems ?? const [], _maxFrequentItems),
          'limit': _recommendLimit,
        },
        timeout: recommendTimeout,
      );
      final seen = {for (final item in currentItems) _sameItemKey(item)};
      final suggestions = <String>[];
      for (final entry in (result['items'] as List?) ?? const []) {
        final name = _cleanSuggestion(entry is Map ? entry['name'] : entry);
        if (name == null || !seen.add(_sameItemKey(name))) continue;
        suggestions.add(name);
        if (suggestions.length == _recommendLimit) break;
      }
      debugPrint('✅ [AI_CATEGORY] ${suggestions.length} recommendations');
      return suggestions;
    } on ClaudeException catch (e) {
      _pauseAfter('recommend', e);
      return null;
    } catch (e) {
      debugPrint('❌ [AI_CATEGORY] Recommendations failed: ${e.runtimeType}');
      return null;
    }
  }

  /// Forgets all Claude answers (learned choices stay).
  Future<void> clearCache() async {
    _dropAnswers();
    debugPrint('✅ [AI_CATEGORY] Category cache cleared');
    await _saving;
  }

  /// Splits what was typed ("2x Milch", "500 g Mehl", "Milch 2") into name,
  /// amount and unit with Teil A's [parseSingleItem], on the device. Without
  /// an amount the result is 1, without a unit "pcs"; units are A's ids
  /// (`g`, `kg`, `ml`, `l`, `pack`, `bottle`, `can`, `box`, `bunch`), and a
  /// note in brackets stays part of the name.
  Future<Map<String, dynamic>> parseIngredient(String input) async {
    final text = input.trim();
    final item = parseSingleItem(text, lang: locale);
    if (item == null) return {'name': text, 'amount': 1.0, 'unit': 'pcs'};
    final name = item.note == null ? item.name : '${item.name} (${item.note})';
    return {
      'name': sanitizeParsedName(text, name),
      'amount': item.quantity,
      'unit': item.unit ?? 'pcs',
    };
  }

  /// Guard against a parser *inventing* words.
  ///
  /// Parsing an item is an extraction task: strip the quantity and unit,
  /// keep the product. A real list once ended up with "Tiefkühlerbsen
  /// erbsen" in the database, and that name then travels into price lookups
  /// and purchase statistics.
  ///
  /// The invariant is therefore that the result must be a *shortening* of
  /// what the user typed: with punctuation, spaces and case removed, it has
  /// to appear inside the input. Word-level checks are not enough — "erbsen"
  /// is a substring of "Tiefkühlerbsen", so the duplicate slipped through a
  /// per-word test. Comparing the whole squashed string catches it.
  ///
  /// Anything else falls back to the typed name: an unparsed but honest name
  /// is always better than a confident wrong one.
  @visibleForTesting
  static String sanitizeParsedName(String input, String? parsed) {
    final candidate = parsed?.trim() ?? '';
    if (candidate.isEmpty) return input;

    String squash(String v) =>
        v.toLowerCase().replaceAll(RegExp(r'[^a-z0-9äöüß]'), '');

    final squashedInput = squash(input);
    final squashedCandidate = squash(candidate);
    if (squashedCandidate.isEmpty) return input;

    return squashedInput.contains(squashedCandidate) ? candidate : input;
  }

  // Answers ------------------------------------------------------------------

  /// The local answer: learned beats cached beats the rest of the pipeline.
  /// [stored] answers (learned or cached) come from data loaded later than
  /// the keywords, so [refineCategory] passes them on.
  ({String id, bool stored, bool guess}) _answer(
    String name, {
    String? languageCode,
  }) {
    final learned = _local.learnedCategory(name);
    if (learned != null) return (id: learned, stored: true, guess: false);
    final cached = _cacheGet(_keyFor(name));
    if (cached != null) return (id: cached, stored: true, guess: false);
    final local = _local.classify(name, preferredLanguage: languageCode);
    return (id: local.categoryId, stored: false, guess: local.isGuess);
  }

  Future<String?> _askOne(String name) {
    final key = _keyFor(name);
    if (key.isEmpty) return Future.value();
    final running = _inFlight[key];
    if (running != null) return running;
    late final Future<String?> asking;
    asking = _ask([name]).then((answers) => answers[key]).whenComplete(() {
      // After a sign-out the map may already hold a newer request.
      if (identical(_inFlight[key], asking)) _inFlight.remove(key);
    });
    return _inFlight[key] = asking;
  }

  /// One `categorize` call for [names]; key → id of every valid answer,
  /// stored in the cache. Blank names are not sent, long ones are cut.
  /// Empty on any failure.
  Future<Map<String, String>> _ask(List<String> names) async {
    final sent = [
      for (final name in names.map(_clip))
        if (normalizeProductName(name).isNotEmpty) name,
    ];
    if (sent.isEmpty || _isPaused('categorize')) return const {};
    final epoch = _epoch;
    try {
      final result = await _claude.run(
        'categorize',
        {
          'items': [
            for (final name in sent) {'name': name},
          ],
        },
        timeout: categorizeTimeout,
      );
      if (epoch != _epoch) return const {}; // signed out meanwhile
      final items = (result['items'] as List?) ?? const [];
      final answers = <String, String>{};
      for (var i = 0; i < sent.length && i < items.length; i++) {
        final item = items[i];
        final id = item is Map ? item['category_id'] : null;
        if (id is String && Categories.allIds.contains(id)) {
          final key = normalizeProductName(sent[i]);
          answers[key] = id;
          _cachePut(key, id);
        }
      }
      if (answers.isNotEmpty) _persist();
      debugPrint(
          '✅ [AI_CATEGORY] Claude categorized ${answers.length}/${sent.length}');
      return answers;
    } on ClaudeException catch (e) {
      _pauseAfter('categorize', e);
      return const {};
    } catch (e) {
      debugPrint('❌ [AI_CATEGORY] Unexpected categorize answer: ${e.runtimeType}');
      return const {};
    }
  }

  bool _isPaused(String task) {
    final now = DateTime.now();
    final all = _allPausedUntil;
    final one = _taskPausedUntil[task];
    return (all != null && now.isBefore(all)) ||
        (one != null && now.isBefore(one));
  }

  void _pauseAfter(String task, ClaudeException e) {
    final now = DateTime.now();
    final retry =
        e.retryAfterS == null ? null : Duration(seconds: e.retryAfterS!);
    final DateTime until;
    switch (e.code) {
      case 'quota_exceeded':
        // The daily quota resets at midnight (Europe/Berlin on the server).
        until = retry != null
            ? now.add(retry)
            : DateTime(now.year, now.month, now.day + 1);
        _taskPausedUntil[task] = until;
      case 'ai_disabled':
        until = now.add(const Duration(minutes: 15));
        _taskPausedUntil[task] = until;
      case 'rate_limited':
        until = now.add(retry ?? const Duration(minutes: 1));
        _allPausedUntil = until;
      default:
        return;
    }
    debugPrint('⚠️ [AI_CATEGORY] ${e.code} ($task): local only until $until');
  }

  // Input and output ---------------------------------------------------------

  /// The cache key of [name]: the normalized form of what would be sent.
  static String _keyFor(String name) => normalizeProductName(_clip(name));

  /// [name] trimmed and cut to [maxNameChars], never inside a character
  /// made of two UTF-16 units.
  static String _clip(String name) {
    final text = name.trim();
    if (text.length <= maxNameChars) return text;
    var end = maxNameChars;
    final last = text.codeUnitAt(end - 1);
    if (last >= 0xD800 && last <= 0xDBFF) end--;
    return text.substring(0, end).trimRight();
  }

  /// At most [max] of [names], trimmed, cut, without blank ones.
  static List<String> _sendable(Iterable<String> names, int max) => [
        for (final name in names.map(_clip))
          if (name.isNotEmpty) name,
      ].take(max).toList();

  /// Two names for the same item ("pasta", "Pasta!") share this key.
  static String _sameItemKey(String name) {
    final normalized = normalizeProductName(name);
    return normalized.isEmpty ? name.trim().toLowerCase() : normalized;
  }

  /// A suggestion as the card may show it, or null. The answer is built
  /// from list entries anyone on a shared list can write, so it is treated
  /// as untrusted text: one line, no invisible characters, no links or
  /// addresses, letters required, short.
  static String? _cleanSuggestion(Object? raw) {
    if (raw is! String) return null;
    final name = raw
        .replaceAll(_invisible, '')
        .replaceAll(_lineBreaksAndControls, ' ')
        .replaceAll(_spaces, ' ')
        .trim();
    if (name.isEmpty || name.length > _maxSuggestionChars) return null;
    if (name.split(' ').length > _maxSuggestionWords) return null;
    if (_linkLike.hasMatch(name) || !_letter.hasMatch(name)) return null;
    return name;
  }

  // Account --------------------------------------------------------------------

  /// Fires when the signed-in account ends: a sign-out, or another account
  /// signing in. Empty when Supabase is not set up (tests, very early start).
  static Stream<void> _supabaseAccountEnds() {
    final GoTrueClient auth;
    try {
      auth = Supabase.instance.client.auth;
    } catch (_) {
      return const Stream<void>.empty();
    }
    var userId = auth.currentUser?.id;
    return auth.onAuthStateChange.where((state) {
      final previous = userId;
      userId = state.session?.user.id;
      return state.event == AuthChangeEvent.signedOut ||
          (previous != null && userId != null && previous != userId);
    }).map((_) {});
  }

  /// The account ended: its Claude answers (memory and storage), pauses
  /// (quota is per account) and requests in flight are forgotten.
  void _forgetAccount() {
    _dropAnswers();
    _inFlight.clear();
    _taskPausedUntil.clear();
    _allPausedUntil = null;
    debugPrint('✅ [AI_CATEGORY] Signed out: Claude answers forgotten');
    _accountReset.add(null);
  }

  // Cache ----------------------------------------------------------------------

  void _dropAnswers() {
    _epoch++;
    _cache.clear();
    _cacheLoaded = true;
    _cacheLoading = Future.value();
    _queueWrite('clear the category cache', (prefs) async {
      await prefs.remove(_cacheKey);
      await prefs.remove(_legacyGeminiCacheKey);
    });
  }

  void _warmUp() {
    if (!_cacheLoaded) unawaited(_ensureLoadedQuietly());
  }

  Future<void> _ensureLoaded() async {
    await (_cacheLoading ??= _loadCache());
    await _local.ensureLearnedLoaded();
  }

  Future<void> _ensureLoadedQuietly() async {
    try {
      await _ensureLoaded();
    } catch (e) {
      debugPrint('⚠️ [AI_CATEGORY] Stored answers unavailable: $e');
    }
  }

  Future<void> _loadCache() async {
    final epoch = _epoch;
    try {
      final prefs = await SharedPreferences.getInstance();
      final stored = <String, String>{};
      _readMap(prefs.getString(_cacheKey)).forEach((key, id) {
        if (Categories.allIds.contains(id)) stored[key] = id;
      });

      final legacy = prefs.getString(_legacyGeminiCacheKey);
      _readMap(legacy).forEach((key, id) {
        final match = _legacyCategoryEntry.firstMatch(key);
        if (match == null || !Categories.allIds.contains(id)) return;
        final name = normalizeProductName(match.group(1)!);
        if (name.isNotEmpty) stored.putIfAbsent(name, () => id);
      });
      if (epoch != _epoch) return; // dropped while loading

      // Answers that arrived while loading are newer than the stored ones.
      final fresh = Map<String, String>.of(_cache);
      _cache
        ..clear()
        ..addAll(stored)
        ..addAll(fresh);
      _trim();
      if (legacy != null) {
        _queueWrite('take over the old category cache', (prefs) async {
          await prefs.setString(_cacheKey, jsonEncode(_cache));
          await prefs.remove(_legacyGeminiCacheKey);
        });
        await _saving;
        debugPrint('✅ [AI_CATEGORY] Took over the old category cache');
      }
    } catch (e) {
      debugPrint('⚠️ [AI_CATEGORY] Could not load the category cache: $e');
    } finally {
      if (epoch == _epoch) _cacheLoaded = true;
    }
  }

  static Map<String, String> _readMap(String? raw) {
    if (raw == null) return const {};
    final decoded = jsonDecode(raw);
    if (decoded is! Map) return const {};
    return {
      for (final entry in decoded.entries)
        if (entry.key is String && entry.value is String)
          entry.key as String: entry.value as String,
    };
  }

  String? _cacheGet(String key) {
    final id = _cache.remove(key);
    if (id != null) _cache[key] = id; // most recently used goes last
    return id;
  }

  void _cachePut(String key, String id) {
    _cache
      ..remove(key)
      ..[key] = id;
    _trim();
  }

  void _trim() {
    while (_cache.length > _cacheCapacity) {
      _cache.remove(_cache.keys.first);
    }
  }

  /// Writes the cache after the current write, without blocking callers.
  void _persist() => _queueWrite(
        'save the category cache',
        (prefs) => prefs.setString(_cacheKey, jsonEncode(_cache)),
      );

  void _queueWrite(
    String what,
    Future<void> Function(SharedPreferences prefs) write,
  ) {
    _saving = _saving.then((_) async {
      try {
        await write(await SharedPreferences.getInstance());
      } catch (e) {
        debugPrint('⚠️ [AI_CATEGORY] Could not $what: $e');
      }
    });
  }
}
