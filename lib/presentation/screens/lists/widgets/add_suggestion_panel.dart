import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:shoply/core/design/design.dart';
import 'package:shoply/core/localization/localization_helper.dart';
import 'package:shoply/data/services/purchase_tracking_service.dart';
import 'package:shoply/presentation/screens/lists/widgets/list_info_rows.dart';
import 'package:shoply/presentation/state/auth_provider.dart';
import 'package:shoply/presentation/state/items_provider.dart';
import 'package:shoply/presentation/widgets/design/avo_icons.dart';

/// The suggestion panel shows at most this many rows per block; more scroll
/// inside the panel (Konzept 00 §12.4, angebote.md S6).
const int kAddPanelMaxRows = 5;

/// From this many own items bought at least twice the start suggestions are
/// the person's own, else the fixed ones (Konzept 17 §9.8).
const int kOwnStartSuggestionsFrom = 5;

/// The panel never takes more than this share of the screen height, so the
/// list stays visible above it at large text sizes.
const double _maxScreenShare = 0.4;

// The panel: a white card on the floating layer (D2 hint card, like Teil
// B's offer rows above it).
const double _shadowAlpha = 0.08; // D2 `.card` on the floating layer
const double _shadowBlur = 14; // D2
const Offset _shadowOffset = Offset(0, 6); // D2

/// The fixed start suggestions (Konzept 17 §9.8: Milch, Brot, Eier,
/// Bananen, Butter; English accordingly).
List<String> defaultStartSuggestions(BuildContext context) => [
  for (var i = 1; i <= kAddPanelMaxRows; i++)
    context.tr('list_detail_start_$i'),
];

/// Names of the person's most bought items (bought at least twice), most
/// bought first. Empty while loading, signed out or on errors. Overridden in
/// tests.
final addFrequentItemNamesProvider = FutureProvider<List<String>>((ref) async {
  if (ref.watch(authUserIdProvider) == null) return const [];
  try {
    final stats = await PurchaseTrackingService().getFrequentItems(limit: 12);
    return [
      for (final s in stats)
        if (s.itemName.trim().isNotEmpty) _capitalize(s.itemName.trim()),
    ];
  } catch (e) {
    debugPrint('⚠️ [ADD_PANEL] Frequent items not read: $e');
    return const [];
  }
});

String _capitalize(String name) =>
    name.characters.first.toUpperCase() + name.characters.skip(1).string;

/// What the panel offers before the first letter on [listId] (Konzept 17
/// §9.8): the person's five most bought items once there are
/// [kOwnStartSuggestionsFrom] of them, else [defaults]; never one that is
/// already open on the list.
List<String> startSuggestionsFor(
  WidgetRef ref, {
  required String listId,
  required List<String> defaults,
}) {
  final own = ref.watch(addFrequentItemNamesProvider).valueOrNull ?? const [];
  final source = own.length >= kOwnStartSuggestionsFrom ? own : defaults;
  final open = {
    for (final i
        in ref.watch(itemsNotifierProvider(listId)).valueOrNull ?? const [])
      if (!i.isChecked) i.name.trim().toLowerCase(),
  };
  return [
    for (final name in source)
      if (!open.contains(name.trim().toLowerCase())) name,
  ].take(kAddPanelMaxRows).toList();
}

/// The suggestion panel above the add field (Konzept 00 §12.4, angebote.md
/// S6 and E-17): Teil B's offers block at the top, so offers that arrive
/// late never move what is under the finger, then the start suggestions.
///
/// Each block shows at most [kAddPanelMaxRows] rows and scrolls inside;
/// the whole panel stays under 40 % of the screen. A block that renders
/// nothing takes no space; without both the panel is gone.
class AddSuggestionPanel extends StatelessWidget {
  const AddSuggestionPanel({
    super.key,
    this.offers,
    this.starts = const [],
    this.onPick,
  });

  /// Teil B's block (`OfferSuggestionsBar`); it draws its own card.
  final Widget? offers;

  /// Start suggestions ("Milch", "Brot"); a tap hands one to [onPick].
  final List<String> starts;

  final ValueChanged<String>? onPick;

  @override
  Widget build(BuildContext context) {
    final offers = this.offers;
    final picks = onPick == null ? const <String>[] : starts;
    if (offers == null && picks.isEmpty) return const SizedBox.shrink();

    final rowHeight = math.max(
      AvoSizes.hitTarget,
      context.typography.lineHeightOf(AvoTextStyle.body) + 2 * AvoSpacing.m,
    );
    final screenCap = MediaQuery.sizeOf(context).height * _maxScreenShare;
    final blockCap = math.min(kAddPanelMaxRows * rowHeight, screenCap);

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: screenCap),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (offers != null)
            Flexible(
              child: _Capped(maxHeight: blockCap, child: offers),
            ),
          if (picks.isNotEmpty)
            Flexible(
              child: _Capped(
                maxHeight: blockCap,
                child: _StartBlock(names: picks, onPick: onPick!),
              ),
            ),
        ],
      ),
    );
  }
}

/// [child] up to [maxHeight], scrolling inside beyond it.
class _Capped extends StatelessWidget {
  const _Capped({required this.maxHeight, required this.child});

  final double maxHeight;
  final Widget child;

  @override
  Widget build(BuildContext context) => ConstrainedBox(
    constraints: BoxConstraints(maxHeight: maxHeight),
    child: SingleChildScrollView(
      physics: const ClampingScrollPhysics(),
      child: child,
    ),
  );
}

/// The start suggestions as tinted rows in one card.
class _StartBlock extends StatelessWidget {
  const _StartBlock({required this.names, required this.onPick});

  final List<String> names;
  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Semantics(
      container: true,
      label: context.tr('list_detail_suggestions'),
      explicitChildNodes: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(AvoRadii.card),
          boxShadow: [
            BoxShadow(
              color: colors.shadow.withValues(alpha: _shadowAlpha),
              offset: _shadowOffset,
              blurRadius: _shadowBlur,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AvoRadii.card),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < names.length; i++) ...[
                if (i > 0)
                  Padding(
                    padding: const EdgeInsetsDirectional.only(
                      start: AvoSpacing.l,
                    ),
                    child: SizedBox(
                      height: AvoSizes.hairline,
                      child: ColoredBox(color: colors.separator),
                    ),
                  ),
                ListInfoActionRow(
                  label: names[i],
                  icon: AvoIcons.plus,
                  onTap: () => onPick(names[i]),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
