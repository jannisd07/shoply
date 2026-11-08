import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Theme;
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:shoply/core/design/design.dart';
import 'package:shoply/core/localization/localization_helper.dart';
import 'package:shoply/data/models/calorie_day.dart';
import 'package:shoply/data/models/water_log_entry.dart';
import 'package:shoply/presentation/screens/calories/widgets/calorie_bar.dart';
import 'package:shoply/presentation/screens/calories/widgets/calorie_colors.dart';
import 'package:shoply/presentation/screens/calories/widgets/calorie_entry_actions.dart';
import 'package:shoply/presentation/screens/calories/widgets/calorie_format.dart';
import 'package:shoply/presentation/state/calorie_diary_provider.dart';
import 'package:shoply/presentation/state/nutrition_provider.dart';
import 'package:shoply/presentation/widgets/design/app_button.dart';
import 'package:shoply/presentation/widgets/design/avo_icons.dart';
import 'package:shoply/presentation/widgets/design/avo_menu.dart';
import 'package:shoply/presentation/widgets/design/filter_chip.dart';
import 'package:shoply/presentation/widgets/design/home_card.dart';
import 'package:shoply/presentation/widgets/design/undo_toast.dart';
import 'package:shoply/routes/route_paths.dart';

/// Amounts of the long-press menu (S12).
const List<int> _kMenuAmounts = [150, 330, 500];

/// Largest amount the "Andere Menge" alert takes.
const int _kMaxWaterMl = 5000;

// D2 water row: drop 20, row 64; tile drops 12 × 14 with 4 apart, at most 12.
const double _kRowDrop = 20; // D2
const double _kRowMinHeight = 64; // D2
const Size _kTileDrop = Size(12, 14); // D2
const double _kTileDropGlyph = 14; // D2
const double _kTileDropGap = AvoSpacing.xs; // D2
const int _kMaxDrops = 12; // D2
const double _kTilePadding = 14; // D2 `.wtile` padding
const double _kTileGridGap = AvoSpacing.m; // D2 grid gap 12
const double _kTilePlusCircle = 32; // D2 "Nochmal kaufen" plus
const double _kTilePlusGlyph = 14; // D2
const double _kTilePlusStroke = 2.4; // D2
const double _kTileIcon = 18; // D2 symbol in the 32 pt square

/// Adds [ml] for [dateKey] (optimistic, queued, Health), plays the light
/// impact in the same frame and offers "Widerrufen" (S12). A null [dateKey]
/// means today at the moment of the tap.
Future<void> addCalorieWater(
  BuildContext context,
  WidgetRef ref,
  int ml, {
  required String? dateKey,
}) async {
  final message = context.tr('cal_water_added', params: {'ml': '$ml'});
  final undo = context.tr('common_undo');
  final diary = ref.read(calorieDiaryProvider);
  unawaited(AvoHaptics.light());
  final WaterLogEntry entry;
  try {
    entry = await diary.addWater(ml, dateKey: dateKey ?? calorieTodayKeyNow(ref));
  } catch (e) {
    debugPrint('❌ [CalorieWater] Adding water failed: ${calorieErrorKind(e)}');
    if (context.mounted) showCalorieWriteFailed(context);
    return;
  }
  if (!context.mounted) return;
  AvoToast.show(
    context,
    message: message,
    actionLabel: undo,
    onAction: () => diary.deleteWater(entry),
  );
}

/// Removes the newest water entry of [day] with "Widerrufen".
Future<void> _removeLastWater(BuildContext context, WidgetRef ref, WaterLogEntry last) async {
  final message = context.tr('cal_water_removed', params: {'ml': '${last.amountMl}'});
  final undo = context.tr('common_undo');
  final diary = ref.read(calorieDiaryProvider);
  try {
    await diary.deleteWater(last);
  } catch (e) {
    debugPrint('❌ [CalorieWater] Removing water failed: ${calorieErrorKind(e)}');
    if (context.mounted) showCalorieWriteFailed(context);
    return;
  }
  if (!context.mounted) return;
  AvoToast.show(
    context,
    message: message,
    actionLabel: undo,
    onAction: () => diary.restoreWater(last),
  );
}

/// The newest water entry of [day], or null.
WaterLogEntry? lastWaterEntry(CalorieDay? day) {
  final water = day?.water ?? const <WaterLogEntry>[];
  if (water.isEmpty) return null;
  return water.reduce((a, b) => b.createdAt.isAfter(a.createdAt) ? b : a);
}

