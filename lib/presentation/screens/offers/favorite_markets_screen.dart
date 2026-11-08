import 'dart:async';

import 'package:flutter/semantics.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:shoply/core/design/design.dart';
import 'package:shoply/core/localization/localization_helper.dart';
import 'package:shoply/data/services/store_chain_directory.dart';
import 'package:shoply/presentation/providers/offer_display_prefs_provider.dart';
import 'package:shoply/presentation/screens/offers/store_menu.dart';
import 'package:shoply/presentation/screens/offers/widgets/offers_page.dart';
import 'package:shoply/presentation/screens/offers/widgets/store_mark.dart';
import 'package:shoply/presentation/widgets/design/avo_icons.dart';
import 'package:shoply/presentation/widgets/design/avo_menu.dart';
import 'package:shoply/presentation/widgets/design/inset_section.dart';
import 'package:shoply/presentation/widgets/design/search_field.dart';
import 'package:shoply/presentation/widgets/design/undo_toast.dart';

const double _kRowMin = 52; // D2 one line
const double _kMark = 28; // D2 StoreMark in rows
const double _kCircle = 22; // D2 selection circle
const double _kHandle = 22; // D2 line.3.horizontal in a 44 target
const double _kLiftShadowBlur = 12; // D2 lifted row while dragging

/// The search appears from this many directory chains on (S13).
const int _kSearchFrom = 12;

/// "Lieblingsmärkte" (S13, `/settings/offers/markets` in the Profil tab,
/// core): where do I shop, and in which order? The order decides the
/// market menu (S1) and, for lists without a fixed market, whose offers
/// come first.
///
/// "Deine Märkte" with a filled circle, letter tile, name and a drag handle
/// (the row follows the finger; long press on the row works too; dropping
/// clicks with the selection haptic). "Weitere Märkte" lists the rest of
/// the directory A–Z, with a search from 12 chains on. A tap adds a market
/// at the end of "Deine Märkte" or takes it out again (with an undo toast).
/// Reduce Motion and the accessibility sizes add "Nach oben" / "Nach unten"
/// to the row's context menu; VoiceOver has them as actions together with
/// "Entfernen" (the handle itself is hidden from it). Works with the offers
/// module off and the kill switch on too; the note says what the order does
/// today (first in the market menu).
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

  void _move(String chainId, int by) {
    unawaited(_prefs.moveFavorite(chainId, by));
    unawaited(AvoHaptics.selection());
  }

  /// [to] is the index after [from] was taken out (`onReorderItem`).
  void _reorder(List<String> favorites, int from, int to) {
    final next = [...favorites];
    final id = next.removeAt(from);
    next.insert(to.clamp(0, next.length), id);
    unawaited(_prefs.setFavorites(next));
    unawaited(AvoHaptics.selection());
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
        SectionCaps(
          context.tr('offer_favorites_yours'),
          padding: context.isAccessibilityText
              ? SectionCaps.plainPadding
              : SectionCaps.insetPadding,
        ),
        _FavoritesGroup(
          favorites: favorites,
          onToggle: (id) => _toggle(id, favorites),
          onMove: _move,
          onReorder: (from, to) => _reorder(favorites, from, to),
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
        separatorIndent: AvoSpacing.l + _kCircle + AvoSpacing.m,
        children: [
          for (final id in more)
            _MarketRow(
              chainId: id,
              selected: false,
              semanticLabel: storeNameOf(id),
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

/// The favourites as a sortable white group (D2 group, radius 26).
class _FavoritesGroup extends StatelessWidget {
  const _FavoritesGroup({
    required this.favorites,
    required this.onToggle,
    required this.onMove,
    required this.onReorder,
  });

  final List<String> favorites;
  final ValueChanged<String> onToggle;
  final void Function(String chainId, int by) onMove;
  final void Function(int from, int to) onReorder;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final plain = context.isAccessibilityText;
    final drag = !context.reduceMotion;
    final m = favorites.length;

    final list = ReorderableList(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: m,
      onReorderItem: onReorder,
      proxyDecorator: (child, index, animation) => DecoratedBox(
        decoration: BoxDecoration(
          color: colors.surface,
          boxShadow: [
            BoxShadow(
              color: colors.shadow.withValues(alpha: 0.18), // D2 lifted row
              blurRadius: _kLiftShadowBlur,
            ),
          ],
        ),
        child: child,
      ),
      itemBuilder: (context, index) {
        final id = favorites[index];
        final row = _MarketRow(
          chainId: id,
          selected: true,
          last: index == m - 1,
          handle: drag
              ? ReorderableDragStartListener(
                  index: index,
                  child: SizedBox(
                    width: AvoSizes.hitTarget,
                    height: AvoSizes.hitTarget,
                    child: Center(
                      child: AvoIcon(
                        AvoIcons.line3Horizontal,
                        size: _kHandle,
                        color: colors.secondaryLabel,
                      ),
                    ),
                  ),
                )
              : null,
          semanticLabel: context.tr(
            'offer_favorites_row_a11y',
            params: {'store': storeNameOf(id), 'n': '${index + 1}', 'm': '$m'},
          ),
          actions: {
            if (index > 0)
              context.tr('offer_favorites_move_up'): () => onMove(id, -1),
            if (index < m - 1)
              context.tr('offer_favorites_move_down'): () => onMove(id, 1),
            context.tr('offer_favorites_remove'): () => onToggle(id),
          },
          menu: !drag || context.isAccessibilityText
              ? [
                  if (index > 0)
                    AvoMenuItem(
                      label: context.tr('offer_favorites_move_up'),
                      onSelected: () => onMove(id, -1),
                    ),
                  if (index < m - 1)
                    AvoMenuItem(
                      label: context.tr('offer_favorites_move_down'),
                      onSelected: () => onMove(id, 1),
                    ),
                ]
              : const [],
          onTap: () => onToggle(id),
        );
        return KeyedSubtree(
          key: ValueKey<String>('favorite-$id'),
          child: drag && !context.isAccessibilityText
              ? ReorderableDelayedDragStartListener(index: index, child: row)
              : row,
        );
      },
    );

    final group = ColoredBox(color: colors.surface, child: list);
    if (plain) return group;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AvoSpacing.screen),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AvoRadii.group),
        child: group,
      ),
    );
  }
}

