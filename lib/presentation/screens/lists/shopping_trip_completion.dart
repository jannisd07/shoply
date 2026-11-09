import 'dart:async';
import 'dart:io';

import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shoply/core/design/design.dart';
import 'package:shoply/core/localization/app_localizations.dart';
import 'package:shoply/core/localization/localization_helper.dart';
import 'package:shoply/data/models/shopping_item_model.dart';
import 'package:shoply/data/services/checkout_store_resolver.dart';
import 'package:shoply/data/services/push_notification_service.dart';
import 'package:shoply/data/services/shopping_history_service.dart';
import 'package:shoply/data/services/store_locator_service.dart';
import 'package:shoply/data/services/supabase_service.dart';
import 'package:shoply/data/services/user_location_service.dart';
import 'package:shoply/presentation/screens/lists/widgets/checkout_store_sheet.dart';
import 'package:shoply/presentation/state/items_provider.dart';
import 'package:shoply/presentation/state/lists_provider.dart';

/// "Complete shopping": saves the checked items to history, removes them
/// from the list and tells the other members. Confirms nothing on success:
/// the host of `openCheckoutFlow` shows the success moment, and the home
/// screen's SplitTripNudgeCard offers to split the cost.
Future<void> completeShoppingTrip(
  BuildContext context,
  WidgetRef ref, {
  required String listId,
  required String listName,
  required List<ShoppingItemModel> items,
}) async {
  final checkedItems = items.where((item) => item.isChecked).toList();

  if (checkedItems.isEmpty) {
    AdaptiveAlertDialog.show(
      context: context,
      title: context.tr('no_checked_items'),
      message: context.tr('no_checked_items_message'),
      icon: PlatformInfo.isIOS26OrHigher()
          ? 'exclamationmark.circle.fill'
          : Icons.info_outline,
      iconColor: Colors.orange,
      actions: [
        AlertAction(
          title: context.tr('ok'),
          style: AlertActionStyle.primary,
          onPressed: () {},
        ),
      ],
    );
    return;
  }

  var confirmed = false;
  await AdaptiveAlertDialog.show(
    context: context,
    title: context.tr('complete_shopping_question'),
    message: context.tr(
      'complete_shopping_checked_message',
      params: {'count': checkedItems.length.toString()},
    ),
    icon: PlatformInfo.isIOS26OrHigher()
        ? 'checkmark.circle.fill'
        : Icons.check_circle_outline,
    iconColor: context.colors.tint,
    actions: [
      AlertAction(
        title: AppLocalizations.of(context).cancel,
        style: AlertActionStyle.cancel,
        onPressed: () {},
      ),
      AlertAction(
        title: context.tr('complete_btn'),
        style: AlertActionStyle.primary,
        onPressed: () => confirmed = true,
      ),
    ],
  );
  if (!confirmed || !context.mounted) return;

  // Work out which shop this was, so purchase stats learn *where* you buy
  // what. Resolves silently from GPS when unambiguous; only asks when it
  // genuinely cannot tell (shopping centre, or no location access).
  final storeName = await _resolveCheckoutStore(context);
  final itemsForHistory = storeName == null
      ? checkedItems
      : [
          for (final item in checkedItems)
            item.priceRetailer == null || item.priceRetailer!.isEmpty
                ? item.copyWith(priceRetailer: storeName)
                : item,
        ];

  try {
    // Purchase tracking (for the "you usually buy X every N days" nudges)
    // happens inside this call.
    await ShoppingHistoryService().completeShoppingTrip(
      listId: listId,
      listName: listName,
      items: itemsForHistory,
    );

    await SupabaseService.instance
        .from('shopping_items')
        .delete()
        .inFilter('id', checkedItems.map((item) => item.id).toList());

    unawaited(ref.read(itemsNotifierProvider(listId).notifier).loadItems());

    var members = const <Map<String, dynamic>>[];
    try {
      members = await ref.read(listRepositoryProvider).getListMembers(listId);
    } catch (e) {
      debugPrint('⚠️ [LIST_DETAIL] Failed to load members: $e');
    }
    if (!context.mounted) return;

    _notifyMembers(
      context,
      members: members,
      listId: listId,
      listName: listName,
    );
  } catch (e) {
    debugPrint('❌ [LIST_DETAIL] Failed to complete trip: $e');
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.tr('action_failed')),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}

/// Which shop the trip happened in, or null when it stays unknown.
///
/// Never blocks the checkout: any failure (no GPS fix, Overpass down,
/// user skips) returns null and the trip is recorded without a shop.
Future<String?> _resolveCheckoutStore(BuildContext context) async {
  StoreResolution resolution;
  try {
    final coords = await UserLocationService.instance.getCoordinates();
    if (coords == null) {
      resolution = const StoreUnknown(locationDenied: true);
    } else {
      final stores = await StoreLocatorService.instance.findNearbyStores(
        latitude: coords.latitude,
        longitude: coords.longitude,
      );
      resolution = CheckoutStoreResolver.resolve(stores);
    }
  } catch (_) {
    resolution = const StoreUnknown();
  }

  // Unambiguous: record it without interrupting the checkout at all.
  if (resolution is StoreResolved) return resolution.store.displayName;

  if (!context.mounted) return null;
  return showCheckoutStoreSheet(context, resolution: resolution);
}

/// Fire-and-forget push to every other member of the list.
void _notifyMembers(
  BuildContext context, {
  required List<Map<String, dynamic>> members,
  required String listId,
  required String listName,
}) {
  if (!(Platform.isIOS || Platform.isAndroid)) return;
  final userId = SupabaseService.instance.currentUser?.id;
  if (userId == null) return;

  final recipients = [
    for (final m in members)
      if (m['user_id'] != userId) m['user_id'] as String,
  ];
  if (recipients.isEmpty) return;

  final me = members.where((m) => m['user_id'] == userId).firstOrNull;
  final myName = (me?['user'] as Map<String, dynamic>?)?['display_name']
          as String? ??
      context.tr('someone');

  unawaited(
    PushNotificationService.instance.sendToUsers(
      userIds: recipients,
      title: context.tr('shopping_complete_push_title'),
      body: context.tr(
        'shopping_complete_push_body',
        params: {'name': myName, 'list': listName},
      ),
      data: {'type': 'shopping_complete', 'listId': listId},
    ),
  );
}
