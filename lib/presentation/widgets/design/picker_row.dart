import 'package:flutter/cupertino.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';

import 'package:shoply/core/design/design.dart';
import 'package:shoply/core/localization/localization_helper.dart';
import 'package:shoply/presentation/widgets/design/avo_icons.dart';
import 'package:shoply/presentation/widgets/design/avo_menu.dart';

/// Minimum row height (D2 X-Profil `.row` min-height 52).
const double _kRowMinHeight = 52; // D2

/// Vertical padding of a row, like the other settings rows (D2: 60 pt with
/// a subtitle).
const double _kRowVerticalPadding = 9; // D2

/// Visible wheel rows (iOS inline pickers show five).
const int _kWheelVisibleRows = 5;

/// Room above and below one wheel line, so the selected value sits in a band
/// like the iOS picker (32 pt at body 17/22).
const double _kWheelLinePadding = 10;

/// Space under an open picker before the next hairline.
const double _kPickerBottom = AvoSpacing.s;

/// Minimum width of the number field from AX3 on.
const double _kFieldMinWidth = 64;

/// Gap between the value and the up-down chevrons of a [MenuValueRow].
const double _kUpDownGap = AvoSpacing.xs;

/// The up-down chevrons are drawn at the size of a small symbol next to
/// 17 pt text.
const double _kUpDownSize = 14;

/// Below this category the pickers are wheels; from AX3 on a number field
/// with the digit keypad (Konzept 18 E18-04: the wheel would be too small).
const ContentSizeCategory _kFieldFrom = ContentSizeCategory.ax3;

/// `chevron.up.chevron.down` of SF Symbols, on the 24 pt grid.
const AvoIconData _kUpDownIcon = AvoIconData([
  AvoIconPath('M8 9.5 12 5.5l4 4M8 14.5l4 4 4-4'),
], strokeWidth: 2);

/// Whether pickers use a number field instead of a wheel at this text size.
bool pickerUsesField(BuildContext context) =>
    context.typography.category.index >= _kFieldFrom.index;

/// The highlight iOS settings rows show while a finger is down (same as the
/// rows in `settings_rows.dart`).
class _PressableRow extends StatefulWidget {
  const _PressableRow({required this.child, required this.onTap});

  final Widget child;
  final VoidCallback onTap;

  @override
  State<_PressableRow> createState() => _PressableRowState();
}

class _PressableRowState extends State<_PressableRow>
    with SingleTickerProviderStateMixin {
  late final AnimationController _highlight;

  @override
  void initState() {
    super.initState();
    _highlight = AnimationController.unbounded(vsync: this);
  }

  void _press() {
    _highlight
      ..stop()
      ..value = 1;
  }

  void _release() {
    _highlight.animateWith(
      SpringSimulation(
        AvoMotion.quick,
        _highlight.value,
        0,
        _highlight.velocity,
      ),
    );
  }

  @override
  void dispose() {
    _highlight.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fill = context.colors.fillStrong;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      excludeFromSemantics: true,
      onTapDown: (_) => _press(),
      onTapUp: (_) => _release(),
      onTapCancel: _release,
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: _highlight,
        builder: (context, child) {
          final t = _highlight.value.clamp(0.0, 1.0);
          return ColoredBox(
            color: fill.withValues(alpha: fill.a * t),
            child: child,
          );
        },
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: _kRowMinHeight),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AvoSpacing.l,
              vertical: _kRowVerticalPadding,
            ),
            child: widget.child,
          ),
        ),
      ),
    );
  }
}

/// Title and value: side by side while both fit (the value wraps below when
/// not), stacked from AX1 on.
class _TitleValue extends StatelessWidget {
  const _TitleValue({required this.title, required this.value, this.leading});

  final Widget title;
  final Widget value;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    final ax = context.isAccessibilityText;
    final Widget body = ax
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [title, value],
          )
        : Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: AvoSpacing.m,
            runSpacing: AvoSpacing.xxs,
            children: [title, value],
          );
    final lead = leading;
    if (lead == null) {
      return Align(
        alignment: AlignmentDirectional.centerStart,
        heightFactor: 1,
        child: body,
      );
    }
    return Row(
      crossAxisAlignment: ax
          ? CrossAxisAlignment.start
          : CrossAxisAlignment.center,
      children: [
        lead,
        const SizedBox(width: AvoSpacing.m),
        Expanded(child: body),
      ],
    );
  }
}