/// One market: selection circle, letter tile 28, name, optional drag
/// handle; the whole row toggles it. Hairline below unless [last].
class _MarketRow extends StatelessWidget {
  const _MarketRow({
    required this.chainId,
    required this.selected,
    required this.semanticLabel,
    required this.onTap,
    this.handle,
    this.last = true,
    this.actions = const {},
    this.menu = const [],
  });

  final String chainId;
  final bool selected;
  final String semanticLabel;
  final VoidCallback onTap;
  final Widget? handle;
  final bool last;
  final Map<String, VoidCallback> actions;
  final List<AvoMenuEntry> menu;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final ax = context.isAccessibilityText;
    final grip = handle;
    final content = Row(
      crossAxisAlignment: ax
          ? CrossAxisAlignment.start
          : CrossAxisAlignment.center,
      children: [
        Padding(
          padding: EdgeInsets.only(top: ax ? AvoSpacing.xxs : 0),
          child: AvoIcon(
            selected ? AvoIcons.checkmarkCircleFill : AvoIcons.circle,
            size: _kCircle,
            color: selected ? colors.tint : colors.uncheckedRing,
          ),
        ),
        const SizedBox(width: AvoSpacing.m),
        StoreMark.chain(chainId, size: _kMark),
        const SizedBox(width: AvoSpacing.m),
        Expanded(
          child: Text(
            storeNameOf(chainId),
            style: context.text(AvoTextStyle.body),
          ),
        ),
      ],
    );
    final main = Semantics(
      container: true,
      button: true,
      selected: selected,
      label: semanticLabel,
      onTap: onTap,
      customSemanticsActions: actions.isEmpty
          ? null
          : {
              for (final e in actions.entries)
                CustomSemanticsAction(label: e.key): e.value,
            },
      excludeSemantics: true,
      child: Builder(
        builder: (anchor) => GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          onLongPress: menu.isEmpty
              ? null
              : () => unawaited(showAvoMenu(anchor, items: menu)),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: _kRowMin),
            child: Padding(
              padding: EdgeInsetsDirectional.fromSTEB(
                AvoSpacing.l,
                AvoSpacing.s,
                grip == null ? AvoSpacing.l : 0,
                AvoSpacing.s,
              ),
              child: content,
            ),
          ),
        ),
      ),
    );
    return ColoredBox(
      color: colors.surface,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: ax
                ? CrossAxisAlignment.start
                : CrossAxisAlignment.center,
            children: [
              Expanded(child: main),
              if (grip != null)
                Padding(
                  padding: const EdgeInsetsDirectional.only(
                    top: AvoSpacing.xs,
                    end: AvoSpacing.xs,
                    bottom: AvoSpacing.xs,
                  ),
                  child: ExcludeSemantics(child: grip),
                ),
            ],
          ),
          if (!last)
            Padding(
              padding: const EdgeInsetsDirectional.only(
                start: AvoSpacing.l + _kCircle + AvoSpacing.m,
              ),
              child: SizedBox(
                height: AvoSizes.hairline,
                width: double.infinity,
                child: ColoredBox(color: colors.separator),
              ),
            ),
        ],
      ),
    );
  }
}
