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

  /// Get all lists the current user is a member of (owner included), with
  /// their total and open item counts, in one round trip.
  ///
  /// The counts come from PostgREST count embeds: `items` (all rows) matches
  /// what [ShoppingListModel.fromJson] already parses, and `open` (unchecked
  /// rows only, filtered via `open.is_checked`) is mapped to
  /// `unchecked_count`.
  Future<List<ShoppingListModel>> getUserLists() async {
    final userId = _supabase.currentUser?.id;
    if (userId == null) throw Exception('User not authenticated');

    final rows = await _supabase
        .from('shopping_lists')
        .select(
          '*, me:list_members!inner(user_id), '
          'items:shopping_items(count), open:shopping_items(count)',
        )
        .eq('me.user_id', userId)
        .eq('open.is_checked', false)
        .order('created_at', ascending: true);

    final lists = [
      for (final row in (rows as List).cast<Map<String, dynamic>>())
        ShoppingListModel.fromJson({
          ...row,
          'item_count': _embeddedCount(row['items']),
          'unchecked_count': _embeddedCount(row['open']),
        }),
    ];

    // `shopping_lists.order_index` is not a DB column yet, so this only takes
    // effect once it exists; createdAt keeps the order total (and stable).
    lists.sort((a, b) {
      final byOrder =
          (a.orderIndex ?? 1 << 30).compareTo(b.orderIndex ?? 1 << 30);
      return byOrder != 0 ? byOrder : a.createdAt.compareTo(b.createdAt);
    });
    return lists;
  }

  static int _embeddedCount(Object? embed) {
    if (embed is List && embed.isNotEmpty) {
      return (embed.first as Map)['count'] as int? ?? 0;
    }
    return 0;
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
    final updates = <String, dynamic>{
      'background_type': backgroundType,
      'background_value': backgroundValue,
      // Only image backgrounds keep an image URL.
      'background_image_url': backgroundType == 'image' ? imageUrl : null,
    };

    // Keep old background_gradient for backwards compatibility
    if (backgroundType == 'gradient' && backgroundValue != null) {
      updates['background_gradient'] = backgroundValue;
    }

    await _supabase.from('shopping_lists').update(updates).eq('id', listId);
  }

  /// Generate and set share code for a list
  Future<String> generateShareCode(String listId) async {
    // Generate random 6-digit code
    final code = _generateRandomCode();

    // Generate share link
    final shareLink = AppConfig.generateShareLink(code);

    await _supabase.from('shopping_lists').update({
      'share_code': code,
      'share_link': shareLink,
      'is_shared': true,
    }).eq('id', listId);

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
          debugPrint('✅ [LIST_REPO] Push notification sent to owner $ownerId');
        }
      } catch (e) {
        debugPrint('⚠️ [LIST_REPO] Failed to send invitation notification: $e');
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