/// A settings row whose value is edited in the row itself (Konzept 18
/// E18-04): tapping it unfolds [picker] under it on the standard spring, the
/// neighbours move down; tapping again folds it. Replaces every slider and
/// picker sheet.
///
/// The page decides which row is open ([expanded], usually one at a time).
/// While open the value is drawn in the accent colour, like iOS. Reduce
/// Motion turns the unfolding into a short fade. VoiceOver reads one button
/// with title, value and the expanded state; the picker below is reachable
/// on its own (wheels are adjustable, the field is a text field).
///
/// Use [NumberPicker], [TimeOfDayPicker] or a [PickerWheel] as [picker]; they
/// switch to a number field from AX3 on.
class PickerRow extends StatefulWidget {
  /// Creates a picker row.
  const PickerRow({
    super.key,
    required this.title,
    required this.value,
    required this.expanded,
    required this.onExpandedChanged,
    required this.picker,
    this.leading,
  });

  /// Row title ("Alter"), 17/22.
  final String title;

  /// The current value as text ("34 Jahre", "Nicht angegeben"), 17/22.
  final String value;

  /// Whether the picker is open.
  final bool expanded;

  /// Called with the new state when the row is tapped.
  final ValueChanged<bool> onExpandedChanged;

  /// The editor shown while [expanded].
  final Widget picker;

  /// Optional icon tile before the title.
  final Widget? leading;

  @override
  State<PickerRow> createState() => _PickerRowState();
}

