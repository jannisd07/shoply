import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:shoply/core/constants/categories.dart';
import 'package:shoply/core/design/design.dart';
import 'package:shoply/core/localization/localization_helper.dart';
import 'package:shoply/core/utils/item_quantity.dart';
import 'package:shoply/data/models/shopping_item_model.dart';
import 'package:shoply/data/models/store_offer.dart';
import 'package:shoply/data/services/connectivity_service.dart';
import 'package:shoply/data/services/offer_savings.dart';
import 'package:shoply/presentation/providers/list_offer_prefs_provider.dart';
import 'package:shoply/presentation/providers/offer_display_prefs_provider.dart';
import 'package:shoply/presentation/providers/offer_lookup_provider.dart';
import 'package:shoply/presentation/providers/price_comparison_provider.dart';
import 'package:shoply/presentation/providers/region_provider.dart';
import 'package:shoply/presentation/providers/store_for_list_provider.dart';
import 'package:shoply/presentation/providers/weekly_offers_provider.dart';
import 'package:shoply/presentation/screens/lists/widgets/offer_suggestions_bar.dart'
    show offerCategoryOfProvider;
import 'package:shoply/presentation/screens/offers/offer_actions.dart';
import 'package:shoply/presentation/screens/offers/offer_paths.dart';
import 'package:shoply/presentation/screens/offers/offer_text.dart';
import 'package:shoply/presentation/screens/offers/store_menu.dart';
import 'package:shoply/presentation/screens/offers/widgets/offer_entry_row.dart';
import 'package:shoply/presentation/screens/offers/widgets/offers_page.dart';
import 'package:shoply/presentation/screens/offers/widgets/offers_source_footnote.dart';
import 'package:shoply/presentation/screens/offers/widgets/postcode_hint.dart';
import 'package:shoply/presentation/widgets/design/avo_icons.dart';
import 'package:shoply/presentation/widgets/design/empty_state.dart';
import 'package:shoply/presentation/widgets/design/inset_section.dart';
import 'package:shoply/presentation/widgets/design/skeleton.dart';
import 'package:shoply/presentation/widgets/design/status_row.dart';
import 'package:shoply/presentation/widgets/design/undo_toast.dart';

/// At most this many regulars in "Diese Woche bei Lidl, oft gekauft".
const int _kRegularsMax = 3;

/// "Angebote bei {Markt}" (S9, `/offers/list/:listId`, a child in the
/// Listen tab): which items of this list are on offer at its market?
///
/// A large title, the mandatory sentence, "Auf deiner Liste" with the
/// offers in the list's order (never by discount; a row opens the offer
/// with "Preis übernehmen"), "Diese Woche bei Lidl, oft gekauft" with up to
/// three regulars that are not on the list (plus puts one on, it joins the
/// first group), "Alle Angebote der Woche" and "Angebote für diese Liste
/// ausblenden" (green, it only hides), then the savings explanation and the
/// source footnote. Pull to refresh renews the list's offers.
///
/// States: skeleton on the very first opening without a local copy,
/// offline with the time of the copy, a failed refresh above the kept
/// content, "Gerade nichts im Angebot.", no region, hidden offers, a list
/// without a market. Module and kill switch are the route gate's. No
/// figure (money), never Pro.
class ListOffersScreen extends ConsumerWidget {
  const ListOffersScreen({super.key, required this.listId});

  final String listId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final listName = ref.watch(offerListNameProvider(listId)) ?? '';
    final guess = ref.watch(storeGuessForListProvider(listId));
    final market = ref.watch(storeForListProvider(listId))?.id;
    final title = market == null
        ? context.tr('offer_list_title_no_store', params: {'list': listName})
        : context.tr(
            'offer_list_title',
            params: {'store': storeNameOf(market)},
          );
    return OffersPage(
      title: guess.hasValue ? title : '',
      onRefresh: market == null ? null : () => refreshListOffers(ref, listId),
      children: [
        _Body(listId: listId, listName: listName, market: market, guess: guess),
      ],
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({
    required this.listId,
    required this.listName,
    required this.market,
    required this.guess,
  });

  final String listId;
  final String listName;
  final String? market;
  final AsyncValue<Object?> guess;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(regionLoadedProvider) ||
        ref.watch(hiddenOfferListsProvider) == null ||
        !guess.hasValue) {
      return const SizedBox.shrink();
    }
    if (ref.watch(offersHiddenForListProvider(listId))) {
      return EmptyState(
        icon: const AvoIcon(AvoIcons.eyeSlash),
        title: context.tr(
          'offer_list_hidden_title',
          params: {'list': listName},
        ),
        actionLabel: context.tr('offer_show_again'),
        onAction: () => unawaited(setOffersHiddenForList(ref, listId, false)),
      );
    }
    if (ref.watch(regionProvider) == null) {
      return EmptyState(
        icon: const AvoIcon(AvoIcons.location),
        title: context.tr('offer_need_area_title'),
        actionLabel: context.tr('offer_need_area_action'),
        onAction: () => unawaited(openRegionFromList(context)),
      );
    }
    final chain = market;
    if (chain == null) {
      // Lists without a market have no offers yet (favourites rule
      // K12-03 is not built); the way out is choosing the market.
      return EmptyState(
        icon: const AvoIcon(AvoIcons.storefront),
        title: context.tr('offer_hint_no_store', params: {'list': listName}),
        actionLabel: context.tr('offer_store_choose'),
        onAction: () => unawaited(openStorePicker(context, listId: listId)),
      );
    }

