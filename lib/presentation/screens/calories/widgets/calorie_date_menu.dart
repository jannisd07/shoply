import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Theme;

import 'package:shoply/core/design/design.dart';
import 'package:shoply/core/localization/localization_helper.dart';
import 'package:shoply/data/models/calorie_day.dart';
import 'package:shoply/presentation/screens/calories/widgets/calorie_format.dart';
import 'package:shoply/presentation/widgets/design/app_button.dart';
import 'package:shoply/presentation/widgets/design/avo_icons.dart';
import 'package:shoply/presentation/widgets/design/avo_menu.dart';

/// Earliest day the picker offers.
final DateTime _kFirstDay = DateTime(2020);

/// Height of the iOS date wheel inside the alert (UIDatePicker: 216).
const double _kWheelHeight = 216;

/// S2 "Datum wählen": a pull-down menu with today, yesterday and the five
/// days before (each with its kcal when something was logged, the shown day
/// checked), then "Datum wählen …", which opens a centred alert with the
/// iOS date wheel (the calendar menu A-C3 is not built yet). Never a sheet.
Future<void> showCalorieDateMenu(
  BuildContext context, {
  required String shownKey,
  required String todayKey,
  required Map<String, int> kcalByDay,
  required ValueChanged<String> onPick,
}) {
  String label(String key, int i) {
    if (i == 0) return context.tr('cal_today');
    if (i == 1) return context.tr('cal_yesterday');
    return context.shortDate(parseCalorieDayKey(key));
  }

  return showAvoMenu(
    context,
    items: [
      for (var i = 0; i < 7; i++)
        AvoMenuItem(
          label: label(shiftCalorieDayKey(todayKey, -i), i),
          subtitle: switch (kcalByDay[shiftCalorieDayKey(todayKey, -i)]) {
            final kcal? => context.tr('cal_meal_sum', params: {'kcal': context.kcal(kcal)}),
            null => null,
          },
          checked: shiftCalorieDayKey(todayKey, -i) == shownKey,
          onSelected: () => onPick(shiftCalorieDayKey(todayKey, -i)),
        ),
      const AvoMenuDivider(),
      AvoMenuItem(
        label: context.tr('cal_date_pick'),
        icon: AvoIcons.calendar,
        onSelected: () async {
          final picked = await showCalorieDatePicker(context, shownKey: shownKey, todayKey: todayKey);
          if (picked != null) onPick(picked);
        },
      ),
    ],
  );
}

/// The date wheel in a centred alert; resolves to the chosen day key or
/// null on "Abbrechen". Days after today cannot be chosen.
Future<String?> showCalorieDatePicker(
  BuildContext context, {
  required String shownKey,
  required String todayKey,
}) {
  if (!context.mounted) return Future.value();
  var chosen = parseCalorieDayKey(shownKey);
  final today = parseCalorieDayKey(todayKey);
  return showCupertinoDialog<String>(
    context: context,
    builder: (dialogContext) {
      final colors = dialogContext.colors;
      return CupertinoTheme(
        data: CupertinoTheme.of(dialogContext).copyWith(
          primaryColor: colors.tint,
          brightness: Theme.of(dialogContext).brightness,
        ),
        child: CupertinoAlertDialog(
          title: Text(dialogContext.tr('cal_date_pick_title')),
          content: SizedBox(
            height: _kWheelHeight,
            // The wheel rows have a fixed height, like UIDatePicker, which
            // does not grow with Dynamic Type either.
            child: MediaQuery.withNoTextScaling(
              child: CupertinoDatePicker(
                mode: CupertinoDatePickerMode.date,
                initialDateTime: chosen,
                minimumDate: _kFirstDay,
                maximumDate: today,
                onDateTimeChanged: (d) => chosen = d,
              ),
            ),
          ),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(dialogContext.tr('cancel')),
            ),
            CupertinoDialogAction(
              isDefaultAction: true,
              onPressed: () => Navigator.of(dialogContext).pop(calorieDayKey(chosen)),
              child: Text(dialogContext.tr('done')),
            ),
          ],
        ),
      );
    },
  );
}

const double _kChevronGlyph = 13; // D2
const double _kDateLineMin = AvoSizes.hitTarget; // D2 44

/// The diary's date line (S1 #3): "Heute, Sa., 7. Nov." with a chevron, the
/// whole line a button that opens [showCalorieDateMenu]; on another day a
/// text button "Heute" at the end.
class CalorieDateLine extends StatelessWidget {
  const CalorieDateLine({
    super.key,
    required this.shownKey,
    required this.todayKey,
    required this.onOpenMenu,
    required this.onToday,
  });

  final String shownKey;
  final String todayKey;

  /// Opens the menu; gets the context of the line (the menu grows from it).
  final ValueChanged<BuildContext> onOpenMenu;
  final VoidCallback onToday;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isToday = shownKey == todayKey;
    final line = Builder(
      builder: (lineContext) => Semantics(
        container: true,
        button: true,
        label: context.tr('cal_date_a11y', params: {'date': context.diaryDateSpoken(shownKey, todayKey)}),
        hint: context.tr('cal_date_hint'),
        onTap: () => onOpenMenu(lineContext),
        excludeSemantics: true,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => onOpenMenu(lineContext),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: _kDateLineMin),
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              widthFactor: 1,
              child: Text.rich(
                TextSpan(children: [
                  TextSpan(text: context.diaryDate(shownKey, todayKey)),
                  const TextSpan(text: ' '),
                  WidgetSpan(
                    alignment: PlaceholderAlignment.middle,
                    child: AvoIcon(
                      AvoIcons.chevronDown,
                      size: _kChevronGlyph,
                      color: colors.secondaryLabel,
                      strokeWidth: 2.6,
                    ),
                  ),
                ]),
                style: context.text(AvoTextStyle.subhead),
              ),
            ),
          ),
        ),
      ),
    );
    if (isToday) return line;
    return Row(
      children: [
        Expanded(child: line),
        const SizedBox(width: AvoSpacing.s),
        AppButton.plain(label: context.tr('cal_jump_today'), onPressed: onToday),
      ],
    );
  }
}