class _PickerRowState extends State<PickerRow>
    with SingleTickerProviderStateMixin {
  late final AnimationController _open;
  bool _reduceMotion = false;

  @override
  void initState() {
    super.initState();
    _open = AnimationController.unbounded(
      vsync: this,
      value: widget.expanded ? 1 : 0,
    );
  }

  @override
  void didUpdateWidget(PickerRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.expanded == widget.expanded) return;
    final target = widget.expanded ? 1.0 : 0.0;
    if (_reduceMotion) {
      _open.animateTo(
        target,
        duration: AvoMotion.fadeReduced,
        curve: Curves.easeInOut,
      );
    } else {
      _open.animateWith(
        SpringSimulation(
          AvoMotion.standard,
          _open.value,
          target,
          _open.velocity,
          snapToEnd: true,
        ),
      );
    }
  }

  @override
  void dispose() {
    _open.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _reduceMotion = context.reduceMotion;
    final colors = context.colors;
    final open = widget.expanded;
    void toggle() => widget.onExpandedChanged(!open);
    final header = Semantics(
      container: true,
      button: true,
      expanded: open,
      label: widget.title,
      value: widget.value,
      onTap: toggle,
      child: ExcludeSemantics(
        child: _PressableRow(
          onTap: toggle,
          child: _TitleValue(
            leading: widget.leading,
            title: Text(widget.title, style: context.text(AvoTextStyle.body)),
            value: Text(
              widget.value,
              style: context.text(
                AvoTextStyle.body,
                color: open ? colors.tint : colors.secondaryLabel,
                tabular: true,
              ),
            ),
          ),
        ),
      ),
    );
    return AnimatedBuilder(
      animation: _open,
      builder: (context, _) {
        final t = _open.value.clamp(0.0, 1.0);
        if (t == 0 && !open) return header;
        final body = Padding(
          padding: const EdgeInsets.fromLTRB(
            AvoSpacing.l,
            0,
            AvoSpacing.l,
            _kPickerBottom,
          ),
          child: widget.picker,
        );
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            header,
            ClipRect(
              child: Align(
                alignment: AlignmentDirectional.topStart,
                // Reduce Motion: the picker keeps its height and only fades.
                heightFactor: _reduceMotion ? 1 : t,
                child: Opacity(opacity: t, child: body),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// One column of a [PickerWheel].
@immutable
class WheelColumn {
  /// Creates a column with [labels], [selectedIndex] chosen.
  const WheelColumn({
    required this.labels,
    required this.selectedIndex,
    required this.onSelected,
    this.semanticLabel,
    this.flex = 1,
  });

  /// The visible rows ("13" … "100", "cm").
  final List<String> labels;

  /// Index of the chosen row.
  final int selectedIndex;

  /// Called when the wheel settles on another row.
  final ValueChanged<int> onSelected;

  /// What this column chooses ("Fuß", "Zoll"), for VoiceOver.
  final String? semanticLabel;

  /// Width share next to other columns.
  final int flex;
}

/// An iOS wheel with one or more [columns] (Konzept 18 E18-04), drawn with
/// the Avo type scale: the line height follows Dynamic Type, so no value is
/// ever cut. The system plays its selection tick while the wheel turns.
///
/// From AX3 on, show a [PickerNumberField] instead ([pickerUsesField]); the
/// ready-made [NumberPicker] and [TimeOfDayPicker] do that themselves.
class PickerWheel extends StatelessWidget {
  /// Creates a wheel.
  const PickerWheel({super.key, required this.columns});

  /// The columns, side by side.
  final List<WheelColumn> columns;

  @override
  Widget build(BuildContext context) {
    final line = context.typography.lineHeightOf(AvoTextStyle.body);
    final extent = line + 2 * _kWheelLinePadding;
    return SizedBox(
      height: extent * _kWheelVisibleRows,
      child: Row(
        children: [
          for (final c in columns)
            Expanded(
              flex: c.flex,
              child: _WheelColumnView(column: c, extent: extent),
            ),
        ],
      ),
    );
  }
}

class _WheelColumnView extends StatefulWidget {
  const _WheelColumnView({required this.column, required this.extent});

  final WheelColumn column;
  final double extent;

  @override
  State<_WheelColumnView> createState() => _WheelColumnViewState();
}

class _WheelColumnViewState extends State<_WheelColumnView> {
  late final FixedExtentScrollController _controller =
      FixedExtentScrollController(initialItem: widget.column.selectedIndex);

  @override
  void didUpdateWidget(_WheelColumnView oldWidget) {
    super.didUpdateWidget(oldWidget);
    final target = widget.column.selectedIndex;
    if (!_controller.hasClients) return;
    if (_controller.selectedItem != target &&
        oldWidget.column.selectedIndex != target) {
      _controller.jumpToItem(target);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final column = widget.column;
    final style = context.text(AvoTextStyle.body, tabular: true);
    final picker = CupertinoPicker(
      scrollController: _controller,
      itemExtent: widget.extent,
      useMagnifier: false,
      selectionOverlay: CupertinoPickerDefaultSelectionOverlay(
        background: colors.fill,
      ),
      onSelectedItemChanged: column.onSelected,
      children: [
        for (final label in column.labels)
          Center(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: style,
            ),
          ),
      ],
    );
    final name = column.semanticLabel;
    if (name == null) return picker;
    return Semantics(container: true, label: name, child: picker);
  }
}

/// A number field with the digit keypad, the AX3+ form of a wheel (Konzept 18
/// E18-04). Takes the number on Return and when the field loses focus; a
/// number outside [min]–[max] is not taken and a hint says the range.
class PickerNumberField extends StatefulWidget {
  /// Creates a number field.
  const PickerNumberField({
    super.key,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    this.unit,
    this.semanticLabel,
  });

  /// The current number; null shows an empty field.
  final int? value;

  /// Smallest allowed number.
  final int min;

  /// Largest allowed number.
  final int max;

  /// Called with a valid new number.
  final ValueChanged<int> onChanged;

  /// Unit after the field ("Jahre", "cm").
  final String? unit;

  /// VoiceOver label of the field.
  final String? semanticLabel;

  @override
  State<PickerNumberField> createState() => _PickerNumberFieldState();
}

class _PickerNumberFieldState extends State<PickerNumberField> {
  late final TextEditingController _text = TextEditingController(
    text: widget.value?.toString() ?? '',
  );
  final FocusNode _focus = FocusNode();
  bool _invalid = false;

  /// The number last reported, until the parent passes it back: Return and
  /// the focus loss right after it must not report it twice.
  int? _sent;

  @override
  void initState() {
    super.initState();
    _focus.addListener(() {
      if (!_focus.hasFocus) _commit();
    });
  }

  @override
  void didUpdateWidget(PickerNumberField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != oldWidget.value) _sent = null;
    if (!_focus.hasFocus && widget.value != oldWidget.value) {
      _text.text = widget.value?.toString() ?? '';
    }
  }

  void _commit() {
    final raw = _text.text.trim();
    if (raw.isEmpty) {
      _text.text = widget.value?.toString() ?? '';
      if (_invalid) setState(() => _invalid = false);
      return;
    }
    final n = int.tryParse(raw);
    final ok = n != null && n >= widget.min && n <= widget.max;
    if (ok) {
      // The same number again (also the reset after a wrong one) keeps the
      // hint; typing clears it.
      if (n == (_sent ?? widget.value)) return;
      _sent = n;
      widget.onChanged(n);
    } else {
      _text.text = (_sent ?? widget.value)?.toString() ?? '';
    }
    if (_invalid == ok) setState(() => _invalid = !ok);
  }

  void _edited(String _) {
    if (_invalid) setState(() => _invalid = false);
  }

  @override
  void dispose() {
    _focus.dispose();
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final style = context.text(AvoTextStyle.body, tabular: true);
    final unit = widget.unit;
    final field = Semantics(
      textField: true,
      label: widget.semanticLabel,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.fill,
          borderRadius: BorderRadius.circular(AvoRadii.imageSmall),
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minHeight: AvoSizes.hitTarget,
            minWidth: _kFieldMinWidth,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AvoSpacing.m,
              vertical: AvoSpacing.s,
            ),
            child: CupertinoTextField(
              controller: _text,
              focusNode: _focus,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              textInputAction: TextInputAction.done,
              onChanged: _edited,
              onSubmitted: (_) => _commit(),
              style: style,
              cursorColor: colors.tint,
              decoration: null,
              padding: EdgeInsets.zero,
              minLines: 1,
              maxLines: null,
            ),
          ),
        ),
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: AvoSpacing.s,
          runSpacing: AvoSpacing.xs,
          children: [
            field,
            if (unit != null)
              Text(
                unit,
                style: context.text(
                  AvoTextStyle.body,
                  color: colors.secondaryLabel,
                ),
              ),
          ],
        ),
        if (_invalid)
          Padding(
            padding: const EdgeInsets.only(top: AvoSpacing.xs),
            child: Text(
              context.tr(
                'setp_picker_range',
                params: {'min': '${widget.min}', 'max': '${widget.max}'},
              ),
              style: context.text(
                AvoTextStyle.footnote,
                color: colors.destructive,
              ),
            ),
          ),
      ],
    );
  }
}

