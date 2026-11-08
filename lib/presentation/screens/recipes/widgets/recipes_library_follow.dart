import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:shoply/data/services/supabase_service.dart';
import 'package:shoply/presentation/state/auth_provider.dart';

/// "Folgen" for recipe creators (Konzept 13 §7, §8, §19.6, E-08).
///
/// The state lives on the device first, per account, so the button changes
/// at once and survives offline; every change is queued and sent to the
/// server table `creator_follows` (migration `new_recipe_features.sql`) when
/// it can be reached. Server rows that are not known here are taken over on
/// the next load. If the table is missing on the server, following simply
/// stays on this device.

/// One creator the person follows.
@immutable
class FollowedCreator {
  const FollowedCreator({
    required this.id,
    required this.name,
    this.avatarUrl,
    required this.followedAt,
    this.lastSeen,
  });

  final String id;

  /// Display name when the follow was made ('' when only the server knew).
  final String name;
  final String? avatarUrl;
  final DateTime followedAt;

  /// When the person last opened this creator's page; recipes newer than
  /// this count as "neu" in the creator list.
  final DateTime? lastSeen;

  FollowedCreator copyWith({
    String? name,
    String? avatarUrl,
    DateTime? lastSeen,
  }) => FollowedCreator(
    id: id,
    name: name ?? this.name,
    avatarUrl: avatarUrl ?? this.avatarUrl,
    followedAt: followedAt,
    lastSeen: lastSeen ?? this.lastSeen,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'avatarUrl': avatarUrl,
    'followedAt': followedAt.toIso8601String(),
    'lastSeen': lastSeen?.toIso8601String(),
  };

  static FollowedCreator? fromJson(Object? json) {
    if (json is! Map) return null;
    final id = json['id'];
    final at = DateTime.tryParse('${json['followedAt']}');
    if (id is! String || id.isEmpty || at == null) return null;
    final seen = json['lastSeen'];
    return FollowedCreator(
      id: id,
      name: json['name'] is String ? json['name'] as String : '',
      avatarUrl: json['avatarUrl'] as String?,
      followedAt: at,
      lastSeen: seen is String ? DateTime.tryParse(seen) : null,
    );
  }
}

/// Who the person follows, newest follow first.
@immutable
class CreatorFollowsState {
  const CreatorFollowsState({this.followed = const {}, this.loaded = false});

  /// By creator id.
  final Map<String, FollowedCreator> followed;

  /// The local state has been read.
  final bool loaded;

  bool isFollowing(String creatorId) => followed.containsKey(creatorId);

  /// Newest follow first.
  List<FollowedCreator> get ordered =>
      followed.values.toList()
        ..sort((a, b) => b.followedAt.compareTo(a.followedAt));
}

/// The server side of following. Every call may throw.
abstract class CreatorFollowBackend {
  /// Creator ids [userId] follows on the server.
  Future<Set<String>> fetch(String userId);

  Future<void> follow(String userId, String creatorId);

  Future<void> unfollow(String userId, String creatorId);
}

/// [CreatorFollowBackend] on the Supabase table `creator_follows`.
class SupabaseCreatorFollowBackend implements CreatorFollowBackend {
  const SupabaseCreatorFollowBackend();

  static const _table = 'creator_follows';

  @override
  Future<Set<String>> fetch(String userId) async {
    final rows = await SupabaseService.instance.client
        .from(_table)
        .select('creator_id')
        .eq('follower_id', userId);
    return {
      for (final row in rows)
        if (row['creator_id'] is String) row['creator_id'] as String,
    };
  }

  @override
  Future<void> follow(String userId, String creatorId) async {
    await SupabaseService.instance.client.from(_table).upsert({
      'follower_id': userId,
      'creator_id': creatorId,
    }, onConflict: 'follower_id,creator_id');
  }

  @override
  Future<void> unfollow(String userId, String creatorId) async {
    await SupabaseService.instance.client
        .from(_table)
        .delete()
        .eq('follower_id', userId)
        .eq('creator_id', creatorId);
  }
}

/// Holds the follows of one account and keeps them in step with the
/// server.
class CreatorFollowsNotifier extends StateNotifier<CreatorFollowsState> {
  CreatorFollowsNotifier({
    required this.userId,
    required CreatorFollowBackend backend,
    Future<SharedPreferences> Function()? preferences,
  }) : _backend = backend,
       _preferences = preferences ?? SharedPreferences.getInstance,
       super(const CreatorFollowsState());

  /// Signed-in account; null keeps everything in memory only.
  final String? userId;
  final CreatorFollowBackend _backend;
  final Future<SharedPreferences> Function() _preferences;

  /// Changes not confirmed by the server yet: creator id -> follow (true)
  /// or unfollow (false).
  Map<String, bool> _pending = {};

  /// The sync that is running, and whether another pass was asked for while
  /// it ran (a change made during a sync must not wait for the next open).
  Future<void>? _running;
  bool _again = false;

  String get _key => 'recipe_lib_follows_$userId';
  String get _pendingKey => 'recipe_lib_follows_pending_$userId';

