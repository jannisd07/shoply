import 'package:flutter/widgets.dart';
import 'package:shoply/core/design/design.dart';
import 'package:shoply/core/localization/localization_helper.dart';
import 'package:shoply/data/models/shopping_list_model.dart';
import 'package:shoply/presentation/screens/home/home_layout.dart';
import 'package:shoply/presentation/widgets/design/avo_icons.dart';
import 'package:shoply/presentation/widgets/design/home_card.dart';
import 'package:shoply/presentation/widgets/slots/b_slots.dart';
import 'package:shoply/routes/app_destinations.dart';

/// "Für dich" on Home: heading and the tile grid in D2 order. Teil B's tiles
/// draw themselves; "Weiter einkaufen" is Teil A's.
class HomeForYou extends StatelessWidget {
  const HomeForYou({super.key, required this.tiles, this.continueList});

  /// Tiles to show (`homeTiles`), never empty.
  final List<HomeTile> tiles;

  /// The list behind "Weiter einkaufen".
  final ShoppingListModel? continueList;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AvoSectionHeader(context.tr('home_for_you')),
        const SizedBox(height: AvoSpacing.s),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AvoSpacing.screen),
          child: AvoTileGrid(
            children: [
              for (final tile in tiles)
                switch (tile) {
                  HomeTile.continueShopping => ContinueShoppingTile(
                    list: continueList!,
                  ),
                  HomeTile.restock => const HomeRestockTile(),
                  HomeTile.offers => const HomeOffersTile(),
                  HomeTile.water => const HomeWaterTile(),
                },
            ],
          ),
        ),
      ],
    );
  }
}

/// "Weiter einkaufen": the list with open items used last, with its
/// progress; opens the list.
class ContinueShoppingTile extends StatelessWidget {
  const ContinueShoppingTile({super.key, required this.list});

  final ShoppingListModel list;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final total = list.itemCount ?? 0;
    final open = list.uncheckedCount ?? 0;
    final done = (total - open).clamp(0, total);
    final title = context.tr('home_continue_shopping');
    final progress = context.tr(
      'home_done_of',
      params: {'done': '$done', 'total': '$total'},
    );
    return AvoTile(
      title: title,
      icon: AvoIcon(AvoIcons.cart, size: 18, color: colors.tint),
      semanticLabel: '$title, ${list.name}, $progress',
      onTap: () => openAppDestination(context, AppDestinations.list(list.id)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(list.name, style: context.text(AvoTextStyle.headline)),
          const SizedBox(height: AvoSpacing.xxs),
          Text(
            progress,
            style: context.text(
              AvoTextStyle.footnote,
              color: colors.secondaryLabel,
              tabular: true,
            ),
          ),
        ],
      ),
    );
  }
}
