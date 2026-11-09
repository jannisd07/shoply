import 'package:flutter/cupertino.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:shoply/core/design/design.dart';
import 'package:shoply/core/localization/localization_helper.dart';
import 'package:shoply/core/modules/app_modules.dart';
import 'package:shoply/presentation/screens/profile/settings/data/profile_settings.dart';
import 'package:shoply/presentation/screens/profile/settings/widgets/settings_page.dart';
import 'package:shoply/presentation/widgets/design/avo_menu.dart';
import 'package:shoply/presentation/widgets/design/inset_section.dart';
import 'package:shoply/presentation/widgets/design/picker_row.dart';
import 'package:shoply/presentation/widgets/design/row_highlight.dart';
import 'package:shoply/presentation/widgets/design/segmented_control.dart';

// Ranges of Konzept 18 §5.3: age 13 to 100, height 100 to 230 cm or 3 to 7 ft
// and 0 to 11 in. Wheels without a value start at a common middle.
const int _kAgeMin = 13;
const int _kAgeMax = 100;
const int _kAgeStart = 30;
const int _kCmMin = 100;
const int _kCmMax = 230;
const int _kCmStart = 170;
const int _kFeetMin = 3;
const int _kFeetMax = 7;

enum _Open { age, height }

/// "182 cm" or "5 ft 11 in"; "Nicht angegeben" without a height.
String personalHeightLabel(BuildContext context, PersonalSettings p) {
  final cm = p.heightCm;
  if (cm == null) return context.tr('setp_not_set');
  if (p.unit == HeightUnit.cm) {
    return context.tr('setp_personal_cm', params: {'n': '${cm.round()}'});
  }
  final fi = cmToFeetInches(cm);
  return context.tr(
    'setp_personal_ft_in',
    params: {'ft': '${fi.feet}', 'in': '${fi.inches}'},
  );
}

/// Persönliche Daten (`/settings/personal`, Konzept 18 §5.3): age and height
/// unfold a picker in the row ([PickerRow], no slider), gender is a
/// pull-down menu ([MenuValueRow]). Values act at once; switching cm and
/// ft converts the height instead of clearing it. The footer says what the
/// values are for, depending on the calories module.
class PersonalSettingsScreen extends ConsumerStatefulWidget {
  const PersonalSettingsScreen({super.key, this.highlightRowId});

  /// Row to highlight once (`?row=`), see `RowHighlightScope`.
  final String? highlightRowId;

  @override
  ConsumerState<PersonalSettingsScreen> createState() =>
      _PersonalSettingsScreenState();
}

