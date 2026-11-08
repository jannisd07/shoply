import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:shoply/data/models/calorie_day.dart';
import 'package:shoply/data/models/diet_challenge.dart';
import 'package:shoply/data/services/app_flags_service.dart';

/// Thrown when starting a built-in challenge the user already has active —
/// the DB's partial unique index is the source of truth (safe under
/// concurrent calls), this is just a friendly wrapper.
class ChallengeAlreadyActiveException implements Exception {
  const ChallengeAlreadyActiveException();
}

/// CRUD + check-ins for `nutrition_challenges` (16:8 fasting, 30 days
/// without sugar, own challenges). Reads never write: fixed challenges past
/// their end are shown as completed ([DietChallenge.asDisplayed]) and closed
/// by the server's schedule (B6 migration). Throws [CalorieDataException].
class DietChallengeService {
  DietChallengeService._();
  static final DietChallengeService instance = DietChallengeService._();

  static const _table = 'nutrition_challenges';
  static const _checkins = 'challenge_checkins';

  SupabaseClient get _supabase => Supabase.instance.client;

  bool get _schemaV2 =>
      AppFlagsService.instance.current.isEnabled(calorieSchemaV2FlagKey, fallback: false);

  String get _select => _schemaV2 ? '*, challenge_checkins(date, kept)' : '*';

  String _userId() {
    final id = _supabase.auth.currentUser?.id;
    if (id == null) throw const CalorieDataException(CalorieErrorCode.notSignedIn);
    return id;
  }

  Future<T> _guard<T>(String what, Future<T> Function() run) async {
    try {
      return await run();
    } on ChallengeAlreadyActiveException {
      rethrow;
    } catch (e) {
      final error = CalorieDataException.from(e);
      debugPrint('❌ [DietChallenge] $what failed: ${error.code.name} ($e)');
      throw error;
    }
  }

  Future<List<DietChallenge>> _load({required bool active}) async {
    var query = _supabase.from(_table).select(_select).eq('user_id', _userId());
    final response = active
        ? await query.eq('status', 'active').order('started_at')
        : await query.order('created_at', ascending: false);
    return (response as List)
        .map((row) => DietChallenge.fromJson(row as Map<String, dynamic>).asDisplayed())
        .toList();
  }

  /// Running challenges (fixed ones past their end are left out).
  Future<List<DietChallenge>> getActiveChallenges() => _guard('Loading active', () async {
        final all = await _load(active: true);
        return all.where((c) => c.status == ChallengeStatus.active).toList();
      });

  /// Finished and abandoned challenges, newest first.
  Future<List<DietChallenge>> getHistory() => _guard('Loading history', () async {
        final all = await _load(active: false);
        return all.where((c) => c.status != ChallengeStatus.active).toList();
      });

  /// Starts a challenge. Built-in types throw
  /// [ChallengeAlreadyActiveException] when one is already running; own
  /// challenges ([ChallengeType.custom]) need [title] and may run in
  /// parallel once the B6 migration relaxed the index.
  Future<DietChallenge> startChallenge(
    ChallengeType type, {
    String? title,
    String? question,
    int? durationDays,
  }) =>
      _guard('Starting', () async {
        final startedAt = DateTime.now();
        final days = type.fixedDurationDays ?? (type == ChallengeType.custom ? durationDays : null);
        final challenge = DietChallenge(
          id: '',
          userId: _userId(),
          type: type,
          startedAt: startedAt,
          targetEndAt: days != null ? startedAt.add(Duration(days: days)) : null,
          createdAt: startedAt,
          title: title,
          question: question,
          durationDays: type == ChallengeType.custom ? durationDays : null,
        );
        try {
          final response = await _supabase
              .from(_table)
              .insert(challenge.toInsertJson(schemaV2: _schemaV2))
              .select(_select)
              .single();
          return DietChallenge.fromJson(response);
        } on PostgrestException catch (e) {
          if (e.code == '23505') throw const ChallengeAlreadyActiveException();
          rethrow;
        }
      });

  /// Marks [date] (default today) as kept or not. With the B6 schema this
  /// is one row per day (two devices never overwrite each other, Inv. 4.10);
  /// before, it merges into the freshest `daily_checkins`.
  Future<DietChallenge> checkIn(DietChallenge challenge, {required bool kept, DateTime? date}) async {
    final key = challengeDateKey(date ?? DateTime.now());
    await setCheckIn(challenge.id, key, kept);
    return challenge.copyWith(dailyCheckins: {...challenge.dailyCheckins, key: kept});
  }

  /// "Ändern": the day is open again.
  Future<DietChallenge> clearCheckIn(DietChallenge challenge, {DateTime? date}) async {
    final key = challengeDateKey(date ?? DateTime.now());
    await setCheckIn(challenge.id, key, null);
    return challenge.copyWith(dailyCheckins: Map.of(challenge.dailyCheckins)..remove(key));
  }

  /// Sets ([kept] true/false) or clears (null) the check-in of [dateKey];
  /// also what the write queue runs for `checkin` writes.
  Future<void> setCheckIn(String challengeId, String dateKey, bool? kept) =>
      _guard('Check-in', () async {
        _userId();
        if (_schemaV2) {
          if (kept == null) {
            await _supabase.from(_checkins).delete().eq('challenge_id', challengeId).eq('date', dateKey);
          } else {
            await _supabase.from(_checkins).upsert(
              {'challenge_id': challengeId, 'date': dateKey, 'kept': kept},
              onConflict: 'challenge_id,date',
            );
          }
          return;
        }
        final fresh = await _supabase
            .from(_table)
            .select('daily_checkins')
            .eq('id', challengeId)
            .single();
        final map = <String, bool>{
          for (final e in ((fresh['daily_checkins'] as Map?) ?? const {}).entries)
            if (e.value is bool) e.key as String: e.value as bool,
        };
        if (kept == null) {
          map.remove(dateKey);
        } else {
          map[dateKey] = kept;
        }
        await _supabase.from(_table).update({'daily_checkins': map}).eq('id', challengeId);
      });

  Future<DietChallenge> completeChallenge(DietChallenge challenge) =>
      _closeOut(challenge, ChallengeStatus.completed);

  Future<DietChallenge> abandonChallenge(DietChallenge challenge) =>
      _closeOut(challenge, ChallengeStatus.abandoned);

  Future<DietChallenge> _closeOut(DietChallenge challenge, ChallengeStatus status) =>
      _guard('Closing', () async {
        final response = await _supabase
            .from(_table)
            .update({
              'status': status.dbValue,
              'completed_at': DateTime.now().toIso8601String(),
            })
            .eq('id', challenge.id)
            .select(_select)
            .single();
        return DietChallenge.fromJson(response);
      });

  /// Undo of "Beenden": the challenge runs again.
  Future<DietChallenge> reopenChallenge(DietChallenge challenge) => _guard('Reopening', () async {
        final response = await _supabase
            .from(_table)
            .update({'status': ChallengeStatus.active.dbValue, 'completed_at': null})
            .eq('id', challenge.id)
            .select(_select)
            .single();
        return DietChallenge.fromJson(response);
      });
}
