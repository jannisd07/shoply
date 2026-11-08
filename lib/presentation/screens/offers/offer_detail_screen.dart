import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/semantics.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:shoply/core/constants/categories.dart';
import 'package:shoply/core/design/design.dart';
import 'package:shoply/core/localization/localization_helper.dart';
import 'package:shoply/data/models/shopping_item_model.dart';
import 'package:shoply/data/models/store_offer.dart';
import 'package:shoply/presentation/providers/app_flags_provider.dart';
import 'package:shoply/presentation/providers/offer_lookup_provider.dart';
import 'package:shoply/presentation/providers/price_comparison_provider.dart';
import 'package:shoply/presentation/providers/region_provider.dart';
import 'package:shoply/presentation/screens/lists/widgets/offer_suggestions_bar.dart'
    show offerCategoryOfProvider;
import 'package:shoply/presentation/screens/offers/offer_actions.dart';
import 'package:shoply/presentation/screens/offers/offer_paths.dart';
import 'package:shoply/presentation/screens/offers/offer_text.dart';
import 'package:shoply/presentation/screens/offers/widgets/offer_icons.dart';
import 'package:shoply/presentation/screens/offers/widgets/offer_price_tag.dart';
import 'package:shoply/presentation/screens/offers/widgets/offer_row.dart';
import 'package:shoply/presentation/screens/offers/widgets/offers_source_footnote.dart';
import 'package:shoply/presentation/screens/offers/widgets/store_mark.dart';
import 'package:shoply/presentation/state/items_provider.dart';
import 'package:shoply/presentation/widgets/design/app_button.dart';
import 'package:shoply/presentation/widgets/design/avo_icons.dart';
import 'package:shoply/presentation/widgets/design/empty_state.dart';
import 'package:shoply/presentation/widgets/design/glass_icon_button.dart';
import 'package:shoply/presentation/widgets/design/glass_toolbar.dart';
import 'package:shoply/presentation/widgets/design/inset_section.dart';
import 'package:shoply/presentation/widgets/design/settings_rows.dart';

// D2-Artikel head of the offer detail (`angebote.md` S5).
const double _kTile = 64; // D2 category tile in the offer head
const double _kTileRadius = 14; // D2
const double _kTileGlyph = 30;
const double _kSimilarIcon = 22; // D2 questionmark.circle
const double _kActionBottom = 28; // D2: 28 above the bottom edge
const double _kActionMinHeight = 54; // D2 large primary button
const int _kMoreOffers = 3;

/// "Angebot" (S5, `/offers/offer/:offerId`, full screen above the tab bar):
/// what exactly is on offer, and does the person take its price or put it
/// on the list? The offer comes from the device (the session's offers or
/// the list's cached ones), never from the URL; an offer that is no longer
/// saved shows "Dieses Angebot ist nicht mehr gespeichert."
///
/// Head with the category symbol, product, market and pack; the big price;
/// "laut Händler statt", "Grundpreis", "Gültig", "Markt", "Region" (missing
/// data leaves its row out); the similar-product note; "Nicht dieses
/// Angebot" (take mode); up to three more offers of the same market (a tap
/// swaps them in); the source footnote; at the bottom "Preis übernehmen"
/// (take) or "Auf die Liste" (add), "Übernommenen Preis entfernen" once
/// taken, disabled "Angebot abgelaufen" after the end. From AX3 the main
/// action sits at the end of the content instead of floating.
///
/// Every action closes the screen at once and shows its undo toast where
/// the person came from. Closes by itself when offers are switched off
/// while it is open. Never Pro, no Avo figure.
class OfferDetailScreen extends ConsumerStatefulWidget {
  const OfferDetailScreen({
    super.key,
    required this.offerId,
    this.listId,
    this.itemId,
    this.mode,
    this.name,
  });

  final int offerId;
  final String? listId;
  final String? itemId;

  /// Null: take with an item, add without.
  final OfferDetailMode? mode;

  /// The item name "Auf die Liste" uses; defaults to the product name.
  final String? name;

  @override
  ConsumerState<OfferDetailScreen> createState() => _OfferDetailScreenState();
}

class _OfferDetailScreenState extends ConsumerState<OfferDetailScreen> {
  /// An offer from "Weitere Angebote" that replaced the opened one.
  StoreOffer? _swapped;

