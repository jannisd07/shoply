import 'package:flutter/physics.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:shoply/core/constants/categories.dart';
import 'package:shoply/core/design/design.dart';
import 'package:shoply/core/localization/localization_helper.dart';
import 'package:shoply/data/models/custom_category.dart';
import 'package:shoply/data/models/shopping_item_model.dart';
import 'package:shoply/data/services/category_order_service.dart';
import 'package:shoply/presentation/widgets/design/avo_icons.dart';
import 'package:shoply/presentation/widgets/design/inset_section.dart';
import 'package:shoply/presentation/widgets/design/item_row.dart';
import 'package:shoply/core/utils/item_quantity.dart';

/// The aisle order of one list: the saved category order and the list's
/// own categories (Konzept 11 §5.2 item 6, §12).
@immutable
class ShoppingAisleOrder {
  const ShoppingAisleOrder({
    this.categoryOrder = const [],
    this.customCategories = const [],
  });

  /// Category ids in walking order; empty uses the default order of
  /// `Categories.all` (typical supermarket path), own categories first.
  final List<String> categoryOrder;

  /// The list's own categories (ids start with `custom_`).
  final List<CustomCategory> customCategories;
}

/// The saved aisle order of [listId] from this device (`CategoryOrderService`).
/// There is no order per market yet; until it exists the order of the list
/// is used. Overridden in tests.
final shoppingAisleOrderProvider = FutureProvider.autoDispose
    .family<ShoppingAisleOrder, String>((ref, listId) async {
      final service = CategoryOrderService();
      final (order, custom) = await (
        service.getCategoryOrder(listId),
        service.getCustomCategories(listId),
      ).wait;
      return ShoppingAisleOrder(categoryOrder: order, customCategories: custom);
    });

/// One aisle in the shopping mode: a category with its items in list order.
@immutable
class ShoppingAisle {
  const ShoppingAisle({
    required this.id,
    required this.name,
    required this.items,
  });

  /// Category id (`dairy`, `custom_…`).
  final String id;

  /// Display name in the current language.
  final String name;

  /// The items, sorted like the list.
  final List<ShoppingItemModel> items;
}

/// The category id [item] belongs to, `other` for unknown ones.
String shoppingCategoryOf(
  ShoppingItemModel item,
  Set<String> customIds,
  String languageCode,
) {
  final raw = item.categoryId ?? item.category ?? 'other';
  if (CustomCategory.isCustomId(raw)) {
    return customIds.contains(raw) ? raw : 'other';
  }
  if (Categories.allIds.contains(raw)) return raw;
  return Categories.getIdByName(raw, languageCode) ?? 'other';
}

/// Groups [items] into aisles in [order]: saved order first, then every
/// other category that has items, in the default walking order. Aisles
/// without items are left out; items keep their list order.
List<ShoppingAisle> shoppingAisles(
  List<ShoppingItemModel> items, {
  required ShoppingAisleOrder order,
  required String languageCode,
}) {
  final customById = {for (final c in order.customCategories) c.id: c};
  final byCategory = <String, List<ShoppingItemModel>>{};
  for (final item in items) {
    final id = shoppingCategoryOf(item, customById.keys.toSet(), languageCode);
    (byCategory[id] ??= []).add(item);
  }

  final ids = <String>[
    for (final id in order.categoryOrder)
      if (byCategory.containsKey(id)) id,
  ];
  void addMissing(Iterable<String> candidates) {
    for (final id in candidates) {
      if (byCategory.containsKey(id) && !ids.contains(id)) ids.add(id);
    }
  }

  addMissing(customById.keys);
  addMissing(Categories.allIds);
  addMissing(byCategory.keys);

  return [
    for (final id in ids)
      ShoppingAisle(
        id: id,
        name:
            customById[id]?.name ??
            Categories.getById(id).getName(languageCode),
        items: _sorted(byCategory[id]!),
      ),
  ];
}

List<ShoppingItemModel> _sorted(List<ShoppingItemModel> items) {
  final indexed = [for (var i = 0; i < items.length; i++) (i, items[i])];
  indexed.sort((a, b) {
    final ai = a.$2.orderIndex ?? a.$2.sortOrder;
    final bi = b.$2.orderIndex ?? b.$2.sortOrder;
    if (ai != null && bi != null && ai != bi) return ai.compareTo(bi);
    if (ai != null && bi == null) return -1;
    if (ai == null && bi != null) return 1;
    return a.$1.compareTo(b.$1); // stable: keep the list's own order
  });
  return [for (final e in indexed) e.$2];
}

/// "500 g", "3 St.", "2 L · still": quantity (left out for a single piece
/// without unit) and note, the second line of a shopping-mode row.
String shoppingItemSubtitle(BuildContext context, ShoppingItemModel item) {
  final quantity = formatQuantity(
    item.quantity,
    item.unit,
    languageCode: Localizations.maybeLocaleOf(context)?.languageCode ?? 'de',
  );
  final note = item.notes?.trim();
  return [?quantity, if (note != null && note.isNotEmpty) note].join(' · ');
}

/// One aisle (D2 X-Einkaufsmodus): the caps heading with the number of
/// open items and a white group of large item rows.
class ShoppingAisleSection extends StatelessWidget {
  /// Creates an aisle section.
  const ShoppingAisleSection({
    super.key,
    required this.title,
    required this.openCount,
    required this.rows,
    this.withThumbs = true,
  });

