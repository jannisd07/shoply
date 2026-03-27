import 'package:shoply/data/services/supabase_service.dart';

/// Repository for admin/maintenance operations
class AdminRepository {
  final SupabaseService _supabase;

  AdminRepository({SupabaseService? supabase})
      : _supabase = supabase ?? SupabaseService.instance;

  /// Fix all shopping lists to be owned by the current user
  /// This is a maintenance function to fix incorrect owner_ids
  Future<void> fixAllListOwnership() async {
    final userId = _supabase.currentUser?.id;
    if (userId == null) throw Exception('User not authenticated');


    // Get all lists in the database
    final allLists = await _supabase.from('shopping_lists').select('id, name, owner_id');


    // Update all lists to be owned by current user
    for (var list in allLists) {
      final listId = list['id'];
      final currentOwnerId = list['owner_id'];
      
      if (currentOwnerId != userId) {
        
        await _supabase.from('shopping_lists').update({
          'owner_id': userId,
        }).eq('id', listId);
      }
    }

    // Clean up list_members - remove other users
    await _supabase.from('list_members').delete().neq('user_id', userId);

    // Ensure current user is a member of all lists
    for (var list in allLists) {
      final listId = list['id'];
      
      try {
        await _supabase.from('list_members').insert({
          'list_id': listId,
          'user_id': userId,
          'role': 'owner',
        });
      } catch (e) {
        // Ignore conflicts - user might already be a member
      }
    }

  }

  /// Delete all shopping lists (nuclear option)
  Future<void> deleteAllLists() async {
    final userId = _supabase.currentUser?.id;
    if (userId == null) throw Exception('User not authenticated');

    
    // This will cascade delete items and memberships
    await _supabase.from('shopping_lists').delete().neq('id', '00000000-0000-0000-0000-000000000000');
    
  }
}