  void _close() {
    if (mounted && context.canPop()) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<bool>(offersAvailableProvider, (previous, next) {
      if (previous == true && !next) _close();
    });
    final colors = context.colors;
    final listId = widget.listId;
    final opened = ref.watch(
      offerByIdProvider((offerId: widget.offerId, listId: listId)),
    );
    final offer = _swapped ?? opened.valueOrNull;
    final items = listId == null
        ? const <ShoppingItemModel>[]
        : ref.watch(itemsNotifierProvider(listId)).valueOrNull ??
              const <ShoppingItemModel>[];
    final itemId = widget.itemId;
    final item = itemId == null
        ? null
        : items.where((i) => i.id == itemId).firstOrNull;

    final Widget content;
    if (offer == null) {
      content = opened.isLoading
          ? const SizedBox.shrink()
          : Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AvoSpacing.screen,
                vertical: AvoSpacing.xxxl,
              ),
              child: EmptyState(
                icon: const AvoIcon(AvoIcons.tag),
                title: context.tr('offer_detail_gone'),
                actionLabel: context.tr('back'),
                onAction: _close,
              ),
            );
    } else {
      content = _Body(
        offer: offer,
        item: item,
        listId: listId,
        mode:
            widget.mode ??
            (item != null ? OfferDetailMode.take : OfferDetailMode.add),
        name: widget.name,
        onSwap: (next) {
          setState(() => _swapped = next);
          final view = View.maybeOf(context);
          if (view != null) {
            unawaited(
              SemanticsService.sendAnnouncement(
                view,
                context.tr(
                  'offer_detail_swapped_a11y',
                  params: {'product': offerProductTitle(next)},
                ),
                Directionality.of(context),
              ),
            );
          }
        },
        onDone: _close,
      );
    }

    return ColoredBox(
      color: colors.background,
      child: Stack(
        children: [
          Positioned.fill(child: content),
          const Positioned(top: 0, left: 0, right: 0, child: ScrollEdgeFade()),
          Positioned(
            top: GlassToolbar.topOffset(context),
            left: 0,
            right: 0,
            child: GlassToolbar(
              leading: GlassIconButton(
                icon: const AvoIcon(AvoIcons.chevronBack),
                semanticLabel: context.tr('back'),
                onPressed: _close,
              ),
              title: context.tr('offer_detail_title'),
            ),
          ),
        ],
      ),
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({
    required this.offer,
    required this.item,
    required this.listId,
    required this.mode,
    required this.name,
    required this.onSwap,
    required this.onDone,
  });

  final StoreOffer offer;
  final ShoppingItemModel? item;
  final String? listId;
  final OfferDetailMode mode;
  final String? name;
  final ValueChanged<StoreOffer> onSwap;
  final VoidCallback onDone;

  /// The item the offer is for, as the person calls it ("Milch").
  String get _itemName =>
      item?.name.trim() ??
      (name?.trim().isNotEmpty == true ? name!.trim() : offer.productName);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final lang = offerLanguageOf(context);
    final ax = context.isAccessibilityText;
    final floatAction =
        context.typography.category.index < ContentSizeCategory.ax3.index;
    final ended = offerHasEnded(offer);
    final store = offerStoreName(offer);
    final chainId = offerChainId(offer);
    final pack = formatPack(offer, lang);
    final region = ref.watch(regionProvider);
    final list = listId;

    // ---- head
    final symbol = Categories.getById(
      item?.categoryId ??
          item?.category ??
          ref.watch(offerCategoryOfProvider)(_itemName),
    ).icon;
    final head = Padding(
      padding: const EdgeInsets.symmetric(horizontal: AvoSpacing.screen),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!ax) ...[
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
                      chainId: chainId,
                      name: store,
                      style: context.text(
                        AvoTextStyle.subhead,
                        color: colors.secondaryLabel,
                      ),
                    ),
                    if (pack != null)
                      // The dot is for the eye only; VoiceOver reads "1 l".
                      Semantics(
                        label: pack,
                        excludeSemantics: true,
                        child: Text(
                          ' · $pack',
                          style: context.text(
                            AvoTextStyle.subhead,
                            color: colors.secondaryLabel,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );

    // ---- big price
    final price = Padding(
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

    // ---- values
    final regular = offer.regularPrice;
    final unitPrice = formatUnitPrice(offer, lang);
    final to = offer.validTo;
    final values = InsetSection(
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
        if (ended)
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
        ValueRow(title: context.tr('offer_detail_store'), value: store),
        if (region != null)
          ValueRow(
            title: context.tr('offer_detail_area'),
            value: [region.zip, ?region.city].join(' '),
          ),
      ],
    );

    // ---- similar product
    final similar = offer.isBroadMatch
        ? Padding(
            padding: const EdgeInsets.only(top: AvoSpacing.section),
            child: InsetSection(
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
                          size: MediaQuery.textScalerOf(
                            context,
                          ).scale(_kSimilarIcon),
                          color: colors.secondaryLabel,
                        ),
                        const SizedBox(width: AvoSpacing.m),
                        Expanded(
                          child: Text(
                            context.tr(
                              'offer_detail_similar',
                              params: {'item': _itemName},
                            ),
                            style: context.text(AvoTextStyle.callout),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          )
        : null;

    // ---- more offers of the market
    final more = list == null
        ? const <StoreOffer>[]
        : (ref
                      .watch(
                        offerSuggestionsProvider((
                          listId: list,
                          query: _itemName,
                        )),
                      )
                      .valueOrNull ??
                  const <StoreOffer>[])
              .where((o) => o.id != offer.id && o.isValidNow)
              .take(_kMoreOffers)
              .toList();

    // ---- main action
    final taken = item != null && isOfferPriceTaken(item!, offer);
    final Widget? action = _action(context, ref, ended: ended, taken: taken);

    final children = <Widget>[
      head,
      price,
      Padding(
        padding: const EdgeInsets.only(top: AvoSpacing.section),
        child: values,
      ),
      ?similar,
      if (mode == OfferDetailMode.take && item != null)
        Padding(
          padding: const EdgeInsets.only(top: AvoSpacing.l),
          child: Center(
            child: AppButton.plain(
              label: context.tr('offer_detail_not_this'),
              onPressed: () {
                unawaited(declineOffer(context, item: item!, offer: offer));
                onDone();
              },
            ),
          ),
        ),
      if (more.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(top: AvoSpacing.s),
          child: InsetSection(
            header: context.tr(
              'offer_detail_more_at',
              params: {'store': store},
            ),
            separatorIndent: ax ? AvoSpacing.l : offerRowTextIndent,
            children: [
              for (final other in more) _moreRow(context, ref, other, lang),
            ],
          ),
        ),
      const Padding(
        padding: EdgeInsets.only(top: AvoSpacing.s),
        child: OffersSourceFootnote(),
      ),
      if (action != null && !floatAction)
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AvoSpacing.screen,
            AvoSpacing.section,
            AvoSpacing.screen,
            0,
          ),
          child: action,
        ),
    ];

    final bottomSafe = MediaQuery.paddingOf(context).bottom;
    final scroll = ListView(
      padding: EdgeInsets.only(
        top:
            GlassToolbar.topOffset(context) +
            AvoSizes.toolbarButton +
            AvoSpacing.l,
        bottom:
            bottomSafe +
            AvoSpacing.section +
            (action != null && floatAction
                ? math.max(
                        _kActionMinHeight,
                        context.typography.lineHeightOf(AvoTextStyle.headline) +
                            AvoSpacing.xxxl,
                      ) +
                      _kActionBottom
                : 0),
      ),
      children: children,
    );
    if (action == null || !floatAction) return scroll;
    return Stack(
      children: [
        Positioned.fill(child: scroll),
        Positioned(
          left: AvoSpacing.screen,
          right: AvoSpacing.screen,
          bottom: bottomSafe + _kActionBottom,
          child: action,
        ),
      ],
    );
  }

  Widget? _action(
    BuildContext context,
    WidgetRef ref, {
    required bool ended,
    required bool taken,
  }) {
    final list = listId;
    final currentItem = item;
    if (ended) {
      return AppButton.primary(
        label: context.tr('offer_detail_expired_action'),
        size: AppButtonSize.large,
        expand: true,
        floating: true,
      );
    }
    if (mode == OfferDetailMode.take && currentItem != null && list != null) {
      if (taken) {
        return AppButton.secondary(
          label: context.tr('offer_detail_remove_price'),
          size: AppButtonSize.large,
          expand: true,
          floating: true,
          onPressed: () {
            unawaited(
              removeOfferPrice(context, listId: list, item: currentItem),
            );
            onDone();
          },
        );
      }
      return AppButton.primary(
        label: context.tr('offer_detail_take_price'),
        size: AppButtonSize.large,
        expand: true,
        floating: true,
        onPressed: () {
          unawaited(
            takeOfferPrice(
              context,
              listId: list,
              item: currentItem,
              offer: offer,
            ),
          );
          onDone();
        },
      );
    }
    // "Auf die Liste" without a list needs the menu "Auf welche Liste?"
    // (S10, a later slice): no action until then.
    if (list == null) return null;
    final listName = ref.watch(offerListNameProvider(list));
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
            name: _itemName,
            offer: offer,
            listName: listName,
          ),
        );
        onDone();
      },
    );
  }

  Widget _moreRow(
    BuildContext context,
    WidgetRef ref,
    StoreOffer other,
    String lang,
  ) {
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

/// A [ValueRow] that VoiceOver reads with [spoken] for the value ("laut
/// Händler statt, 1,19 Euro").
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
