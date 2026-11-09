import 'dart:async';

import 'package:flutter/semantics.dart';
import 'package:flutter/widgets.dart';

import 'package:shoply/presentation/widgets/design/avo_menu.dart';
import 'package:shoply/presentation/widgets/design/swipe_actions.dart';

export 'package:shoply/presentation/widgets/design/avo_menu.dart'
    show AvoMenuDivider, AvoMenuEntry, AvoMenuItem, AvoMenuTitle, AvoSubmenu;
export 'package:shoply/presentation/widgets/design/swipe_actions.dart'
    show SwipeAction;

/// The secondary actions of one row in one place (A-V17): swipe actions on
/// both sides ([SwipeActions]), a context menu on a long press
/// ([showAvoMenu]) and the same actions for VoiceOver.
///
/// - Swiping works as in [SwipeActions]: [trailingActions] at the end edge,
///   [leadingActions] at the start edge, a full swipe runs the first one.
/// - A long press on the row opens [menuItems] at the finger, with
///   [menuPreview] lifted over the row when given. While the row is swiped
///   open a long press does nothing, like a tap.
/// - VoiceOver gets every swipe action and every enabled [AvoMenuItem] of
///   the first menu level as a custom action. Two with the same label count
///   once and run the swipe action. A row that builds its own semantics node
///   sets [exposeSemantics] to false and adds [RowActions.semanticActionsOf]
///   to its own actions.
///
/// The row keeps its own tap: put the tappable row in [child]. Every action
/// of the menu should also be reachable without the gesture (detail screen,
/// "Mehr" menu), because a long press is easy to miss.
class RowActions extends StatelessWidget {
  /// Wraps [child] with swipe actions and a context menu.
  const RowActions({
    super.key,
    required this.child,
    this.trailingActions = const [],
    this.leadingActions = const [],
    this.menuItems = const [],
    this.menuPreview,
    this.menuSemanticLabel,
    this.fullSwipe = true,
    this.enabled = true,
    this.exposeSemantics = true,
    this.borderRadius = BorderRadius.zero,
  });

  /// The row.
  final Widget child;

  /// Actions at the end edge (swipe towards the start). First = outermost.
  final List<SwipeAction> trailingActions;

  /// Actions at the start edge (swipe towards the end). First = outermost.
  final List<SwipeAction> leadingActions;

  /// The context menu of a long press. Without a row that can be chosen the
  /// long press does nothing.
  final List<AvoMenuEntry> menuItems;

  /// Drawn lifted over the row while the menu is open (a copy of the row).
  final Widget? menuPreview;

  /// What VoiceOver calls the open menu ("Aktionen für Wocheneinkauf").
  final String? menuSemanticLabel;

  /// A full swipe runs the first action of that side.
  final bool fullSwipe;

  /// False turns swiping and the long press off and returns [child].
  final bool enabled;

  /// Adds the actions as custom actions to the enclosing semantics node.
  final bool exposeSemantics;

  /// Rounds the action surfaces (the card radius of a card row).
  final BorderRadiusGeometry borderRadius;

  /// The VoiceOver custom actions of a row with these actions: the enabled
  /// first-level [menuItems], then the swipe actions.
  static Map<CustomSemanticsAction, VoidCallback> semanticActionsOf({
    Iterable<SwipeAction> trailingActions = const [],
    Iterable<SwipeAction> leadingActions = const [],
    Iterable<AvoMenuEntry> menuItems = const [],
  }) => {
    for (final entry in menuItems)
      if (entry is AvoMenuItem && entry.enabled)
        CustomSemanticsAction(label: entry.label): entry.onSelected,
    ...SwipeActions.semanticActionsOf(trailingActions),
    ...SwipeActions.semanticActionsOf(leadingActions),
  };

  bool get _hasMenu => menuItems.any(
    (entry) =>
        (entry is AvoMenuItem && entry.enabled) ||
        (entry is AvoSubmenu && entry.enabled),
  );

  void _openMenu(BuildContext context, Offset globalPosition) {
    unawaited(
      showAvoMenu(
        context,
        items: menuItems,
        semanticLabel: menuSemanticLabel,
        preview: menuPreview,
        // With a preview the menu sits next to the lifted row; without one
        // it grows from the finger, like the menu of an item row.
        anchorRect: menuPreview != null
            ? null
            : Rect.fromCenter(center: globalPosition, width: 1, height: 1),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!enabled) return child;
    Widget row = child;
    if (_hasMenu) {
      row = GestureDetector(
        behavior: HitTestBehavior.translucent,
        excludeFromSemantics: true,
        onLongPressStart: (details) =>
            _openMenu(context, details.globalPosition),
        child: row,
      );
    }
    // The long press sits inside the swipe: an open row absorbs it.
    row = SwipeActions(
      trailingActions: trailingActions,
      leadingActions: leadingActions,
      fullSwipe: fullSwipe,
      exposeSemantics: false,
      borderRadius: borderRadius,
      child: row,
    );
    if (!exposeSemantics) return row;
    final actions = semanticActionsOf(
      trailingActions: trailingActions,
      leadingActions: leadingActions,
      menuItems: menuItems,
    );
    if (actions.isEmpty) return row;
    return Semantics(customSemanticsActions: actions, child: row);
  }
}
