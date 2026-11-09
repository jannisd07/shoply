import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shoply/data/models/food_log_entry.dart';
import 'package:shoply/data/models/meal_plan.dart';
import 'package:shoply/data/services/supabase_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

// Wochenplan (B7): the plan store. Local first: every change is visible at
// once, written to the device and queued in an outbox; the outbox goes to
// Supabase (meal_plan_entries, meal_plans, meal_plan_settings) whenever the
// network allows. Entry ids are made on the device, so a retried upsert or
// an undo (re-insert with the same id) is idempotent. The device cache holds
// this week and the next one, enough for the first frame of the plan, the
// home card and the widget.

/// The Supabase side of the plan; RLS limits every call to the person.
abstract class MealPlanRemote {
  /// Entries with `from <= plan_date < to`.
  Future<List<Map<String, dynamic>>> fetchEntries(DateTime from, DateTime to);
  Future<void> upsertEntries(List<Map<String, dynamic>> rows);
  Future<void> deleteEntries(List<String> ids);

  /// Week rows with `from <= week_start < to`.
  Future<List<Map<String, dynamic>>> fetchWeeks(DateTime from, DateTime to);
  Future<void> upsertWeek(Map<String, dynamic> row);
  Future<Map<String, dynamic>?> fetchSettings();
  Future<void> upsertSettings(Map<String, dynamic> row);
}

class SupabaseMealPlanRemote implements MealPlanRemote {
  SupabaseMealPlanRemote(this.userId, {SupabaseClient? client}) : _clientOverride = client;

  final String userId;
  final SupabaseClient? _clientOverride;

  SupabaseClient get _client => _clientOverride ?? SupabaseService.instance.client;

  @override
  Future<List<Map<String, dynamic>>> fetchEntries(DateTime from, DateTime to) async {
    final rows = await _client
        .from('meal_plan_entries')
        .select()
        .eq('user_id', userId)
        .gte('plan_date', planDateKey(from))
        .lt('plan_date', planDateKey(to))
        .order('plan_date')
        .order('position');
    return [for (final r in rows) Map<String, dynamic>.from(r)];
  }

  @override
  Future<void> upsertEntries(List<Map<String, dynamic>> rows) async {
    if (rows.isEmpty) return;
    await _client.from('meal_plan_entries').upsert(rows, onConflict: 'id');
  }

  @override
  Future<void> deleteEntries(List<String> ids) async {
    if (ids.isEmpty) return;
    await _client.from('meal_plan_entries').delete().eq('user_id', userId).inFilter('id', ids);
  }

  @override
  Future<List<Map<String, dynamic>>> fetchWeeks(DateTime from, DateTime to) async {
    final rows = await _client
        .from('meal_plans')
        .select('week_start, target_list_id, first_sent_at')
        .eq('user_id', userId)
        .gte('week_start', planDateKey(from))
        .lt('week_start', planDateKey(to));
    return [for (final r in rows) Map<String, dynamic>.from(r)];
  }

  @override
  Future<void> upsertWeek(Map<String, dynamic> row) =>
      _client.from('meal_plans').upsert(row, onConflict: 'user_id,week_start');

  @override
  Future<Map<String, dynamic>?> fetchSettings() async {
    final row = await _client.from('meal_plan_settings').select().eq('user_id', userId).maybeSingle();
    return row == null ? null : Map<String, dynamic>.from(row);
  }

  @override
  Future<void> upsertSettings(Map<String, dynamic> row) =>
      _client.from('meal_plan_settings').upsert(row, onConflict: 'user_id');
}

/// What a change replaced, to put it back ("Widerrufen"). A null value
/// means the entry or week did not exist before.
class MealPlanUndo {
  const MealPlanUndo({this.entries = const {}, this.weeks = const {}});

  final Map<String, MealPlanEntry?> entries;
  final Map<DateTime, MealPlanWeek?> weeks;

  bool get isEmpty => entries.isEmpty && weeks.isEmpty;
}

