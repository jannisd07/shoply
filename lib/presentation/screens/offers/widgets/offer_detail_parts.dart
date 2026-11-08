/// The pieces of "Angebot" (S5, `angebote.md`): head, values, similar
/// product note, more offers and the main action. The screen composes them
/// in `offer_detail_screen.dart`.
library;

import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:shoply/core/design/design.dart';
import 'package:shoply/core/localization/localization_helper.dart';
import 'package:shoply/data/models/shopping_item_model.dart';
import 'package:shoply/data/models/store_offer.dart';
import 'package:shoply/presentation/providers/offer_lookup_provider.dart';
import 'package:shoply/presentation/providers/region_provider.dart';
import 'package:shoply/presentation/screens/offers/offer_actions.dart';
import 'package:shoply/presentation/screens/offers/offer_paths.dart';
import 'package:shoply/presentation/screens/offers/offer_text.dart';
import 'package:shoply/presentation/screens/offers/widgets/offer_icons.dart';
import 'package:shoply/presentation/screens/offers/widgets/offer_price_tag.dart';
import 'package:shoply/presentation/screens/offers/widgets/offer_row.dart';
import 'package:shoply/presentation/screens/offers/widgets/store_mark.dart';
import 'package:shoply/presentation/widgets/design/app_button.dart';
import 'package:shoply/presentation/widgets/design/avo_icons.dart';
import 'package:shoply/presentation/widgets/design/inset_section.dart';
import 'package:shoply/presentation/widgets/design/settings_rows.dart';

// D2-Artikel head of the offer detail.
const double _kTile = 64; // D2 category tile in the offer head
const double _kTileRadius = 14; // D2
const double _kTileGlyph = 30; // D2 symbol inside the 64-pt tile
const double _kSimilarIcon = 22; // D2 questionmark.circle
const double _kRowMin = 52; // D2 X-Profil `.row` min-height, like ValueRow

/// At most this many "Weitere Angebote".
const int offerDetailMoreMax = 3;

/// Category tile, product name (a header), market and pack (D2-Artikel
/// head). From AX1 the tile goes.
class OfferDetailHead extends StatelessWidget {
  const OfferDetailHead({super.key, required this.offer, required this.symbol});

  final StoreOffer offer;
  final IconData symbol;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final lang = offerLanguageOf(context);
    final pack = formatPack(offer, lang);
    final meta = context.text(
      AvoTextStyle.subhead,
      color: colors.secondaryLabel,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AvoSpacing.screen),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!context.isAccessibilityText) ...[
            ExcludeSemantics(
              child: Container(
                width: _kTile,
                height: _kTile,
                decoration: BoxDecoration(
                  color: colors.fill,
                  borderRadius: BorderRadius.circular(_kTileRadius),
                ),
                child: Icon(
                  symbol,
                  size: _kTileGlyph,
                  color: colors.secondaryLabel,
                ),
              ),
            ),
            const SizedBox(width: AvoSpacing.l),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Semantics(
                  header: true,
                  child: Text(
                    offerProductTitle(offer),
                    style: context.text(AvoTextStyle.title2),
                  ),
                ),
                const SizedBox(height: AvoSpacing.xxs),
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    StoreLabel(
                      chainId: offerChainId(offer),
                      name: offerStoreName(offer),
                      style: meta,
                    ),
                    if (pack != null)
                      // The dot is for the eye only; VoiceOver reads "1 l".
                      Semantics(
                        label: pack,
                        excludeSemantics: true,
                        child: Text(' · $pack', style: meta),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The big price in its green capsule, "0,99 Euro, Angebotspreis".
class OfferDetailPrice extends StatelessWidget {
  const OfferDetailPrice({super.key, required this.offer});

  final StoreOffer offer;

  @override
  Widget build(BuildContext context) {
    final lang = offerLanguageOf(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AvoSpacing.screen,
        AvoSpacing.l,
        AvoSpacing.screen,
        0,
      ),
      child: Align(
        alignment: AlignmentDirectional.centerStart,
        child: Semantics(
          label: context.tr(
            'offer_price_tag_a11y',
            params: {'price': spokenEuro(offer.price, lang)},
          ),
          child: OfferPriceTag(
            price: formatEuro(offer.price, lang),
            uncertain: offer.isBroadMatch,
            size: OfferPriceTagSize.large,
          ),
        ),
      ),
    );
  }
}

/// "laut Händler statt", "Grundpreis", "Gültig", "Markt", "Region"; a row
/// without data is left out. Values are read out in full ("laut Händler
/// statt, 1,19 Euro").
class OfferDetailValues extends ConsumerWidget {
  const OfferDetailValues({super.key, required this.offer});

  final StoreOffer offer;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = offerLanguageOf(context);
    final region = ref.watch(regionProvider);
    final regular = offer.regularPrice;
    final unitPrice = formatUnitPrice(offer, lang);
    final to = offer.validTo;
    return InsetSection(
      children: [
        if (regular != null)
          _SpokenValueRow(
            title: context.tr('offer_detail_was'),
            value: formatEuro(regular, lang),
            spoken: spokenEuro(regular, lang),
          ),
        if (unitPrice != null)
          _SpokenValueRow(
            title: context.tr('offer_detail_unit_price'),
            value: unitPrice,
            spoken: spokenUnitPrice(offer, lang)!,
          ),
        if (offerHasEnded(offer))
          ValueRow(
            title: context.tr('offer_detail_valid'),
            value: context.tr('offer_detail_expired'),
          )
        else if (to != null)
          _SpokenValueRow(
            title: context.tr('offer_detail_valid'),
            value: offerValidUntil(offer, lang)!,
            spoken: context.tr(
              'offer_valid_until',
              params: {'date': spokenOfferDate(to, lang)},
            ),
          ),
        _StoreValueRow(
          title: context.tr('offer_detail_store'),
          chainId: offerChainId(offer),
          name: offerStoreName(offer),
        ),
        if (region != null)
          ValueRow(
            title: context.tr('offer_detail_area'),
            value: [region.zip, ?region.city].join(' '),
          ),
      ],
    );
  }
}