/// A whole number from [min] to [max] (Konzept 18 E18-04): a wheel below
/// AX3, a [PickerNumberField] from AX3 on. With no [value] the wheel starts
/// at [initial] without reporting it.
class NumberPicker extends StatelessWidget {
  /// Creates a number picker.
  const NumberPicker({
    super.key,
    required this.value,
    required this.min,
    required this.max,
    required this.initial,
    required this.onChanged,
    this.unit,
    this.semanticLabel,
  }) : assert(min <= max);

  /// The current number, or null when none is set.
  final int? value;

  /// Smallest number.
  final int min;

  /// Largest number.
  final int max;

  /// Where the wheel starts without a [value].
  final int initial;

  /// Called with the new number.
  final ValueChanged<int> onChanged;

  /// Unit after the number field ("Jahre").
  final String? unit;

  /// VoiceOver label ("Alter").
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    if (pickerUsesField(context)) {
      return PickerNumberField(
        value: value,
        min: min,
        max: max,
        onChanged: onChanged,
        unit: unit,
        semanticLabel: semanticLabel,
      );
    }
    final current = (value ?? initial).clamp(min, max);
    return PickerWheel(
      columns: [
        WheelColumn(
          labels: [for (var n = min; n <= max; n++) '$n'],
          selectedIndex: current - min,
          onSelected: (i) => onChanged(min + i),
          semanticLabel: semanticLabel,
        ),
      ],
    );
  }
}

/// A time of day (Konzept 18 §5.5): hour and minute wheels below AX3, a time
/// field ("9:00") with the keypad from AX3 on. [use24Hour] picks 0–23 over
/// 1–12 with AM/PM.
class TimeOfDayPicker extends StatelessWidget {
  /// Creates a time picker.
  const TimeOfDayPicker({
    super.key,
    required this.hour,
    required this.minute,
    required this.onChanged,
    this.minuteStep = 5,
    this.use24Hour = true,
    this.semanticLabel,
  }) : assert(minuteStep > 0 && 60 % minuteStep == 0);

  /// Hour, 0–23.
  final int hour;

  /// Minute, 0–59.
  final int minute;

  /// Called with hour (0–23) and minute.
  final void Function(int hour, int minute) onChanged;

  /// Step of the minute wheel.
  final int minuteStep;

