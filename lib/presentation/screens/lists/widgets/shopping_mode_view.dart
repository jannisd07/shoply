import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:shoply/core/design/design.dart';
import 'package:shoply/core/localization/localization_helper.dart';
import 'package:shoply/data/models/shopping_item_model.dart';
import 'package:shoply/presentation/screens/lists/widgets/shopping_mode_aisles.dart';
import 'package:shoply/presentation/screens/lists/widgets/shopping_mode_bars.dart';
import 'package:shoply/presentation/screens/lists/widgets/shopping_mode_header.dart';
import 'package:shoply/presentation/widgets/design/avo_figure.dart';
import 'package:shoply/presentation/widgets/design/avo_menu.dart';
import 'package:shoply/presentation/widgets/design/check_circle.dart';
import 'package:shoply/presentation/widgets/design/empty_state.dart';
import 'package:shoply/presentation/widgets/design/glass_toolbar.dart';
import 'package:shoply/presentation/widgets/design/item_row.dart';
import 'package:shoply/presentation/widgets/design/skeleton.dart';
import 'package:shoply/presentation/widgets/design/status_row.dart';
import 'package:shoply/presentation/widgets/design/undo_toast.dart';
import 'package:shoply/presentation/widgets/slots/b_slots.dart';

// How long a checked row stays in its aisle before it moves to "Im Wagen"
// (Konzept 11 §5.2). Display times, not animation durations.
const Duration _holdOwn = Duration(milliseconds: 600);
const Duration _holdOther = Duration(seconds: 2); // Konzept 11 §1.5
const Duration _holdIdleReduced = Duration(seconds: 1); // K-12

/// VoiceOver announces checks by others at most this often (Konzept 11
/// §1.5).
const Duration _announceGap = Duration(seconds: 3);

/// Gap above the status row, the empty state and the bottom spacer.
const double _blockGap = AvoSpacing.xxl;

/// Check a row of the shopping mode; completes when the change is saved,
/// throws when it is not.
typedef ShoppingToggle =
    Future<void> Function(ShoppingItemModel item, bool checked);

/// The shopping mode as a widget of plain data (D2 X-Einkaufsmodus,
/// Konzept 11 §5): [ShoppingModeScreen] feeds it from the providers.
///
/// - Aisles in [order], large rows; the whole row checks an item off (light
///   haptic, the last open item: success). A checked row stays struck
///   through in its aisle for 0.6 s (one checked by someone else: 2 s with
///   "gerade abgehakt"), then moves into "Im Wagen". With Reduce Motion it
///   stays until nothing was scrolled or tapped for 1 s.
/// - Every check shows "Abgehakt: Bananen · Widerrufen"; a failed save
///   rolls back, plays the error haptic and offers "Erneut versuchen".
/// - "Einkauf abschließen" is dimmed until something is checked.
/// - [items] null: still loading without a local copy (calm placeholder) or,
///   with [loadFailed], a status row with "Erneut versuchen".
class ShoppingModeView extends StatefulWidget {
  /// Creates the view.
  const ShoppingModeView({
    super.key,
    required this.listId,
    required this.title,
    required this.items,
    required this.onToggle,
    required this.onAdd,
    required this.onEdit,
    required this.onFinish,
    required this.onClose,
    this.order = const ShoppingAisleOrder(),
    this.companions = const [],
    this.offline = false,
    this.loadFailed = false,
    this.screenOn = true,
    this.showImages = true,
    this.onRetry,
  });

  /// The list (Teil B slots).
  final String listId;

  /// The list name, the large title.
  final String title;

  /// All items of the list, checked ones included; null while unknown.
  final List<ShoppingItemModel>? items;

  /// Saves a check or uncheck.
  final ShoppingToggle onToggle;

  /// "+": add an item.
  final VoidCallback onAdd;

  /// Long press or the VoiceOver action "Bearbeiten".
  final ValueChanged<ShoppingItemModel> onEdit;

