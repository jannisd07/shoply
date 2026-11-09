import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:shoply/core/design/design.dart';
import 'package:shoply/core/localization/localization_helper.dart';
import 'package:shoply/core/modules/app_modules.dart';
import 'package:shoply/data/models/shopping_history.dart';
import 'package:shoply/data/models/shopping_item_model.dart';
import 'package:shoply/data/repositories/item_batch.dart';
import 'package:shoply/data/services/store_chain_directory.dart';
import 'package:shoply/presentation/providers/store_choice_provider.dart';
import 'package:shoply/presentation/screens/history/history_format.dart';
import 'package:shoply/presentation/screens/history/history_paths.dart';
import 'package:shoply/presentation/state/auth_provider.dart';
import 'package:shoply/presentation/state/items_provider.dart';
import 'package:shoply/presentation/state/shopping_history_provider.dart';
import 'package:shoply/presentation/state/trip_history_provider.dart';
import 'package:shoply/presentation/widgets/design/avo_icons.dart';
import 'package:shoply/presentation/widgets/design/avo_menu.dart';
import 'package:shoply/presentation/widgets/design/confirm_dialog.dart';
import 'package:shoply/presentation/widgets/design/module_off_alert.dart';
import 'package:shoply/presentation/widgets/design/undo_toast.dart';

// Actions shared by V4 (rows), V5 (menu) and V8 (verlauf-kosten.md V4, V5,
// V13). Everything is optimistic: the row changes at once, a failure brings
// it back with a toast and the error haptic.

/// One trip that is not in the local history: read once from the server
/// (a notification on a cold start, a link); null when gone.
final tripLookupProvider = FutureProvider.autoDispose
    .family<ShoppingHistory?, String>((ref, tripId) async {
      if (isLocalTripId(tripId)) return null;
      final trip = await ref.read(shoppingHistoryServiceProvider).getTrip(tripId);
      if (trip != null) ref.read(tripHistoryProvider.notifier).upsert(trip);
      return trip;
    });

/// V5–V7 for a trip that does not exist (any more): to the history, which
/// says "Dieser Einkauf wurde gelöscht." (§1.2). `go`, so no blank page of
/// the gone trip stays below, wherever it was opened from.
void leaveGoneTrip(BuildContext context) {
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (!context.mounted) return;
    GoRouter.of(context).go(historyLocation(tripGone: true));
  });
}

/// Whether the signed-in person finished [trip] (amount, market, delete).
bool isOwnTrip(WidgetRef ref, ShoppingHistory trip) {
  final me = ref.read(authUserIdProvider);
  return me != null && (trip.completedBy ?? trip.userId) == me;
}

/// The name for item comparisons ("Milch" = "milch ").
String _key(String name) => name.trim().toLowerCase();

/// Items of [trip] that are not open on the list [open] already.
List<ShoppingHistoryItem> itemsToReadd(
  ShoppingHistory trip,
  List<ShoppingItemModel> open,
) {
  final there = {
    for (final i in open)
      if (!i.isChecked) _key(i.name),
  };
  final seen = <String>{};
  return [
    for (final item in trip.items)
      if (!there.contains(_key(item.name)) && seen.add(_key(item.name))) item,
  ];
}