class _PersonalSettingsScreenState
    extends ConsumerState<PersonalSettingsScreen> {
  _Open? _open;

  void _toggle(_Open which, bool open) =>
      setState(() => _open = open ? which : null);

  @override
  Widget build(BuildContext context) {
    final p = ref.watch(personalSettingsProvider);
    final notifier = ref.read(personalSettingsProvider.notifier);
    final caloriesOn = ref.watch(moduleEnabledProvider(AppModule.calories));
    final age = p.age;
    final gender = p.gender;

    return SettingsPage(
      title: context.tr('setp_personal_title'),
      highlightRowId: widget.highlightRowId,
      children: [
        InsetSection(
          footer: context.tr(
            caloriesOn ? 'setp_personal_footer_on' : 'setp_personal_footer_off',
          ),
          children: [
            HighlightableRow(
              id: 'personal.age',
              child: PickerRow(
                title: context.tr('setp_personal_age'),
                value: age == null
                    ? context.tr('setp_not_set')
                    : context.tr(
                        'setp_personal_age_value',
                        params: {'n': '$age'},
                      ),
                expanded: _open == _Open.age,
                onExpandedChanged: (o) => _toggle(_Open.age, o),
                picker: NumberPicker(
                  value: age,
                  min: _kAgeMin,
                  max: _kAgeMax,
                  initial: _kAgeStart,
                  onChanged: notifier.setAge,
                  unit: context.tr('setp_personal_years'),
                  semanticLabel: context.tr('setp_personal_age'),
                ),
              ),
            ),
            HighlightableRow(
              id: 'personal.height',
              child: PickerRow(
                title: context.tr('setp_personal_height'),
                value: personalHeightLabel(context, p),
                expanded: _open == _Open.height,
                onExpandedChanged: (o) => _toggle(_Open.height, o),
                picker: _HeightPicker(settings: p, notifier: notifier),
              ),
            ),
            HighlightableRow(
              id: 'personal.gender',
              child: MenuValueRow(
                title: context.tr('setp_personal_gender'),
                value: gender == null
                    ? context.tr('setp_not_set')
                    : context.tr('setp_gender_$gender'),
                items: [
                  for (final g in kPersonalGenders)
                    AvoMenuItem(
                      label: context.tr('setp_gender_$g'),
                      checked: g == gender,
                      onSelected: () => notifier.setGender(g),
                    ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// "cm | ft, in" and the wheel(s) for the height (Konzept 18 §5.3).
class _HeightPicker extends StatelessWidget {
  const _HeightPicker({required this.settings, required this.notifier});

  final PersonalSettings settings;
  final PersonalSettingsNotifier notifier;

  @override
  Widget build(BuildContext context) {
    final unit = settings.unit;
    final cm = settings.heightCm;
    final Widget picker;
    if (unit == HeightUnit.cm) {
      picker = NumberPicker(
        value: cm?.round(),
        min: _kCmMin,
        max: _kCmMax,
        initial: _kCmStart,
        onChanged: (v) => notifier.setHeightCm(v.toDouble()),
        unit: 'cm',
        semanticLabel: context.tr('setp_personal_height'),
      );
    } else {
      final fi = cmToFeetInches(cm ?? _kCmStart.toDouble());
      final feet = fi.feet.clamp(_kFeetMin, _kFeetMax);
      final inches = fi.inches;
      void set(int f, int i) => notifier.setHeightCm(feetInchesToCm(f, i));
      final feetLabel = context.tr('setp_personal_feet');
      final inchLabel = context.tr('setp_personal_inches');
      picker = pickerUsesField(context)
          ? Wrap(
              spacing: AvoSpacing.l,
              runSpacing: AvoSpacing.s,
              children: [
                PickerNumberField(
                  value: cm == null ? null : feet,
                  min: _kFeetMin,
                  max: _kFeetMax,
                  onChanged: (f) => set(f, inches),
                  unit: 'ft',
                  semanticLabel: feetLabel,
                ),
                PickerNumberField(
                  value: cm == null ? null : inches,
                  min: 0,
                  max: 11,
                  onChanged: (i) => set(feet, i),
                  unit: 'in',
                  semanticLabel: inchLabel,
                ),
              ],
            )
          : PickerWheel(
              columns: [
                WheelColumn(
                  labels: [
                    for (var f = _kFeetMin; f <= _kFeetMax; f++) '$f ft',
                  ],
                  selectedIndex: feet - _kFeetMin,
                  onSelected: (i) => set(_kFeetMin + i, inches),
                  semanticLabel: feetLabel,
                ),
                WheelColumn(
                  labels: [for (var i = 0; i < 12; i++) '$i in'],
                  selectedIndex: inches,
                  onSelected: (i) => set(feet, i),
                  semanticLabel: inchLabel,
                ),
              ],
            );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        AppSegmentedControl<HeightUnit>(
          semanticLabel: context.tr('setp_personal_unit'),
          segments: [
            SegmentItem(value: HeightUnit.cm, label: 'cm'),
            SegmentItem(
              value: HeightUnit.feet,
              label: context.tr('setp_personal_ft_in_short'),
            ),
          ],
          selected: unit,
          onChanged: notifier.setUnit,
        ),
        const SizedBox(height: AvoSpacing.s),
        picker,
      ],
    );
  }
}