/// Read-only view of the plan at one moment.
class MealPlanSnapshot {
  const MealPlanSnapshot({
    this.entries = const {},
    this.weeks = const {},
    this.settings = MealPlanSettings.defaults,
    this.loaded = false,
    this.pendingChanges = 0,
  });

  /// By id; only the weeks loaded so far.
  final Map<String, MealPlanEntry> entries;

  /// By Monday.
  final Map<DateTime, MealPlanWeek> weeks;
  final MealPlanSettings settings;

  /// The device cache has been read.
  final bool loaded;

  /// Changes not yet on the server ("3 Änderungen warten").
  final int pendingChanges;

  /// The day's entries in their order.
  List<MealPlanEntry> entriesForDay(DateTime day) {
    final d = planDay(day);
    return _sorted(entries.values.where((e) => e.planDate == d));
  }

  /// Monday to Sunday of the week containing [weekStart].
  List<MealPlanEntry> entriesForWeek(DateTime weekStart) {
    final start = planWeekStart(weekStart);
    final end = planAddDays(start, 7);
    return _sorted(entries.values.where((e) => !e.planDate.isBefore(start) && e.planDate.isBefore(end)));
  }

  MealPlanWeek? week(DateTime weekStart) => weeks[planWeekStart(weekStart)];

  static List<MealPlanEntry> _sorted(Iterable<MealPlanEntry> entries) => entries.toList()
    ..sort((a, b) {
      final byDay = a.planDate.compareTo(b.planDate);
      if (byDay != 0) return byDay;
      final byPosition = a.position.compareTo(b.position);
      return byPosition != 0 ? byPosition : a.createdAt.compareTo(b.createdAt);
    });
}

/// One queued write. A newer op for the same key replaces the older one.
class _Op {
  const _Op(this.kind, this.key, this.row);

  factory _Op.fromJson(Map<String, dynamic> json) =>
      _Op(json['kind'] as String, json['key'] as String, (json['row'] as Map?)?.cast<String, dynamic>());

  /// entry_upsert, entry_delete, week_upsert, settings_upsert.
  final String kind;
  final String key;
  final Map<String, dynamic>? row;

  Map<String, dynamic> toJson() => {'kind': kind, 'key': key, 'row': row};
}

class MealPlanRepository {
  MealPlanRepository({
    required this.userId,
    MealPlanRemote? remote,
    DateTime Function()? now,
    String Function()? newId,
    Future<SharedPreferences> Function()? prefs,
  })  : _remote = remote,
        _now = now ?? DateTime.now,
        _newId = newId ?? const Uuid().v4,
        _prefs = prefs ?? SharedPreferences.getInstance;

  final String userId;
  final MealPlanRemote? _remote;
  final DateTime Function() _now;
  final String Function() _newId;
  final Future<SharedPreferences> Function() _prefs;

  final Map<String, MealPlanEntry> _entries = {};
  final Map<DateTime, MealPlanWeek> _weeks = {};
  MealPlanSettings _settings = MealPlanSettings.defaults;
  final Map<String, _Op> _outbox = {};
  final Set<DateTime> _fetchedWeeks = {};

  /// Local change counter per entry id; a server answer that started before
  /// a local change never overwrites or removes it.
  final Map<String, int> _touched = {};
  int _seq = 0;
  bool _loaded = false;
  bool _disposed = false;

  /// Synchronous, so a provider sees a change before the call returns.
  final _changes = StreamController<MealPlanSnapshot>.broadcast(sync: true);
  MealPlanSnapshot _snapshot = const MealPlanSnapshot();
  Future<void>? _ready;
  Future<void>? _syncing;
  Future<void> _flushChain = Future.value();

  String get _cacheKey => 'meal_plan_cache_v1_$userId';
  String get _outboxKey => 'meal_plan_outbox_v1_$userId';

  MealPlanSnapshot get snapshot => _snapshot;

  /// Every change, local or from the server.
  Stream<MealPlanSnapshot> get changes => _changes.stream;

