import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:shoply/core/design/design.dart';
import 'package:shoply/core/localization/localization_helper.dart';
import 'package:shoply/data/services/store_chain_directory.dart';
import 'package:shoply/presentation/providers/offer_display_prefs_provider.dart';
import 'package:shoply/presentation/providers/store_choice_provider.dart';
import 'package:shoply/presentation/providers/store_for_list_provider.dart';
import 'package:shoply/presentation/screens/offers/offer_paths.dart';
import 'package:shoply/presentation/screens/offers/offer_text.dart';
import 'package:shoply/presentation/screens/offers/store_menu.dart';
import 'package:shoply/presentation/screens/offers/widgets/store_mark.dart';
import 'package:shoply/presentation/widgets/design/app_button.dart';
import 'package:shoply/presentation/widgets/design/avo_icons.dart';
import 'package:shoply/presentation/widgets/design/glass_icon_button.dart';
import 'package:shoply/presentation/widgets/design/glass_toolbar.dart';
import 'package:shoply/presentation/widgets/design/inset_section.dart';
import 'package:shoply/presentation/widgets/design/search_field.dart';

// D2 rows of the store picker (`angebote.md` S2).
const double _kMark = 28; // D2 StoreMark in S2 rows
const double _kCheck = 17; // D2 check mark at the row start
const double _kRowMin = 52; // D2 one line
const double _kRowMinTwoLines = 60; // D2 with a second line
const double _kRowVertical = AvoSpacing.s; // D2 row padding 8
const double _kGap = AvoSpacing.m; // D2 gap 12

/// "Markt wählen" (S2, `/stores/pick`, full screen, core): which market is
/// it when it is not in the menu? A search over every market (aliases and
/// typos: "lidel" finds Lidl), "Deine Märkte" (the list's current market
/// with a check mark and the markets of its trips), "In der Nähe" (only with
/// a location the app may already read, never asking), "Alle Märkte" A–Z
/// and "Kein fester Markt".
///
/// A tap picks and closes (the push goes back to the right); swiping back
/// cancels. With [listId] the screen saves the choice itself and the undo
/// toast appears over the screen it returns to; it pops the
/// [StoreChoice] in any case. A market of the person's own is only offered
/// without [listId], because a list can store chains only so far.
class StorePickerScreen extends ConsumerStatefulWidget {
  const StorePickerScreen({
    super.key,
    this.listId,
    this.from = StorePickerOrigin.chip,
    this.tripListId,
    this.selectedChainId,
  });

  final String? listId;
  final StorePickerOrigin from;

  /// Mode `trip` (V2 "Markt für diesen Einkauf"): the list whose markets
  /// fill "Deine Märkte"; the choice is only returned, never saved.
  final String? tripListId;

  /// The market chosen for the trip so far (check mark), mode `trip`.
  final String? selectedChainId;

  bool get _trip => from == StorePickerOrigin.checkout;

  @override
  ConsumerState<StorePickerScreen> createState() => _StorePickerScreenState();
}

class _StorePickerScreenState extends ConsumerState<StorePickerScreen> {
  final TextEditingController _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _pick(StoreChoice choice) {
    final listId = widget.listId;
    if (listId != null) unawaited(applyStoreChoice(context, listId, choice));
    context.pop(choice);
  }

  bool _matches(String chainId) => storeMatchesQuery(chainId, _query);

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final listId = widget.listId;
    final lang = offerLanguageOf(context);
    final trip = widget._trip;
    final historyListId = trip ? widget.tripListId : listId;
    final current = trip
        ? widget.selectedChainId
        : listId == null
        ? null
        : ref.watch(storeForListProvider(listId))?.id;
    final history = historyListId == null
        ? const <String>[]
        : ref.watch(listStoreHistoryProvider(historyListId)).valueOrNull ??
              const <String>[];
    final nearby =
        ref.watch(nearbyStoreOptionsProvider).valueOrNull ?? const [];

    final favorites = ref.watch(favoriteStoresProvider);
    final yours = <String>{
      if (current != null) current,
      for (final id in [...favorites, ...history])
        if (StoreChainDirectory.byId(id) != null) id,
    }.where(_matches).toList();
    final near = nearby.where((n) => _matches(n.chainId)).toList();
    final all =
        [
          for (final chain in StoreChainDirectory.chains)
            if (_matches(chain.id)) chain.id,
        ]..sort(
          (a, b) => storeNameOf(
            a,
          ).toLowerCase().compareTo(storeNameOf(b).toLowerCase()),
        );
    final query = _query.trim();
    final nothing =
        query.isNotEmpty && yours.isEmpty && near.isEmpty && all.isEmpty;
    final markIndent = AvoSpacing.l + _kMark + _kGap;