  /// The aisle name in normal spelling ("Obst & Gemüse").
  final String title;

  /// Items not yet checked off, shown at the end of the heading.
  final int openCount;

  /// The rows, each a [ShoppingRowMotion] around an [ItemRow].
  final List<Widget> rows;

  /// Whether the rows show article images (hairlines start at the text).
  final bool withThumbs;

  @override
  Widget build(BuildContext context) => InsetSection(
    header: title,
    headerTrailing: Text('$openCount'),
    separatorIndent: ItemRow.separatorIndentOf(
      context,
      size: ItemRowSize.large,
      withThumb: withThumbs,
    ),
    children: rows,
  );
}

/// "Im Wagen (5)": the checked items at the end, collapsed by default
/// (Konzept 11 §5.2 item 7). Tapping the heading opens or closes it.
class ShoppingCartSection extends StatelessWidget {
  /// Creates the cart section.
  const ShoppingCartSection({
    super.key,
    required this.count,
    required this.expanded,
    required this.onToggle,
    required this.rows,
    this.withThumbs = true,
  });

  /// Number of checked items.
  final int count;

  /// Whether the rows show.
  final bool expanded;

  /// Opens or closes the section.
  final VoidCallback onToggle;

  /// The checked rows.
  final List<Widget> rows;

  /// Whether the rows show article images (hairlines start at the text).
  final bool withThumbs;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final glyph = context.typography.lineHeightOf(AvoTextStyle.sectionCaps);
    final heading = Semantics(
      button: true,
      expanded: expanded,
      label: context.tr('list_shop_in_cart_label', params: {'count': '$count'}),
      onTap: onToggle,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onToggle,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: AvoSizes.hitTarget),
          child: Align(
            alignment: AlignmentDirectional.bottomStart,
            heightFactor: 1,
            child: SectionCaps(
              context.tr('list_shop_in_cart'),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('$count'),
                  const SizedBox(width: AvoSpacing.xs),
                  AnimatedRotation(
                    turns: expanded ? 0 : -0.25,
                    duration: context.reduceMotion
                        ? Duration.zero
                        : AvoMotion.fadeReduced,
                    child: AvoIcon(
                      AvoIcons.chevronDown,
                      size: glyph * _cartChevronShare,
                      color: colors.secondaryLabel,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        heading,
        if (expanded)
          InsetSection(
            separatorIndent: ItemRow.separatorIndentOf(
              context,
              size: ItemRowSize.large,
              withThumb: withThumbs,
            ),
            children: rows,
          ),
      ],
    );
  }
}

/// The chevron takes this share of the caps line (13 pt in an 18 pt line).
const double _cartChevronShare = 0.72;

/// Moves a shopping-mode row in and out of its aisle (Konzept 11 §5.2): a
/// new or unchecked row grows in at its place, a checked row collapses once
/// [leaving] turns true, both on the [AvoMotion.move] spring. With Reduce
/// Motion both are a short cross-fade and the row then simply goes.
/// [onLeft] runs when the row is gone.
class ShoppingRowMotion extends StatefulWidget {
  /// Wraps one row.
  const ShoppingRowMotion({
    super.key,
    required this.child,
    this.appear = false,
    this.leaving = false,
    this.onLeft,
  });

  /// The row.
  final Widget child;

  /// Grow in when first shown (not on the screen's first frame).
  final bool appear;

  /// Collapse and then call [onLeft].
  final bool leaving;

  /// Called once the row has collapsed.
  final VoidCallback? onLeft;

  @override
  State<ShoppingRowMotion> createState() => _ShoppingRowMotionState();
}

class _ShoppingRowMotionState extends State<ShoppingRowMotion>
    with SingleTickerProviderStateMixin {
  late final AnimationController _shown = AnimationController(
    vsync: this,
    value: widget.appear ? 0 : 1,
  );
  bool _started = false;
  bool _reduced = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduced = context.reduceMotion;
    if (_started) return;
    _started = true;
    if (widget.leaving) {
      _leave();
    } else if (widget.appear) {
      _animate(1);
    }
  }

  @override
  void didUpdateWidget(covariant ShoppingRowMotion oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.leaving && !oldWidget.leaving) {
      _leave();
    } else if (!widget.leaving && oldWidget.leaving) {
      _animate(1);
    }
  }

  @override
  void dispose() {
    _shown.dispose();
    super.dispose();
  }

  Future<void> _animate(double target) async {
    if (_reduced) {
      await _shown
          .animateTo(
            target,
            duration: AvoMotion.fadeReduced,
            curve: Curves.easeInOut,
          )
          .orCancel
          .catchError((Object _) {});
    } else {
      await _shown
          .animateWith(
            SpringSimulation(
              AvoMotion.move,
              _shown.value,
              target,
              _shown.velocity,
              snapToEnd: true,
            ),
          )
          .orCancel
          .catchError((Object _) {});
    }
  }

  Future<void> _leave() async {
    await _animate(0);
    if (mounted && widget.leaving && _shown.value == 0) widget.onLeft?.call();
  }

  @override
  Widget build(BuildContext context) {
    final fade = FadeTransition(opacity: _shown, child: widget.child);
    if (_reduced) return fade;
    return SizeTransition(
      sizeFactor: _shown,
      alignment: AlignmentDirectional.topStart,
      child: fade,
    );
  }
}