/// A [ValueRow] that VoiceOver reads with [spoken] for the value.
class _SpokenValueRow extends StatelessWidget {
  const _SpokenValueRow({
    required this.title,
    required this.value,
    required this.spoken,
  });

  final String title;
  final String value;
  final String spoken;

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    label: '$title, $spoken',
    excludeSemantics: true,
    child: ValueRow(title: title, value: value),
  );
}

/// "Markt · [StoreLabel] Lidl" in the look of A's [ValueRow]; from AX1 the
/// value sits below the title. VoiceOver: "Markt, Lidl".
class _StoreValueRow extends StatelessWidget {
  const _StoreValueRow({
    required this.title,
    required this.chainId,
    required this.name,
  });

  final String title;
  final String? chainId;
  final String name;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final label = StoreLabel(
      chainId: chainId,
      name: name,
      style: context.text(AvoTextStyle.body, color: colors.secondaryLabel),
    );
    final titleText = Text(title, style: context.text(AvoTextStyle.body));
    return Semantics(
      container: true,
      label: '$title, $name',
      excludeSemantics: true,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: _kRowMin),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AvoSpacing.l,
            vertical: AvoSpacing.s,
          ),
          child: context.isAccessibilityText
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [titleText, label],
                )
              : Row(
                  children: [
                    Expanded(child: titleText),
                    const SizedBox(width: AvoSpacing.m),
                    Flexible(child: label),
                  ],
                ),
        ),
      ),
    );
  }
}

/// "Ähnliches Produkt. Prüf vor dem Kauf, ob es zu „Milch“ passt."
class OfferSimilarNote extends StatelessWidget {
  const OfferSimilarNote({super.key, required this.itemName});

