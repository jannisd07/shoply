import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:shoply/core/constants/categories.dart';
import 'package:shoply/core/design/design.dart';
import 'package:shoply/core/localization/localization_helper.dart';
import 'package:shoply/data/models/store_offer.dart';
import 'package:shoply/data/services/connectivity_service.dart';
import 'package:shoply/presentation/providers/offer_display_prefs_provider.dart';
import 'package:shoply/presentation/providers/region_provider.dart';
import 'package:shoply/presentation/providers/weekly_offers_provider.dart';
import 'package:shoply/presentation/screens/lists/widgets/offer_suggestions_bar.dart'
    show offerCategoryOfProvider;
import 'package:shoply/presentation/screens/offers/list_target_menu.dart';
import 'package:shoply/presentation/screens/offers/offer_actions.dart';
import 'package:shoply/presentation/screens/offers/offer_paths.dart';
import 'package:shoply/presentation/screens/offers/offer_text.dart';
import 'package:shoply/presentation/screens/offers/region_screen.dart'
    show openAppSettingsProvider, regionText;
import 'package:shoply/presentation/screens/offers/store_menu.dart';
import 'package:shoply/presentation/screens/offers/widgets/offer_entry_row.dart';
import 'package:shoply/presentation/screens/offers/widgets/offer_swipe.dart';
import 'package:shoply/presentation/screens/offers/widgets/offers_page.dart';
import 'package:shoply/presentation/screens/offers/widgets/offers_source_footnote.dart';
import 'package:shoply/presentation/screens/offers/widgets/store_filter_chip.dart';
import 'package:shoply/presentation/widgets/design/app_button.dart';
import 'package:shoply/presentation/widgets/design/avo_figure.dart';
import 'package:shoply/presentation/widgets/design/avo_icons.dart';
import 'package:shoply/presentation/widgets/design/avo_menu.dart';
import 'package:shoply/presentation/widgets/design/empty_state.dart';
import 'package:shoply/presentation/widgets/design/filter_chip.dart';
import 'package:shoply/presentation/widgets/design/inset_section.dart';
import 'package:shoply/presentation/widgets/design/search_field.dart';
import 'package:shoply/presentation/widgets/design/segmented_control.dart';
import 'package:shoply/presentation/widgets/design/skeleton.dart';
import 'package:shoply/presentation/widgets/design/status_row.dart';
import 'package:shoply/presentation/widgets/design/undo_toast.dart';

const double _kMetaChevron = 11; // D2 chevron after the area line

enum _Segment { lists, regulars }

/// "Angebote der Woche" (S10, `/offers`, the root pushed in the Listen tab):
/// what of my things is on offer this week? Two questions, one segment
/// each: "Deine Listen" (the offers of the two lists changed last, at their
/// markets) and "Oft gekauft" (what the person buys often, at the market
/// they buy it at). A search over all markets groups its hits by market,
/// never by price; the market chips only filter, they never compare.
///
/// The area line opens the region; a row opens the offer (S5, "Auf die
/// Liste"), its `plus.circle` puts it on the section's list, or opens "Auf
/// welche Liste?" outside a list. Swipe to the end: "Auf die Liste"; in
/// "Oft gekauft" swipe to the start or the context menu: "Nicht
/// interessiert" (hidden until the offer ends, at most 7 days).
///
/// Without a real region nothing is asked: "Wo kaufst du ein?" with
/// "Standort verwenden" and "Postleitzahl eingeben". The one figure of the
/// area: Avo thinks along when a search finds nothing. Never Pro.
class WeeklyOffersScreen extends ConsumerStatefulWidget {
  const WeeklyOffersScreen({super.key, this.regulars = false, this.query});

  /// `filter=regulars`: opens on "Oft gekauft".
  final bool regulars;

  /// `q=`: the search, filled in (from Avo).
  final String? query;

  @override
  ConsumerState<WeeklyOffersScreen> createState() => _WeeklyOffersScreenState();
}

class _WeeklyOffersScreenState extends ConsumerState<WeeklyOffersScreen> {
  late final TextEditingController _search = TextEditingController(
    text: widget.query?.trim() ?? '',
  );
  late _Segment _segment = widget.regulars ? _Segment.regulars : _Segment.lists;
  String? _chain;
  bool _locating = false;
  bool _denied = false;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  String get _query => _search.text.trim();

