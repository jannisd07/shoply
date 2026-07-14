import 'package:flutter/foundation.dart';
import 'package:shoply/data/models/diet_challenge.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Thrown when starting a challenge the user already has active — the DB's
/// `nutrition_challenges_one_active_per_type` unique index is the source of
/// truth (safe under concurrent calls), this is just a friendly wrapper.
class ChallengeAlreadyActiveException implements Exception {
  const ChallengeAlreadyActiveException();
}

/// CRUD + adherence tracking for `nutrition_challenges` (16:8 fasting,
/// 30-day no sugar, ...). One active row per challenge type per user is
/// enforced server-side by a partial unique index.
class DietChallengeService {
  DietChallengeService._();
  static final DietChallengeService instance = DietChallengeService._();

  final _supabase = Supabase.instance.client;

  String? get _userId => _supabase.auth.currentUser?.id;

  Future<List<DietChallenge>> getActiveChallenges() async {
    final userId = _userId;
    if (userId == null) return [];
    try {
      final response = await _supabase
          .from('nutrition_challenges')
          .select()
          .eq('user_id', userId)
          .eq('status', 'active')
          .order('started_at');
      final challenges = (response as List)
          .map((row) => DietChallenge.fromJson(row as Map<String, dynamic>))
          .toList();
      // Fixed-length challenges (30-day no sugar) auto-close once their
      // target date has passed, so the user sees a final result instead of
      // an indefinitely-lingering "active" challenge.
      final results = <DietChallenge>[];
      for (final challenge in challenges) {
        if (challenge.isPastTargetEnd) {
          results.add(await _closeOut(challenge, ChallengeStatus.completed));
        } else {
          results.add(challenge);
        }
      }
      return results;
    } catch (e) {
      debugPrint('⚠️ [DietChallenge] Failed to load active challenges: $e');
      return [];
    }
  }

  Future<List<DietChallenge>> getHistory() async {
    final userId = _userId;
    if (userId == null) return [];
    try {
      final response = await _supabase
          .from('nutrition_challenges')
          .select()
          .eq('user_id', userId)
          .neq('status', 'active')
          .order('created_at', ascending: false);
      return (response as List)
          .map((row) => DietChallenge.fromJson(row as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('⚠️ [DietChallenge] Failed to load history: $e');
      return [];
    }
  }

  /// Starts a new challenge of [type]. Throws
  /// [ChallengeAlreadyActiveException] if the user already has one of this
  /// type active (server-enforced, not a client-side race-prone check).
  Future<DietChallenge> startChallenge(ChallengeType type) async {
    final userId = _userId;
    if (userId == null) throw Exception('User not authenticated');
    final startedAt = DateTime.now();
    final durationDays = type.fixedDurationDays;
    final challenge = DietChallenge(
      id: '',
      userId: userId,
      type: type,
      startedAt: startedAt,
      targetEndAt: durationDays != null ? startedAt.add(Duration(days: durationDays)) : null,
      createdAt: startedAt,
    );
    try {
      final response =
          await _supabase.from('nutrition_challenges').insert(challenge.toInsertJson()).select().single();
      return DietChallenge.fromJson(response);
    } on PostgrestException catch (e) {
      if (e.code == '23505') throw const ChallengeAlreadyActiveException();
      rethrow;
    }
  }

  /// Marks [date] (default today) as kept or not on [challenge] — a full
  /// read-merge-write of `daily_checkins` since the client can't do a
  /// partial jsonb patch without an RPC.
  Future<DietChallenge> checkIn(DietChallenge challenge, {required bool kept, DateTime? date}) async {
    final key = challengeDateKey(date ?? DateTime.now());
    final updatedCheckins = {...challenge.dailyCheckins, key: kept};
    final response = await _supabase
        .from('nutrition_challenges')
        .update({'daily_checkins': updatedCheckins})
        .eq('id', challenge.id)
        .select()
        .single();
    return DietChallenge.fromJson(response);
  }

  Future<DietChallenge> completeChallenge(DietChallenge challenge) =>
      _closeOut(challenge, ChallengeStatus.completed);

  Future<DietChallenge> abandonChallenge(DietChallenge challenge) =>
      _closeOut(challenge, ChallengeStatus.abandoned);

  Future<DietChallenge> _closeOut(DietChallenge challenge, ChallengeStatus status) async {
    final response = await _supabase
        .from('nutrition_challenges')
        .update({
          'status': status.dbValue,
          'completed_at': DateTime.now().toIso8601String(),
        })
        .eq('id', challenge.id)
        .select()
        .single();
    return DietChallenge.fromJson(response);
  }
}
