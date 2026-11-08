import 'package:flutter/material.dart' show Theme;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:shoply/core/design/design.dart';
import 'package:shoply/core/localization/localization_helper.dart';
import 'package:shoply/presentation/providers/offer_lookup_provider.dart';
import 'package:shoply/presentation/widgets/design/avo_icons.dart';

// D2-Home counter pill on the cover (`angebote.md` 2.1, 3.8).
const EdgeInsetsDirectional _kPadding = EdgeInsetsDirectional.fromSTEB(
  7,
  4,
  9,
  4,
); // D2 padding 4 9 4 7
const double _kIcon = 11; // D2 tag
const double _kGap = AvoSpacing.xs; // D2 4

/// Pseudo glass on the cover photo, at least 92 % opaque so the green text
/// keeps 4.5:1 over a dark photo (A's ContentGlass has 78 %, request A-T2).
const double _kGlassAlpha = 0.92; // D2 + 3.8

/// "2 Angebote" at the top start of a list card's cover (S8, D2-Home,
/// contract `b_slots.dart`): open items of [listId] with a current offer of
/// its market, from the cached offers only, so the list overview never
/// starts a request per card.
///
/// Renders nothing for 0 and while offers may not show on the list (module,
/// kill switch, hidden list, no real region, "Angebote an Artikeln" off).
/// Not tappable; its sentence ("2 Artikel im Angebot") joins the card's
/// VoiceOver label. Reduce Transparency: solid white with an outline.
class ListOfferCountBadge extends ConsumerWidget {
  const ListOfferCountBadge({super.key, required this.listId});

  final String listId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count =
        ref.watch(listOfferBadgeCountProvider(listId)).valueOrNull ?? 0;
    if (count <= 0) return const SizedBox.shrink();
    final colors = context.colors;
    final text = count == 1
        ? context.tr('offer_count_badge_one')
        : context.tr('offer_count_badge_other', params: {'n': '$count'});
    final label = count == 1
        ? context.tr('offer_count_badge_a11y_one')
        : context.tr('offer_count_badge_a11y_other', params: {'n': '$count'});

    final solid = context.reduceTransparency;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final fill = solid
        ? colors.surface
        : (dark ? colors.glassFallback : colors.surface).withValues(
            alpha: _kGlassAlpha,
          );
    return Semantics(
      label: label,
      child: ExcludeSemantics(
        child: DecoratedBox(
          decoration: ShapeDecoration(
            color: fill,
            shape: StadiumBorder(
              side: BorderSide(
                color: solid ? colors.separator : colors.glassBorder,
                width: AvoSizes.hairline,
              ),
            ),
          ),
          child: Padding(
            padding: _kPadding,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                AvoIcon(
                  AvoIcons.tag,
                  size: MediaQuery.textScalerOf(context).scale(_kIcon),
                  color: colors.tint,
                ),
                const SizedBox(width: _kGap),
                Flexible(
                  child: Text(
                    text,
                    style: context.text(
                      AvoTextStyle.caption2,
                      color: colors.tint,
                      weight: FontWeight.w600,
                      tabular: true,
                    ),
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