/// The S12 pull-down menu: +150, +330, +500 ml, "Andere Menge …", and
/// "Letzten Eintrag entfernen (250 ml, 16:10)" when there is one. A null
/// [dateKey] means today.
Future<void> showWaterMenu(
  BuildContext context,
  WidgetRef ref, {
  required String? dateKey,
}) {
  final day = ref.read(calorieDayProvider(dateKey ?? calorieTodayKeyNow(ref))).day;
  final last = lastWaterEntry(day);
  return showAvoMenu(
    context,
    items: [
      for (final ml in _kMenuAmounts)
        AvoMenuItem(
          label: context.tr('cal_water_quick', params: {'ml': '$ml'}),
          onSelected: () => addCalorieWater(context, ref, ml, dateKey: dateKey),
        ),
      AvoMenuItem(
        label: context.tr('cal_water_other'),
        onSelected: () => _askOtherAmount(context, ref, dateKey),
      ),
      if (last != null) ...[
        const AvoMenuDivider(),
        AvoMenuItem(
          label: context.tr('cal_water_remove_last', params: {
            'ml': '${last.amountMl}',
            'time': context.clockTime(last.createdAt.toLocal()),
          }),
          icon: AvoIcons.trash,
          destructive: true,
          onSelected: () => _removeLastWater(context, ref, last),
        ),
      ],
    ],
  );
}

Future<void> _askOtherAmount(BuildContext context, WidgetRef ref, String? dateKey) async {
  final ml = await showWaterAmountAlert(context);
  if (ml == null || !context.mounted) return;
  await addCalorieWater(context, ref, ml, dateKey: dateKey);
}

/// "Wasser hinzufügen": a centred alert with a millilitre field (S12).
/// Resolves to the amount, or null on "Abbrechen". An invalid number shows
/// a hint under the field instead of silently becoming 0 (§3.3).
Future<int?> showWaterAmountAlert(BuildContext context) {
  return showCupertinoDialog<int>(
    context: context,
    builder: (dialogContext) => const _WaterAmountAlert(),
  );
}

class _WaterAmountAlert extends StatefulWidget {
  const _WaterAmountAlert();

  @override
  State<_WaterAmountAlert> createState() => _WaterAmountAlertState();
}

class _WaterAmountAlertState extends State<_WaterAmountAlert> {
  final _controller = TextEditingController();
  bool _invalid = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final input = parseCalorieNumber(
      _controller.text,
      integer: true,
      required: true,
      min: 1,
      max: _kMaxWaterMl.toDouble(),
    );
    if (!input.isValid) {
      setState(() => _invalid = true);
      return;
    }
    Navigator.of(context).pop(input.value!.round());
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return CupertinoTheme(
      data: CupertinoTheme.of(context).copyWith(
        primaryColor: colors.tint,
        brightness: Theme.of(context).brightness,
      ),
      child: CupertinoAlertDialog(
        title: Text(context.tr('cal_water_alert_title')),
        content: Padding(
          padding: const EdgeInsets.only(top: AvoSpacing.m),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              CupertinoTextField(
                controller: _controller,
                autofocus: true,
                placeholder: context.tr('cal_water_alert_field'),
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _submit(),
                onChanged: (_) {
                  if (_invalid) setState(() => _invalid = false);
                },
              ),
              if (_invalid)
                Padding(
                  padding: const EdgeInsets.only(top: AvoSpacing.xs),
                  child: Semantics(
                    liveRegion: true,
                    child: Text(
                      context.tr('cal_number_invalid'),
                      style: context.text(AvoTextStyle.footnote, color: colors.destructive),
                    ),
                  ),
                ),
            ],
          ),
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(context.tr('cancel')),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: _submit,
            child: Text(context.tr('cal_add')),
          ),
        ],
      ),
    );
  }
}

/// "1,25 l von 2 l" with the amount in semibold (S1 #8); "1,25 l" without a
/// goal.
Text _waterAmountText(BuildContext context, {required int ml, required int? goalMl}) {
  const marker = '\u0000';
  final template = goalMl == null
      ? context.tr('cal_water_plain', params: {'amount': marker})
      : context.tr('cal_water_of', params: {'amount': marker, 'goal': context.liters(goalMl)});
  final parts = template.split(marker);
  final style = context.text(AvoTextStyle.body, tabular: true);
  return Text.rich(
    TextSpan(children: [
      TextSpan(text: parts.first),
      TextSpan(text: context.liters(ml), style: style.copyWith(fontWeight: FontWeight.w600)),
      if (parts.length > 1) TextSpan(text: parts.sublist(1).join(marker)),
    ]),
    style: style,
  );
}

