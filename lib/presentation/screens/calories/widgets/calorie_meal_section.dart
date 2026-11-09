import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/semantics.dart';

import 'package:shoply/core/design/design.dart';
import 'package:shoply/core/localization/localization_helper.dart';
import 'package:shoply/data/models/calorie_day.dart';
import 'package:shoply/data/models/food_log_entry.dart';
import 'package:shoply/presentation/screens/calories/widgets/calorie_format.dart';
import 'package:shoply/presentation/widgets/design/avo_icons.dart';
import 'package:shoply/presentation/widgets/design/avo_menu.dart';
import 'package:shoply/presentation/widgets/design/inset_section.dart';
import 'package:shoply/presentation/widgets/design/item_row.dart';

/// A full swipe deletes once the row moved this share of its width (as in
/// the list, Konzept 11 §1.1).
const double _kDeleteThreshold = 0.6;

// D2 rows: entry at least 60 high (`.row` 2 lines), "Eintragen" 52, image 44.
const double _kEntryMinHeight = 60; // D2
const double _kLogRowMinHeight = 52; // D2
const double _kRowVertical = 9; // D2 (60 - 22 - 20) / 2
const double _kPlusGlyph = 17; // D2
const double _kPlusStroke = 2.4; // D2 plus stroke
const double _kSyncGlyph = 10; // D2 sync mark behind the kcal
const double _kFailedGlyph = 17; // D2

/// What a diary row can do; null hides the action (its screen is not built
/// yet, or it does not apply to this day).
class FoodEntryActions {
  const FoodEntryActions({
    required this.onDelete,
    required this.onMove,
    required this.onRetry,
    this.onLogAgainToday,
    this.onEdit,
  });

  /// Tap, "Bearbeiten": opens S9.
  final VoidCallback? onEdit;

  /// Deletes (with undo); resolves to false when it failed, so a swiped row
  /// slides back.
  final Future<bool> Function() onDelete;
  final ValueChanged<MealType> onMove;

  /// Tap on a "Nicht gespeichert" row.
  final VoidCallback onRetry;

  /// "Heute nochmal eintragen" (past days only).
  final VoidCallback? onLogAgainToday;
}

/// One meal of the diary (`MealSection`, S1 #7): caps heading with the sum
/// ("FRÜHSTÜCK · 420 kcal"), its entries and a last row "Eintragen". An empty
/// meal is only the "Eintragen" row.
class MealSection extends StatelessWidget {
  const MealSection({
    super.key,
    required this.meal,
    required this.entries,
    required this.syncStateOf,
    required this.actionsFor,
    required this.onLog,
  });

  final MealType meal;
  final List<FoodLogEntry> entries;
  final CalorieSyncState Function(String id) syncStateOf;
  final FoodEntryActions Function(FoodLogEntry entry) actionsFor;

  /// "Eintragen": opens S3 with this meal.
  final VoidCallback onLog;

  @override
  Widget build(BuildContext context) {
    final name = context.mealName(meal);
    final sum = entries.fold<int>(0, (s, e) => s + e.calories);
    final withImage = !context.isAccessibilityText && entries.any((e) => e.photoUrl != null);
    return InsetSection(
      header: name,
      headerTrailing: entries.isEmpty
          ? null
          : Semantics(
              label: context.tr('cal_kcal_value', params: {'kcal': context.kcal(sum)}),
              excludeSemantics: true,
              child: Text(context.tr('cal_meal_sum', params: {'kcal': context.kcal(sum)})),
            ),
      separatorIndent: withImage ? AvoSpacing.l + AvoSizes.thumbSmall + AvoSpacing.m : AvoSpacing.l,
      children: [
        for (final e in entries)
          FoodEntryRow(
            key: ValueKey('cal-entry-${e.id}'),
            entry: e,
            mealName: name,
            syncState: syncStateOf(e.id),
            reserveImage: withImage,
            actions: actionsFor(e),
          ),
        _LogRow(meal: name, onTap: onLog),
      ],
    );
  }
}

/// A diary entry (`FoodEntryRow`): optional 44 pt image, name, "60 g ·
/// geschätzt", kcal on the right (under the name from AX1 on), the sync
/// mark or "Nicht gespeichert". Swipe left deletes, a long press opens the
/// context menu; VoiceOver gets the same actions.
class FoodEntryRow extends StatelessWidget {
  const FoodEntryRow({
    super.key,
    required this.entry,
    required this.mealName,
    required this.syncState,
    required this.actions,
    this.reserveImage = false,
  });

  final FoodLogEntry entry;
  final String mealName;
  final CalorieSyncState syncState;
  final FoodEntryActions actions;

  /// Some row of the meal has an image: keep the 44 pt column (empty
  /// without one), so the text edge stays straight.
  final bool reserveImage;

  void _openMenu(BuildContext context) {
    showAvoMenu(context, items: [
      if (actions.onEdit case final edit?)
        AvoMenuItem(label: context.tr('cal_menu_edit'), onSelected: edit),
      AvoMenuItem(
        label: context.tr('cal_menu_move'),
        onSelected: () => _openMoveMenu(context),
      ),
      if (actions.onLogAgainToday case final again?)
        AvoMenuItem(label: context.tr('cal_menu_again'), onSelected: again),
      const AvoMenuDivider(),
      AvoMenuItem(
        label: context.tr('cal_menu_delete'),
        icon: AvoIcons.trash,
        destructive: true,
        onSelected: () => actions.onDelete(),
      ),
    ]);
  }