  /// "Einkauf abschließen".
  final Future<void> Function() onFinish;

  /// Back button.
  final VoidCallback onClose;

  /// Aisle order of the list.
  final ShoppingAisleOrder order;

  /// Others shopping right now.
  final List<String> companions;

  /// No connection.
  final bool offline;

  /// Loading failed and there is nothing to show.
  final bool loadFailed;

  /// The screen is kept on (shows the capsule).
  final bool screenOn;

  /// Article images are on (`articleImagesShown`): rows without them take
  /// no room for the 52 pt image.
  final bool showImages;

  /// Loads the items again after [loadFailed].
  final VoidCallback? onRetry;

  @override
  State<ShoppingModeView> createState() => _ShoppingModeViewState();
}

/// A checked row that still stands in its aisle. Each has its own timer
/// (no wall clock, so it behaves the same under test time).
class _Hold {
  _Hold({required this.byOther});

  final bool byOther;
  bool leaving = false;
  Timer? timer;
}

class _ShoppingModeViewState extends State<ShoppingModeView> {
  /// Checked rows that still stand in their aisle, by item id.
  final Map<String, _Hold> _held = {};

  /// Checks started here that the items do not show yet (target state).
  final Map<String, bool> _ownChanges = {};

  /// Ids shown in the aisles in the last build; null before the first one.
  Set<String>? _aisleIds;

  bool _cartOpen = false;
  bool _finishing = false;
  bool _reduced = false;