  Future<void> _useLocation() async {
    setState(() => _locating = true);
    final controller = ref.read(regionControllerProvider.notifier);
    final result = await controller.locate();
    if (!mounted) return;
    setState(() {
      _locating = false;
      _denied = result.outcome == LocateOutcome.denied;
    });
    final region = result.region;
    if (result.outcome == LocateOutcome.found && region != null) {
      await controller.saveRegion(region);
      if (!mounted) return;
      AvoToast.show(
        context,
        message: context
            .tr(
              'offer_toast_region_set',
              params: {'postcode': region.zip, 'city': region.city ?? ''},
            )
            .trim(),
        actionLabel: context.tr('common_undo'),
        onAction: () => unawaited(controller.remove()),
      );
    } else if (result.outcome != LocateOutcome.denied) {
      // Nothing found: the postcode is the way on.
      unawaited(context.push(storeRegionLocation(from: RegionOrigin.offers)));
    }
  }

  Future<void> _refresh() async {
    final sections = ref.read(weeklyListSectionsProvider).valueOrNull;
    if (sections != null && sections.isNotEmpty) {
      await refreshWeeklyListOffers(ref, sections);
    }
    ref.invalidate(regularOffersProvider);
  }

  @override
  Widget build(BuildContext context) {
    final loaded = ref.watch(regionLoadedProvider);
    final region = ref.watch(regionProvider);
    return OffersPage(
      title: context.tr('offer_week_title'),
      onRefresh: region == null ? null : _refresh,
      children: [
        if (!loaded)
          const SizedBox.shrink()
        else if (region == null)
          _noArea(context)
        else
          _content(context, region),
      ],
    );
  }

  Widget _noArea(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_denied)
          Padding(
            padding: const EdgeInsets.only(top: AvoSpacing.m),
            child: StatusRow(
              kind: StatusKind.permission,
              text: context.tr('offer_location_off'),
              actionLabel: context.tr('settings'),
              onAction: () => unawaited(ref.read(openAppSettingsProvider)()),
            ),
          ),
        EmptyState(
          icon: const AvoIcon(AvoIcons.location),
          title: context.tr('offer_week_no_area_title'),
          message: context.tr('offer_week_no_area_body'),
          actionLabel: _denied || _locating
              ? null
              : context.tr('offer_use_location'),
          onAction: _denied || _locating
              ? null
              : () => unawaited(_useLocation()),
        ),
        Center(
          child: AppButton.plain(
            label: context.tr('offer_enter_postcode'),
            onPressed: () => unawaited(
              context.push(storeRegionLocation(from: RegionOrigin.offers)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _content(BuildContext context, Region region) {
    final colors = context.colors;
    final tips = ref.watch(
      offerDisplayPrefsProvider.select(
        (p) => p?.isOn(OfferSurface.homeTips) ?? false,
      ),
    );
    final segment = tips ? _segment : _Segment.lists;
    final searching = _query.length >= 2;
    final sections =
        ref.watch(weeklyListSectionsProvider).valueOrNull ?? const [];
    final favorites = ref.watch(favoriteStoresProvider);
    final chips = <String>{
      for (final s in sections) s.chainId,
      ...favorites,
    }.toList();
    final offline = ref.watch(isOfflineProvider);
    final area = regionText(region);

    final Widget body;
    if (searching) {
      body = _SearchResults(
        query: _query,
        chain: _chain,
        listMarkets: [for (final s in sections) s.chainId],
        favorites: favorites,
      );
    } else if (segment == _Segment.regulars) {
      body = _Regulars(chain: _chain);
    } else {
      body = _Lists(chain: _chain, offline: offline);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AvoSpacing.screen),
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            child: Semantics(
              container: true,
              button: true,
              label: context
                  .tr(
                    'offer_week_area_a11y',
                    params: {'postcode': area, 'city': ''},
                  )
                  .replaceAll(' ,', ','),
              onTap: () => unawaited(
                context.push(storeRegionLocation(from: RegionOrigin.offers)),
              ),
              excludeSemantics: true,
              child: PressableScale(
                onPressed: () => unawaited(
                  context.push(storeRegionLocation(from: RegionOrigin.offers)),
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    minHeight: AvoSizes.hitTarget,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          context
                              .tr(
                                'offer_week_area',
                                params: {'postcode': area, 'city': ''},
                              )
                              .trim(),
                          style: context.text(
                            AvoTextStyle.subhead,
                            color: colors.secondaryLabel,
                          ),
                        ),
                      ),
                      const SizedBox(width: AvoSpacing.xs),
                      AvoIcon(
                        AvoIcons.chevronRight,
                        size: _kMetaChevron,
                        color: colors.secondaryLabel,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: AvoSpacing.m),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AvoSpacing.screen),
          child: AvoSearchField(
            controller: _search,
            hint: context.tr('offer_week_search'),
            onChanged: (_) => setState(() {}),
          ),
        ),
        if (tips && !searching) ...[
          const SizedBox(height: AvoSpacing.m),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AvoSpacing.screen),
            child: AppSegmentedControl<_Segment>(
              segments: [
                SegmentItem(
                  value: _Segment.lists,
                  label: context.tr('offer_week_seg_lists'),
                ),
                SegmentItem(
                  value: _Segment.regulars,
                  label: context.tr('offer_week_seg_regulars'),
                ),
              ],
              selected: segment,
              onChanged: (value) => setState(() => _segment = value),
            ),
          ),
        ],
        if (chips.isNotEmpty) ...[
          const SizedBox(height: AvoSpacing.s),
          ChipRow(
            chips: [
              for (final id in chips)
                StoreFilterChip(
                  chainId: id,
                  label: storeNameOf(id),
                  selected: _chain == id,
                  onTap: () =>
                      setState(() => _chain = _chain == id ? null : id),
                ),
            ],
          ),
        ],
        if (offline && searching)
          Padding(
            padding: const EdgeInsets.only(top: AvoSpacing.m),
            child: StatusRow(
              kind: StatusKind.offline,
              text: context.tr('offer_status_offline_search'),
            ),
          ),
        body,
        const OffersSourceFootnote(),
      ],
    );
  }
}