/// "Alle wieder auf die Liste" (V5): adds what is not already open on
/// [listId] with its quantity and without old prices, then "9 Artikel auf
/// Wocheneinkauf · Widerrufen". Items already open are skipped (not merged)
/// until A-V19 gives `addItems` a skip option.
Future<void> readdTrip(
  BuildContext context,
  WidgetRef ref, {
  required ShoppingHistory trip,
  required String listId,
  required String listName,
  List<ShoppingHistoryItem>? only,
}) async {
  final open =
      ref.read(itemsNotifierProvider(listId)).valueOrNull ??
      const <ShoppingItemModel>[];
  final items = only ?? itemsToReadd(trip, open);
  if (items.isEmpty) return;
  final repo = ref.read(itemRepositoryProvider);
  final message = only != null && only.length == 1
      ? context.tr(
          'hist_item_readd_done',
          params: {'name': only.first.name, 'list': listName},
        )
      : (items.length == 1
            ? context.tr('hist_readd_done_one', params: {'list': listName})
            : context.tr(
                'hist_readd_done',
                params: {'n': '${items.length}', 'list': listName},
              ));
  try {
    final result = await repo.addItems(listId, [
      for (final i in items)
        NewItem(
          name: i.name,
          quantity: i.quantity,
          unit: i.unit,
          category: i.category,
        ),
    ]);
    unawaited(ref.read(itemsNotifierProvider(listId).notifier).loadItems());
    if (!context.mounted) return;
    AvoToast.show(
      context,
      message: message,
      actionLabel: context.tr('common_undo'),
      onAction: () async {
        await repo.undoAddItems(result.token);
        unawaited(
          ref.read(itemsNotifierProvider(listId).notifier).loadItems(),
        );
      },
    );
  } catch (e) {
    debugPrint('❌ [HISTORY] Re-add failed: ${e.runtimeType}');
    unawaited(AvoHaptics.error());
    if (context.mounted) {
      AvoToast.show(context, message: context.tr('common_not_saved'));
    }
  }
}

/// V13 "Einkauf vom 7. Nov. löschen?" with the text for the case, then the
/// optimistic delete. True when deleted.
Future<bool> confirmAndDeleteTrip(
  BuildContext context,
  WidgetRef ref,
  ShoppingHistory trip, {
  required bool shared,
  required bool hasSplit,
}) async {
  final lang = Localizations.localeOf(context).languageCode;
  final now = ref.read(historyClockProvider)();
  final ok = await showAvoConfirm(
    context,
    title: context.tr(
      'hist_delete_title',
      params: {'date': dayMonth(trip.completedAt, lang, now)},
    ),
    message: context.tr(
      hasSplit
          ? 'hist_delete_body_split'
          : (shared ? 'hist_delete_body_shared' : 'hist_delete_body'),
    ),
    confirmLabel: context.tr('hist_delete_confirm'),
  );
  if (!ok || !context.mounted) return false;
  final controller = ref.read(tripHistoryProvider.notifier);
  try {
    await controller.deleteTrip(trip.id);
    return true;
  } catch (e) {
    unawaited(AvoHaptics.error());
    if (context.mounted) {
      AvoToast.show(
        context,
        message: context.tr('hist_delete_failed'),
        actionLabel: context.tr('common_try_again'),
        onAction: () => unawaited(
          confirmAndDeleteTrip(
            context,
            ref,
            trip,
            shared: shared,
            hasSplit: hasSplit,
          ),
        ),
      );
    }
    return false;
  }
}

/// "Markt ändern" (V5): V2 in mode `trip`; the choice saves at once with
/// "Markt: REWE · Widerrufen".
Future<void> changeTripStore(
  BuildContext context,
  WidgetRef ref,
  ShoppingHistory trip,
) async {
  final choice = await context.push<Object?>(
    storePickTripLocation(listId: trip.listId, selected: trip.storeChainId),
  );
  if (!context.mounted || choice == null) return;
  final String? chain = switch (choice) {
    ChainStoreChoice(:final chainId) => chainId,
    NoStoreChoice() => null,
    _ => trip.storeChainId,
  };
  if (chain == trip.storeChainId) return;
  await setTripStore(context, ref, trip, chain);
}