    final lang = offerLanguageOf(context);
    final snapshot = ref.watch(listOfferSnapshotProvider(listId));
    final offers = ref.watch(listItemOffersProvider(listId));
    final items = ref.watch(offerListItemsProvider(listId));
    final summary = ref.watch(listOfferSummaryProvider(listId));
    final rowsOn = ref.watch(
      offerSurfaceVisibleProvider((
        surface: OfferSurface.itemOffers,
        listId: listId,
      )),
    );
    final offline = ref.watch(isOfflineProvider);
    final store = storeNameOf(chain);
    final symbolOf = ref.watch(offerCategoryOfProvider);

    if (snapshot.isLoading && !snapshot.hasValue) {
      return const Padding(
        padding: EdgeInsets.only(top: AvoSpacing.section),
        child: SkeletonSection(),
      );
    }
    final known = snapshot.valueOrNull;
    final entries = <ListOfferEntry>[
      if (rowsOn)
        for (final item in items)
          if (offers[item.id] case final offer?)
            ListOfferEntry(item: item, offer: offer),
    ];

    Widget? status;
    if (offline && known != null) {
      status = StatusRow(
        kind: StatusKind.offline,
        text: context.tr(
          'offer_status_offline_as_of',
          params: {'datetime': formatOfferDateTime(known.fetchedAt, lang)},
        ),
      );
    } else if (known != null && !known.complete) {
      status = StatusRow(
        kind: StatusKind.sectionError,
        text: context.tr(
          entries.isEmpty
              ? 'offer_status_load_failed'
              : 'offer_status_refresh_failed',
        ),
        actionLabel: context.tr('common_try_again'),
        onAction: () => unawaited(refreshListOffers(ref, listId)),
      );
    }