/// Puts an offer of a list section onto that list ("Auf die Liste").
Future<void> _addToSection(
  BuildContext context,
  WeeklyListSection section,
  ListOfferEntry entry,
) => addOfferToList(
  context,
  listId: section.listId,
  name: entry.item.name,
  offer: entry.offer,
  quantity: entry.item.quantity,
  listName: section.listName,
  otherList: true,
).then((_) {});

/// Opens the offer (S5) with "Auf die Liste"; [listId] when it belongs to a
/// list section.
void _openOffer(
  BuildContext context,
  StoreOffer offer, {
  String? listId,
  String? name,
}) {
  rememberOffer(context, offer);
  unawaited(
    context.push(
      offerDetailLocation(
        offer.id,
        listId: listId,
        mode: OfferDetailMode.add,
        name: name,
      ),
    ),
  );
}

/// "Deine Listen": one group per list with a market.
class _Lists extends ConsumerWidget {
  const _Lists({required this.chain, required this.offline});

  final String? chain;
  final bool offline;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = offerLanguageOf(context);
    final async = ref.watch(weeklyListSectionsProvider);
    final symbolOf = ref.watch(offerCategoryOfProvider);
    final all = async.valueOrNull;
    if (all == null) {
      if (async.hasError) {
        return _sectionError(
          context,
          () => ref.invalidate(weeklyListSectionsProvider),
        );
      }
      return const Padding(
        padding: EdgeInsets.only(top: AvoSpacing.section),
        child: SkeletonSection(),
      );
    }
    final sections = [
      for (final s in all)
        if (chain == null || s.chainId == chain) s,
    ];
    final shown = sections.where((s) => s.entries.isNotEmpty).toList();
    final failed = sections.where((s) => s.entries.isEmpty && !s.complete);
    final oldest = all.isEmpty
        ? null
        : all.map((s) => s.fetchedAt).reduce((a, b) => a.isBefore(b) ? a : b);

    final children = <Widget>[
      if (offline && oldest != null)
        Padding(
          padding: const EdgeInsets.only(top: AvoSpacing.m),
          child: StatusRow(
            kind: StatusKind.offline,
            text: context.tr(
              'offer_status_offline_as_of',
              params: {'datetime': formatOfferDateTime(oldest, lang)},
            ),
          ),
        ),
      for (final _ in failed.take(1))
        _sectionError(
          context,
          () => unawaited(refreshWeeklyListOffers(ref, failed.toList())),
        ),
      for (final s in shown)
        InsetSection(
          header: context.tr(
            'offer_week_section',
            params: {'list': s.listName, 'store': storeNameOf(s.chainId)},
          ),
          headerTrailing: Text('${s.entries.length}'),
          children: [
            for (final e in s.entries)
              _row(context, s, e, lang, symbolOf(e.item.name)),
          ],
        ),
      if (shown.isEmpty && failed.isEmpty)
        EmptyState(
          icon: const AvoIcon(AvoIcons.tag),
          title: context.tr('offer_week_lists_empty_title'),
          message: context.tr('offer_week_lists_empty_body'),
        ),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    );
  }

  Widget _row(
    BuildContext context,
    WeeklyListSection section,
    ListOfferEntry entry,
    String lang,
    String categoryId,
  ) {
    final offer = entry.offer;
    final item = entry.item.name.trim();
    final product = offerProductTitle(offer);
    final differs = !product.toLowerCase().contains(item.toLowerCase());
    final forLine = context.tr(
      'offer_week_for_item',
      params: {'item': item, 'list': section.listName},
    );
    final details = OfferLines.details(offer, lang);
    final flag = OfferLines.flag(offer, lang);
    final addLabel = context.tr(
      'offer_add_plus_a11y',
      params: {'product': item, 'list': section.listName},
    );
    void add() => unawaited(_addToSection(context, section, entry));
    return OfferSwipe(
      id: '${section.listId}-${entry.item.id}-${offer.id}',
      start: OfferSwipeAction(
        label: context.tr('offer_week_add_swipe'),
        icon: AvoIcons.plusCircle,
        run: add,
      ),
      child: offerEntryRow(
        context,
        offer: offer,
        title: product,
        lines: [
          if (differs) (shown: forLine, spoken: forLine),
          ?details,
          ?flag,
        ],
        symbol: Categories.getById(
          entry.item.categoryId ?? entry.item.category ?? categoryId,
        ).icon,
        onTap: () =>
            _openOffer(context, offer, listId: section.listId, name: item),
        onAdd: (_) => add(),
        addLabel: addLabel,
        actions: {context.tr('offer_week_add_swipe'): add},
      ),
    );
  }
}

