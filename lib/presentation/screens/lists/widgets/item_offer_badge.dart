import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:shoply/core/design/design.dart';
import 'package:shoply/core/localization/localization_helper.dart';
import 'package:shoply/data/models/shopping_item_model.dart';
import 'package:shoply/data/models/store_offer.dart';
import 'package:shoply/presentation/providers/offer_display_prefs_provider.dart';
import 'package:shoply/presentation/providers/price_comparison_provider.dart';
import 'package:shoply/presentation/screens/offers/offer_actions.dart';
import 'package:shoply/presentation/screens/offers/offer_paths.dart';
import 'package:shoply/presentation/screens/offers/offer_text.dart';
import 'package:shoply/presentation/screens/offers/widgets/offer_price_tag.dart';
import 'package:shoply/presentation/widgets/design/avo_icons.dart';
import 'package:shoply/presentation/widgets/design/avo_menu.dart';

/// Room around the pill inside its 44-pt target (`angebote.md` 3.9).
const double _kTargetInset = AvoSpacing.xs; // D2 target = pill + 8 (3.9)

/// The offer pill at one item of a list (S3, contract `b_slots.dart`): the
/// price of the item's current offer at the list's market, "0,99 €", with a
/// question mark for a similar product.
///
/// In a normal list a tap on the pill (44-pt target) opens the offer to take
/// its price; [compact] (shopping mode) is not tappable on its own, there the
/// row checks the item off. The pill adds its sentence to the row's
/// VoiceOver label ("im Angebot 0,99 Euro laut Händler").
///
/// Renders nothing, and asks the offers source nothing, while offers are off
/// (module, kill switch), hidden on [listId], without a real region, with
/// "Angebote an Artikeln" off, for a checked item, or without an offer. It
/// shows only offers the list's cached snapshot knows; it fades in where the
/// row already has room.
class ItemOfferBadge extends ConsumerWidget {
  const ItemOfferBadge({
    super.key,
    required this.listId,
    required this.item,
    this.compact = false,
  });

  final String listId;
  final ShoppingItemModel item;
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final offer = _shownOffer(ref, listId, item);
    if (offer == null) return const SizedBox.shrink();

    final lang = offerLanguageOf(context);
    Widget pill = Semantics(
      label: _spokenPill(context, offer),
      child: OfferPriceTag(
        price: formatEuro(offer.price, lang),
        uncertain: offer.isBroadMatch,
      ),
    );
    if (!compact) {
      pill = GestureDetector(
        behavior: HitTestBehavior.opaque,
        excludeFromSemantics: true,
        onTap: () => _openOffer(context, offer, listId, item),
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minWidth: AvoSizes.hitTarget,
            minHeight: AvoSizes.hitTarget,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: _kTargetInset),
            child: Center(widthFactor: 1, child: pill),
          ),
        ),
      );
    }
    return _FadeIn(child: pill);
  }
}

/// What Teil A's `ItemRow` needs from the offer pill of one item (S3,
/// request A-C1), for `trailingSemanticsLabel`, `trailingActions` and
/// `contextMenuItems`:
///
/// - [semanticsLabel]: the pill's sentence ("im Angebot 0,99 Euro laut
///   Händler"); with it the row hides the slot's own semantics.
/// - [actions]: "Angebot ansehen" as a custom action of the row (normal list
///   and shopping mode).
/// - [menuItems]: "Angebot ansehen" for the row's long-press menu, only in
///   shopping mode, where the pill is not tappable on its own.
@immutable
class ItemOfferRowExtras {
  const ItemOfferRowExtras({
    required this.semanticsLabel,
    required this.actions,
    required this.menuItems,
  });

  final String semanticsLabel;
  final Map<String, VoidCallback> actions;
  final List<AvoMenuEntry> menuItems;
}

/// The [ItemOfferRowExtras] for [item] on [listId], or null while the pill
/// shows nothing (the same rules as [ItemOfferBadge]; then pass nothing to
/// the row). Call it in the row's `build` with its [WidgetRef]: it watches
/// the same providers as the pill, so both change together. [shoppingMode]
/// as for `ItemOfferBadge(compact:)`.
ItemOfferRowExtras? itemOfferRowExtras(
  BuildContext context,
  WidgetRef ref, {
  required String listId,
  required ShoppingItemModel item,
  bool shoppingMode = false,
}) {
  final offer = _shownOffer(ref, listId, item);
  if (offer == null) return null;
  final view = context.tr('offer_action_view');
  void open() => _openOffer(context, offer, listId, item);
  return ItemOfferRowExtras(
    semanticsLabel: _spokenPill(context, offer),
    actions: {view: open},
    menuItems: shoppingMode
        ? [AvoMenuItem(label: view, icon: AvoIcons.tag, onSelected: open)]
        : const [],
  );
}

/// The offer the pill shows, or null (offers off, hidden on the list, no
/// region, "Angebote an Artikeln" off, checked item, no offer).
StoreOffer? _shownOffer(WidgetRef ref, String listId, ShoppingItemModel item) {
  if (item.isChecked) return null;
  final visible = ref.watch(
    offerSurfaceVisibleProvider((
      surface: OfferSurface.itemOffers,
      listId: listId,
    )),
  );
  if (!visible) return null;
  return ref.watch(itemOfferProvider((listId: listId, itemId: item.id)));
}

String _spokenPill(BuildContext context, StoreOffer offer) {
  final spoken = spokenEuro(offer.price, offerLanguageOf(context));
  return offer.isBroadMatch
      ? context.tr('offer_badge_similar_a11y', params: {'price': spoken})
      : context.tr('offer_badge_a11y', params: {'price': spoken});
}

/// S5 with "Preis übernehmen" for the item.
void _openOffer(
  BuildContext context,
  StoreOffer offer,
  String listId,
  ShoppingItemModel item,
) {
  rememberOffer(context, offer);
  unawaited(
    context.push(
      offerDetailLocation(
        offer.id,
        listId: listId,
        itemId: item.id,
        mode: OfferDetailMode.take,
      ),
    ),
  );
}

/// A short fade when the pill first appears (no change of the row height).
class _FadeIn extends StatelessWidget {
  const _FadeIn({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween(begin: 0, end: 1),
    duration: AvoMotion.fadeReduced,
    child: child,
    builder: (context, opacity, child) =>
        Opacity(opacity: opacity, child: child),
  );
}