  void _openMoveMenu(BuildContext context) {
    if (!context.mounted) return;
    showAvoMenu(context, items: [
      for (final meal in kMealOrder)
        if (meal != entry.mealType)
          AvoMenuItem(
            label: context.mealName(meal),
            onSelected: () => actions.onMove(meal),
          ),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final ax = context.isAccessibilityText;
    final failed = syncState == CalorieSyncState.failed;
    final pending = syncState == CalorieSyncState.pending;
    final subtitle = context.entrySubtitle(entry);
    final kcalText = context.kcal(entry.calories);

    final Widget trailing = failed
        ? Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(CupertinoIcons.exclamationmark_circle, size: _kFailedGlyph, color: colors.destructive),
              const SizedBox(width: AvoSpacing.xs),
              Flexible(
                child: Text(
                  context.tr('cal_row_not_saved'),
                  style: context.text(AvoTextStyle.subhead, color: colors.destructive),
                ),
              ),
            ],
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text.rich(
                TextSpan(children: [
                  TextSpan(text: kcalText),
                  TextSpan(
                    text: ' ${context.tr('cal_unit_kcal')}',
                    style: context.text(AvoTextStyle.subhead, color: colors.secondaryLabel),
                  ),
                ]),
                style: context.text(AvoTextStyle.body, tabular: true),
              ),
              if (pending) ...[
                const SizedBox(width: AvoSpacing.xs),
                AvoIcon(AvoIcons.sync, size: _kSyncGlyph, color: colors.secondaryLabel),
              ],
            ],
          );

    final text = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(entry.foodName, style: context.text(AvoTextStyle.body)),
        if (subtitle != null)
          Text(subtitle, style: context.text(AvoTextStyle.subhead, color: colors.secondaryLabel)),
      ],
    );

    final photo = entry.photoUrl;
    final content = Row(
      children: [
        if (reserveImage && !ax) ...[
          SizedBox.square(
            dimension: AvoSizes.thumbSmall,
            child: photo == null ? null : ItemThumb(image: NetworkImage(photo)),
          ),
          const SizedBox(width: AvoSpacing.m),
        ],
        Expanded(child: AdaptiveTrailing(stacked: ax, trailing: trailing, child: text)),
      ],
    );

    final spoken = [
      entry.foodName,
      if (entry.estimated) context.tr('cal_estimated_suffix'),
      context.tr('cal_kcal_value', params: {'kcal': kcalText}),
      mealName,
    ].join(', ');
    final label = failed
        ? context.tr('cal_row_not_saved_a11y', params: {'name': spoken})
        : pending
            ? '$spoken, ${context.tr('cal_row_sending_a11y')}'
            : spoken;

    final edit = actions.onEdit;
    final row = Semantics(
      container: true,
      label: label,
      button: failed || edit != null,
      hint: !failed && edit != null ? context.tr('cal_edit_hint') : null,
      onTap: failed ? actions.onRetry : edit,
      customSemanticsActions: {
        CustomSemanticsAction(label: context.tr('cal_menu_move')): () => _openMoveMenu(context),
        if (actions.onLogAgainToday case final again?)
          CustomSemanticsAction(label: context.tr('cal_menu_again')): again,
        CustomSemanticsAction(label: context.tr('cal_menu_delete')): () => actions.onDelete(),
      },
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: failed
            ? () {
                unawaited(AvoHaptics.error());
                actions.onRetry();
              }
            : edit,
        onLongPress: () => _openMenu(context),
        child: ColoredBox(
          color: colors.surface,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: _kEntryMinHeight),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AvoSpacing.l, vertical: _kRowVertical),
              child: content,
            ),
          ),
        ),
      ),
    );

    return Dismissible(
      key: ValueKey<String>('cal-dismiss-${entry.id}'),
      direction: DismissDirection.endToStart,
      dismissThresholds: const {DismissDirection.endToStart: _kDeleteThreshold},
      onUpdate: (details) {
        if (details.reached && !details.previousReached) unawaited(AvoHaptics.light());
      },
      // Deleting is optimistic: the day drops the row at once. Only when it
      // fails does the row slide back (with the error toast).
      confirmDismiss: (_) => actions.onDelete(),
      background: ColoredBox(
        color: colors.destructive,
        child: Align(
          alignment: AlignmentDirectional.centerEnd,
          child: Padding(
            padding: const EdgeInsetsDirectional.only(end: AvoSpacing.xl),
            child: AvoIcon(AvoIcons.trash, color: colors.onTint),
          ),
        ),
      ),
      child: row,
    );
  }
}

/// "Eintragen" at the end of a meal: plus and label in the accent colour,
/// the whole 52 pt row is the button ("Frühstück eintragen").
class _LogRow extends StatelessWidget {
  const _LogRow({required this.meal, required this.onTap});

  final String meal;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tint = context.colors.tint;
    return Semantics(
      container: true,
      button: true,
      label: context.tr('cal_log_meal_a11y', params: {'meal': meal}),
      onTap: onTap,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: _kLogRowMinHeight),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AvoSpacing.l, vertical: AvoSpacing.s),
            child: Row(
              children: [
                AvoIcon(AvoIcons.plus, size: _kPlusGlyph, color: tint, strokeWidth: _kPlusStroke),
                const SizedBox(width: AvoSpacing.s),
                Expanded(child: Text(context.tr('cal_log'), style: context.text(AvoTextStyle.body, color: tint))),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
