import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:shoply/core/design/design.dart';
import 'package:shoply/core/localization/localization_helper.dart';
import 'package:shoply/data/services/connectivity_service.dart';
import 'package:shoply/presentation/providers/offer_display_prefs_provider.dart';
import 'package:shoply/presentation/providers/region_provider.dart';
import 'package:shoply/presentation/providers/weekly_offers_provider.dart';
import 'package:shoply/presentation/screens/offers/offer_paths.dart';
import 'package:shoply/presentation/screens/offers/region_screen.dart'
    show openAppSettingsProvider, regionText;
import 'package:shoply/presentation/screens/offers/store_menu.dart';
import 'package:shoply/presentation/screens/offers/widgets/offers_page.dart';
import 'package:shoply/presentation/screens/offers/widgets/offers_source_footnote.dart';
import 'package:shoply/presentation/screens/offers/widgets/store_mark.dart';
import 'package:shoply/presentation/screens/offers/widgets/weekly_offer_sections.dart';
import 'package:shoply/presentation/widgets/design/app_button.dart';
import 'package:shoply/presentation/widgets/design/avo_icons.dart';
import 'package:shoply/presentation/widgets/design/empty_state.dart';
import 'package:shoply/presentation/widgets/design/filter_chip.dart';
import 'package:shoply/presentation/widgets/design/search_field.dart';
import 'package:shoply/presentation/widgets/design/segmented_control.dart';
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
      body = WeeklySearchSection(
        query: _query,
        chain: _chain,
        listMarkets: [for (final s in sections) s.chainId],
        favorites: favorites,
      );
    } else if (segment == _Segment.regulars) {
      body = WeeklyRegularsSection(chain: _chain);
    } else {
      body = WeeklyListsSection(chain: _chain, offline: offline);
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
                        size: MediaQuery.textScalerOf(
                          context,
                        ).scale(_kMetaChevron),
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
          SingleChoiceChipRow<String>(
            choices: [
              for (final id in chips)
                ChipChoice(
                  value: id,
                  label: storeNameOf(id),
                  leading: StoreMark.chain(id),
                ),
            ],
            value: _chain,
            allowDeselect: true,
            onChanged: (id) => setState(() => _chain = id),
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
