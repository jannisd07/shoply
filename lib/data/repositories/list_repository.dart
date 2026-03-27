import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shoply/core/constants/app_config.dart';
import 'package:shoply/data/models/shopping_list_model.dart';
import 'package:shoply/data/services/push_notification_service.dart';
import 'package:shoply/data/services/supabase_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ListRepository {
  static final ListRepository instance = ListRepository();
  final SupabaseService _supabase;
  RealtimeChannel? _itemsChannel;

  ListRepository({SupabaseService? supabase})
      : _supabase = supabase ?? SupabaseService.instance;

  /// Get all lists for the current user
  Future<List<ShoppingListModel>> getUserLists() async {
    final userId = _supabase.currentUser?.id;
    if (userId == null) throw Exception('User not authenticated');

    // Get all list IDs where user is a member (including as owner)
    final memberResponse = await _supabase
        .from('list_members')
        .select('list_id')
        .eq('user_id', userId);
    
    final memberListIds = (memberResponse as List)
        .map((m) => m['list_id'] as String)
        .toList();

    if (memberListIds.isEmpty) {
      return [];
    }

    // Get all lists where user is a member
    final listsData = await _supabase.from('shopping_lists').select('''
      *
    ''').inFilter('id', memberListIds);

    final lists = <ShoppingListModel>[];
    
    // For each list, fetch the REAL current item count from the database
    for (final listJson in (listsData as List)) {
      // Get actual count of ALL items for this list (both checked and unchecked)
      final items = await _supabase
          .from('shopping_items')
          .select('id')
          .eq('list_id', listJson['id']);
      
      final actualCount = (items as List).length;
      
      // Add the count to the JSON before creating the model
      listJson['item_count'] = actualCount;
      
      lists.add(ShoppingListModel.fromJson(listJson));
    }
    
    // Sort by order_index (nulls last)
    lists.sort((a, b) {
      final aOrder = a.orderIndex ?? 999999;
      final bOrder = b.orderIndex ?? 999999;
      return aOrder.compareTo(bOrder);
    });
    
    return lists;
  }

  /// Get a single list by ID
  Future<ShoppingListModel?> getListById(String listId) async {
    final response = await _supabase
        .from('shopping_lists')
        .select()
        .eq('id', listId)
        .maybeSingle();

    if (response == null) return null;
    return ShoppingListModel.fromJson(response);
  }

  /// Create a new shopping list
  Future<ShoppingListModel> createList(String name) async {
    final userId = _supabase.currentUser?.id;
    if (userId == null) throw Exception('User not authenticated');

    final response = await _supabase.from('shopping_lists').insert({
      'name': name,
      'owner_id': userId,
    }).select().single();

    // Also add user as owner in list_members
    await _supabase.from('list_members').insert({
      'list_id': response['id'],
      'user_id': userId,
      'role': 'owner',
    });

    return ShoppingListModel.fromJson(response);
  }

  /// Update a list
  Future<ShoppingListModel> updateList(
    String listId,
    Map<String, dynamic> updates,
  ) async {
    final response = await _supabase
        .from('shopping_lists')
        .update(updates)
        .eq('id', listId)
        .select()
        .single();

    return ShoppingListModel.fromJson(response);
  }

  /// Delete a list
  Future<void> deleteList(String listId) async {
    await _supabase.from('shopping_lists').delete().eq('id', listId);
  }

  /// Save background for a list (Prompt 5 - unified method)
  /// Supports: color (hex), gradient (ID), image (URL)
  Future<void> saveBackground(
    String listId,
    String backgroundType,
    String? backgroundValue,
    String? imageUrl,
  ) async {
    try {
      final updates = <String, dynamic>{
        'background_type': backgroundType,
        'background_value': backgroundValue,
      };

      // Only set image URL if type is image
      if (backgroundType == 'image') {
        updates['background_image_url'] = imageUrl;
      } else {
        updates['background_image_url'] = null;
      }

      // Keep old background_gradient for backwards compatibility
      if (backgroundType == 'gradient' && backgroundValue != null) {
        updates['background_gradient'] = backgroundValue;
      }

      await _supabase.from('shopping_lists').update(updates).eq('id', listId);
    } catch (e) {
      rethrow;
    }
  }

  /// Generate and set share code for a list
  Future<String> generateShareCode(String listId) async {
    // Generate random 6-digit code
    final code = _generateRandomCode();

    // Generate share link
    final shareLink = AppConfig.generateShareLink(code);

    try {
      await _supabase.from('shopping_lists').update({
        'share_code': code,
        'share_link': shareLink,
        'is_shared': true,
      }).eq('id', listId);
    } catch (e) {
      rethrow;
    }

    return code;
  }

  /// Get share link for a list
  Future<String?> getShareLink(String listId) async {
    final list = await getListById(listId);
    return list?.shareLink;
  }

  /// Join a list using share code
  Future<ShoppingListModel?> joinListWithCode(String shareCode) async {
    final userId = _supabase.currentUser?.id;
    if (userId == null) throw Exception('User not authenticated');

    // Find list with share code
    final listResponse = await _supabase
        .from('shopping_lists')
        .select()
        .eq('share_code', shareCode)
        .maybeSingle();

    if (listResponse == null) {
      return null;
    }

    // Check if user is already a member
    final existingMember = await _supabase
        .from('list_members')
        .select()
        .eq('list_id', listResponse['id'])
        .eq('user_id', userId)
        .maybeSingle();

    if (existingMember != null) {
      // User already a member, just return the list
      return ShoppingListModel.fromJson(listResponse);
    }

    // Add user as member
    await _supabase.from('list_members').insert({
      'list_id': listResponse['id'],
      'user_id': userId,
      'role': 'member',
    });

    // 🔔 Send notification to list owner about new member
    if (Platform.isIOS || Platform.isAndroid) {
      try {
        final listName = listResponse['name'] as String;
        final ownerId = listResponse['owner_id'] as String;
        
        // Get new member's name
        final memberResponse = await _supabase
            .from('users')
            .select('display_name')
            .eq('id', userId)
            .single();
        
        final memberName = memberResponse['display_name'] as String? ?? 'Someone';
        
        // Send PUSH notification to owner (not to self!)
        if (ownerId != userId) {
          await PushNotificationService.instance.sendToUsers(
            userIds: [ownerId],
            title: 'New List Member!',
            body: '$memberName joined "$listName"',
            data: {
              'type': 'list_member_joined',
              'list_id': listResponse['id'],
            },
          );
          print('✅ [LIST_REPO] Push notification sent to owner $ownerId');
        }
      } catch (e) {
        if (kDebugMode) {
          print('⚠️ [LIST_REPO] Failed to send invitation notification: $e');
        }
      }
    }

    return ShoppingListModel.fromJson(listResponse);
  }

  /// Join a list using share link
  Future<ShoppingListModel?> joinListWithLink(String shareLink) async {
    // Extract share code from link
    final shareCode = AppConfig.extractShareCodeFromLink(shareLink);
    if (shareCode == null) {
      throw Exception('Invalid share link');
    }

    // Use existing joinListWithCode method
    return joinListWithCode(shareCode);
  }

  /// Get list members
  Future<List<Map<String, dynamic>>> getListMembers(String listId) async {
    final response = await _supabase
        .from('list_members')
        .select('*, user:users(*)')
        .eq('list_id', listId);

    return (response as List).cast<Map<String, dynamic>>();
  }

  /// Leave a list
  Future<void> leaveList(String listId) async {
    final userId = _supabase.currentUser?.id;
    if (userId == null) throw Exception('User not authenticated');

    await _supabase
        .from('list_members')
        .delete()
        .eq('list_id', listId)
        .eq('user_id', userId);
  }

  String _generateRandomCode() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = Random.secure();
    var code = '';
    for (var i = 0; i < 6; i++) {
      code += chars[random.nextInt(chars.length)];
    }
    return code;
  }

  /// Subscribe to shopping items AND lists changes for realtime updates
  void subscribeToItemChanges(Function() onUpdate) {
    _itemsChannel = _supabase.client
        .channel('db_changes')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'shopping_items',
          callback: (payload) {
            onUpdate();
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'shopping_lists',
          callback: (payload) {
            onUpdate();
          },
        )
        .subscribe();
  }

  /// Unsubscribe from shopping items changes
  void unsubscribeFromItemChanges() {
    _itemsChannel?.unsubscribe();
    _itemsChannel = null;
  }
}