Widget _sectionError(BuildContext context, VoidCallback retry) => Padding(
  padding: const EdgeInsets.only(top: AvoSpacing.m),
  child: StatusRow(
    kind: StatusKind.sectionError,
    text: context.tr('offer_status_load_failed'),
    actionLabel: context.tr('common_try_again'),
    onAction: retry,
  ),
);

/// "Nicht interessiert": hides [offer] until it ends, at most 7 days; toast
/// "Ausgeblendet bis Sa., 14. Nov. · Widerrufen".
Future<void> _notInterested(
  BuildContext context,
  WidgetRef ref,
  StoreOffer offer,
) async {
  final prefs = ref.read(offerDisplayPrefsProvider.notifier);
  final lang = offerLanguageOf(context);
  final toast = Navigator.of(context, rootNavigator: true).context;
  final until = await prefs.notInterested(offer.id, offer.validTo);
  if (!toast.mounted) return;
  AvoToast.show(
    toast,
    message: toast.tr(
      'offer_toast_not_interested',
      params: {'date': formatOfferDate(until, lang)},
    ),
    actionLabel: toast.tr('common_undo'),
    onAction: () => unawaited(prefs.undoNotInterested(offer.id)),
  );
}

/// "Oft gekauft": regulars on offer at the market the person buys them at.
class _Regulars extends ConsumerWidget {
  const _Regulars({required this.chain});

  final String? chain;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = offerLanguageOf(context);
    final async = ref.watch(regularOffersProvider);
    final result = async.valueOrNull;
    final symbolOf = ref.watch(offerCategoryOfProvider);
    if (result == null) {
      if (async.hasError) {
        return _sectionError(
          context,
          () => ref.invalidate(regularOffersProvider),
        );
      }
      return const Padding(
        padding: EdgeInsets.only(top: AvoSpacing.section),
        child: SkeletonSection(),
      );
    }
    if (!result.hasStats) {
      return EmptyState(
        icon: const AvoIcon(AvoIcons.tag),
        title: context.tr('offer_week_regulars_new'),
      );
    }
    final offers = [
      for (final r in result.offers)
        if (chain == null || r.chainId == chain) r,
    ];
    if (offers.isEmpty) {
      return EmptyState(
        icon: const AvoIcon(AvoIcons.tag),
        title: context.tr('offer_week_regulars_empty'),
      );
    }
    return InsetSection(
      children: [
        for (final r in offers)
          Builder(
            builder: (rowContext) {
              final offer = r.offer;
              final rhythm = context.tr(
                'offer_week_rhythm',
                params: {
                  'store': storeNameOf(r.chainId),
                  'days': '${r.averageDays}',
                },
              );
              final details = OfferLines.details(offer, lang);
              void add(BuildContext anchor) => unawaited(
                showListTargetMenu(
                  anchor,
                  ref,
                  offer: offer,
                  name: r.name,
                  quantity: r.quantity ?? 1,
                ),
              );
              void notInterested() =>
                  unawaited(_notInterested(context, ref, offer));
              return OfferSwipe(
                id: 'regular-${offer.id}',
                start: OfferSwipeAction(
                  label: context.tr('offer_week_add_swipe'),
                  icon: AvoIcons.plusCircle,
                  run: () => add(rowContext),
                ),
                end: OfferSwipeAction(
                  label: context.tr('offer_week_not_interested'),
                  icon: AvoIcons.eyeSlash,
                  run: notInterested,
                  removes: true,
                ),
                child: _withMenu(
                  rowContext,
                  child: offerEntryRow(
                    context,
                    offer: offer,
                    title: offerProductTitle(offer),
                    lines: [(shown: rhythm, spoken: rhythm), ?details],
                    symbol: Categories.getById(
                      r.categoryId ?? symbolOf(r.name),
                    ).icon,
                    onTap: () => _openOffer(context, offer, name: r.name),
                    onAdd: add,
                    addLabel:
                        '${r.name}, ${context.tr('offer_week_add_swipe')}',
                    actions: {
                      context.tr('offer_week_add_swipe'): () => add(rowContext),
                      context.tr('offer_week_not_interested'): notInterested,
                    },
                  ),
                  items: [
                    AvoMenuItem(
                      label: context.tr('offer_week_add_swipe'),
                      icon: AvoIcons.plusCircle,
                      onSelected: () => add(rowContext),
                    ),
                    AvoMenuItem(
                      label: context.tr('offer_week_not_interested'),
                      icon: AvoIcons.eyeSlash,
                      onSelected: notInterested,
                    ),
                  ],
                ),
              );
            },
          ),
      ],
    );
  }
}

