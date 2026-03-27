import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:shoply/data/models/shopping_item_model.dart';
import 'package:shoply/data/services/supabase_service.dart';
import 'package:shoply/data/services/gemini_categorization_service.dart';
import 'package:shoply/data/services/language_detection_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ItemRepository {
  static final ItemRepository instance = ItemRepository();
  final SupabaseService _supabase;
  final GeminiCategorizationService _geminiService = GeminiCategorizationService();
  final Map<String, RealtimeChannel> _channels = {};

  ItemRepository({SupabaseService? supabase})
      : _supabase = supabase ?? SupabaseService.instance;

  /// Get current user ID
  String? get currentUserId => _supabase.currentUser?.id;

  /// Get the name of a shopping list
  Future<String?> getListName(String listId) async {
    try {
      final response = await _supabase
          .from('shopping_lists')
          .select('name')
          .eq('id', listId)
          .single();
      return response['name'] as String?;
    } catch (e) {
      debugPrint('⚠️ [ItemRepo] Failed to get list name: $e');
      return null;
    }
  }

  /// Get all items for a list
  Future<List<ShoppingItemModel>> getListItems(String listId) async {
    final response = await _supabase
        .from('shopping_items')
        .select()
        .eq('list_id', listId)
        .order('created_at', ascending: true);

    final items = (response as List)
        .map((json) => ShoppingItemModel.fromJson(json))
        .toList();
    
    // Sort by order_index if available, otherwise keep created_at order
    items.sort((a, b) {
      final aOrder = a.orderIndex ?? 999999;
      final bOrder = b.orderIndex ?? 999999;
      return aOrder.compareTo(bOrder);
    });
    
    return items;
  }

  /// Add a new item to a list
  /// Automatically merges with existing items if same name exists
  /// Automatically categorizes with Gemini AI if category is null
  /// Automatically parses amount and unit from text if not provided (e.g., "2 cups flour")
  Future<ShoppingItemModel> addItem({
    required String listId,
    required String name,
    double quantity = 1.0,
    String? unit,
    String? category,
    String? notes,
    bool isDietWarning = false,
    String? barcode,
  }) async {
    print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    print('🔵 [ITEM_REPO] addItem() METHOD ENTRY');
    print('🔵 [ITEM_REPO] - name: "$name"');
    print('🔵 [ITEM_REPO] - listId: $listId');
    print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    
    final userId = _supabase.currentUser?.id;
    if (userId == null) {
      print('❌ [ITEM_REPO] User not authenticated!');
      throw Exception('User not authenticated');
    }

    // 🧠 AUTO-PARSE: If quantity is default (1.0) and no unit provided,
    // try to parse the input text for amount and unit (e.g., "2 cups flour")
    String parsedName = name;
    double parsedQuantity = quantity;
    String? parsedUnit = unit;
    
    if (quantity == 1.0 && unit == null && name.trim().isNotEmpty) {
      try {
        if (kDebugMode) {
          print('🧠 [ITEM_REPO] Auto-parsing ingredient: "$name"');
        }
        final parsed = await _geminiService.parseIngredient(name);
        parsedName = parsed['name'] as String? ?? name;
        parsedQuantity = (parsed['amount'] as num?)?.toDouble() ?? 1.0;
        parsedUnit = parsed['unit'] as String?;
        
        // Convert "pcs" to null for cleaner display
        if (parsedUnit == 'pcs' || parsedUnit == 'pc') {
          parsedUnit = null;
        }
        
        if (kDebugMode) {
          print('✅ [ITEM_REPO] Parsed: "$name" → name="$parsedName", qty=$parsedQuantity, unit=$parsedUnit');
        }
      } catch (e) {
        if (kDebugMode) {
          print('⚠️ [ITEM_REPO] Auto-parse failed, using original: $e');
        }
      }
    }

    // 🔍 MERGE LOGIC: Check if item with same name already exists (unchecked only)
    try {
      final existingItems = await _supabase
          .from('shopping_items')
          .select()
          .eq('list_id', listId)
          .eq('is_checked', false)
          .ilike('name', parsedName.trim());
      
      if ((existingItems as List).isNotEmpty) {
        // Item exists - update quantity instead of creating new
        final existingItem = ShoppingItemModel.fromJson(existingItems.first);
        final newQuantity = existingItem.quantity + parsedQuantity;
        
        print('🔄 [ITEM_REPO] Found existing item "${existingItem.name}" - merging quantities: ${existingItem.quantity} + $quantity = $newQuantity');
        
        final updatedResponse = await _supabase
            .from('shopping_items')
            .update({'quantity': newQuantity, 'updated_at': DateTime.now().toIso8601String()})
            .eq('id', existingItem.id)
            .select()
            .single();
        
        await _touchList(listId);
        print('✅ [ITEM_REPO] Merged item quantity to $newQuantity');
        return ShoppingItemModel.fromJson(updatedResponse);
      }
    } catch (e) {
      print('⚠️ [ITEM_REPO] Error checking for existing item: $e - will create new item');
    }

    // Auto-categorize with Gemini if category is null
    String? finalCategory = category;
    if (finalCategory == null) {
      try {
        if (kDebugMode) {
          print('🔵 [ITEM_REPO] Starting Gemini categorization for "$parsedName"...');
        }
        final startTime = DateTime.now();
        
        // Returns category ID (language-agnostic)
        finalCategory = await _geminiService.categorizeItem(parsedName);
        
        final duration = DateTime.now().difference(startTime);
        if (kDebugMode) {
          print('✅ [ITEM_REPO] Auto-categorized "$name" → $finalCategory (took ${duration.inMilliseconds}ms)');
        }
      } catch (e, stackTrace) {
        if (kDebugMode) {
          print('⚠️ [ITEM_REPO] Auto-categorization failed for "$name": $e');
          print('⚠️ [ITEM_REPO] StackTrace: $stackTrace');
        }
        finalCategory = 'other'; // Fallback to 'other' category ID
      }
    }

    // Detect language from item name
    final detectedLanguage = LanguageDetectionService.detectLanguage(parsedName);
    if (kDebugMode) {
      print('🔵 [ITEM_REPO] Detected language for "$parsedName": $detectedLanguage');
    }

    try {
      if (kDebugMode) {
        print('🔵 [ITEM_REPO] Inserting item "$parsedName" (qty: $parsedQuantity, unit: $parsedUnit) into database...');
      }
      
      final response = await _supabase.from('shopping_items').insert({
        'list_id': listId,
        'name': parsedName,
        'quantity': parsedQuantity,
        'unit': parsedUnit,
        'category': finalCategory, // Legacy field - keep for backward compatibility
        'category_id': finalCategory, // New field - category ID
        'language': detectedLanguage, // New field - detected language
        'notes': notes,
        'is_diet_warning': isDietWarning,
        'barcode': barcode,
        'added_by': userId,
      }).select().single();

      if (kDebugMode) {
        print('✅ [ITEM_REPO] Successfully added item "$name" with ID: ${response['id']}');
      }

      final item = ShoppingItemModel.fromJson(response);

      // Update list timestamp
      await _touchList(listId);

      // 🔔 Notifications are sent via realtime subscription in items_provider.dart
      // to avoid duplicate notifications

      return item;
    } catch (e, stackTrace) {
      if (kDebugMode) {
        print('❌ [ITEM_REPO] Database insert failed for "$name": $e');
        print('❌ [ITEM_REPO] StackTrace: $stackTrace');
      }
      rethrow;
    }
  }

  /// Update an item
  Future<ShoppingItemModel> updateItem(
    String itemId,
    Map<String, dynamic> updates,
  ) async {
    final response = await _supabase
        .from('shopping_items')
        .update(updates)
        .eq('id', itemId)
        .select()
        .single();
    
    final item = ShoppingItemModel.fromJson(response);
    await _touchList(item.listId);

    return item;
  }

  /// Toggle item checked status
  Future<ShoppingItemModel> toggleItemChecked(
    String itemId,
    bool isChecked,
  ) async {
    final updates = {
      'is_checked': isChecked,
      'checked_at': isChecked ? DateTime.now().toIso8601String() : null,
    };

    final updatedItem = await updateItem(itemId, updates);
    
    // list updated_at is handled inside updateItem
    
    // 🔔 Send notification to list members about item toggle
    if (Platform.isIOS || Platform.isAndroid) {
      try {
        final userId = _supabase.client.auth.currentUser?.id;
        if (userId != null) {
          if (kDebugMode) {
            print('🔔 [ITEM_REPO] Sending toggle notification for "${updatedItem.name}"...');
          }
          await _sendItemToggleNotifications(
            updatedItem.listId,
            updatedItem.name,
            isChecked,
            userId,
          );
        }
      } catch (e) {
        if (kDebugMode) {
          print('⚠️ [ITEM_REPO] Failed to send toggle notification: $e');
        }
      }
    }
    
    return updatedItem;
  }

  /// Delete an item
  Future<void> deleteItem(String itemId) async {
    // 🔔 Get item details before deletion for notification
    if (Platform.isIOS || Platform.isAndroid) {
      try {
        final itemResponse = await _supabase
            .from('shopping_items')
            .select('list_id, name, added_by')
            .eq('id', itemId)
            .single();
        
        final listId = itemResponse['list_id'] as String;
        final itemName = itemResponse['name'] as String;
        final userId = _supabase.client.auth.currentUser?.id;
        
        // Delete the item
        await _supabase.from('shopping_items').delete().eq('id', itemId);
        
        // Update list timestamp
        await _touchList(listId);
        
        // Send notification after successful deletion
        if (userId != null) {
          if (kDebugMode) {
            print('🔔 [ITEM_REPO] Sending deletion notification for "$itemName"...');
          }
          await _sendItemDeletionNotifications(listId, itemName, userId);
        }
      } catch (e) {
        if (kDebugMode) {
          print('⚠️ [ITEM_REPO] Failed to delete item or send notification: $e');
        }
        rethrow;
      }
    } else {
      // Non-mobile platforms: just delete without notifications
      // First get listId to touch it
      try {
        final item = await _supabase.from('shopping_items').select('list_id').eq('id', itemId).single();
        await _supabase.from('shopping_items').delete().eq('id', itemId);
        await _touchList(item['list_id'] as String);
      } catch (_) {
        await _supabase.from('shopping_items').delete().eq('id', itemId);
      }
    }
  }

  /// Update sort order for items
  Future<void> updateSortOrder(List<String> itemIds) async {
    if (itemIds.isEmpty) return;
    
    for (var i = 0; i < itemIds.length; i++) {
      await _supabase
          .from('shopping_items')
          .update({'sort_order': i})
          .eq('id', itemIds[i]);
    }
    
    // Touch list once (get listId from first item)
    try {
       final item = await _supabase.from('shopping_items').select('list_id').eq('id', itemIds[0]).single();
       await _touchList(item['list_id'] as String);
    } catch (_) {}
  }
  
  /// Updates the updated_at timestamp of the list
  Future<void> _touchList(String listId) async {
    try {
      await _supabase
          .from('shopping_lists')
          .update({'updated_at': DateTime.now().toUtc().toIso8601String()})
          .eq('id', listId);
    } catch (e) {
      if (kDebugMode) {
        print('⚠️ [ITEM_REPO] Failed to touch list: $e');
      }
    }
  }

  /// Get items by category
  Future<Map<String, List<ShoppingItemModel>>> getItemsByCategory(
    String listId,
  ) async {
    final items = await getListItems(listId);
    final grouped = <String, List<ShoppingItemModel>>{};

    for (final item in items) {
      final category = item.category ?? 'other'; // Use category ID
      grouped.putIfAbsent(category, () => []).add(item);
    }

    return grouped;
  }

  /// Search items
  Future<List<ShoppingItemModel>> searchItems(
    String listId,
    String query,
  ) async {
    final response = await _supabase
        .from('shopping_items')
        .select()
        .eq('list_id', listId)
        .or('name.ilike.%$query%,category.ilike.%$query%,notes.ilike.%$query%');

    return (response as List)
        .map((json) => ShoppingItemModel.fromJson(json))
        .toList();
  }

  /// Subscribe to item changes for a specific list
  void subscribeToItemChanges(String listId, Function() onUpdate) {
    print('🔵 [ITEM_REPO] subscribeToItemChanges called for list: $listId');
    
    // Don't create duplicate subscriptions
    if (_channels.containsKey(listId)) {
      print('⚠️ [ITEM_REPO] Subscription already exists for list: $listId');
      return;
    }

    print('🔵 [ITEM_REPO] Creating new subscription for list: $listId');
    final channel = _supabase.client
        .channel('shopping_items_$listId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'shopping_items',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'list_id',
            value: listId,
          ),
          callback: (payload) {
            print('🔥🔥🔥 [ITEM_REPO] REALTIME CALLBACK FROM SUPABASE! Event: ${payload.eventType}');
            print('🔥 Payload: ${payload.newRecord}');
            onUpdate();
          },
        )
        .subscribe();
    
    _channels[listId] = channel;
    print('✅ [ITEM_REPO] Subscription created and stored for list: $listId');
  }

  /// Unsubscribe from item changes for a specific list
  void unsubscribeFromItemChanges(String listId) {
    final channel = _channels[listId];
    if (channel != null) {
      channel.unsubscribe();
      _channels.remove(listId);
    }
  }

  /// Send real-time notifications to all list members when item is added
  Future<void> _sendListUpdateNotifications(
    String listId,
    String itemName,
    String addedByUserId,
  ) async {
    print('📢 [ITEM_REPO] _sendListUpdateNotifications START');
    try {
      // Get list name, members, and adder info
      print('📢 [ITEM_REPO] Fetching list info...');
      final listResponse = await _supabase
          .from('shopping_lists')
          .select('name')
          .eq('id', listId)
          .single();

      final listName = listResponse['name'] as String;
      print('📢 [ITEM_REPO] List name: $listName');

      print('📢 [ITEM_REPO] Fetching list members (excluding adder)...');
      final membersResponse = await _supabase
          .from('list_members')
          .select('user_id')
          .eq('list_id', listId)
          .neq('user_id', addedByUserId);

      print('📢 [ITEM_REPO] Found ${(membersResponse as List).length} members to notify');

      print('📢 [ITEM_REPO] Fetching adder display name...');
      final adderResponse = await _supabase
          .from('users')
          .select('display_name')
          .eq('id', addedByUserId)
          .single();

      final adderName = adderResponse['display_name'] as String? ?? 'Someone';
      print('📢 [ITEM_REPO] Adder name: $adderName');

      // Send push notifications to other members
      int notificationsSent = 0;
      for (final member in membersResponse) {
        final memberId = member['user_id'] as String;
        print('📢 [ITEM_REPO] Processing member: $memberId');
        
        try {
          final userResponse = await _supabase
              .from('users')
              .select('fcm_token, display_name')
              .eq('id', memberId)
              .single();
          
          final fcmToken = userResponse['fcm_token'] as String?;
          final memberName = userResponse['display_name'] as String? ?? 'Unknown';
          
          print('📢 [ITEM_REPO] Member $memberName has FCM token: ${fcmToken != null && fcmToken.isNotEmpty}');
          
          if (fcmToken != null && fcmToken.isNotEmpty) {
            print('📢 [ITEM_REPO] Sending FCM notification to $memberName...');
            print('📢 [ITEM_REPO] Token (first 40 chars): ${fcmToken.substring(0, fcmToken.length > 40 ? 40 : fcmToken.length)}...');
            
            final response = await _supabase.client.functions.invoke(
              'send-push-notification',
              body: {
                'token': fcmToken,
                'notification': {
                  'title': listName,
                  'body': '$adderName added "$itemName"',
                },
                'data': {
                  'type': 'list_update',
                  'listId': listId,
                },
              },
            );
            
            print('📨 [ITEM_REPO] Edge Function Response Status: ${response.status}');
            final responseData = response.data;
            if (responseData is Map && responseData['debug'] != null) {
              print('📋 [ITEM_REPO] Edge Function Debug:');
              for (final line in (responseData['debug'] as List)) {
                print('   $line');
              }
            }
            if (responseData is Map && responseData['error'] != null) {
              print('❌ [ITEM_REPO] Edge Function Error: ${responseData['error']}');
            }
            
            if (response.status == 200) {
              notificationsSent++;
              print('✅ [ITEM_REPO] FCM notification sent to $memberName');
            } else {
              print('⚠️ [ITEM_REPO] Notification failed for $memberName (status: ${response.status})');
            }
          } else {
            print('⚠️ [ITEM_REPO] Member $memberName has no FCM token - skipping');
          }
        } catch (e) {
          // Continue with other members if one fails
          print('❌ [ITEM_REPO] Failed to send notification to member $memberId: $e');
        }
      }
      print('✅ [ITEM_REPO] _sendListUpdateNotifications COMPLETE - sent $notificationsSent notifications');
    } catch (e) {
      print('❌ [ITEM_REPO] Failed to send list update notifications: $e');
    }
  }

  /// Public method to send item added notification (for realtime updates)
  Future<void> sendItemAddedNotification({
    required String listId,
    required String itemName,
    required String addedByUserId,
  }) async {
    print('🚀 [ITEM_REPO] sendItemAddedNotification CALLED');
    print('🚀 [ITEM_REPO] - listId: $listId');
    print('🚀 [ITEM_REPO] - itemName: $itemName');
    print('🚀 [ITEM_REPO] - addedByUserId: $addedByUserId');
    await _sendListUpdateNotifications(listId, itemName, addedByUserId);
    print('✅ [ITEM_REPO] sendItemAddedNotification COMPLETED');
  }

  /// Send real-time notifications when item is deleted
  Future<void> _sendItemDeletionNotifications(
    String listId,
    String itemName,
    String deletedByUserId,
  ) async {
    try {
      final listResponse = await _supabase
          .from('shopping_lists')
          .select('name')
          .eq('id', listId)
          .single();
      
      final listName = listResponse['name'] as String;

      final membersResponse = await _supabase
          .from('list_members')
          .select('user_id')
          .eq('list_id', listId)
          .neq('user_id', deletedByUserId);

      final deleterResponse = await _supabase
          .from('users')
          .select('display_name')
          .eq('id', deletedByUserId)
          .single();
      
      final deleterName = deleterResponse['display_name'] as String? ?? 'Someone';

      for (final member in membersResponse) {
        final memberId = member['user_id'] as String;
        
        try {
          final userResponse = await _supabase
              .from('users')
              .select('fcm_token, display_name')
              .eq('id', memberId)
              .single();
          
          final fcmToken = userResponse['fcm_token'] as String?;
          final memberName = userResponse['display_name'] as String? ?? 'Unknown';
          
          if (fcmToken != null && fcmToken.isNotEmpty) {
            print('📤 [ITEM_REPO] Sending delete notification to $memberName...');
            
            // Send via Supabase Edge Function
            final response = await _supabase.client.functions.invoke(
              'send-push-notification',
              body: {
                'token': fcmToken,
                'notification': {
                  'title': listName,
                  'body': '$deleterName removed "$itemName"',
                },
                'data': {
                  'type': 'item_deleted',
                  'listId': listId,
                },
              },
            );
            
            if (response.status == 200) {
              print('✅ [ITEM_REPO] Delete notification sent to $memberName');
            } else {
              print('⚠️ [ITEM_REPO] Delete notification failed for $memberName: ${response.status}');
            }
          } else {
            print('⚠️ [ITEM_REPO] Member $memberName has no FCM token');
          }
        } catch (e) {
          print('❌ [ITEM_REPO] Failed to send delete notification to member $memberId: $e');
        }
      }
    } catch (e) {
      print('❌ [ITEM_REPO] Failed to send item deletion notifications: $e');
    }
  }

  /// Send real-time notifications when item is toggled
  Future<void> _sendItemToggleNotifications(
    String listId,
    String itemName,
    bool isChecked,
    String toggledByUserId,
  ) async {
    try {
      final listResponse = await _supabase
          .from('shopping_lists')
          .select('name')
          .eq('id', listId)
          .single();
      
      final listName = listResponse['name'] as String;

      final membersResponse = await _supabase
          .from('list_members')
          .select('user_id')
          .eq('list_id', listId)
          .neq('user_id', toggledByUserId);

      final togglerResponse = await _supabase
          .from('users')
          .select('display_name')
          .eq('id', toggledByUserId)
          .single();
      
      final togglerName = togglerResponse['display_name'] as String? ?? 'Someone';

      final action = isChecked ? 'checked off' : 'unchecked';

      for (final member in membersResponse) {
        final memberId = member['user_id'] as String;
        
        try {
          final userResponse = await _supabase
              .from('users')
              .select('fcm_token, display_name')
              .eq('id', memberId)
              .single();
          
          final fcmToken = userResponse['fcm_token'] as String?;
          final memberName = userResponse['display_name'] as String? ?? 'Unknown';
          
          if (fcmToken != null && fcmToken.isNotEmpty) {
            print('📤 [ITEM_REPO] Sending toggle notification to $memberName...');
            
            // Send via Supabase Edge Function
            final response = await _supabase.client.functions.invoke(
              'send-push-notification',
              body: {
                'token': fcmToken,
                'notification': {
                  'title': listName,
                  'body': '$togglerName $action "$itemName"',
                },
                'data': {
                  'type': 'item_toggled',
                  'listId': listId,
                  'isChecked': isChecked,
                },
              },
            );
            
            if (response.status == 200) {
              print('✅ [ITEM_REPO] Toggle notification sent to $memberName');
            } else {
              print('⚠️ [ITEM_REPO] Toggle notification failed for $memberName: ${response.status}');
            }
          } else {
            print('⚠️ [ITEM_REPO] Member $memberName has no FCM token');
          }
        } catch (e) {
          print('❌ [ITEM_REPO] Failed to send toggle notification to member $memberId: $e');
        }
      }
    } catch (e) {
      print('❌ [ITEM_REPO] Failed to send item toggle notifications: $e');
    }
  }
}
