import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:shoply/core/design/design.dart';
import 'package:shoply/core/localization/localization_helper.dart';
import 'package:shoply/data/services/store_chain_directory.dart';
import 'package:shoply/presentation/providers/offer_display_prefs_provider.dart';
import 'package:shoply/presentation/screens/offers/store_menu.dart';
import 'package:shoply/presentation/screens/offers/widgets/offers_page.dart';
import 'package:shoply/presentation/screens/offers/widgets/store_mark.dart';
import 'package:shoply/presentation/widgets/design/inset_section.dart';
import 'package:shoply/presentation/widgets/design/reorderable_section.dart';
import 'package:shoply/presentation/widgets/design/search_field.dart';
import 'package:shoply/presentation/widgets/design/select_circle.dart';
import 'package:shoply/presentation/widgets/design/undo_toast.dart';

const double _kRowMin = 52; // D2 one line
const double _kMark = 28; // D2 StoreMark in rows
const double _kCircle = 22; // D2 selection circle

/// The circle's 44 pt target starts this far in, so the 22 pt glyph sits
/// 16 pt from the edge as in D2.
const double _kCircleStart = AvoSpacing.l - (AvoSizes.hitTarget - _kCircle) / 2;

/// Gap after the 44 pt target: 12 pt after the visible circle.
const double _kCircleGap = AvoSpacing.m - (AvoSizes.hitTarget - _kCircle) / 2;
const double _kSeparatorIndent = AvoSpacing.l + _kCircle + AvoSpacing.m;

/// The search appears from this many directory chains on (S13).
const int _kSearchFrom = 12;

/// "Lieblingsmärkte" (S13, `/settings/offers/markets` in the Profil tab,
/// core): where do I shop, and in which order? The order decides the
/// market menu (S1) and, for lists without a fixed market, whose offers
/// come first.
///
/// "Deine Märkte" is A's [ReorderableInsetSection]: [SelectCircle], letter
/// tile, name and the drag handle (hold the handle to lift the row; its
/// VoiceOver element has "Nach oben" / "Nach unten"). "Weitere Märkte" lists
/// the rest of the directory A–Z, with a search from 12 chains on. A tap
/// adds a market at the end of "Deine Märkte" or takes it out again (with an
/// undo toast). Works with the offers module off and the kill switch on too;
/// the note says what the order does today (first in the market menu).
class FavoriteMarketsScreen extends ConsumerStatefulWidget {
  const FavoriteMarketsScreen({super.key});

  @override
  ConsumerState<FavoriteMarketsScreen> createState() =>
      _FavoriteMarketsScreenState();
}

class _FavoriteMarketsScreenState extends ConsumerState<FavoriteMarketsScreen> {
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  OfferDisplayPrefsNotifier get _prefs =>
      ref.read(offerDisplayPrefsProvider.notifier);

  void _toggle(String chainId, List<String> favorites) {
    final removing = favorites.contains(chainId);
    unawaited(_prefs.toggleFavorite(chainId));
    if (!removing) return;
    final before = [...favorites];
    AvoToast.show(
      context,
      message: context.tr(
        'offer_toast_favorite_removed',
        params: {'store': storeNameOf(chainId)},
      ),
      actionLabel: context.tr('common_undo'),
      onAction: () => unawaited(_prefs.setFavorites(before)),
    );
  }

  /// [to] is the index after the move (`ReorderableInsetSection`); the
  /// section ticks the haptic itself.
  void _reorder(List<String> favorites, int from, int to) {
    final next = [...favorites];
    final id = next.removeAt(from);
    next.insert(to.clamp(0, next.length), id);
    unawaited(_prefs.setFavorites(next));
  }

  @override
  Widget build(BuildContext context) {
    final favorites = [
      for (final id in ref.watch(favoriteStoresProvider))
        if (StoreChainDirectory.byId(id) != null) id,
    ];
    final query = _search.text;
    final more =
        [
          for (final chain in StoreChainDirectory.chains)
            if (!favorites.contains(chain.id) &&
                storeMatchesQuery(chain.id, query))
              chain.id,
        ]..sort(
          (a, b) => storeNameOf(
            a,
          ).toLowerCase().compareTo(storeNameOf(b).toLowerCase()),
        );
    // "Listen ohne festen Markt zeigen Angebote dieser Märkte" (the note
    // with offers) waits for the favourites rule K12-03; until lists
    // without a market have offers, the true sentence is the core one.
    final note = context.tr('offer_favorites_note_stores');

    final children = <Widget>[
      if (favorites.isEmpty) ...[
        OffersLead(
          context.tr('offer_favorites_empty'),
          style: AvoTextStyle.body,
          top: 0,
        ),
        OffersFootnote(note),
      ] else ...[
        ReorderableInsetSection(
          header: context.tr('offer_favorites_yours'),
          plain: context.isAccessibilityText,
          separatorIndent: _kSeparatorIndent,
          labels: [for (final id in favorites) storeNameOf(id)],
          onReorder: (from, to) => _reorder(favorites, from, to),
          children: [
            for (final id in favorites)
              _MarketRow(
                key: ValueKey<String>('favorite-$id'),
                chainId: id,
                selected: true,
                onTap: () => _toggle(id, favorites),
              ),
          ],
        ),
        OffersFootnote(note),
      ],
      if (StoreChainDirectory.chains.length >= _kSearchFrom) ...[
        const SizedBox(height: AvoSpacing.section),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AvoSpacing.screen),
          child: AvoSearchField(
            controller: _search,
            hint: context.tr('offer_pick_search'),
            onChanged: (_) => setState(() {}),
          ),
        ),
      ],
      InsetSection(
        header: context.tr('offer_favorites_more'),
        separatorIndent: _kSeparatorIndent,
        children: [
          for (final id in more)
            _MarketRow(
              chainId: id,
              selected: false,
              onTap: () => _toggle(id, favorites),
            ),
        ],
      ),
      if (more.isEmpty && query.trim().isNotEmpty)
        OffersLead(
          context.tr('offer_pick_no_result', params: {'query': query.trim()}),
          style: AvoTextStyle.body,
          top: AvoSpacing.xl,
        ),
    ];

    return OffersPage(
      title: context.tr('offer_favorites_title'),
      largeTitle: false,
      children: children,
    );
  }
}

/// One market: [SelectCircle], letter tile 28 and name; the whole row
/// toggles it. VoiceOver reads the circle (a switch named after the market).
class _MarketRow extends StatelessWidget {
  const _MarketRow({
    super.key,
    required this.chainId,
    required this.selected,
    required this.onTap,
  });

  final String chainId;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ax = context.isAccessibilityText;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      excludeFromSemantics: true,
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: _kRowMin),
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(
            _kCircleStart,
            AvoSpacing.xxs,
            AvoSpacing.l,
            AvoSpacing.xxs,
          ),
          child: Row(
            crossAxisAlignment: ax
                ? CrossAxisAlignment.start
                : CrossAxisAlignment.center,
            children: [
              SelectCircle(
                selected: selected,
                onChanged: (_) => onTap(),
                semanticLabel: storeNameOf(chainId),
              ),
              const SizedBox(width: _kCircleGap),
              Padding(
                padding: EdgeInsets.only(top: ax ? AvoSpacing.s : 0),
                child: StoreMark.chain(chainId, size: _kMark),
              ),
              const SizedBox(width: AvoSpacing.m),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    vertical: ax ? AvoSpacing.s : 0,
                  ),
                  child: ExcludeSemantics(
                    child: Text(
                      storeNameOf(chainId),
                      style: context.text(AvoTextStyle.body),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