/// The spoken water value: "Wasser, 1,25 von 2 Litern" (S12).
String _waterSpoken(BuildContext context, {required int ml, required int? goalMl}) => goalMl == null
    ? context.tr('cal_water_a11y_plain', params: {'amount': context.liters(ml)})
    : context.tr('cal_water_a11y', params: {
        'amount': context.liters(ml),
        'goal': context.liters(goalMl),
      });

/// The diary's water row (S1 #8, S12): drop, "1,25 l von 2 l", a 4 pt bar
/// and the "+250 ml" chip. Long press opens the S12 menu. One VoiceOver
/// element whose default action adds the quick amount; "Andere Menge" and
/// "Letzten Eintrag entfernen" are its custom actions. The chip moves under
/// the text from AX1 on (and from xxL on a 320 pt screen).
class WaterRow extends ConsumerWidget {
  const WaterRow({super.key, required this.dateKey, required this.day, this.followsToday = false});

  /// The shown day.
  final String dateKey;

  /// The diary shows "today": writes go to today at the moment of the tap.
  final bool followsToday;

  String? get _writeKey => followsToday ? null : dateKey;

  /// The shown day; null while unknown (the row then shows 0).
  final CalorieDay? day;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final water = CalorieColors.of(context);
    final quick = ref.watch(calorieWaterQuickMlProvider);
    final goalMl = ref.watch(calorieWaterGoalMlProvider);
    final ml = day?.waterMl ?? 0;
    final reached = goalMl != null && ml >= goalMl;
    final last = lastWaterEntry(day);

    void add() => addCalorieWater(context, ref, quick, dateKey: _writeKey);

    final text = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Flexible(child: _waterAmountText(context, ml: ml, goalMl: goalMl)),
            if (reached) ...[
              const SizedBox(width: AvoSpacing.xs),
              Icon(CupertinoIcons.checkmark_circle_fill, size: _kRowDrop, color: colors.tint),
            ],
          ],
        ),
        if (goalMl != null) ...[
          const SizedBox(height: AvoSpacing.s),
          CalorieBar(fraction: ml / goalMl, color: water.water),
        ],
      ],
    );
    final chip = AppFilterChip(
      label: context.tr('cal_water_quick', params: {'ml': '$quick'}),
      selected: false,
      onSelected: (_) => add(),
    );
    final category = context.typography.category;
    final narrow = MediaQuery.sizeOf(context).width < 360;
    final stacked = context.isAccessibilityText ||
        (narrow && category.index >= ContentSizeCategory.xxLarge.index);

    final content = Row(
      crossAxisAlignment: stacked ? CrossAxisAlignment.start : CrossAxisAlignment.center,
      children: [
        Icon(CupertinoIcons.drop_fill, size: _kRowDrop, color: water.water),
        const SizedBox(width: AvoSpacing.m),
        Expanded(
          child: stacked
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [text, const SizedBox(height: AvoSpacing.s), chip],
                )
              : text,
        ),
        if (!stacked) ...[const SizedBox(width: AvoSpacing.m), chip],
      ],
    );

    return Semantics(
      container: true,
      button: true,
      label: _waterSpoken(context, ml: ml, goalMl: goalMl),
      hint: context.tr('cal_water_a11y_add', params: {'ml': '$quick'}),
      onTap: add,
      customSemanticsActions: {
        CustomSemanticsAction(label: context.tr('cal_water_other')): () =>
            _askOtherAmount(context, ref, _writeKey),
        if (last != null)
          CustomSemanticsAction(label: context.tr('cal_water_a11y_remove')): () =>
              _removeLastWater(context, ref, last),
      },
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onLongPress: () => showWaterMenu(context, ref, dateKey: _writeKey),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: _kRowMinHeight),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AvoSpacing.l, vertical: AvoSpacing.m),
            child: content,
          ),
        ),
      ),
    );
  }
}

/// The Home tile "Wasser heute" (D2 Kachel, S0/S12): drop square, a 44 pt
/// plus that adds the quick amount, "1,25 / 2 l" and a row of drops (filled
/// = glasses drunk, outlined = still open). With more than 12 glasses, or
/// when the drops do not fit, a 4 pt bar replaces them. Tap opens the diary
/// at the water row; long press opens the S12 menu.
class WaterTile extends ConsumerWidget {
  const WaterTile({super.key, required this.day});

  /// Today; null while unknown (the value then shows a dash).
  final CalorieDay? day;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final water = CalorieColors.of(context);
    final quick = ref.watch(calorieWaterQuickMlProvider);
    final goalMl = ref.watch(calorieWaterGoalMlProvider);
    final ml = day?.waterMl;
    final amount = ml == null ? '–' : context.liters(ml);
    final value = goalMl == null
        ? context.tr('cal_water_plain', params: {'amount': amount})
        : context.tr('cal_water_tile_value', params: {'amount': amount, 'goal': context.liters(goalMl)});
    final total = goalMl == null ? 0 : math.max(1, (goalMl / quick).ceil());
    final filled = ml == null ? 0 : math.min(total, ml ~/ quick);