/// Saves [chain] as the market of [trip], optimistically, with undo.
Future<void> setTripStore(
  BuildContext context,
  WidgetRef ref,
  ShoppingHistory trip,
  String? chain, {
  bool showToast = true,
}) async {
  final controller = ref.read(tripHistoryProvider.notifier);
  final service = ref.read(shoppingHistoryServiceProvider);
  final before = trip;
  controller.upsert(
    chain == null
        ? trip.copyWith(clearStore: true)
        : trip.copyWith(storeChainId: chain),
  );
  final name = chain == null
      ? context.tr('hist_store_none')
      : (StoreChainDirectory.byId(chain)?.displayName ?? chain);
  try {
    await service.setTripStore(trip.id, chain);
    if (!showToast || !context.mounted) return;
    AvoToast.show(
      context,
      message: context.tr('hist_store_saved', params: {'store': name}),
      actionLabel: context.tr('common_undo'),
      onAction: () => unawaited(
        setTripStore(context, ref, trip, before.storeChainId, showToast: false),
      ),
    );
  } catch (e) {
    debugPrint('❌ [HISTORY] Store not saved: ${e.runtimeType}');
    controller.upsert(before);
    unawaited(AvoHaptics.error());
    if (context.mounted) {
      AvoToast.show(context, message: context.tr('common_not_saved'));
    }
  }
}

/// Opens [location] behind the Kosten-teilen guard (§1.3): with the module
/// off the alert comes first, "Einschalten" then opens it.
Future<void> openWithCostSplit(
  BuildContext context,
  WidgetRef ref,
  String location,
) async {
  if (!ref.read(moduleEnabledProvider(AppModule.costSplit))) {
    final on = await showModuleOffAlert(
      context,
      moduleName: context.tr('common_module_cost_split'),
      body: context.tr('hist_split_module_off_body'),
      onEnable: () => ref
          .read(appModulesProvider.notifier)
          .setEnabled(AppModule.costSplit, true),
    );
    if (!on || !context.mounted) return;
  }
  await context.push<Object?>(location);
}

/// The long-press menu of a trip (V4) and V5's "Mehr": only what is
/// allowed shows (no greyed entries).
List<AvoMenuEntry> tripMenu(
  BuildContext context,
  WidgetRef ref,
  ShoppingHistory trip, {
  required bool hasSplit,
  required bool shared,
  VoidCallback? onReadd,
  VoidCallback? afterDelete,
}) {
  final own = isOwnTrip(ref, trip);
  final split = ref.read(moduleEnabledProvider(AppModule.costSplit));
  final hasAmount = (trip.totalCostCents ?? 0) > 0;
  return [
    if (onReadd != null)
      AvoMenuItem(
        label: context.tr('hist_menu_readd'),
        icon: AvoIcons.cartBadgePlus,
        onSelected: onReadd,
      ),
    if (split && !isLocalTripId(trip.id))
      AvoMenuItem(
        label: context.tr(hasSplit ? 'hist_menu_split_edit' : 'hist_menu_split'),
        icon: AvoIcons.eurosignCircle,
        onSelected: () => unawaited(
          openWithCostSplit(context, ref, historySplitLocation(trip.id)),
        ),
      ),
    if (own && !isLocalTripId(trip.id)) ...[
      AvoMenuItem(
        label: context.tr(
          hasAmount ? 'hist_menu_amount_edit' : 'hist_menu_amount_add',
        ),
        icon: AvoIcons.eurosignCircle,
        onSelected: () =>
            unawaited(context.push<Object?>(historyAmountLocation(trip.id))),
      ),
      AvoMenuItem(
        label: context.tr('hist_menu_store'),
        icon: AvoIcons.storefront,
        onSelected: () => unawaited(changeTripStore(context, ref, trip)),
      ),
    ],
    if (own) ...[
      const AvoMenuDivider(),
      AvoMenuItem(
        label: context.tr('hist_menu_delete'),
        icon: AvoIcons.trash,
        destructive: true,
        onSelected: () => unawaited(
          confirmAndDeleteTrip(
            context,
            ref,
            trip,
            shared: shared,
            hasSplit: hasSplit,
          ).then((deleted) {
            if (deleted) afterDelete?.call();
          }),
        ),
      ),
    ],
  ];
}
