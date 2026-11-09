/// What a person does with an offer (S3–S6): take its price for an item,
/// remove that price again, hide the offer for the item, put it on a list.
/// Every write is optimistic through the list's items notifier (prices via
/// A's `setPrice` / `clearPrice` / `undoPrice`), shows an undo toast and, when it fails, rolls back with the error haptic and a
/// "Erneut versuchen" toast (`angebote.md` 3.6, 3.7). No success haptic:
/// money is no success moment.
library;

import 'dart:async';

import 'package:flutter/semantics.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:shoply/core/design/design.dart';
import 'package:shoply/core/localization/localization_helper.dart';
import 'package:shoply/data/models/shopping_item_model.dart';
import 'package:shoply/data/models/store_offer.dart';
import 'package:shoply/data/repositories/item_batch.dart' show ItemPrice;
import 'package:shoply/data/services/store_chain_directory.dart';
import 'package:shoply/presentation/providers/offer_display_prefs_provider.dart';
import 'package:shoply/presentation/providers/offer_lookup_provider.dart';
import 'package:shoply/presentation/screens/offers/offer_text.dart';
import 'package:shoply/presentation/state/items_provider.dart';
import 'package:shoply/presentation/widgets/design/undo_toast.dart';

/// How long an add waits for the items of a list that is not open yet.
const Duration _itemsWait = Duration(seconds: 3);

/// How long "Nicht dieses Angebot" holds for an offer without an end date.
const Duration _declineWithoutEnd = Duration(days: 7);

/// A row created this long before the add counts as the one just added
/// (server clocks drift a little).
const Duration _addedWindow = Duration(minutes: 1);

/// The price an offer writes onto an item (A-D1 `ItemPrice`). The market is
/// stored in the directory's spelling ("Lidl", "Aldi Süd"), which the trip
/// history reads back as the chain.
ItemPrice offerItemPrice(StoreOffer offer) => ItemPrice(
  price: offer.price,
  retailer: offerStoreName(offer),
  unit: offer.unitSizeLabel ?? offer.unitShortName,
  oldValue: offer.regularPrice,
);

/// Whether [item] carries the price of [offer] ("Preis übernommen").
bool isOfferPriceTaken(ShoppingItemModel item, StoreOffer offer) {
  final price = item.price;
  if (price == null || (price - offer.price).abs() >= 0.005) return false;
  final retailer = item.priceRetailer?.trim() ?? '';
  final chain = offerChainId(offer);
  if (retailer.isEmpty || chain == null) return false;
  return matchChain(retailer) == chain || retailer.toLowerCase() == chain;
}

/// The root navigator's context: toasts outlive the screen that asked.
BuildContext _toastContext(BuildContext context) =>
    Navigator.of(context, rootNavigator: true).context;

/// Remembers [offer] for the detail screen; call before opening it.
void rememberOffer(BuildContext context, StoreOffer offer) =>
    ProviderScope.containerOf(
      context,
      listen: false,
    ).read(offerCacheProvider).remember(offer);

/// Sets [price] on [item] (null removes it) through Teil A's optimistic
/// `ItemsNotifier.setPrice` / `clearPrice` and shows [message] with undo
/// (`undoPrice`, which puts the old price back only while the item still
/// has this one). On failure the row rolls back (the notifier does that),
/// the toast says "Preis nicht gespeichert" with a retry and the result is
/// false.
Future<bool> _writePrice(
  BuildContext context, {
  required String listId,
  required ShoppingItemModel item,
  required ItemPrice? price,
  required String message,
}) async {
  final container = ProviderScope.containerOf(context, listen: false);
  final notifier = container.read(itemsNotifierProvider(listId).notifier);
  final toastContext = _toastContext(context);
  final write = price == null
      ? notifier.clearPrice(item.id)
      : notifier.setPrice(item.id, price);
  AvoToast.show(
    toastContext,
    message: message,
    actionLabel: toastContext.tr('common_undo'),
    onAction: () =>
        unawaited(_quietly(write.then((token) => notifier.undoPrice(token)))),
  );
  try {
    await write;
    return true;
  } catch (e) {
    debugPrint('❌ [OFFERS] Price of an item not saved: $e');
    unawaited(AvoHaptics.error());
    if (!toastContext.mounted) return false;
    AvoToast.show(
      toastContext,
      message: toastContext.tr('offer_toast_price_failed'),
      actionLabel: toastContext.tr('common_try_again'),
      onAction: () {
        if (!toastContext.mounted) return;
        unawaited(
          _writePrice(
            toastContext,
            listId: listId,
            item: item,
            price: price,
            message: message,
          ),
        );
      },
    );
    return false;
  }
}

Future<void> _quietly(Future<void> write) async {
  try {
    await write;
  } catch (e) {
    debugPrint('❌ [OFFERS] Undo not saved: $e');
  }
}