  final String itemName;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return InsetSection(
      children: [
        Semantics(
          container: true,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AvoSpacing.l,
              vertical: AvoSpacing.m,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AvoIcon(
                  OfferIcons.questionmarkCircle,
                  size: MediaQuery.textScalerOf(context).scale(_kSimilarIcon),
                  color: colors.secondaryLabel,
                ),
                const SizedBox(width: AvoSpacing.m),
                Expanded(
                  child: Text(
                    context.tr(
                      'offer_detail_similar',
                      params: {'item': itemName},
                    ),
                    style: context.text(AvoTextStyle.callout),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// "Weitere Angebote bei Lidl": up to three [OfferRow]s; a tap swaps the
/// offer of the screen.
class OfferMoreSection extends StatelessWidget {
  const OfferMoreSection({
    super.key,
    required this.store,
    required this.offers,
    required this.onSwap,
  });

  final String store;
  final List<StoreOffer> offers;
  final ValueChanged<StoreOffer> onSwap;

  @override
  Widget build(BuildContext context) {
    final lang = offerLanguageOf(context);
    return InsetSection(
      header: context.tr('offer_detail_more_at', params: {'store': store}),
      separatorIndent: context.isAccessibilityText
          ? AvoSpacing.l
          : offerRowTextIndent,
      children: [for (final other in offers) _row(context, other, lang)],
    );
  }

  Widget _row(BuildContext context, StoreOffer other, String lang) {
    final pack = formatPack(other, lang);
    final regular = other.regularPrice;
    final ends = offerEndsLabel(other, lang) ?? offerValidUntil(other, lang);
    final lines = [
      [?pack, ?formatUnitPrice(other, lang)].join(' · '),
      if (regular != null)
        context.tr(
          'offer_was_price',
          params: {'price': formatEuro(regular, lang)},
        ),
      if (other.isBroadMatch) context.tr('offer_similar_product') else ?ends,
    ].where((l) => l.isNotEmpty).toList();
    final spoken = [
      offerProductTitle(other),
      ?pack,
      if (regular != null)
        context.tr(
          'offer_was_price',
          params: {'price': spokenEuro(regular, lang)},
        ),
      context.tr(
        'offer_badge_a11y',
        params: {'price': spokenEuro(other.price, lang)},
      ),
    ].join(', ');
    return OfferRow(
      title: offerProductTitle(other),
      lines: lines,
      price: formatEuro(other.price, lang),
      uncertain: other.isBroadMatch,
      semanticLabel: spoken,
      onTap: () {
        rememberOffer(context, other);
        onSwap(other);
      },
    );
  }
}

/// What the main action of the offer detail is.
enum OfferDetailAction { none, ended, take, remove, add }

/// The main action for [offer] in [mode]: ended offers disable it, a taken
/// price can be removed, "Auf die Liste" needs a list (without one the menu
/// "Auf welche Liste?" of S10 is still missing).
OfferDetailAction offerDetailActionFor({
  required StoreOffer offer,
  required OfferDetailMode mode,
  required ShoppingItemModel? item,
  required String? listId,
}) {
  if (offerHasEnded(offer)) return OfferDetailAction.ended;
  if (listId == null) return OfferDetailAction.none;
  if (mode == OfferDetailMode.take && item != null) {
    return isOfferPriceTaken(item, offer)
        ? OfferDetailAction.remove
        : OfferDetailAction.take;
  }
  return OfferDetailAction.add;
}

/// The large main action at the bottom of the offer detail. Every action
/// starts its write, then [onDone] closes the screen; the undo toast shows
/// where the person came from.
class OfferDetailButton extends ConsumerWidget {
  const OfferDetailButton({
    super.key,
    required this.action,
    required this.offer,
    required this.item,
    required this.listId,
    required this.itemName,
    required this.onDone,
  });

  final OfferDetailAction action;
  final StoreOffer offer;
  final ShoppingItemModel? item;
  final String? listId;
  final String itemName;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final list = listId;
    final current = item;
    switch (action) {
      case OfferDetailAction.none:
        return const SizedBox.shrink();
      case OfferDetailAction.ended:
        return AppButton.primary(
          label: context.tr('offer_detail_expired_action'),
          size: AppButtonSize.large,
          expand: true,
          floating: true,
        );
      case OfferDetailAction.remove:
        return AppButton.secondary(
          label: context.tr('offer_detail_remove_price'),
          size: AppButtonSize.large,
          expand: true,
          floating: true,
          onPressed: () {
            unawaited(removeOfferPrice(context, listId: list!, item: current!));
            onDone();
          },
        );
      case OfferDetailAction.take:
        return AppButton.primary(
          label: context.tr('offer_detail_take_price'),
          size: AppButtonSize.large,
          expand: true,
          floating: true,
          onPressed: () {
            unawaited(
              takeOfferPrice(
                context,
                listId: list!,
                item: current!,
                offer: offer,
              ),
            );
            onDone();
          },
        );
      case OfferDetailAction.add:
        final listName = ref.watch(offerListNameProvider(list!));
        return AppButton.primary(
          label: context.tr('offer_detail_add_to_list'),
          size: AppButtonSize.large,
          expand: true,
          floating: true,
          onPressed: () {
            unawaited(
              addOfferToList(
                context,
                listId: list,
                name: itemName,
                offer: offer,
                listName: listName,
              ),
            );
            onDone();
          },
        );
    }
  }
}