  /// Reads the local state, then syncs with the server in the background.
  Future<void> load() async {
    if (userId == null) {
      state = const CreatorFollowsState(loaded: true);
      return;
    }
    try {
      final prefs = await _preferences();
      final followed = <String, FollowedCreator>{};
      final raw = prefs.getString(_key);
      if (raw != null) {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          for (final entry in decoded) {
            final creator = FollowedCreator.fromJson(entry);
            if (creator != null) followed[creator.id] = creator;
          }
        }
      }
      final rawPending = prefs.getString(_pendingKey);
      if (rawPending != null) {
        final decoded = jsonDecode(rawPending);
        if (decoded is Map) {
          // Changes made while the file was read win over stored ones.
          _pending = {
            for (final e in decoded.entries)
              if (e.key is String && e.value is bool)
                e.key as String: e.value as bool,
            ..._pending,
          };
        }
      }
      if (!mounted) return;
      // A tap on "Folgen" before the file was read is kept.
      for (final e in _pending.entries) {
        if (!e.value) followed.remove(e.key);
      }
      state = CreatorFollowsState(
        followed: {...followed, ...state.followed},
        loaded: true,
      );
    } catch (e) {
      debugPrint('⚠️ [CREATOR_FOLLOWS] Local state unreadable: $e');
      if (mounted) {
        state = CreatorFollowsState(followed: state.followed, loaded: true);
      }
    }
    unawaited(sync());
  }

  /// Sends queued changes, then takes over what the server knows. A call
  /// while a sync runs joins it and makes it run once more.
  Future<void> sync() {
    if (userId == null || !mounted) return Future.value();
    final running = _running;
    if (running != null) {
      _again = true;
      return running;
    }
    final next = _syncPasses().whenComplete(() => _running = null);
    _running = next;
    return next;
  }

  Future<void> _syncPasses() async {
    do {
      _again = false;
      await _syncOnce();
    } while (_again && mounted);
  }

  Future<void> _syncOnce() async {
    final user = userId;
    if (user == null || !mounted) return;
    try {
      await _flush(user);
      final remote = await _backend.fetch(user);
      if (!mounted) return;
      final next = Map<String, FollowedCreator>.from(state.followed);
      final now = DateTime.now();
      for (final id in remote) {
        if (_pending[id] == false) continue;
        next.putIfAbsent(
          id,
          () =>
              FollowedCreator(id: id, name: '', followedAt: now, lastSeen: now),
        );
      }
      next.removeWhere((id, _) => !remote.contains(id) && _pending[id] != true);
      state = CreatorFollowsState(followed: next, loaded: true);
      await _persist();
    } catch (e) {
      debugPrint('⚠️ [CREATOR_FOLLOWS] Sync later: $e');
    }
  }

  Future<void> _flush(String user) async {
    for (final entry in Map<String, bool>.from(_pending).entries) {
      if (entry.value) {
        await _backend.follow(user, entry.key);
      } else {
        await _backend.unfollow(user, entry.key);
      }
      // A newer change for the same creator stays queued.
      if (_pending[entry.key] == entry.value) _pending.remove(entry.key);
    }
  }

  /// Follows [creatorId] at once; the server learns it when reachable.
  Future<void> follow(
    String creatorId, {
    required String name,
    String? avatarUrl,
  }) async {
    if (creatorId.isEmpty || creatorId == userId) return;
    final now = DateTime.now();
    state = CreatorFollowsState(
      followed: {
        ...state.followed,
        creatorId: FollowedCreator(
          id: creatorId,
          name: name,
          avatarUrl: avatarUrl,
          followedAt: now,
          lastSeen: now,
        ),
      },
      loaded: true,
    );
    _pending[creatorId] = true;
    await _changed();
  }

  /// Stops following [creatorId] at once.
  Future<void> unfollow(String creatorId) async {
    if (!state.followed.containsKey(creatorId)) return;
    state = CreatorFollowsState(
      followed: {...state.followed}..remove(creatorId),
      loaded: true,
    );
    _pending[creatorId] = false;
    await _changed();
  }

  /// Brings back a follow that was just undone (keeps its date).
  Future<void> restore(FollowedCreator creator) async {
    state = CreatorFollowsState(
      followed: {...state.followed, creator.id: creator},
      loaded: true,
    );
    _pending[creator.id] = true;
    await _changed();
  }

  /// The person opened the creator's page: their recipes so far are seen.
  /// Also fills in a name the server did not know.
  Future<void> markSeen(
    String creatorId, {
    String? name,
    String? avatarUrl,
  }) async {
    final current = state.followed[creatorId];
    if (current == null) return;
    state = CreatorFollowsState(
      followed: {
        ...state.followed,
        creatorId: current.copyWith(
          lastSeen: DateTime.now(),
          name: (name?.trim().isNotEmpty ?? false) ? name : null,
          avatarUrl: avatarUrl,
        ),
      },
      loaded: true,
    );
    await _persist();
  }

  Future<void> _changed() async {
    await _persist();
    unawaited(sync());
  }

  Future<void> _persist() async {
    if (userId == null) return;
    try {
      final prefs = await _preferences();
      await prefs.setString(
        _key,
        jsonEncode([for (final c in state.followed.values) c.toJson()]),
      );
      await prefs.setString(_pendingKey, jsonEncode(_pending));
    } catch (e) {
      debugPrint('⚠️ [CREATOR_FOLLOWS] Could not store follows: $e');
    }
  }
}

/// The server side; tests replace it.
final creatorFollowBackendProvider = Provider<CreatorFollowBackend>(
  (ref) => const SupabaseCreatorFollowBackend(),
);

/// Who the signed-in person follows. Rebuilt per account.
final creatorFollowsProvider =
    StateNotifierProvider<CreatorFollowsNotifier, CreatorFollowsState>((ref) {
      final notifier = CreatorFollowsNotifier(
        userId: ref.watch(authUserIdProvider),
        backend: ref.watch(creatorFollowBackendProvider),
      );
      unawaited(notifier.load());
      return notifier;
    });