/// "Preis übernehmen": [offer]'s price, market, pack and "statt" price go
/// onto [item]; toast "Preis für Milch übernommen · Widerrufen".
Future<void> takeOfferPrice(
  BuildContext context, {
  required String listId,
  required ShoppingItemModel item,
  required StoreOffer offer,
}) => _writePrice(
  context,
  listId: listId,
  item: item,
  price: offerItemPrice(offer),
  message: context.tr('offer_toast_price_taken', params: {'item': item.name}),
).then((_) {});

/// "Übernommenen Preis entfernen"; toast "Preis für Milch entfernt".
Future<void> removeOfferPrice(
  BuildContext context, {
  required String listId,
  required ShoppingItemModel item,
}) => _writePrice(
  context,
  listId: listId,
  item: item,
  price: null,
  message: context.tr('offer_toast_price_removed', params: {'item': item.name}),
).then((_) {});

/// "Nicht dieses Angebot": [offer] is hidden for [item] until it ends;
/// toast "Angebot für Milch ausgeblendet · Widerrufen".
Future<void> declineOffer(
  BuildContext context, {
  required ShoppingItemModel item,
  required StoreOffer offer,
}) async {
  final container = ProviderScope.containerOf(context, listen: false);
  final prefs = container.read(offerDisplayPrefsProvider.notifier);
  final now = container.read(offerClockProvider)();
  final toastContext = _toastContext(context);
  AvoToast.show(
    toastContext,
    message: toastContext.tr(
      'offer_toast_offer_hidden',
      params: {'item': item.name},
    ),
    actionLabel: toastContext.tr('common_undo'),
    onAction: () => unawaited(prefs.undecline(item.id)),
  );
  await prefs.decline(
    item.id,
    offer.id,
    offer.validTo ?? now.add(_declineWithoutEnd),
  );
}

/// Puts [offer] on [listId] as [name] ("Milch", as typed; not the product
/// name): an open item of that name gets the offer attached, otherwise a
/// new item with [quantity] and [unit] and the offer's price is added.
///
/// [listName] set: toast "Milch auf Wocheneinkauf · Widerrufen" for a new
/// item; an attached offer says "Angebot an Milch angehängt", or with
/// [otherList] (put on from outside the list, S10) "Angebot an Milch auf
/// Wocheneinkauf angehängt". A list that is not open yet is read first, so
/// an open "Milch" is never added a second time. Once
/// saved, VoiceOver hears "Milch hinzugefügt, im Angebot" or "Angebot an
/// Milch angehängt". Returns false when the write failed (the toast then
/// says "Nicht hinzugefügt" or "Preis nicht gespeichert"), so the caller
/// keeps what was typed.
Future<bool> addOfferToList(
  BuildContext context, {
  required String listId,
  required String name,
  required StoreOffer offer,
  double quantity = 1,
  String? unit,
  String? listName,
  bool otherList = false,
}) async {
  final container = ProviderScope.containerOf(context, listen: false);
  final notifier = container.read(itemsNotifierProvider(listId).notifier);
  final toastContext = _toastContext(context);
  final direction = Directionality.of(context);
  final trimmed = name.trim();
  final key = trimmed.toLowerCase();
  final items = await _itemsOf(container, listId);
  if (!toastContext.mounted) return false;
  final open = items
      .where((i) => !i.isChecked && i.name.trim().toLowerCase() == key)
      .firstOrNull;

  if (open != null) {
    final attached = otherList && listName != null
        ? toastContext.tr(
            'offer_toast_attached_list',
            params: {'item': open.name, 'list': listName},
          )
        : toastContext.tr('offer_toast_attached', params: {'item': open.name});
    final saved = await _writePrice(
      toastContext,
      listId: listId,
      item: open,
      price: offerItemPrice(offer),
      message: attached,
    );
    // Said once it is saved: "Angebot an Milch angehängt".
    if (saved && toastContext.mounted) {
      _announce(toastContext, attached, direction);
    }
    return saved;
  }

  final started = DateTime.now();
  final price = offerItemPrice(offer);
  try {
    await notifier.addItem(
      name: trimmed,
      quantity: quantity,
      unit: unit,
      price: price.price,
      priceCurrency: price.currency,
      priceRetailer: price.retailer,
      priceUnit: price.unit,
      priceOldValue: price.oldValue,
      autoParse: false,
    );
  } catch (e) {
    debugPrint('❌ [OFFERS] Offer not put on the list: $e');
    unawaited(AvoHaptics.error());
    if (toastContext.mounted) {
      AvoToast.show(
        toastContext,
        message: toastContext.tr('offer_toast_add_failed'),
        actionLabel: toastContext.tr('common_try_again'),
        onAction: () {
          if (!toastContext.mounted) return;
          unawaited(
            addOfferToList(
              toastContext,
              listId: listId,
              name: name,
              offer: offer,
              quantity: quantity,
              unit: unit,
              listName: listName,
              otherList: otherList,
            ),
          );
        },
      );
    }
    return false;
  }
  if (!toastContext.mounted) return true;
  _announce(
    toastContext,
    toastContext.tr('offer_suggest_added_a11y', params: {'item': trimmed}),
    direction,
  );
  if (listName != null) {
    final added =
        (container.read(itemsNotifierProvider(listId)).valueOrNull ??
                const <ShoppingItemModel>[])
            .where(
              (i) =>
                  i.name.trim().toLowerCase() == key &&
                  !i.id.startsWith('pending-') &&
                  !i.createdAt.isBefore(started.subtract(_addedWindow)),
            )
            .lastOrNull;
    AvoToast.show(
      toastContext,
      message: toastContext.tr(
        'offer_toast_added_list',
        params: {'item': trimmed, 'list': listName},
      ),
      actionLabel: added == null ? null : toastContext.tr('common_undo'),
      onAction: added == null
          ? null
          : () => unawaited(_quietly(notifier.deleteItem(added.id))),
    );
  }
  return true;
}

