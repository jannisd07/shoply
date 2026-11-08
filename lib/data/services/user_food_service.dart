import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:shoply/data/models/calorie_day.dart';
import 'package:shoply/data/models/user_food.dart';
import 'package:shoply/data/services/app_flags_service.dart';

/// Own foods in `user_food` (B6 migration): manual entries with grams and
/// barcodes Open Food Facts did not know. Throws [CalorieDataException];
/// before the migration every call is `rejected`.
class UserFoodService {
  UserFoodService._();
  static final UserFoodService instance = UserFoodService._();

  static const _table = 'user_food';

  SupabaseClient get _supabase => Supabase.instance.client;

  bool get _available =>
      AppFlagsService.instance.current.isEnabled(calorieSchemaV2FlagKey, fallback: false);

  String _userId() {
    final id = _supabase.auth.currentUser?.id;
    if (id == null) throw const CalorieDataException(CalorieErrorCode.notSignedIn);
    return id;
  }

  Future<T> _guard<T>(String what, Future<T> Function() run) async {
    if (!_available) {
      debugPrint('⚠️ [UserFood] $what skipped: user_food not migrated yet');
      throw const CalorieDataException(CalorieErrorCode.rejected);
    }
    try {
      return await run();
    } catch (e) {
      final error = CalorieDataException.from(e);
      debugPrint('❌ [UserFood] $what failed: ${error.code.name} (${e is PostgrestException ? e.code : e.runtimeType})');
      throw error;
    }
  }

  static List<UserFood> _rows(Object response) => (response as List)
      .map((row) => UserFood.fromJson(row as Map<String, dynamic>))
      .toList();

  /// All own foods, newest first (a few hundred rows at most; the search
  /// screen filters them locally, letter by letter).
  Future<List<UserFood>> getAll({int limit = 500}) => _guard('Loading', () async {
        final response = await _supabase
            .from(_table)
            .select()
            .eq('user_id', _userId())
            .order('created_at', ascending: false)
            .limit(limit);
        return _rows(response);
      });

  /// The own food with this barcode, or null (not on error).
  Future<UserFood?> findByBarcode(String barcode) => _guard('Barcode lookup', () async {
        final response = await _supabase
            .from(_table)
            .select()
            .eq('user_id', _userId())
            .eq('barcode', barcode)
            .maybeSingle();
        return response == null ? null : UserFood.fromJson(response);
      });

  Future<UserFood> upsert(UserFood food) => _guard('Saving', () async {
        final row = {...food.toUpsertJson(), if (food.userId.isEmpty) 'user_id': _userId()};
        final response = await _supabase.from(_table).upsert(row, onConflict: 'id').select().single();
        return UserFood.fromJson(response);
      });

  Future<void> delete(String id) => _guard('Deleting', () async {
        await _supabase.from(_table).delete().eq('user_id', _userId()).eq('id', id);
      });
}