  /// 24-hour wheels; false shows 1–12 and AM/PM.
  final bool use24Hour;

  /// VoiceOver label ("Uhrzeit").
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    if (pickerUsesField(context)) {
      return _TimeField(
        hour: hour,
        minute: minute,
        onChanged: onChanged,
        semanticLabel: semanticLabel,
      );
    }
    final minutes = [for (var m = 0; m < 60; m += minuteStep) m];
    var minuteIndex = minutes.indexWhere((m) => m >= minute);
    if (minuteIndex < 0) minuteIndex = minutes.length - 1;
    final minuteColumn = WheelColumn(
      labels: [for (final m in minutes) m.toString().padLeft(2, '0')],
      selectedIndex: minuteIndex,
      onSelected: (i) => onChanged(hour, minutes[i]),
      semanticLabel: context.tr('setp_picker_minutes'),
    );
    if (use24Hour) {
      return PickerWheel(
        columns: [
          WheelColumn(
            labels: [for (var h = 0; h < 24; h++) '$h'],
            selectedIndex: hour,
            onSelected: (h) => onChanged(h, minute),
            semanticLabel: context.tr('setp_picker_hours'),
          ),
          minuteColumn,
        ],
      );
    }
    final pm = hour >= 12;
    final hour12 = hour % 12 == 0 ? 12 : hour % 12;
    return PickerWheel(
      columns: [
        WheelColumn(
          labels: [for (var h = 1; h <= 12; h++) '$h'],
          selectedIndex: hour12 - 1,
          onSelected: (i) {
            final h = (i + 1) % 12 + (pm ? 12 : 0);
            onChanged(h, minute);
          },
          semanticLabel: context.tr('setp_picker_hours'),
        ),
        minuteColumn,
        WheelColumn(
          labels: const ['AM', 'PM'],
          selectedIndex: pm ? 1 : 0,
          onSelected: (i) => onChanged(hour % 12 + (i == 1 ? 12 : 0), minute),
        ),
      ],
    );
  }
}

/// Parses "9:00", "09.30", "930" or "18" into hour and minute; null when it
/// is no valid time.
({int hour, int minute})? parsePickerTime(String raw) {
  final text = raw.trim();
  if (text.isEmpty) return null;
  int? h;
  int? m;
  final parts = text.split(RegExp(r'[:.\s]'));
  if (parts.length >= 2) {
    h = int.tryParse(parts[0]);
    m = int.tryParse(parts[1]);
  } else {
    final digits = parts.first;
    if (digits.length <= 2) {
      h = int.tryParse(digits);
      m = 0;
    } else if (digits.length <= 4) {
      h = int.tryParse(digits.substring(0, digits.length - 2));
      m = int.tryParse(digits.substring(digits.length - 2));
    }
  }
  if (h == null || m == null || h < 0 || h > 23 || m < 0 || m > 59) {
    return null;
  }
  return (hour: h, minute: m);
}

class _TimeField extends StatefulWidget {
  const _TimeField({
    required this.hour,
    required this.minute,
    required this.onChanged,
    this.semanticLabel,
  });

  final int hour;
  final int minute;
  final void Function(int hour, int minute) onChanged;
  final String? semanticLabel;

  @override
  State<_TimeField> createState() => _TimeFieldState();
}

class _TimeFieldState extends State<_TimeField> {
  late final TextEditingController _text = TextEditingController(
    text: _format(widget.hour, widget.minute),
  );
  final FocusNode _focus = FocusNode();
  bool _invalid = false;

  /// The time last reported, until the parent passes it back.
  ({int hour, int minute})? _sent;

  static String _format(int h, int m) => '$h:${m.toString().padLeft(2, '0')}';

  @override
  void initState() {
    super.initState();
    _focus.addListener(() {
      if (!_focus.hasFocus) _commit();
    });
  }

  @override
  void didUpdateWidget(_TimeField oldWidget) {
    super.didUpdateWidget(oldWidget);
    final changed =
        oldWidget.hour != widget.hour || oldWidget.minute != widget.minute;
    if (changed) _sent = null;
    if (!_focus.hasFocus && changed) {
      _text.text = _format(widget.hour, widget.minute);
    }
  }

