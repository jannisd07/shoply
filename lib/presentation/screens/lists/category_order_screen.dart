import 'package:flutter/cupertino.dart';
import 'package:flutter/semantics.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:shoply/core/constants/categories.dart';
import 'package:shoply/core/design/design.dart';
import 'package:shoply/core/localization/localization_helper.dart';
import 'package:shoply/data/models/custom_category.dart';
import 'package:shoply/data/services/category_order_service.dart';
import 'package:shoply/presentation/screens/lists/widgets/list_info_category_editor.dart';
import 'package:shoply/presentation/screens/lists/widgets/list_info_rows.dart';
import 'package:shoply/presentation/state/items_provider.dart';
import 'package:shoply/presentation/widgets/design/app_button.dart';
import 'package:shoply/presentation/widgets/design/avo_icons.dart';
import 'package:shoply/presentation/widgets/design/confirm_dialog.dart';
import 'package:shoply/presentation/widgets/design/glass_icon_button.dart';
import 'package:shoply/presentation/widgets/design/glass_toolbar.dart';
import 'package:shoply/presentation/widgets/design/inset_section.dart';
import 'package:shoply/presentation/widgets/design/undo_toast.dart';
import 'package:shoply/presentation/widgets/slots/b_slots.dart';

/// Category symbol size (Konzept 11 §12.1: 17 pt, `labelSecondary`).
const double _kSymbolSize = 17;

/// Lift while dragging (Konzept 11 §12.1: 1.03 with `shadowFloat`).
const double _kLiftScale = 1.03;
const double _kLiftShadowAlpha = 0.16; // D2 floating shadow
const double _kLiftShadowBlur = 18; // D2
const Offset _kLiftShadowOffset = Offset(0, 6); // D2

/// Category ids whose items count as one category: the open items per
/// category of a list. Overridden in tests.
final categoryOrderOpenCountsProvider = Provider.autoDispose
    .family<Map<String, int>, String>((ref, listId) {
      final items =
          ref.watch(itemsNotifierProvider(listId)).valueOrNull ?? const [];
      final counts = <String, int>{};
      for (final i in items) {
        if (i.isChecked) continue;
        final id = i.categoryId ?? i.category ?? 'other';
        counts[id] = (counts[id] ?? 0) + 1;
      }
      return counts;
    });

/// One row of the order.
@immutable
class _Category {
  const _Category.builtIn(this.id) : custom = null;
  _Category.custom(CustomCategory this.custom) : id = custom.id;

  final String id;
  final CustomCategory? custom;

  bool get isCustom => custom != null;

  String name(BuildContext context) =>
      custom?.name ??
      Categories.getById(
        id,
      ).getName(Localizations.localeOf(context).languageCode);
}

/// "Reihenfolge im Markt" (Konzept 11 §12.1): every category of the list in
/// the order the person walks through the store, always sortable by the
/// handle or a long press, with the open count; own categories (tap to
/// rename or delete), "Kategorie hinzufügen" and "Standard-Reihenfolge".
///
/// Order and own categories are kept by [CategoryOrderService], today on
/// this device only. The screen pops `true` when something changed, so the
/// list regroups.
class CategoryOrderScreen extends ConsumerStatefulWidget {
  const CategoryOrderScreen({
    super.key,
    required this.listId,
    required this.listName,
  });

  final String listId;
  final String listName;

  @override
  ConsumerState<CategoryOrderScreen> createState() =>
      _CategoryOrderScreenState();
}