    final spoken = StringBuffer(_waterSpokenTile(context, ml: ml ?? 0, goalMl: goalMl));
    if (goalMl != null && total <= _kMaxDrops) {
      spoken.write(' ');
      spoken.write(context.tr('cal_water_glasses_a11y', params: {'n': '$filled', 'total': '$total'}));
    }

    final tile = AvoTile(
      title: context.tr('cal_water_today'),
      icon: Icon(CupertinoIcons.drop_fill, size: _kTileIcon, color: water.water),
      iconBackground: water.waterFill,
      trailing: const SizedBox.square(dimension: AvoSizes.hitTarget),
      onTap: () => context.push('${RoutePaths.calories}?focus=water'),
      semanticLabel: spoken.toString(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(value, style: context.text(AvoTextStyle.title3, weight: FontWeight.w700, tabular: true)),
          if (goalMl != null) ...[
            const SizedBox(height: AvoSpacing.s),
            _Drops(total: total, filled: filled, fraction: (ml ?? 0) / goalMl),
          ],
        ],
      ),
    );

    return GestureDetector(
      // Today at the moment of the tap (Home may be open since yesterday).
      onLongPress: () => showWaterMenu(context, ref, dateKey: null),
      child: Stack(
        children: [
          tile,
          PositionedDirectional(
            top: _kTilePadding,
            end: _kTilePadding,
            child: _TilePlus(
              label: context.tr('cal_water_add_a11y', params: {'ml': '$quick'}),
              onTap: () => addCalorieWater(context, ref, quick, dateKey: null),
            ),
          ),
        ],
      ),
    );
  }
}

String _waterSpokenTile(BuildContext context, {required int ml, required int? goalMl}) => goalMl == null
    ? context.tr('cal_water_tile_a11y_plain', params: {'amount': context.liters(ml)})
    : context.tr('cal_water_tile_a11y', params: {
        'amount': context.liters(ml),
        'goal': context.liters(goalMl),
      });

/// Drops in a row; a bar when there are too many or they do not fit.
///
/// Home lays the tiles out with intrinsic heights, so this cannot measure
/// itself (no LayoutBuilder): the room is the tile's width on this screen,
/// two tiles per row below AX1 and one from AX1 on (`AvoTileGrid`).
class _Drops extends StatelessWidget {
  const _Drops({required this.total, required this.filled, required this.fraction});

  final int total;
  final int filled;
  final double fraction;

  @override
  Widget build(BuildContext context) {
    final c = CalorieColors.of(context);
    final screen = MediaQuery.sizeOf(context).width - 2 * AvoSpacing.screen;
    final tile = context.isAccessibilityText ? screen : (screen - _kTileGridGap) / 2;
    final room = tile - 2 * _kTilePadding;
    final needed = total * _kTileDrop.width + (total - 1) * _kTileDropGap;
    if (total > _kMaxDrops || needed > room) {
      return CalorieBar(fraction: fraction, color: c.water);
    }
    return ExcludeSemantics(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < total; i++) ...[
            if (i > 0) const SizedBox(width: _kTileDropGap),
            SizedBox.fromSize(
              size: _kTileDrop,
              child: OverflowBox(
                maxWidth: _kTileDropGlyph,
                maxHeight: _kTileDropGlyph,
                child: Icon(
                  i < filled ? CupertinoIcons.drop_fill : CupertinoIcons.drop,
                  size: _kTileDropGlyph,
                  color: i < filled ? c.water : c.emptyDrop,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// The tinted 32 pt plus in a 44 pt target (D2 "Nochmal kaufen").
class _TilePlus extends StatelessWidget {
  const _TilePlus({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Semantics(
      container: true,
      button: true,
      label: label,
      onTap: onTap,
      excludeSemantics: true,
      child: PressableScale(
        onPressed: onTap,
        child: SizedBox.square(
          dimension: AvoSizes.hitTarget,
          child: Center(
            child: DecoratedBox(
              decoration: BoxDecoration(color: colors.tintFill, shape: BoxShape.circle),
              child: SizedBox.square(
                dimension: _kTilePlusCircle,
                child: Center(
                  child: AvoIcon(AvoIcons.plus, size: _kTilePlusGlyph, color: colors.onTint, strokeWidth: _kTilePlusStroke),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
