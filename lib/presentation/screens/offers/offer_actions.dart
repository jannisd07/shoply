/// What a person does with an offer (S3–S6): take its price for an item,
/// remove that price again, hide the offer for the item, put it on a list.
/// Every write is optimistic through the list's items notifier, shows an
/// undo toast and, when it fails, rolls back with the error haptic and a
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
import 'package:shoply/data/services/store_chain_directory.dart';
import 'package:shoply/presentation/providers/offer_display_prefs_provider.dart';
import 'package:shoply/presentation/providers/offer_lookup_provider.dart';
import 'package:shoply/presentation/screens/offers/offer_text.dart';
import 'package:shoply/presentation/state/items_provider.dart';
import 'package:shoply/presentation/widgets/design/undo_toast.dart';

/// How long "Nicht dieses Angebot" holds for an offer without an end date.
const Duration _declineWithoutEnd = Duration(days: 7);

/// A row created this long before the add counts as the one just added
/// (server clocks drift a little).
const Duration _addedWindow = Duration(minutes: 1);

/// The price columns an offer writes onto an item. The market is stored in
/// the directory's spelling ("Lidl", "Aldi Süd"), which the trip history
/// reads back as the chain.
Map<String, dynamic> offerPriceFields(StoreOffer offer) => {
  'price': offer.price,
  'price_currency': 'EUR',
  'price_retailer': offerStoreName(offer),
  'price_unit': offer.unitSizeLabel ?? offer.unitShortName,
  'price_updated_at': DateTime.now().toUtc().toIso8601String(),
  'price_old_value': offer.regularPrice,
};

/// The price columns of [item] as they are, to put back on undo.
Map<String, dynamic> _priceFieldsOf(ShoppingItemModel item) => {
  'price': item.price,
  'price_currency': item.priceCurrency,
  'price_retailer': item.priceRetailer,
  'price_unit': item.priceUnit,
  'price_updated_at': item.priceUpdatedAt?.toIso8601String(),
  'price_old_value': item.priceOldValue,
};

const Map<String, dynamic> _noPrice = {
  'price': null,
  'price_currency': null,
  'price_retailer': null,
  'price_unit': null,
  'price_updated_at': null,
  'price_old_value': null,
};

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

/// Writes [fields] onto [item] and shows [message] with undo. On failure
/// the item rolls back (the notifier does that) and the toast says
/// "Preis nicht gespeichert" with a retry.
Future<void> _writePrice(
  BuildContext context, {
  required String listId,
  required ShoppingItemModel item,
  required Map<String, dynamic> fields,
  required String message,
}) async {
  final container = ProviderScope.containerOf(context, listen: false);
  final notifier = container.read(itemsNotifierProvider(listId).notifier);
  final toastContext = _toastContext(context);
  final before = _priceFieldsOf(item);
  AvoToast.show(
    toastContext,
    message: message,
    actionLabel: toastContext.tr('common_undo'),
    onAction: () => unawaited(_quietly(notifier.updateItem(item.id, before))),
  );
  try {
    await notifier.updateItem(item.id, fields);
  } catch (e) {
    debugPrint('❌ [OFFERS] Price of an item not saved: $e');
    unawaited(AvoHaptics.error());
    if (!toastContext.mounted) return;
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
            fields: fields,
            message: message,
          ),
        );
      },
    );
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
  fields: offerPriceFields(offer),
  message: context.tr('offer_toast_price_taken', params: {'item': item.name}),
);

/// "Übernommenen Preis entfernen"; toast "Preis für Milch entfernt".
Future<void> removeOfferPrice(
  BuildContext context, {
  required String listId,
  required ShoppingItemModel item,
}) => _writePrice(
  context,
  listId: listId,
  item: item,
  fields: _noPrice,
  message: context.tr('offer_toast_price_removed', params: {'item': item.name}),
);

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
/// item; an attached offer always says "Angebot an Milch angehängt".
/// VoiceOver hears "Milch hinzugefügt, im Angebot". Returns false when the
/// write failed (the toast then says "Nicht hinzugefügt").
Future<bool> addOfferToList(
  BuildContext context, {
  required String listId,
  required String name,
  required StoreOffer offer,
  double quantity = 1,
  String? unit,
  String? listName,
}) async {
  final container = ProviderScope.containerOf(context, listen: false);
  final notifier = container.read(itemsNotifierProvider(listId).notifier);
  final toastContext = _toastContext(context);
  final direction = Directionality.of(context);
  final trimmed = name.trim();
  final key = trimmed.toLowerCase();
  final items =
      container.read(itemsNotifierProvider(listId)).valueOrNull ?? const [];
  final open = items
      .where((i) => !i.isChecked && i.name.trim().toLowerCase() == key)
      .firstOrNull;

  if (open != null) {
    _announce(toastContext, trimmed, direction);
    await _writePrice(
      toastContext,
      listId: listId,
      item: open,
      fields: offerPriceFields(offer),
      message: toastContext.tr(
        'offer_toast_attached',
        params: {'item': open.name},
      ),
    );
    return true;
  }

  final started = DateTime.now();
  final fields = offerPriceFields(offer);
  try {
    await notifier.addItem(
      name: trimmed,
      quantity: quantity,
      unit: unit,
      price: offer.price,
      priceCurrency: fields['price_currency'] as String,
      priceRetailer: fields['price_retailer'] as String,
      priceUnit: fields['price_unit'] as String?,
      priceOldValue: offer.regularPrice,
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
            ),
          );
        },
      );
    }
    return false;
  }
  if (!toastContext.mounted) return true;
  _announce(toastContext, trimmed, direction);
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

void _announce(BuildContext context, String item, TextDirection direction) {
  final view = View.maybeOf(context);
  if (view == null) return;
  unawaited(
    SemanticsService.sendAnnouncement(
      view,
      context.tr('offer_suggest_added_a11y', params: {'item': item}),
      direction,
    ),
  );
}