  DateTime get _thisWeek => planWeekStart(_now());

  // ---------------------------------------------------------------- loading

  /// Reads the device cache (once), then syncs in the background.
  Future<void> load() => _ready ??= _load();

  Future<void> _load() async {
    try {
      final prefs = await _prefs();
      final cache = prefs.getString(_cacheKey);
      if (cache != null) {
        final json = jsonDecode(cache) as Map<String, dynamic>;
        for (final row in json['entries'] as List? ?? const []) {
          final e = MealPlanEntry.fromRow((row as Map).cast<String, dynamic>());
          _entries[e.id] = e;
        }
        for (final row in json['weeks'] as List? ?? const []) {
          final w = MealPlanWeek.fromRow((row as Map).cast<String, dynamic>());
          _weeks[w.weekStart] = w;
        }
        final settings = json['settings'];
        if (settings is Map) _settings = MealPlanSettings.fromRow(settings.cast<String, dynamic>());
      }
      final outbox = prefs.getString(_outboxKey);
      if (outbox != null) {
        for (final op in jsonDecode(outbox) as List) {
          final o = _Op.fromJson((op as Map).cast<String, dynamic>());
          _outbox[o.key] = o;
        }
        // Pending entry upserts are newer than the cache.
        for (final op in _outbox.values) {
          if (op.kind == 'entry_upsert' && op.row != null) {
            final e = MealPlanEntry.fromRow(op.row!);
            _entries[e.id] = e;
          } else if (op.kind == 'entry_delete') {
            _entries.remove(op.key.substring(2));
          }
        }
      }
    } catch (e) {
      debugPrint('⚠️ [MEAL_PLAN] Device cache unreadable, starting empty: $e');
    }
    _loaded = true;
    _emit();
    unawaited(sync());
  }

  /// Sends queued changes, then loads this and next week and the settings.
  Future<void> sync() => _syncing ??= _sync().whenComplete(() => _syncing = null);

  Future<void> _sync() async {
    if (_remote == null) return;
    await flush();
    final week = _thisWeek;
    await ensureWeek(week);
    await ensureWeek(planAddDays(week, 7));
    try {
      final row = await _remote.fetchSettings();
      if (row != null && !_outbox.containsKey('s') && !_disposed) {
        _settings = MealPlanSettings.fromRow(row);
        await _persist();
        _emit();
      }
    } catch (e) {
      debugPrint('⚠️ [MEAL_PLAN] Settings not loaded (offline?): $e');
    }
  }

  /// Loads [weekStart]'s week from the server once per app run.
  Future<void> ensureWeek(DateTime weekStart) async {
    final start = planWeekStart(weekStart);
    if (_remote == null || !_fetchedWeeks.add(start)) return;
    try {
      await refreshWeek(start);
    } catch (e) {
      _fetchedWeeks.remove(start);
      debugPrint('⚠️ [MEAL_PLAN] Week ${planDateKey(start)} not loaded (offline?): $e');
    }
  }

  /// Takes the server state of one week; entries with unsent local changes
  /// stay as they are on the device.
  Future<void> refreshWeek(DateTime weekStart) async {
    final remote = _remote;
    if (remote == null) return;
    await load();
    final start = planWeekStart(weekStart);
    final end = planAddDays(start, 7);
    final asked = _seq;
    final rows = await remote.fetchEntries(start, end);
    final weekRows = await remote.fetchWeeks(start, end);
    if (_disposed) return;

    bool keepLocal(String id) => _outbox.containsKey('e:$id') || (_touched[id] ?? 0) > asked;
    _entries.removeWhere((id, e) => !e.planDate.isBefore(start) && e.planDate.isBefore(end) && !keepLocal(id));
    for (final row in rows) {
      final e = MealPlanEntry.fromRow(row);
      if (!keepLocal(e.id)) _entries[e.id] = e;
    }
    if (!_outbox.containsKey('w:${planDateKey(start)}')) {
      _weeks.remove(start);
      for (final row in weekRows) {
        final w = MealPlanWeek.fromRow(row);
        _weeks[w.weekStart] = w;
      }
    }
    _fetchedWeeks.add(start);
    await _persist();
    _emit();
  }

