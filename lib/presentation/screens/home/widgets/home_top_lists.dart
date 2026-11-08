import 'package:flutter/widgets.dart';
import 'package:shoply/core/design/design.dart';
import 'package:shoply/core/localization/localization_helper.dart';
import 'package:shoply/data/models/shopping_list_model.dart';
import 'package:shoply/presentation/widgets/design/avo_icons.dart';
import 'package:shoply/presentation/widgets/design/home_card.dart';
import 'package:shoply/presentation/widgets/design/inset_section.dart';
import 'package:shoply/presentation/widgets/design/item_row.dart';
import 'package:shoply/presentation/widgets/design/list_card.dart';
import 'package:shoply/routes/app_destinations.dart';

/// How many lists "Top-Listen" shows (D2: three).
const int kHomeTopListCount = 3;

/// The lists for "Top-Listen": the ones used last, at most
/// [kHomeTopListCount].
List<ShoppingListModel> homeTopLists(List<ShoppingListModel> lists) {
  final sorted = [...lists]
    ..sort(
      (a, b) => (b.lastAccessedAt ?? b.updatedAt).compareTo(
        a.lastAccessedAt ?? a.updatedAt,
      ),
    );
  return sorted.take(kHomeTopListCount).toList();
}

/// A list's colour from its `#RRGGBB` background, or null.
Color? listColorOf(ShoppingListModel list) {
  if (list.getBackgroundType() != 'color') return null;
  final hex = list.getBackgroundValue()?.replaceFirst('#', '');
  if (hex == null || hex.length != 6) return null;
  final value = int.tryParse(hex, radix: 16);
  return value == null ? null : Color(0xFF000000 | value);
}

/// "Top-Listen" on Home (D2): heading with "Alle", up to three lists as
/// rows with cover or colour square, open count and "Alles erledigt".
class HomeTopLists extends StatelessWidget {
  const HomeTopLists({super.key, required this.lists});

  /// All lists; the section picks [homeTopLists].
  final List<ShoppingListModel> lists;

  @override
  Widget build(BuildContext context) {
    final top = homeTopLists(lists);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AvoSectionHeader(
          context.tr('home_top_lists'),
          actionLabel: context.tr('common_all'),
          onAction: () => openAppDestination(context, AppDestinations.lists),
        ),
        const SizedBox(height: AvoSpacing.s),
        InsetSection(
          separatorIndent: ListRow.separatorIndent,
          children: [for (final list in top) _row(context, list)],
        ),
      ],
    );
  }

  Widget _row(BuildContext context, ShoppingListModel list) {
    final colors = context.colors;
    final total = list.itemCount ?? 0;
    final open = list.uncheckedCount ?? 0;
    final complete = total > 0 && open == 0;
    final parts = [
      if (!complete && open > 0)
        context.tr('home_open_items', params: {'n': '$open'}),
      if (list.isShared) context.tr('shared_label'),
    ];
    final imageUrl = list.getBackgroundType() == 'image'
        ? list.backgroundImageUrl
        : null;
    return ListRow(
      title: list.name,
      meta: complete
          ? context.tr('home_all_done')
          : (parts.isEmpty ? null : parts.join(' · ')),
      complete: complete,
      cover: imageUrl == null ? null : ItemThumb(image: NetworkImage(imageUrl)),
      color: listColorOf(list),
      glyph: AvoIcon(AvoIcons.cart, size: 20, color: colors.onTint),
      showChevron: false,
      onTap: () => openAppDestination(context, AppDestinations.list(list.id)),
    );
  }
}