/// Long press opens [items] as a pull-down menu out of the row (the context
/// menu of S10; the same entries are VoiceOver actions of the row).
Widget _withMenu(
  BuildContext anchor, {
  required Widget child,
  required List<AvoMenuEntry> items,
}) => GestureDetector(
  behavior: HitTestBehavior.translucent,
  excludeFromSemantics: true,
  onLongPress: () => unawaited(showAvoMenu(anchor, items: items)),
  child: child,
);

/// The search over all markets, grouped by market.
class _SearchResults extends ConsumerWidget {
  const _SearchResults({
    required this.query,
    required this.chain,
    required this.listMarkets,
    required this.favorites,
  });

  final String query;
  final String? chain;
  final List<String> listMarkets;
  final List<String> favorites;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = offerLanguageOf(context);
    final offline = ref.watch(isOfflineProvider);
    final key = (query: query, offline: offline);
    final async = ref.watch(weeklyOfferSearchProvider(key));
    final symbolOf = ref.watch(offerCategoryOfProvider);
    final offers = async.valueOrNull;
    if (offers == null) {
      if (async.hasError) {
        return _sectionError(
          context,
          () => ref.invalidate(weeklyOfferSearchProvider(key)),
        );
      }
      return const Padding(
        padding: EdgeInsets.only(top: AvoSpacing.section),
        child: SkeletonSection(withImage: false),
      );
    }
    final groups = [
      for (final g in groupOffersByMarket(
        query,
        [
          for (final o in offers)
            if (o.isValidNow) o,
        ],
        listMarkets: listMarkets,
        favorites: favorites,
      ))
        if (chain == null || g.chainId == chain) g,
    ];
    if (groups.isEmpty) {
      return EmptyState(
        pose: AvoPose.thinking,
        icon: const AvoIcon(AvoIcons.tag),
        title: context.tr('offer_week_search_empty', params: {'query': query}),
      );
    }
    final category = symbolOf(query);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final g in groups)
          InsetSection(
            header: storeNameOf(g.chainId),
            headerTrailing: Text('${g.offers.length}'),
            children: [
              for (final offer in g.offers)
                Builder(
                  builder: (rowContext) {
                    final details = OfferLines.details(offer, lang);
                    final flag = OfferLines.flag(offer, lang);
                    void add(BuildContext anchor) => unawaited(
                      showListTargetMenu(
                        anchor,
                        ref,
                        offer: offer,
                        name: query,
                      ),
                    );
                    return OfferSwipe(
                      id: 'search-${offer.id}',
                      start: OfferSwipeAction(
                        label: context.tr('offer_week_add_swipe'),
                        icon: AvoIcons.plusCircle,
                        run: () => add(rowContext),
                      ),
                      child: offerEntryRow(
                        context,
                        offer: offer,
                        title: offerProductTitle(offer),
                        lines: [?details, ?flag],
                        symbol: Categories.getById(category).icon,
                        onTap: () => _openOffer(context, offer, name: query),
                        onAdd: add,
                        addLabel:
                            '${offerProductTitle(offer)}, '
                            '${context.tr('offer_week_add_swipe')}',
                        actions: {
                          context.tr('offer_week_add_swipe'): () =>
                              add(rowContext),
                        },
                      ),
                    );
                  },
                ),
            ],
          ),
      ],
    );
  }
}
