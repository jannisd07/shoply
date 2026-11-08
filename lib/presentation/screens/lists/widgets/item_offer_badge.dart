import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:shoply/core/design/design.dart';
import 'package:shoply/core/localization/localization_helper.dart';
import 'package:shoply/data/models/shopping_item_model.dart';
import 'package:shoply/presentation/providers/offer_display_prefs_provider.dart';
import 'package:shoply/presentation/providers/price_comparison_provider.dart';
import 'package:shoply/presentation/screens/offers/offer_actions.dart';
import 'package:shoply/presentation/screens/offers/offer_paths.dart';
import 'package:shoply/presentation/screens/offers/offer_text.dart';
import 'package:shoply/presentation/screens/offers/widgets/offer_price_tag.dart';

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
    if (item.isChecked) return const SizedBox.shrink();
    final visible = ref.watch(
      offerSurfaceVisibleProvider((
        surface: OfferSurface.itemOffers,
        listId: listId,
      )),
    );
    if (!visible) return const SizedBox.shrink();
    final offer = ref.watch(
      itemOfferProvider((listId: listId, itemId: item.id)),
    );
    if (offer == null) return const SizedBox.shrink();

    final lang = offerLanguageOf(context);
    final spoken = spokenEuro(offer.price, lang);
    final label = offer.isBroadMatch
        ? context.tr('offer_badge_similar_a11y', params: {'price': spoken})
        : context.tr('offer_badge_a11y', params: {'price': spoken});
    Widget pill = Semantics(
      label: label,
      child: OfferPriceTag(
        price: formatEuro(offer.price, lang),
        uncertain: offer.isBroadMatch,
      ),
    );
    if (!compact) {
      pill = GestureDetector(
        behavior: HitTestBehavior.opaque,
        excludeFromSemantics: true,
        onTap: () {
          rememberOffer(context, offer);
          context.push(
            offerDetailLocation(
              offer.id,
              listId: listId,
              itemId: item.id,
              mode: OfferDetailMode.take,
            ),
          );
        },
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