  // ---------------------------------------------------------------- changes

  /// Puts a recipe at the end of [day].
  Future<({MealPlanEntry entry, MealPlanUndo undo})> addEntry({
    required String? recipeId,
    required PlanRecipeSnapshot snapshot,
    required DateTime day,
    required int servings,
    MealType? mealType,
  }) async {
    await load();
    final now = _now();
    final entry = MealPlanEntry(
      id: _newId(),
      userId: userId,
      planDate: day,
      recipeId: recipeId,
      snapshot: snapshot,
      servings: servings,
      mealType: mealType,
      position: _nextPosition(day),
      createdAt: now,
      updatedAt: now,
    );
    final undo = await _apply([entry], const []);
    return (entry: entry, undo: undo);
  }

  Future<MealPlanUndo> setServings(String id, int servings) =>
      _change(id, (e) => e.copyWith(servings: servings));

  /// Moves an entry to the end of another day.
  Future<MealPlanUndo> moveEntry(String id, DateTime day) async {
    await load();
    final e = _entries[id];
    if (e == null || e.planDate == planDay(day)) return const MealPlanUndo();
    return _change(id, (e) => e.copyWith(planDate: day, position: _nextPosition(day)));
  }

  /// New order of one day's entries.
  Future<MealPlanUndo> reorderDay(List<String> orderedIds) async {
    await load();
    final changed = <MealPlanEntry>[
      for (var i = 0; i < orderedIds.length; i++)
        if (_entries[orderedIds[i]] case final e? when e.position != i) e.copyWith(position: i, updatedAt: _now()),
    ];
    return _apply(changed, const []);
  }

  Future<MealPlanUndo> setMealType(String id, MealType? mealType) => _change(
        id,
        (e) => MealPlanEntry(
          id: e.id,
          userId: e.userId,
          planDate: e.planDate,
          recipeId: e.recipeId,
          snapshot: e.snapshot,
          servings: e.servings,
          mealType: mealType,
          position: e.position,
          sentListId: e.sentListId,
          sentServings: e.sentServings,
          sentAt: e.sentAt,
          createdAt: e.createdAt,
          updatedAt: e.updatedAt,
        ),
      );

  /// Fresh recipe data for the snapshot (when the recipe was loaded).
  Future<MealPlanUndo> refreshSnapshot(String id, PlanRecipeSnapshot snapshot) async {
    await load();
    if (_entries[id]?.snapshot == snapshot) return const MealPlanUndo();
    return _change(id, (e) => e.copyWith(snapshot: snapshot));
  }

  Future<MealPlanUndo> removeEntries(Iterable<String> ids) async {
    await load();
    return _apply(const [], ids.where(_entries.containsKey).toList());
  }

  /// "Woche leeren" (W-08: no question, with undo).
  Future<MealPlanUndo> clearWeek(DateTime weekStart) async {
    await load();
    return removeEntries([for (final e in _snapshot.entriesForWeek(weekStart)) e.id]);
  }

  /// "Rezepte der Vorwoche übernehmen": same weekdays and servings, new ids,
  /// not sent.
  Future<MealPlanUndo> copyPreviousWeek(DateTime weekStart) async {
    await load();
    final start = planWeekStart(weekStart);
    final now = _now();
    final copies = [
      for (final e in _snapshot.entriesForWeek(planAddDays(start, -7)))
        MealPlanEntry(
          id: _newId(),
          userId: userId,
          planDate: planAddDays(e.planDate, 7),
          recipeId: e.recipeId,
          snapshot: e.snapshot,
          servings: e.servings,
          mealType: e.mealType,
          position: e.position,
          createdAt: now,
          updatedAt: now,
        ),
    ];
    return _apply(copies, const []);
  }