  void _commit() {
    final t = parsePickerTime(_text.text);
    final current = _sent ?? (hour: widget.hour, minute: widget.minute);
    if (t != null) {
      _text.text = _format(t.hour, t.minute);
      if (t == current) return;
      _sent = t;
      widget.onChanged(t.hour, t.minute);
    } else {
      _text.text = _format(current.hour, current.minute);
    }
    if (_invalid != (t == null)) setState(() => _invalid = t == null);
  }

  void _edited(String _) {
    if (_invalid) setState(() => _invalid = false);
  }

  @override
  void dispose() {
    _focus.dispose();
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Semantics(
          textField: true,
          label: widget.semanticLabel,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: colors.fill,
              borderRadius: BorderRadius.circular(AvoRadii.imageSmall),
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                minHeight: AvoSizes.hitTarget,
                minWidth: _kFieldMinWidth,
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AvoSpacing.m,
                  vertical: AvoSpacing.s,
                ),
                child: CupertinoTextField(
                  controller: _text,
                  focusNode: _focus,
                  keyboardType: TextInputType.datetime,
                  textInputAction: TextInputAction.done,
                  onChanged: _edited,
                  onSubmitted: (_) => _commit(),
                  style: context.text(AvoTextStyle.body, tabular: true),
                  cursorColor: colors.tint,
                  decoration: null,
                  padding: EdgeInsets.zero,
                  minLines: 1,
                  maxLines: null,
                ),
              ),
            ),
          ),
        ),
        if (_invalid)
          Padding(
            padding: const EdgeInsets.only(top: AvoSpacing.xs),
            child: Text(
              context.tr('setp_picker_time_invalid'),
              style: context.text(
                AvoTextStyle.footnote,
                color: colors.destructive,
              ),
            ),
          ),
      ],
    );
  }
}

/// A settings row whose value is chosen from a pull-down menu (Konzept 18
/// E18-04, §10.1 "Geschlecht, Liste beim Start"): the value with
/// `chevron.up.chevron.down` at the end; tapping the row opens [items] as an
/// Avo menu growing out of the value. Mark the current choice with
/// `AvoMenuItem.checked`.
///
/// VoiceOver reads one button with title and value. From AX1 on the value
/// moves below the title.
class MenuValueRow extends StatefulWidget {
  /// Creates a menu value row.
  const MenuValueRow({
    super.key,
    required this.title,
    required this.value,
    required this.items,
    this.subtitle,
    this.leading,
  });

  /// Row title ("Geschlecht").
  final String title;

  /// The current choice ("Männlich").
  final String value;

  /// The choices. An empty list shows the row disabled.
  final List<AvoMenuEntry> items;

  /// Optional second line under the title.
  final String? subtitle;

  /// Optional icon tile before the title.
  final Widget? leading;

  @override
  State<MenuValueRow> createState() => _MenuValueRowState();
}

class _MenuValueRowState extends State<MenuValueRow> {
  final GlobalKey _valueKey = GlobalKey();

  void _open() {
    showAvoMenu(
      context,
      items: widget.items,
      anchorKey: _valueKey,
      semanticLabel: widget.title,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final enabled = widget.items.any((e) => e is AvoMenuItem);
    final secondary = colors.secondaryLabel;
    final sub = widget.subtitle;
    final title = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          widget.title,
          style: context.text(
            AvoTextStyle.body,
            color: enabled ? colors.label : secondary,
          ),
        ),
        if (sub != null)
          Text(
            sub,
            style: context.text(AvoTextStyle.subhead, color: secondary),
          ),
      ],
    );
    final value = Row(
      key: _valueKey,
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: Text(
            widget.value,
            style: context.text(AvoTextStyle.body, color: secondary),
          ),
        ),
        const SizedBox(width: _kUpDownGap),
        AvoIcon(_kUpDownIcon, size: _kUpDownSize, color: secondary),
      ],
    );
    final content = _TitleValue(
      leading: widget.leading,
      title: title,
      value: value,
    );
    return Semantics(
      container: true,
      button: true,
      enabled: enabled,
      label: sub == null ? widget.title : '${widget.title}, $sub',
      value: widget.value,
      onTap: enabled ? _open : null,
      child: ExcludeSemantics(
        child: enabled
            ? _PressableRow(onTap: _open, child: content)
            : ConstrainedBox(
                constraints: const BoxConstraints(minHeight: _kRowMinHeight),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AvoSpacing.l,
                    vertical: _kRowVerticalPadding,
                  ),
                  child: content,
                ),
              ),
      ),
    );
  }
}
