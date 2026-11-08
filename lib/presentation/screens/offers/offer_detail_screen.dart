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
import 'package:shoply/presentation/providers/offer_lookup_provider.dart';
import 'package:shoply/presentation/screens/lists/widgets/offer_suggestions_bar.dart'
    show offerCategoryOfProvider;
import 'package:shoply/presentation/screens/offers/offer_actions.dart';
import 'package:shoply/presentation/screens/offers/offer_paths.dart';
import 'package:shoply/presentation/screens/offers/offer_text.dart';
import 'package:shoply/presentation/screens/offers/widgets/offer_detail_parts.dart';
import 'package:shoply/presentation/screens/offers/widgets/offers_source_footnote.dart';
import 'package:shoply/presentation/state/items_provider.dart';
import 'package:shoply/presentation/widgets/design/app_button.dart';
import 'package:shoply/presentation/widgets/design/avo_icons.dart';
import 'package:shoply/presentation/widgets/design/empty_state.dart';
import 'package:shoply/presentation/widgets/design/glass_icon_button.dart';
import 'package:shoply/presentation/widgets/design/glass_toolbar.dart';

const double _kActionBottom = 28; // D2: 28 above the bottom edge
const double _kActionMinHeight = 54; // D2 large primary button

/// "Angebot" (S5, `/offers/offer/:offerId`, full screen above the tab bar):
/// what exactly is on offer, and does the person take its price or put it
/// on the list? The offer comes from the device (the session's offers or
/// the list's cached ones), never from the URL; an offer that is no longer
/// saved, or any offer without a real region, shows "Dieses Angebot ist
/// nicht mehr gespeichert."
///
/// [OfferDetailHead], the big price, [OfferDetailValues], the
/// similar-product note, "Nicht dieses Angebot" (take mode), up to three
/// more offers of the market that are already on the device (a tap swaps
/// them in), the source footnote and the main action ([OfferDetailButton]),
/// which floats at the bottom and from AX3 sits at the end of the content.
///
/// Every action closes the screen at once and shows its undo toast where
/// the person came from. When offers switch off while it is open, the route
/// gate in `offers_routes.dart` closes it silently. Never Pro, no figure.
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

  void _swap(StoreOffer next) {
    setState(() => _swapped = next);
    final view = View.maybeOf(context);
    if (view == null) return;
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

  @override
  Widget build(BuildContext context) {
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
    if (offer != null) {
      content = _Body(
        offer: offer,
        item: item,
        listId: listId,
        mode:
            widget.mode ??
            (item != null ? OfferDetailMode.take : OfferDetailMode.add),
        name: widget.name,
        onSwap: _swap,
        onDone: _close,
      );
    } else if (opened.isLoading) {
      content = const SizedBox.shrink();
    } else {
      content = Padding(
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
    }

    return ColoredBox(
      color: context.colors.background,
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

/// The content of an offer: the parts in reading order, the main action
/// floating below (or last from AX3).
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
    final list = listId;
    final current = item;
    final symbol = Categories.getById(
      current?.categoryId ??
          current?.category ??
          ref.watch(offerCategoryOfProvider)(_itemName),
    ).icon;
    final more = list == null
        ? const <StoreOffer>[]
        : ref
              .watch(cachedMoreOffersProvider((listId: list, query: _itemName)))
              .where((o) => o.id != offer.id && o.isValidNow)
              .take(offerDetailMoreMax)
              .toList();
    final kind = offerDetailActionFor(
      offer: offer,
      mode: mode,
      item: current,
      listId: list,
    );
    final action = kind == OfferDetailAction.none
        ? null
        : OfferDetailButton(
            action: kind,
            offer: offer,
            item: current,
            listId: list,
            itemName: _itemName,
            onDone: onDone,
          );
    final floating =
        context.typography.category.index < ContentSizeCategory.ax3.index;

    final children = <Widget>[
      OfferDetailHead(offer: offer, symbol: symbol),
      OfferDetailPrice(offer: offer),
      Padding(
        padding: const EdgeInsets.only(top: AvoSpacing.section),
        child: OfferDetailValues(offer: offer),
      ),
      if (offer.isBroadMatch)
        Padding(
          padding: const EdgeInsets.only(top: AvoSpacing.section),
          child: OfferSimilarNote(itemName: _itemName),
        ),
      if (mode == OfferDetailMode.take && current != null)
        Padding(
          padding: const EdgeInsets.only(top: AvoSpacing.l),
          child: Center(
            child: AppButton.plain(
              label: context.tr('offer_detail_not_this'),
              onPressed: () {
                unawaited(declineOffer(context, item: current, offer: offer));
                onDone();
              },
            ),
          ),
        ),
      if (more.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(top: AvoSpacing.s),
          child: OfferMoreSection(
            store: offerStoreName(offer),
            offers: more,
            onSwap: onSwap,
          ),
        ),
      const Padding(
        padding: EdgeInsets.only(top: AvoSpacing.s),
        child: OffersSourceFootnote(),
      ),
      if (action != null && !floating)
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
    final actionSpace = action != null && floating
        ? math.max(
                _kActionMinHeight,
                context.typography.lineHeightOf(AvoTextStyle.headline) +
                    AvoSpacing.xxxl,
              ) +
              _kActionBottom
        : 0.0;
    final scroll = ListView(
      padding: EdgeInsets.only(
        top:
            GlassToolbar.topOffset(context) +
            AvoSizes.toolbarButton +
            AvoSpacing.l,
        bottom: bottomSafe + AvoSpacing.section + actionSpace,
      ),
      children: children,
    );
    if (action == null || !floating) return scroll;
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
}