    final sections = <Widget>[
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: AvoSpacing.screen),
        child: AvoSearchField(
          controller: _search,
          hint: context.tr('offer_pick_search'),
          onChanged: (value) => setState(() => _query = value),
        ),
      ),
      if (yours.isNotEmpty)
        InsetSection(
          header: context.tr('offer_pick_yours'),
          footer: trip ? context.tr('hist_store_pick_note') : null,
          separatorIndent: markIndent + _kCheck + AvoSpacing.s,
          children: [
            for (final id in yours)
              _StoreRow(
                mark: StoreMark.chain(id, size: _kMark),
                title: storeNameOf(id),
                checked: id == current,
                reserveCheck: true,
                onTap: () => _pick(ChainStoreChoice(id)),
              ),
          ],
        ),
      if (near.isNotEmpty)
        InsetSection(
          header: context.tr('offer_pick_nearby'),
          separatorIndent: markIndent,
          children: [
            for (final store in near) _nearbyRow(context, store, lang),
          ],
        ),
      if (all.isNotEmpty)
        InsetSection(
          header: context.tr('offer_pick_all'),
          separatorIndent: markIndent,
          children: [
            for (final id in all)
              _StoreRow(
                mark: StoreMark.chain(id, size: _kMark),
                title: storeNameOf(id),
                onTap: () => _pick(ChainStoreChoice(id)),
              ),
          ],
        ),
      if (nothing)
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AvoSpacing.screen,
            AvoSpacing.xxl,
            AvoSpacing.screen,
            0,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                context.tr('offer_pick_no_result', params: {'query': query}),
                style: context.text(AvoTextStyle.body),
              ),
              // A trip stores chains only so far (no market of one's own).
              if (listId == null && !widget._trip)
                AppButton.plain(
                  label: context.tr(
                    'offer_pick_use_custom',
                    params: {'query': query},
                  ),
                  onPressed: () => _pick(CustomStoreChoice(query)),
                ),
            ],
          ),
        ),
      if (query.isEmpty)
        Padding(
          padding: const EdgeInsets.only(top: AvoSpacing.section),
          child: InsetSection(
            children: [
              _StoreRow(
                title: context.tr(trip ? 'hist_store_none' : 'offer_store_none'),
                onTap: () => _pick(const NoStoreChoice()),
              ),
            ],
          ),
        ),
    ];

    return ColoredBox(
      color: colors.background,
      child: Stack(
        children: [
          CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: SizedBox(
                  height:
                      GlassToolbar.topOffset(context) +
                      AvoSizes.toolbarButton +
                      AvoSpacing.m,
                ),
              ),
              for (final section in sections)
                SliverToBoxAdapter(child: section),
              SliverToBoxAdapter(
                child: SizedBox(
                  height:
                      MediaQuery.paddingOf(context).bottom + AvoSpacing.section,
                ),
              ),
            ],
          ),
          const Positioned(top: 0, left: 0, right: 0, child: ScrollEdgeFade()),
          Positioned(
            top: GlassToolbar.topOffset(context),
            left: 0,
            right: 0,
            child: GlassToolbar(
              // Mode `trip` is a follow-up step of V1/V5: back, not close.
              leading: GlassIconButton(
                icon: AvoIcon(
                  widget._trip ? AvoIcons.chevronBack : AvoIcons.xmark,
                ),
                semanticLabel: context.tr(
                  widget._trip ? 'back' : 'common_close',
                ),
                onPressed: () => context.pop(),
              ),
              title: context.tr(
                trip ? 'hist_store_pick_title' : 'offer_pick_title',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _nearbyRow(
    BuildContext context,
    NearbyStoreOption store,
    String lang,
  ) {
    final distance = formatDistance(store.distanceMeters, lang);
    final street = store.street?.trim();
    final name = storeNameOf(store.chainId);
    final sub = street == null || street.isEmpty
        ? distance.shown
        : context.tr(
            'offer_pick_distance',
            params: {'street': street, 'distance': distance.shown},
          );
    final spoken = [
      name,
      if (street != null && street.isNotEmpty) street,
      distance.spoken,
    ].join(', ');
    return _StoreRow(
      mark: StoreMark.chain(store.chainId, size: _kMark),
      title: name,
      subtitle: sub,
      semanticLabel: spoken,
      onTap: () => _pick(ChainStoreChoice(store.chainId)),
    );
  }
}

/// One market: optional check mark, letter tile, name, optional second line.
/// The whole row picks; it highlights the moment a finger touches it.
class _StoreRow extends StatefulWidget {
  const _StoreRow({
    required this.title,
    required this.onTap,
    this.mark,
    this.subtitle,
    this.checked = false,
    this.reserveCheck = false,
    this.semanticLabel,
  });

  final String title;
  final VoidCallback onTap;
  final Widget? mark;
  final String? subtitle;
  final bool checked;
  final bool reserveCheck;
  final String? semanticLabel;

  @override
  State<_StoreRow> createState() => _StoreRowState();
}

class _StoreRowState extends State<_StoreRow> {
  bool _pressed = false;

  void _press(bool down) {
    if (_pressed != down && mounted) setState(() => _pressed = down);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final mark = widget.mark;
    final subtitle = widget.subtitle;
    // "Lidl, ausgewählt": VoiceOver adds the state from [selected].
    final label = widget.semanticLabel ?? widget.title;
    return Semantics(
      container: true,
      button: true,
      selected: widget.checked,
      label: label,
      excludeSemantics: true,
      onTap: widget.onTap,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => _press(true),
        onTapUp: (_) => _press(false),
        onTapCancel: () => _press(false),
        onTap: widget.onTap,
        child: ColoredBox(
          color: _pressed ? colors.fillStrong : colors.surface,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: subtitle == null ? _kRowMin : _kRowMinTwoLines,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AvoSpacing.l,
                vertical: _kRowVertical,
              ),
              child: Row(
                children: [
                  if (widget.reserveCheck) ...[
                    SizedBox(
                      width: _kCheck,
                      child: widget.checked
                          ? AvoIcon(
                              AvoIcons.check,
                              size: _kCheck,
                              color: colors.tint,
                            )
                          : null,
                    ),
                    const SizedBox(width: AvoSpacing.s),
                  ],
                  if (mark != null) ...[mark, const SizedBox(width: _kGap)],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          widget.title,
                          style: context.text(AvoTextStyle.body),
                        ),
                        if (subtitle != null)
                          Text(
                            subtitle,
                            style: context.text(
                              AvoTextStyle.subhead,
                              color: colors.secondaryLabel,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