/// The items of [listId]. A list that is open (its items are watched) is
/// read as it is; one that was not open yet is loaded first, waiting up to
/// [_itemsWait] (empty when it does not load).
Future<List<ShoppingItemModel>> _itemsOf(
  ProviderContainer container,
  String listId,
) async {
  final provider = itemsNotifierProvider(listId);
  final open = container.exists(provider);
  final now = container.read(provider);
  if (now.hasValue || open) return now.valueOrNull ?? const [];
  final notifier = container.read(provider.notifier);
  try {
    final loaded = await notifier.stream
        .firstWhere((s) => s.hasValue || s.hasError)
        .timeout(_itemsWait);
    return loaded.valueOrNull ?? const [];
  } catch (_) {
    return container.read(provider).valueOrNull ?? const [];
  }
}

/// Puts [name] on [listId] without the offer, because [offer] does not
/// apply at that list's market (S10 "Angebot gilt dort nicht"): an open
/// item of that name stays as it is; toast "Haferflocken auf Wocheneinkauf
/// · Angebot gilt nur bei Lidl · Widerrufen".
Future<bool> addWithoutOffer(
  BuildContext context, {
  required String listId,
  required String listName,
  required String name,
  required StoreOffer offer,
  double quantity = 1,
}) async {
  final container = ProviderScope.containerOf(context, listen: false);
  final notifier = container.read(itemsNotifierProvider(listId).notifier);
  final toastContext = _toastContext(context);
  final direction = Directionality.of(context);
  final trimmed = name.trim();
  final key = trimmed.toLowerCase();
  final items = await _itemsOf(container, listId);
  final message = toastContext.mounted
      ? toastContext.tr(
          'offer_toast_added_no_offer',
          params: {
            'item': trimmed,
            'list': listName,
            'store': offerStoreName(offer),
          },
        )
      : '';
  if (items.any((i) => !i.isChecked && i.name.trim().toLowerCase() == key)) {
    if (toastContext.mounted) AvoToast.show(toastContext, message: message);
    return true;
  }
  final started = DateTime.now();
  try {
    await notifier.addItem(name: trimmed, quantity: quantity, autoParse: false);
  } catch (e) {
    debugPrint('❌ [OFFERS] Item not put on the list: $e');
    unawaited(AvoHaptics.error());
    if (toastContext.mounted) {
      AvoToast.show(
        toastContext,
        message: toastContext.tr('offer_toast_add_failed'),
        actionLabel: toastContext.tr('common_try_again'),
        onAction: () {
          if (!toastContext.mounted) return;
          unawaited(
            addWithoutOffer(
              toastContext,
              listId: listId,
              listName: listName,
              name: name,
              offer: offer,
              quantity: quantity,
            ),
          );
        },
      );
    }
    return false;
  }
  if (!toastContext.mounted) return true;
  _announce(toastContext, message, direction);
  final added =
      (container.read(itemsNotifierProvider(listId)).valueOrNull ??
              const <ShoppingItemModel>[])
          .where(
            (i) =>
                i.name.trim().toLowerCase() == key &&
                !i.id.startsWith('pending-') &&
                !i.createdAt.isBefore(started.subtract(_addedWindow)),
          )
          .lastOrNull;
  AvoToast.show(
    toastContext,
    message: message,
    actionLabel: added == null ? null : toastContext.tr('common_undo'),
    onAction: added == null
        ? null
        : () => unawaited(_quietly(notifier.deleteItem(added.id))),
  );
  return true;
}

void _announce(BuildContext context, String message, TextDirection direction) {
  final view = View.maybeOf(context);
  if (view == null) return;
  unawaited(SemanticsService.sendAnnouncement(view, message, direction));
}