  /// Stops the VoiceOver announcements from coming closer than 3 s.
  Timer? _announceQuiet;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduced = context.reduceMotion;
  }

  @override
  void didUpdateWidget(covariant ShoppingModeView oldWidget) {
    super.didUpdateWidget(oldWidget);
    final before = oldWidget.items;
    final now = widget.items;
    if (before == null || now == null || identical(before, now)) return;
    final wasChecked = {for (final i in before) i.id: i.isChecked};
    final present = <String>{};
    final byOthers = <ShoppingItemModel>[];
    for (final item in now) {
      present.add(item.id);
      final was = wasChecked[item.id];
      final own = _ownChanges[item.id];
      if (own != null && own == item.isChecked) _ownChanges.remove(item.id);
      if (was == false && item.isChecked && own == null) {
        byOthers.add(item);
      } else if (was == true && !item.isChecked) {
        _drop(item.id);
      }
    }
    for (final id in [..._held.keys]) {
      if (!present.contains(id)) _drop(id);
    }
    _ownChanges.removeWhere((id, _) => !present.contains(id));
    if (byOthers.isEmpty) return;
    for (final item in byOthers) {
      _hold(item.id, byOther: true);
    }
    _announce(byOthers);
  }

  @override
  void dispose() {
    for (final hold in _held.values) {
      hold.timer?.cancel();
    }
    _announceQuiet?.cancel();
    super.dispose();
  }

  // ------------------------------------------------------------- checking

  /// Keeps [id] in its aisle: 0.6 s for an own check, 2 s for one by
  /// someone else; with Reduce Motion at least until 1 s without input.
  void _hold(String id, {required bool byOther}) {
    _drop(id);
    final hold = _held[id] = _Hold(byOther: byOther);
    final wait = byOther
        ? _holdOther
        : (_reduced ? _holdIdleReduced : _holdOwn);
    hold.timer = Timer(wait, () => _release(id));
  }

  void _drop(String id) => _held.remove(id)?.timer?.cancel();

  void _release(String id) {
    if (!mounted) return;
    final hold = _held[id];
    if (hold == null || hold.leaving) return;
    setState(() => hold.leaving = true);
  }

  void _toggle(ShoppingItemModel item, bool checked) {
    if (!mounted) return;
    final items = widget.items ?? const <ShoppingItemModel>[];
    _ownChanges[item.id] = checked;
    if (checked) {
      setState(() => _hold(item.id, byOther: false));
      final lastOpen = !items.any((i) => !i.isChecked && i.id != item.id);
      if (lastOpen && items.isNotEmpty) unawaited(AvoHaptics.success());
      // The toast outlives this screen: after leaving, undo still saves.
      final save = widget.onToggle;
      AvoToast.show(
        context,
        message: context.tr(
          'list_shop_checked_toast',
          params: {'name': item.name.trim()},
        ),
        actionLabel: context.tr('common_undo'),
        onAction: () {
          if (mounted) {
            _toggle(item, false);
          } else {
            unawaited(
              save(item, false).catchError((Object e) {
                debugPrint('❌ [SHOPPING] Undo not saved: $e');
              }),
            );
          }
        },
      );
    } else {
      setState(() => _drop(item.id));
    }
    unawaited(_save(item, checked));
  }

  Future<void> _save(ShoppingItemModel item, bool checked) async {
    try {
      await widget.onToggle(item, checked);
    } catch (e) {
      debugPrint('❌ [SHOPPING] Check not saved: $e');
      if (!mounted) return;
      _ownChanges.remove(item.id);
      setState(() => _drop(item.id));
      unawaited(AvoHaptics.error());
      AvoToast.show(
        context,
        message: context.tr(
          'list_shop_not_saved',
          params: {'name': item.name.trim()},
        ),
        actionLabel: context.tr('common_try_again'),
        onAction: () => _toggle(item, checked),
      );
    }
  }

  /// Reduce Motion: a scroll or touch starts the 1 s of quiet over for every
  /// checked row still in its aisle (K-12).
  void _interacted() {
    if (!_reduced || _held.isEmpty) return;
    _held.forEach((id, hold) {
      if (hold.leaving) return;
      hold.timer?.cancel();
      hold.timer = Timer(_holdIdleReduced, () => _release(id));
    });
  }

  void _rowLeft(String id) {
    if (!mounted) return;
    final hold = _held[id];
    if (hold == null || !hold.leaving) return;
    setState(() => _drop(id));
  }

  void _announce(List<ShoppingItemModel> items) {
    if (defaultTargetPlatform != TargetPlatform.iOS) return;
    if (_announceQuiet?.isActive ?? false) return;
    _announceQuiet = Timer(_announceGap, () {});
    final view = View.maybeOf(context);
    if (view == null) return;
    SemanticsService.sendAnnouncement(
      view,
      context.tr(
        'list_shop_checked_by_other',
        params: {'name': items.map((i) => i.name.trim()).join(', ')},
      ),
      Directionality.maybeOf(context) ?? TextDirection.ltr,
    );
  }

  Future<void> _finish() async {
    if (_finishing) return;
    setState(() => _finishing = true);
    try {
      await widget.onFinish();
    } finally {
      if (mounted) setState(() => _finishing = false);
    }
  }

  // ------------------------------------------------------------- building

  Widget _row(ShoppingItemModel item, {required bool appear}) {
    final hold = _held[item.id];
    final byOther = hold?.byOther ?? false;
    final edit = context.tr('common_edit_item');
    void onEdit() => widget.onEdit(item);
    // With an offer the long press opens a menu ("Bearbeiten", "Angebot
    // ansehen"), whose entries are also the row's custom actions (status-B
    // 17, A-C1); without one it edits at once, as before.
    return Consumer(
      key: ValueKey('shop-row-${item.id}'),
      builder: (context, ref, _) {
        final offer = item.isChecked
            ? null
            : itemOfferRowExtras(
                context,
                ref,
                listId: widget.listId,
                item: item,
                shoppingMode: true,
              );
        final menu = offer == null
            ? const <AvoMenuEntry>[]
            : [
                AvoMenuItem(label: edit, onSelected: onEdit),
                ...offer.menuItems,
              ];
        return ShoppingRowMotion(
          appear: appear,
          leaving: hold?.leaving ?? false,
          onLeft: () => _rowLeft(item.id),
          child: GestureDetector(
            // VoiceOver gets "Bearbeiten" as a custom action of the row.
            excludeFromSemantics: true,
            onLongPress: menu.isEmpty ? onEdit : null,
            child: ItemRow(
              title: item.name,
              subtitle: byOther
                  ? context.tr('list_shop_just_checked')
                  : shoppingItemSubtitle(context, item),
              thumb: _thumb(item),
              trailing: item.isChecked
                  ? null
                  : ItemOfferBadge(
                      listId: widget.listId,
                      item: item,
                      compact: true,
                    ),
              checked: item.isChecked,
              onToggle: (checked) => _toggle(item, checked),
              size: ItemRowSize.large,
              checkState: byOther && item.isChecked
                  ? CheckState.doneByOther
                  : null,
              semanticActions: menu.isEmpty ? {edit: onEdit} : const {},
              trailingSemanticsLabel: offer?.semanticsLabel,
              trailingActions: offer?.actions ?? const {},
              contextMenuItems: menu,
            ),
          ),
        );
      },
    );
  }

  Widget? _thumb(ShoppingItemModel item) => widget.showImages
      ? ArticleImage(
          item: item,
          size: AvoSizes.thumbMedium,
          radius: AvoRadii.imageMedium,
        )
      : null;

  Widget _cartRow(ShoppingItemModel item) => GestureDetector(
    key: ValueKey('shop-cart-${item.id}'),
    // VoiceOver gets "Bearbeiten" as a custom action of the row.
    excludeFromSemantics: true,
    onLongPress: () => widget.onEdit(item),
    child: ItemRow(
      title: item.name,
      subtitle: shoppingItemSubtitle(context, item),
      thumb: _thumb(item),
      checked: true,
      onToggle: (checked) => _toggle(item, checked),
      size: ItemRowSize.large,
      semanticActions: {
        context.tr('common_edit_item'): () => widget.onEdit(item),
      },
    ),
  );

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final items = widget.items;
    final language = Localizations.localeOf(context).languageCode;
    final all = items ?? const <ShoppingItemModel>[];
    final total = all.length;
    final done = all.where((i) => i.isChecked).length;

    final inAisle = [
      for (final i in all)
        if (!i.isChecked || _held.containsKey(i.id)) i,
    ];
    final inCart = [
      for (final i in all)
        if (i.isChecked && !_held.containsKey(i.id)) i,
    ]..sort(_newestCheckFirst);
    final aisles = shoppingAisles(
      inAisle,
      order: widget.order,
      languageCode: language,
    );
    final previous = _aisleIds;
    _aisleIds = {for (final i in inAisle) i.id};
    bool appears(ShoppingItemModel i) =>
        previous != null && !previous.contains(i.id);

    final topOffset = GlassToolbar.topOffset(context);
    final canFinish = done > 0 && !_finishing;
    final finish = canFinish ? _finish : null;

    final content = <Widget>[
      // Invisible twin of the top row: the content starts under it at any
      // text size without measuring after the frame.
      ExcludeSemantics(
        child: IgnorePointer(
          child: Opacity(
            opacity: 0,
            child: Padding(
              padding: EdgeInsets.only(top: topOffset, bottom: AvoSpacing.s),
              child: ShoppingTopBar(
                onBack: widget.onClose,
                screenOn: widget.screenOn,
                twin: true,
              ),
            ),
          ),
        ),
      ),
      ShoppingModeHeader(
        listId: widget.listId,
        title: widget.title,
        done: done,
        total: total,
        companions: widget.companions,
      ),
      if (widget.offline)
        Padding(
          padding: const EdgeInsets.only(top: AvoSpacing.m),
          child: StatusRow(
            kind: StatusKind.offline,
            text: context.tr('list_shop_offline'),
          ),
        ),
      if (items == null && widget.loadFailed)
        Padding(
          padding: const EdgeInsets.only(top: _blockGap),
          child: StatusRow(
            kind: StatusKind.sectionError,
            text: context.tr('common_section_error'),
            actionLabel: widget.onRetry == null
                ? null
                : context.tr('common_try_again'),
            onAction: widget.onRetry,
          ),
        ),
      if (items == null && !widget.loadFailed)
        Padding(
          padding: const EdgeInsets.only(top: AvoSpacing.xl),
          child: const SkeletonSection(rows: 4),
        ),
      for (final aisle in aisles)
        ShoppingAisleSection(
          key: ValueKey('shop-aisle-${aisle.id}'),
          title: aisle.name,
          openCount: aisle.items.where((i) => !i.isChecked).length,
          withThumbs: widget.showImages,
          rows: [
            for (final item in aisle.items) _row(item, appear: appears(item)),
          ],
        ),
      if (items != null && inAisle.isEmpty)
        Padding(
          padding: const EdgeInsets.only(top: _blockGap),
          child: total == 0
              ? EmptyState(
                  title: context.tr('list_shop_empty_title'),
                  message: context.tr('list_shop_empty_body'),
                  actionLabel: context.tr('list_shop_add'),
                  onAction: widget.onAdd,
                )
              : EmptyState(
                  title: context.tr('list_shop_all_done_title'),
                  message: context.tr('list_shop_all_done_body'),
                  pose: AvoPose.celebrating,
                ),
        ),
      if (inCart.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(top: AvoSpacing.s),
          child: ShoppingCartSection(
            count: inCart.length,
            expanded: _cartOpen,
            onToggle: () => setState(() => _cartOpen = !_cartOpen),
            withThumbs: widget.showImages,
            rows: [for (final item in inCart) _cartRow(item)],
          ),
        ),
      // Invisible twin of the bottom bar, so the last row can scroll above
      // the floating capsule.
      ExcludeSemantics(
        child: IgnorePointer(
          child: Opacity(
            opacity: 0,
            child: Padding(
              padding: EdgeInsets.only(
                top: _blockGap,
                bottom: ShoppingBottomBar.bottomOffset(context),
              ),
              child: ShoppingBottomBar(
                onAdd: widget.onAdd,
                onFinish: finish,
                twin: true,
              ),
            ),
          ),
        ),
      ),
    ];

    final scroll = NotificationListener<ScrollNotification>(
      onNotification: (_) {
        _interacted();
        return false;
      },
      child: Listener(
        onPointerDown: (_) => _interacted(),
        child: ListView(padding: EdgeInsets.zero, children: content),
      ),
    );

    return ColoredBox(
      color: colors.background,
      child: Stack(
        children: [
          // VoiceOver: top row, content, bottom bar (all start at an edge,
          // so geometry alone cannot decide).
          Positioned.fill(
            child: Semantics(
              container: true,
              sortKey: const OrdinalSortKey(1),
              child: scroll,
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Semantics(
              container: true,
              explicitChildNodes: true,
              sortKey: const OrdinalSortKey(0),
              child: Stack(
                children: [
                  const Positioned.fill(child: ScrollEdgeFade()),
                  Padding(
                    padding: EdgeInsets.only(top: topOffset),
                    child: ShoppingTopBar(
                      onBack: widget.onClose,
                      screenOn: widget.screenOn,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: ShoppingBottomBar.bottomOffset(context),
            child: Semantics(
              container: true,
              explicitChildNodes: true,
              sortKey: const OrdinalSortKey(2),
              child: ShoppingBottomBar(onAdd: widget.onAdd, onFinish: finish),
            ),
          ),
        ],
      ),
    );
  }
}

int _newestCheckFirst(ShoppingItemModel a, ShoppingItemModel b) {
  final at = a.checkedAt;
  final bt = b.checkedAt;
  if (at == null && bt == null) return 0;
  if (at == null) return 1;
  if (bt == null) return -1;
  return bt.compareTo(at);
}
