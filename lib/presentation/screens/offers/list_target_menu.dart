/// "Auf welche Liste?" (S10, `angebote.md`): the pull-down menu out of a
/// `plus.circle` (and of "Auf die Liste" in S5 without a list) that puts an
/// offer on one of the person's lists. No check marks; the list of today
/// first, then by last change. A list whose market is another one stays
/// pickable: then only the item goes on, without the offer.
library;

import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:shoply/core/localization/localization_helper.dart';
import 'package:shoply/data/models/shopping_list_model.dart';
import 'package:shoply/data/models/store_offer.dart';
import 'package:shoply/presentation/providers/offer_lookup_provider.dart';
import 'package:shoply/presentation/providers/store_for_list_provider.dart';
import 'package:shoply/presentation/screens/lists/widgets/all_lists_new_list.dart';
import 'package:shoply/presentation/screens/offers/offer_actions.dart';
import 'package:shoply/presentation/screens/offers/offer_text.dart';
import 'package:shoply/presentation/screens/offers/store_menu.dart';
import 'package:shoply/presentation/state/last_list_provider.dart';
import 'package:shoply/presentation/state/lists_provider.dart';
import 'package:shoply/presentation/widgets/design/avo_icons.dart';
import 'package:shoply/presentation/widgets/design/avo_menu.dart';

/// A list the menu offers.
@immutable
class OfferTargetList {
  const OfferTargetList({required this.id, required this.name});

  final String id;
  final String name;
}

/// The person's lists for the menu: the list of today (opened last) first,
/// then by last change. Override in tests.
final offerTargetListsProvider = Provider.autoDispose<List<OfferTargetList>>((
  ref,
) {
  final lists = [...?ref.watch(listsNotifierProvider).valueOrNull]
    ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  String? today;
  try {
    today = ref.watch(lastAccessedListProvider).valueOrNull;
  } catch (_) {
    today = null;
  }
  final first = lists.where((l) => l.id == today).toList();
  return [
    for (final l in [...first, ...lists.where((l) => l.id != today)])
      OfferTargetList(id: l.id, name: l.name.trim()),
  ];
});

/// A's editor for a new list ("Neue Liste …"); override in tests.
final newListOpenerProvider =
    Provider<Future<ShoppingListModel?> Function(BuildContext context)>(
      (ref) => openNewListEditor,
    );

/// Opens "Auf welche Liste?" out of [anchor] for [offer], put on as [name]
/// ("Haferflocken", not the product name) with [quantity]. [onPicked] runs
/// once a list was chosen (the offer detail closes then); for "Neue Liste …"
/// only after the new list exists, so cancelling its editor keeps the
/// screen that asked.
Future<void> showListTargetMenu(
  BuildContext anchor,
  WidgetRef ref, {
  required StoreOffer offer,
  required String name,
  double quantity = 1,
  VoidCallback? onPicked,
}) {
  final chain = offerChainId(offer);
  final lists = ref.read(offerTargetListsProvider);
  rememberOffer(anchor, offer);

  AvoMenuItem entry(OfferTargetList list) {
    final market = ref.read(cachedStoreOfListProvider(list.id));
    final applies = market == null || chain == null || market == chain;
    final subtitle = market == null
        ? null
        : applies
        ? storeNameOf(market)
        : anchor.tr(
            'offer_menu_not_valid_there',
            params: {'store': storeNameOf(market)},
          );
    return AvoMenuItem(
      label: list.name,
      subtitle: subtitle,
      onSelected: () {
        onPicked?.call();
        unawaited(
          applies
              ? addOfferToList(
                  anchor,
                  listId: list.id,
                  name: name,
                  offer: offer,
                  quantity: quantity,
                  listName: list.name,
                  otherList: true,
                )
              : addWithoutOffer(
                  anchor,
                  listId: list.id,
                  listName: list.name,
                  name: name,
                  offer: offer,
                  quantity: quantity,
                ),
        );
      },
    );
  }

  return showAvoMenu(
    anchor,
    semanticLabel: anchor.tr('offer_menu_which_list'),
    items: [
      for (final list in lists) entry(list),
      const AvoMenuDivider(),
      AvoMenuItem(
        label: anchor.tr('offer_menu_new_list'),
        icon: AvoIcons.plus,
        onSelected: () => unawaited(
          _toNewList(
            anchor,
            offer: offer,
            name: name,
            quantity: quantity,
            onCreated: onPicked,
          ),
        ),
      ),
    ],
  );
}

/// "Neue Liste …": A's editor for a new list; the new list gets the offer's
/// market (quietly, the add says what happened) and then the item, with
/// the undo toast. The add runs from the root navigator and the app's
/// providers, so it finishes even when the screen that asked closes
/// ([onCreated], S5).
Future<void> _toNewList(
  BuildContext anchor, {
  required StoreOffer offer,
  required String name,
  required double quantity,
  VoidCallback? onCreated,
}) async {
  final container = ProviderScope.containerOf(anchor, listen: false);
  final root = Navigator.of(anchor, rootNavigator: true).context;
  final list = await container.read(newListOpenerProvider)(anchor);
  if (list == null || !root.mounted) return;
  final chain = offerChainId(offer);
  final added = Future<void>(() async {
    if (chain != null) {
      try {
        await container
            .read(listStoreRepositoryProvider)
            .setExplicit(list.id, chain);
      } catch (e) {
        debugPrint('⚠️ [OFFERS] Market of the new list not saved: $e');
      }
    }
    if (!root.mounted) return;
    await addOfferToList(
      root,
      listId: list.id,
      name: name,
      offer: offer,
      quantity: quantity,
      listName: list.name.trim(),
      otherList: true,
    );
  });
  onCreated?.call();
  await added;
}
