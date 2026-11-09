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
import 'package:shoply/presentation/providers/weekly_offers_provider.dart';
import 'package:shoply/presentation/screens/lists/widgets/offer_suggestions_bar.dart'
    show offerCategoryOfProvider;
import 'package:shoply/presentation/screens/offers/list_target_menu.dart';
import 'package:shoply/presentation/screens/offers/offer_actions.dart';
import 'package:shoply/presentation/screens/offers/offer_paths.dart';
import 'package:shoply/presentation/screens/offers/offer_text.dart';
import 'package:shoply/presentation/screens/offers/store_menu.dart';
import 'package:shoply/presentation/screens/offers/widgets/offer_entry_row.dart';
import 'package:shoply/presentation/screens/offers/widgets/offer_swipe.dart';
import 'package:shoply/presentation/widgets/design/avo_figure.dart';
import 'package:shoply/presentation/widgets/design/avo_icons.dart';
import 'package:shoply/presentation/widgets/design/avo_menu.dart';
import 'package:shoply/presentation/widgets/design/empty_state.dart';
import 'package:shoply/presentation/widgets/design/inset_section.dart';
import 'package:shoply/presentation/widgets/design/skeleton.dart';
import 'package:shoply/presentation/widgets/design/status_row.dart';
import 'package:shoply/presentation/widgets/design/undo_toast.dart';

// The three bodies of "Angebote der Woche" (S10, `weekly_offers_screen.dart`):
// "Deine Listen", "Oft gekauft" and the search.

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
class WeeklyListsSection extends ConsumerWidget {
  const WeeklyListsSection({
    super.key,
    required this.chain,
    required this.offline,
  });

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
/// "Ausgeblendet bis Sa., 14. Nov. · Widerrufen". [onUndo] runs when the
/// person takes it back.
Future<void> notInterestedWithUndo(
  BuildContext context,
  WidgetRef ref,
  StoreOffer offer, {
  VoidCallback? onUndo,
}) async {
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
    onAction: () {
      unawaited(prefs.undoNotInterested(offer.id));
      onUndo?.call();
    },
  );
}

/// "Oft gekauft": regulars on offer at the market the person buys them at.
/// Swipe to the start, the context menu or the VoiceOver action "Nicht
/// interessiert" takes the row away in the same frame; undo brings it back.
class WeeklyRegularsSection extends ConsumerStatefulWidget {
  const WeeklyRegularsSection({super.key, required this.chain});

  /// The market chip that filters, if any.
  final String? chain;

  @override
  ConsumerState<WeeklyRegularsSection> createState() =>
      _WeeklyRegularsSectionState();
}

class _WeeklyRegularsSectionState extends ConsumerState<WeeklyRegularsSection> {
  /// Offers dismissed here; the prefs follow a moment later.
  final Set<int> _gone = {};

  void _dismiss(BuildContext context, StoreOffer offer) {
    setState(() => _gone.add(offer.id));
    unawaited(
      notInterestedWithUndo(
        context,
        ref,
        offer,
        onUndo: () {
          if (mounted) setState(() => _gone.remove(offer.id));
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
    // "Nicht interessiert" leaves at once: rows hidden in the prefs and the
    // ones dismissed in this frame (before the prefs have saved).
    final prefs = ref.watch(offerDisplayPrefsProvider);
    final now = ref.watch(offerClockProvider)();
    final offers = [
      for (final r in interestingRegulars(result.offers, prefs, now))
        if ((widget.chain == null || r.chainId == widget.chain) &&
            !_gone.contains(r.offer.id))
          r,
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
              void notInterested() => _dismiss(context, offer);
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
class WeeklySearchSection extends ConsumerWidget {
  const WeeklySearchSection({
    super.key,
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
                        name: _asItem(query),
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
                        onTap: () =>
                            _openOffer(context, offer, name: _asItem(query)),
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

/// A search term as an item name: "haferflocken" becomes "Haferflocken".
String _asItem(String query) {
  final q = query.trim();
  return q.isEmpty ? q : '${q[0].toUpperCase()}${q.substring(1)}';
}