class _CategoryOrderScreenState extends ConsumerState<CategoryOrderScreen> {
  final CategoryOrderService _service = CategoryOrderService();
  List<_Category>? _items;
  bool _changed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final order = await _service.getCategoryOrder(widget.listId);
    final customs = await _service.getCustomCategories(widget.listId);
    final customById = {for (final c in customs) c.id: c};
    final builtIn = Categories.allIds;
    final items = <_Category>[];
    for (final id in order) {
      final c = customById[id];
      if (c != null) {
        items.add(_Category.custom(c));
      } else if (builtIn.contains(id)) {
        items.add(_Category.builtIn(id));
      }
    }
    for (final id in builtIn) {
      if (!order.contains(id)) items.add(_Category.builtIn(id));
    }
    for (final c in customs) {
      if (!order.contains(c.id)) items.insert(0, _Category.custom(c));
    }
    if (mounted) setState(() => _items = items);
  }

  Future<void> _save(List<_Category> items) async {
    _changed = true;
    await _service.saveCategoryOrder(widget.listId, [
      for (final c in items) c.id,
    ]);
  }

  /// Moves the row at [oldIndex] to [newIndex] (both in the list without
  /// the moved row's gap, as `onReorderItem` reports them).
  void _reorder(int oldIndex, int newIndex) {
    final items = [...?_items];
    if (oldIndex == newIndex || newIndex < 0 || newIndex >= items.length) {
      return;
    }
    AvoHaptics.selection();
    items.insert(newIndex, items.removeAt(oldIndex));
    setState(() => _items = items);
    _save(items);
  }

  Future<void> _reset() async {
    final previous = [...?_items];
    final customs = [
      for (final c in previous)
        if (c.isCustom) c,
    ];
    final items = [
      ...customs,
      for (final id in Categories.allIds) _Category.builtIn(id),
    ];
    setState(() => _items = items);
    await _save(items);
    if (!mounted) return;
    AvoToast.show(
      context,
      message: context.tr('list_ov_order_reset'),
      actionLabel: context.tr('common_undo'),
      onAction: () {
        if (!mounted) return;
        setState(() => _items = previous);
        _save(previous);
      },
    );
  }

  Set<String> _takenNames(BuildContext context) => {
    for (final c in _items ?? const <_Category>[]) c.name(context),
  };

  Future<void> _add() async {
    final result = await openCategoryEditor(
      context,
      takenNames: _takenNames(context),
    );
    final name = result?.name;
    if (name == null || !mounted) return;
    await _service.addCustomCategory(
      widget.listId,
      name,
      Categories.getById('other').color,
    );
    _changed = true;
    await _load();
  }

  Future<void> _edit(_Category category) async {
    final custom = category.custom;
    if (custom == null) return;
    final result = await openCategoryEditor(
      context,
      initialName: custom.name,
      takenNames: _takenNames(context),
    );
    if (result == null || !mounted) return;
    if (result.delete) {
      await _delete(category);
      return;
    }
    final name = result.name;
    if (name == null || name == custom.name) return;
    await _service.updateCustomCategory(
      widget.listId,
      CustomCategory(id: custom.id, name: name, color: custom.color),
    );
    _changed = true;
    await _load();
  }

  Future<void> _delete(_Category category) async {
    final custom = category.custom;
    if (custom == null) return;
    final other = Categories.getById(
      'other',
    ).getName(Localizations.localeOf(context).languageCode);
    final confirmed = await showAvoConfirm(
      context,
      title: context.tr('list_ov_delete_title', params: {'name': custom.name}),
      message: context.tr(
        'list_ov_category_delete_message',
        params: {'other': other},
      ),
      confirmLabel: context.tr('list_ov_delete'),
    );
    if (!confirmed || !mounted) return;
    await _service.deleteCustomCategory(widget.listId, custom.id);
    _changed = true;
    await _load();
  }

  void _close() => Navigator.of(context).pop(_changed);

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final items = _items;
    final counts = ref.watch(categoryOrderOpenCountsProvider(widget.listId));
    final store = ref.watch(storeForListProvider(widget.listId));
    final route = ModalRoute.of(context);
    final cover = route is PageRoute && route.fullscreenDialog;
    final ax = context.isAccessibilityText;
    final intro = store == null
        ? context.tr(
            'list_ov_order_for_list',
            params: {'list': widget.listName},
          )
        : context.tr(
            'list_ov_order_for_store',
            params: {'store': store.name, 'list': widget.listName},
          );

    final slivers = <Widget>[
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AvoSpacing.screen,
            0,
            AvoSpacing.screen,
            AvoSpacing.m,
          ),
          child: Text(intro, style: context.text(AvoTextStyle.body)),
        ),
      ),
      if (items != null)
        SliverPadding(
          padding: EdgeInsets.symmetric(horizontal: ax ? 0 : AvoSpacing.screen),
          sliver: SliverReorderableList(
            itemCount: items.length,
            onReorderItem: _reorder,
            proxyDecorator: (child, index, animation) => AnimatedBuilder(
              animation: animation,
              child: child,
              builder: (context, child) {
                final t = Curves.easeOut.transform(animation.value);
                final scale = context.reduceMotion
                    ? 1.0
                    : 1 + (_kLiftScale - 1) * t;
                return Transform.scale(
                  scale: scale,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      boxShadow: [
                        BoxShadow(
                          color: colors.shadow.withValues(
                            alpha: _kLiftShadowAlpha * t,
                          ),
                          blurRadius: _kLiftShadowBlur,
                          offset: _kLiftShadowOffset,
                        ),
                      ],
                    ),
                    child: child,
                  ),
                );
              },
            ),
            itemBuilder: (context, index) => _OrderRow(
              key: ValueKey(items[index].id),
              index: index,
              count: items.length,
              name: items[index].name(context),
              symbol: items[index].isCustom
                  ? const AvoIcon(AvoIcons.tag, size: _kSymbolSize)
                  : Icon(
                      Categories.getById(items[index].id).icon,
                      size: _kSymbolSize,
                    ),
              open: counts[items[index].id] ?? 0,
              onTap: items[index].isCustom ? () => _edit(items[index]) : null,
              onMove: (delta) => _reorder(index, index + delta),
            ),
          ),
        ),
      SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            ax ? AvoSpacing.l : AvoSpacing.xxxl,
            AvoSpacing.s,
            ax ? AvoSpacing.l : AvoSpacing.xxxl,
            0,
          ),
          child: Text(
            context.tr('list_ov_order_footer'),
            style: context.text(
              AvoTextStyle.footnote,
              color: colors.secondaryLabel,
            ),
          ),
        ),
      ),
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.only(top: AvoSpacing.section),
          child: InsetSection(
            children: [
              ListInfoActionRow(
                label: context.tr('list_ov_add_category'),
                icon: AvoIcons.plus,
                onTap: _add,
              ),
            ],
          ),
        ),
      ),
      SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            AvoSpacing.screen,
            AvoSpacing.l,
            AvoSpacing.screen,
            ShellInsets.bottom(context),
          ),
          child: Center(
            child: AppButton.plain(
              label: context.tr('list_ov_default_order'),
              onPressed: items == null ? null : _reset,
            ),
          ),
        ),
      ),
    ];

    return PopScope<Object?>(
      canPop: !_changed,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _close();
      },
      child: ColoredBox(
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
                ...slivers,
              ],
            ),
            const Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: ScrollEdgeFade(),
            ),
            Positioned(
              top: GlassToolbar.topOffset(context),
              left: 0,
              right: 0,
              child: GlassToolbar(
                leading: GlassIconButton(
                  icon: AvoIcon(cover ? AvoIcons.xmark : AvoIcons.chevronBack),
                  semanticLabel: context.tr(cover ? 'common_close' : 'back'),
                  onPressed: _close,
                ),
                title: context.tr('list_ov_order'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One category row: symbol, name, open count, grip. Rounded at the ends
/// of the group (plain from AX1), hairline below except the last.
class _OrderRow extends StatelessWidget {
  const _OrderRow({
    super.key,
    required this.index,
    required this.count,
    required this.name,
    required this.symbol,
    required this.open,
    required this.onMove,
    this.onTap,
  });

  final int index;
  final int count;
  final String name;
  final Widget symbol;
  final int open;

  /// Moves the row by -1 or +1 (VoiceOver actions).
  final ValueChanged<int> onMove;

  /// Own categories: rename or delete.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final ax = context.isAccessibilityText;
    final first = index == 0;
    final last = index == count - 1;
    final radius = ax ? 0.0 : AvoRadii.group;
    final countText = open > 0
        ? Text(
            '$open',
            style: context.text(
              AvoTextStyle.subhead,
              color: colors.secondaryLabel,
              tabular: true,
            ),
          )
        : null;

    final grip = ReorderableDragStartListener(
      index: index,
      child: SizedBox.square(
        dimension: AvoSizes.hitTarget,
        child: Center(
          child: AvoIcon(
            AvoIcons.line3Horizontal,
            size: 20,
            color: colors.secondaryLabel,
          ),
        ),
      ),
    );

    final text = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(name, style: context.text(AvoTextStyle.body)),
        if (ax && countText != null) countText,
      ],
    );

    final row = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: AvoSizes.hitTarget),
      child: Padding(
        padding: const EdgeInsetsDirectional.only(
          start: AvoSpacing.l,
          end: AvoSpacing.xs,
        ),
        child: Row(
          children: [
            IconTheme.merge(
              data: IconThemeData(color: colors.secondaryLabel),
              child: symbol,
            ),
            const SizedBox(width: AvoSpacing.m),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: AvoSpacing.s),
                child: text,
              ),
            ),
            if (!ax && countText != null) ...[
              countText,
              const SizedBox(width: AvoSpacing.xs),
            ],
            grip,
          ],
        ),
      ),
    );

    final actions = <CustomSemanticsAction, VoidCallback>{
      if (index > 0)
        CustomSemanticsAction(label: context.tr('list_ov_move_up')): () =>
            onMove(-1),
      if (index < count - 1)
        CustomSemanticsAction(label: context.tr('list_ov_move_down')): () =>
            onMove(1),
    };

    final tap = onTap;
    return Semantics(
      container: true,
      button: tap != null,
      label: open > 0
          ? '$name, ${context.tr('home_open_items', params: {'n': '$open'})}'
          : name,
      onTap: tap,
      customSemanticsActions: actions,
      excludeSemantics: true,
      child: ReorderableDelayedDragStartListener(
        index: index,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: tap,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(first ? radius : 0),
                bottom: Radius.circular(last ? radius : 0),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                row,
                if (!last)
                  Padding(
                    padding: const EdgeInsetsDirectional.only(
                      start: AvoSpacing.l + _kSymbolSize + AvoSpacing.m,
                    ),
                    child: SizedBox(
                      height: AvoSizes.hairline,
                      width: double.infinity,
                      child: ColoredBox(color: colors.separator),
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