    final regulars = _regulars(ref, chain, items);
    final children = <Widget>[
      if (summary != null) OffersLead(offerSummaryText(summary, lang).sentence),
      if (status != null)
        Padding(
          padding: const EdgeInsets.only(top: AvoSpacing.m),
          child: status,
        ),
      if (entries.isEmpty &&
          regulars.isEmpty &&
          known != null &&
          known.complete)
        EmptyState(
          icon: const AvoIcon(AvoIcons.tag),
          title: context.tr('offer_list_empty_title'),
          message: context.tr('offer_list_empty_body'),
        ),
      if (entries.isNotEmpty)
        InsetSection(
          header: context.tr('offer_list_on_list'),
          headerTrailing: Text('${entries.length}'),
          children: [
            for (final e in entries)
              _onListRow(context, e, lang, symbolOf(e.item.name)),
          ],
        ),
      if (regulars.isNotEmpty)
        InsetSection(
          header: context.tr('offer_list_regulars', params: {'store': store}),
          children: [
            for (final r in regulars)
              _regularRow(context, ref, r, chain, lang, symbolOf(r.name)),
          ],
        ),
      const SizedBox(height: AvoSpacing.section),
      InsetSection(
        children: [
          OfferTextRow(
            label: context.tr('offer_list_all_offers'),
            onTap: () => unawaited(context.push(weeklyOffersLocation())),
          ),
          OfferTextRow(
            label: context.tr('offer_hide_for_list'),
            icon: AvoIcons.eyeSlash,
            onTap: () => _hide(context, ref),
          ),
        ],
      ),
      OffersFootnote(context.tr('offer_savings_explainer')),
      const OffersSourceFootnote(),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    );
  }

  /// Regulars on offer at this list's market that are not on the list.
  List<RegularOffer> _regulars(
    WidgetRef ref,
    String chain,
    List<ShoppingItemModel> items,
  ) {
    final on = items.map((i) => i.name.trim().toLowerCase()).toSet();
    final all = ref.watch(regularOffersProvider).valueOrNull?.offers;
    return [
      for (final r in all ?? const <RegularOffer>[])
        if (r.chainId == chain && !on.contains(r.name.trim().toLowerCase())) r,
    ].take(_kRegularsMax).toList();
  }

  Widget _onListRow(
    BuildContext context,
    ListOfferEntry e,
    String lang,
    String categoryId,
  ) {
    final item = e.item;
    final offer = e.offer;
    // "Milch · 2": pieces as the bare count, other units as in the list.
    final qty = isPieceUnit(item.unit)
        ? (item.quantity == 1
              ? null
              : NumberFormat('0.##', lang).format(item.quantity))
        : formatQuantity(item.quantity, item.unit, languageCode: lang);
    final title = qty == null
        ? item.name.trim()
        : context.tr(
            'offer_list_item_qty',
            params: {'item': item.name.trim(), 'qty': qty},
          );
    final was = OfferLines.was(offer, lang);
    return offerEntryRow(
      context,
      offer: offer,
      title: title,
      spokenTitle: qty == null ? item.name.trim() : '${item.name.trim()}, $qty',
      lines: [OfferLines.product(offer, lang), ?was],
      symbol: Categories.getById(
        item.categoryId ?? item.category ?? categoryId,
      ).icon,
      onTap: () => _open(context, offer, item: item),
    );
  }

  Widget _regularRow(
    BuildContext context,
    WidgetRef ref,
    RegularOffer r,
    String chain,
    String lang,
    String categoryId,
  ) {
    final offer = r.offer;
    final was = OfferLines.was(offer, lang);
    return offerEntryRow(
      context,
      offer: offer,
      title: r.name,
      lines: [OfferLines.product(offer, lang), ?was],
      symbol: Categories.getById(r.categoryId ?? categoryId).icon,
      onTap: () => _open(context, offer, name: r.name),
      onAdd: (_) => unawaited(_addRegular(context, ref, r, chain)),
      addLabel: context.tr(
        'offer_add_plus_a11y',
        params: {'product': r.name, 'list': listName},
      ),
    );
  }

  void _open(
    BuildContext context,
    StoreOffer offer, {
    ShoppingItemModel? item,
    String? name,
  }) {
    rememberOffer(context, offer);
    unawaited(
      context.push(
        offerDetailLocation(
          offer.id,
          listId: listId,
          itemId: item?.id,
          mode: item == null ? OfferDetailMode.add : OfferDetailMode.take,
          name: name,
        ),
      ),
    );
  }

  Future<void> _addRegular(
    BuildContext context,
    WidgetRef ref,
    RegularOffer r,
    String chain,
  ) async {
    final sync = ref.read(listOfferSyncProvider);
    final saved = await addOfferToList(
      context,
      listId: listId,
      name: r.name,
      offer: r.offer,
      quantity: r.quantity ?? 1,
      listName: listName,
    );
    if (!saved) return;
    await sync.attach(
      listId: listId,
      chainId: chain,
      name: r.name,
      offer: r.offer,
    );
    ref.invalidate(listOfferSnapshotProvider(listId));
  }

  void _hide(BuildContext context, WidgetRef ref) {
    final toast = Navigator.of(context, rootNavigator: true).context;
    unawaited(setOffersHiddenForList(ref, listId, true));
    final notifier = ref.read(hiddenOfferListsProvider.notifier);
    AvoToast.show(
      toast,
      message: toast.tr('offer_toast_list_hidden', params: {'list': listName}),
      actionLabel: toast.tr('common_undo'),
      onAction: () => unawaited(notifier.setHidden(listId, false)),
    );
    if (context.canPop()) context.pop();
  }
}

/// A text button as a row of its own (52 pt, `tint`, optional glyph before
/// it): "Alle Angebote der Woche", "Angebote für diese Liste ausblenden".
/// Never red: these only open or hide.
class OfferTextRow extends StatelessWidget {
  const OfferTextRow({
    super.key,
    required this.label,
    required this.onTap,
    this.icon,
  });

  final String label;
  final VoidCallback onTap;
  final AvoIconData? icon;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final glyph = icon;
    return Semantics(
      container: true,
      button: true,
      label: label,
      onTap: onTap,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 52), // D2
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AvoSpacing.l,
              vertical: AvoSpacing.s,
            ),
            child: Row(
              children: [
                if (glyph != null) ...[
                  AvoIcon(glyph, size: 20, color: colors.tint), // D2
                  const SizedBox(width: AvoSpacing.m),
                ],
                Expanded(
                  child: Text(
                    label,
                    style: context.text(AvoTextStyle.body, color: colors.tint),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