  /// Marks entries as on [listId] with these servings (W-05) and, when
  /// [noteFirstSend] (something was added), notes the first send of their
  /// week (E-15). Also used by the recipe detail ("Zutaten auf Liste" for a
  /// planned recipe, Konzept 13.3).
  Future<({MealPlanUndo undo, bool firstSend})> markEntriesSent({
    required Map<String, int> servingsById,
    required String listId,
    bool noteFirstSend = true,
  }) async {
    await load();
    final now = _now();
    final changed = [
      for (final e in servingsById.entries)
        if (_entries[e.key] case final entry?)
          entry.copyWith(sentListId: listId, sentServings: e.value, sentAt: now.toUtc(), updatedAt: now),
    ];
    final weeks = <MealPlanWeek>[];
    for (final start in {if (noteFirstSend) for (final e in changed) planWeekStart(e.planDate)}) {
      final week = _weeks[start];
      if (week?.firstSentAt == null) {
        weeks.add((week ?? MealPlanWeek(weekStart: start)).copyWith(firstSentAt: now.toUtc()));
      }
    }
    final undo = await _apply(changed, const [], weeks: weeks);
    return (undo: undo, firstSend: weeks.isNotEmpty);
  }

  /// Target list of one week; null = the default from the settings.
  Future<MealPlanUndo> setWeekTargetList(DateTime weekStart, String? listId) async {
    await load();
    final start = planWeekStart(weekStart);
    final old = _weeks[start];
    final week = MealPlanWeek(weekStart: start, targetListId: listId, firstSentAt: old?.firstSentAt);
    return _apply(const [], const [], weeks: [week]);
  }

  Future<void> updateSettings(MealPlanSettings settings) async {
    await load();
    _settings = settings;
    _queue(_Op('settings_upsert', 's', settings.toRow(userId)));
    await _persist();
    _emit();
    unawaited(flush());
  }

  /// Puts back what [undo] recorded.
  Future<void> undo(MealPlanUndo undo) async {
    await load();
    final restore = [for (final e in undo.entries.values) if (e != null) e];
    final remove = [for (final e in undo.entries.entries) if (e.value == null) e.key];
    final weeks = [
      for (final w in undo.weeks.entries) w.value ?? MealPlanWeek(weekStart: w.key),
    ];
    await _apply(restore, remove, weeks: weeks);
  }

  Future<MealPlanUndo> _change(String id, MealPlanEntry Function(MealPlanEntry e) update) async {
    await load();
    final e = _entries[id];
    if (e == null) return const MealPlanUndo();
    return _apply([update(e).copyWith(updatedAt: _now())], const []);
  }

  int _nextPosition(DateTime day) {
    final entries = _snapshot.entriesForDay(day);
    return entries.isEmpty ? 0 : entries.last.position + 1;
  }

  /// Applies upserts, deletes and week rows locally, queues them, saves and
  /// publishes; the server write follows in the background.
  Future<MealPlanUndo> _apply(
    List<MealPlanEntry> upserts,
    List<String> deletes, {
    List<MealPlanWeek> weeks = const [],
  }) async {
    final before = <String, MealPlanEntry?>{};
    final weeksBefore = <DateTime, MealPlanWeek?>{};
    for (final e in upserts) {
      before.putIfAbsent(e.id, () => _entries[e.id]);
      _entries[e.id] = e;
      _touched[e.id] = ++_seq;
      _queue(_Op('entry_upsert', 'e:${e.id}', e.toCacheJson()));
    }
    for (final id in deletes) {
      before.putIfAbsent(id, () => _entries[id]);
      _entries.remove(id);
      _touched[id] = ++_seq;
      _queue(_Op('entry_delete', 'e:$id', null));
    }
    for (final w in weeks) {
      weeksBefore.putIfAbsent(w.weekStart, () => _weeks[w.weekStart]);
      _weeks[w.weekStart] = w;
      _queue(_Op('week_upsert', 'w:${planDateKey(w.weekStart)}', w.toRow(userId)));
    }
    if (upserts.isEmpty && deletes.isEmpty && weeks.isEmpty) return const MealPlanUndo();
    await _persist();
    _emit();
    unawaited(flush());
    return MealPlanUndo(entries: before, weeks: weeksBefore);
  }

  /// Without a server (signed out) the plan stays on the device only.
  void _queue(_Op op) {
    if (_remote == null) return;
    _outbox.remove(op.key);
    _outbox[op.key] = op;
  }

  // ---------------------------------------------------------------- sync

  /// Sends the outbox in order; stops at the first failure (offline) and
  /// keeps the rest for the next try. Calls run one after another.
  Future<void> flush() => _flushChain = _flushChain.then((_) => _flushOnce()).catchError((Object e) {
        debugPrint('⚠️ [MEAL_PLAN] Sync paused: $e');
      });

  Future<void> _flushOnce() async {
    final remote = _remote;
    if (remote == null || _disposed) return;
    var sent = 0;
    while (_outbox.isNotEmpty && !_disposed) {
      final op = _outbox.values.first;
      try {
        await _send(remote, op);
      } on PostgrestException catch (e) {
        // The database refused the row itself (constraint, permission):
        // retrying cannot help and would block every later change.
        if (!_isRefusal(e)) rethrow;
        debugPrint('❌ [MEAL_PLAN] Server refused ${op.kind} ${op.key}, dropped: ${e.code} ${e.message}');
      }
      // A newer change of the same key may have been queued meanwhile.
      if (identical(_outbox[op.key], op)) _outbox.remove(op.key);
      sent++;
    }
    if (sent > 0) {
      await _persist();
      _emit();
      debugPrint('✅ [MEAL_PLAN] $sent changes synced');
    }
  }

  Future<void> _send(MealPlanRemote remote, _Op op) async {
    final row = op.row;
    switch (op.kind) {
      case 'entry_upsert':
        final entry = Map<String, dynamic>.of(row!)
          ..remove('created_at')
          ..remove('updated_at');
        await remote.upsertEntries([entry]);
      case 'entry_delete':
        await remote.deleteEntries([op.key.substring(2)]);
      case 'week_upsert':
        await remote.upsertWeek(row!);
      case 'settings_upsert':
        await remote.upsertSettings(row!);
    }
  }

  /// Postgres errors about the data (classes 22 and 23), privileges (42501)
  /// and raised exceptions (P0001); not the network, not the server load.
  static bool _isRefusal(PostgrestException e) {
    final code = e.code ?? '';
    return code.startsWith('22') || code.startsWith('23') || code == '42501' || code == 'P0001';
  }

  // ---------------------------------------------------------------- storage

  Future<void> _persist() async {
    if (_disposed) return;
    try {
      final prefs = await _prefs();
      final from = _thisWeek;
      final to = planAddDays(from, 14);
      bool cached(DateTime d) => !d.isBefore(from) && d.isBefore(to);
      await prefs.setString(_cacheKey, jsonEncode({
        'entries': [for (final e in _entries.values) if (cached(e.planDate)) e.toCacheJson()],
        'weeks': [for (final w in _weeks.values) if (cached(w.weekStart)) w.toRow(userId)],
        'settings': _settings.toRow(userId),
      }));
      if (_outbox.isEmpty) {
        await prefs.remove(_outboxKey);
      } else {
        await prefs.setString(_outboxKey, jsonEncode([for (final op in _outbox.values) op.toJson()]));
      }
    } catch (e) {
      debugPrint('❌ [MEAL_PLAN] Saving the plan on the device failed: $e');
    }
  }

  void _emit() {
    if (_disposed) return;
    _snapshot = MealPlanSnapshot(
      entries: Map.unmodifiable(_entries),
      weeks: Map.unmodifiable(_weeks),
      settings: _settings,
      loaded: _loaded,
      pendingChanges: _outbox.length,
    );
    _changes.add(_snapshot);
  }

  void dispose() {
    _disposed = true;
    _changes.close();
  }
}
