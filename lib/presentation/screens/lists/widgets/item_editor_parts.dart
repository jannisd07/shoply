import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart' show kTouchSlop;
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:shoply/core/design/design.dart';
import 'package:shoply/core/localization/localization_helper.dart';
import 'package:shoply/presentation/widgets/design/segmented_control.dart';
import 'package:shoply/presentation/widgets/design/value_stepper.dart';

// D2-Artikel rows: at least 56 high, padding 0 10 0 16 (the stepper and the
// unit control bring their own 44 pt hit areas, so they sit 10 from the edge).
const double _rowMinHeight = 56; // D2
const double _rowEnd = 10; // D2
const double _rowVertical = 6; // D2 (56 - 44) / 2

// The compact segmented control (D2-Artikel unit picker) sizes each segment
// to the widest label plus 8 pt on both sides, at least 52, with 2 pt inner
// padding (`segmented_control.dart`). Used to decide whether it fits inline.
const double _segmentMin = 52; // D2
const double _segmentLabelPad = AvoSpacing.s;
const double _segmentTrackPad = 2; // D2

/// Unit ids as items store them (`item_input_parser.dart`, `categories.dart`);
/// null means pieces.
abstract final class ItemUnits {
  /// Pieces; stored as null.
  static const String pieces = 'pcs';

  /// The three D2 segments: St., g, kg.
  static const List<String> main = [pieces, 'g', 'kg'];

  /// The other units, in the "Mehr" menu.
  static const List<String> others = [
    'l',
    'ml',
    'pack',
    'bottle',
    'can',
    'box',
    'dozen',
    'bunch',
  ];

  /// All known units.
  static const List<String> all = [...main, ...others];

  /// Stored form of [unit]: null for pieces and for empty text.
  static String? normalize(String? unit) {
    final u = unit?.trim().toLowerCase();
    if (u == null || u.isEmpty || u == pieces || u == 'pc' || u == 'stk') {
      return null;
    }
    return u;
  }

  /// One step of the quantity stepper for [unit] (Konzept 11 §4: 50 for
  /// g and ml, else 1).
  static int stepOf(String? unit) => switch (normalize(unit)) {
    'g' || 'ml' => 50,
    _ => 1,
  };

  /// Short label ("St.", "g", "Pck."); unknown units as stored.
  static String shortLabel(BuildContext context, String? unit) {
    final u = normalize(unit) ?? pieces;
    if (!all.contains(u)) return unit ?? '';
    return context.tr('list_item_unit_${u}_short');
  }

  /// Full name for the menu ("Packung").
  static String longLabel(BuildContext context, String unit) {
    final u = normalize(unit) ?? pieces;
    if (!all.contains(u)) return unit;
    return context.tr('list_item_unit_$u');
  }
}

/// [value] without trailing zeros and with the decimal separator of
/// [languageCode]: 2, 1,5 (de), 1.5 (en).
String formatItemNumber(double value, String languageCode) {
  if (value == value.roundToDouble()) return value.toInt().toString();
  var text = value.toStringAsFixed(2);
  text = text.replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '');
  return languageCode == 'de' ? text.replaceAll('.', ',') : text;
}

/// Reads a typed quantity, accepting a comma ("1,5"). Null when it is no
/// positive number.
double? parseItemNumber(String text) {
  final value = double.tryParse(text.trim().replaceAll(',', '.'));
  if (value == null || value.isNaN || value <= 0) return null;
  return value;
}

/// "2", "500 g", "1,5 kg", "2 Fl.": quantity and unit as a short label.
/// Null for a single piece without unit (nothing worth showing).
String? itemQuantityLabel(
  BuildContext context, {
  required double? quantity,
  required String? unit,
}) {
  final q = quantity ?? 1;
  final u = ItemUnits.normalize(unit);
  final lang = Localizations.localeOf(context).languageCode;
  if (u == null) return q == 1 ? null : formatItemNumber(q, lang);
  return '${formatItemNumber(q, lang)} ${ItemUnits.shortLabel(context, u)}';
}

/// When something was added, as D2 writes it: "heute, 9:15", "gestern",
/// "Dienstag" (this week), otherwise "5.11.".
String itemAddedWhen(BuildContext context, DateTime at, {DateTime? now}) {
  final local = at.toLocal();
  final today = now ?? DateTime.now();
  final day = DateTime(local.year, local.month, local.day);
  final start = DateTime(today.year, today.month, today.day);
  final days = start.difference(day).inDays;
  final lang = Localizations.localeOf(context).languageCode;
  if (days <= 0) {
    final minutes = local.minute.toString().padLeft(2, '0');
    final time = lang == 'de'
        ? '${local.hour}:$minutes'
        : '${(local.hour + 11) % 12 + 1}:$minutes '
              '${local.hour < 12 ? 'AM' : 'PM'}';
    return context.tr('list_item_today_at', params: {'time': time});
  }
  if (days == 1) return context.tr('list_item_yesterday');
  if (days < 7) return context.tr('list_item_weekday_${local.weekday}');
  return lang == 'de'
      ? '${local.day}.${local.month}.'
      : '${local.month}/${local.day}';
}

/// Pads its child only while the child has a size: a Teil B slot or an
/// [ArticleImage] that renders nothing leaves no gap behind.
class CollapsingPadding extends SingleChildRenderObjectWidget {
  /// Creates the padding around [child].
  const CollapsingPadding({super.key, required this.padding, super.child});

  /// Space around the child while it is visible.
  final EdgeInsetsDirectional padding;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderCollapsingPadding(padding, Directionality.of(context));

  @override
  void updateRenderObject(
    BuildContext context,
    covariant RenderObject renderObject,
  ) {
    (renderObject as _RenderCollapsingPadding)
      ..padding = padding
      ..textDirection = Directionality.of(context);
  }
}

class _RenderCollapsingPadding extends RenderShiftedBox {
  _RenderCollapsingPadding(this._padding, this._textDirection) : super(null);

  EdgeInsetsDirectional _padding;
  set padding(EdgeInsetsDirectional value) {
    if (value == _padding) return;
    _padding = value;
    markNeedsLayout();
  }

  TextDirection _textDirection;
  set textDirection(TextDirection value) {
    if (value == _textDirection) return;
    _textDirection = value;
    markNeedsLayout();
  }

  EdgeInsets get _resolved => _padding.resolve(_textDirection);

  Size _sizeFor(BoxConstraints constraints, Size childSize) {
    if (childSize.isEmpty) return constraints.smallest;
    final pad = _resolved;
    return constraints.constrain(
      Size(childSize.width + pad.horizontal, childSize.height + pad.vertical),
    );
  }

  @override
  Size computeDryLayout(covariant BoxConstraints constraints) {
    final child = this.child;
    if (child == null) return constraints.smallest;
    return _sizeFor(
      constraints,
      child.getDryLayout(constraints.deflate(_resolved)),
    );
  }

  @override
  void performLayout() {
    final child = this.child;
    if (child == null) {
      size = constraints.smallest;
      return;
    }
    final pad = _resolved;
    child.layout(constraints.deflate(pad), parentUsesSize: true);
    final data = child.parentData! as BoxParentData;
    data.offset = child.size.isEmpty ? Offset.zero : Offset(pad.left, pad.top);
    size = _sizeFor(constraints, child.size);
  }

  double _withPad(double value, double pad) => value <= 0 ? 0 : value + pad;

  @override
  double computeMinIntrinsicWidth(double height) =>
      _withPad(child?.getMinIntrinsicWidth(height) ?? 0, _resolved.horizontal);

  @override
  double computeMaxIntrinsicWidth(double height) =>
      _withPad(child?.getMaxIntrinsicWidth(height) ?? 0, _resolved.horizontal);

  @override
  double computeMinIntrinsicHeight(double width) =>
      _withPad(child?.getMinIntrinsicHeight(width) ?? 0, _resolved.vertical);

  @override
  double computeMaxIntrinsicHeight(double width) =>
      _withPad(child?.getMaxIntrinsicHeight(width) ?? 0, _resolved.vertical);
}

/// A D2-Artikel row: [label] at the start, [control] at the end, at least
/// 56 pt high. The control moves below the label from AX1 on, or when it
/// needs more than [controlWidth] and the label leave room for.
class ItemControlRow extends StatelessWidget {
  /// Creates a row with a label and a control.
  const ItemControlRow({
    super.key,
    required this.label,
    required this.control,
    this.controlWidth,
    this.stretchWhenStacked = false,
  });

  /// The row title, 17/22.
  final String label;

  /// The stepper or segmented control.
  final Widget control;

  /// The width the control needs inline. Null: it sizes itself (stepper).
  final double? controlWidth;

  /// Give the control the full width when it sits below the label.
  final bool stretchWhenStacked;

  /// Minimum height of the D2-Artikel rows.
  static const double minHeight = _rowMinHeight;

  @override
  Widget build(BuildContext context) {
    final labelText = Text(label, style: context.text(AvoTextStyle.body));
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: _rowMinHeight),
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(
          AvoSpacing.l,
          _rowVertical,
          _rowEnd,
          _rowVertical,
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = controlWidth;
            var inline = !context.isAccessibilityText;
            if (inline && width != null) {
              final labelWidth = _textWidth(
                context,
                label,
                context.text(AvoTextStyle.body),
              );
              inline =
                  labelWidth + AvoSpacing.m + width <= constraints.maxWidth;
            }
            if (inline) {
              return Row(
                children: [
                  Expanded(child: labelText),
                  const SizedBox(width: AvoSpacing.m),
                  if (width == null)
                    control
                  else
                    SizedBox(width: width, child: control),
                ],
              );
            }
            return Column(
              crossAxisAlignment: stretchWhenStacked
                  ? CrossAxisAlignment.stretch
                  : CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsetsDirectional.only(end: AvoSpacing.s),
                  child: labelText,
                ),
                const SizedBox(height: AvoSpacing.xs),
                control,
              ],
            );
          },
        ),
      ),
    );
  }
}

double _textWidth(BuildContext context, String text, TextStyle style) {
  var effective = style;
  if (MediaQuery.boldTextOf(context)) {
    effective = effective.merge(const TextStyle(fontWeight: FontWeight.bold));
  }
  final painter = TextPainter(
    text: TextSpan(text: text, style: effective),
    textDirection: Directionality.of(context),
    textScaler: MediaQuery.textScalerOf(context),
    maxLines: 1,
  )..layout();
  final width = painter.width;
  painter.dispose();
  return width.ceilToDouble();
}

/// The width the compact [AppSegmentedControl] takes for [labels] when it
/// sizes segments to their labels (D2-Artikel unit picker).
double compactSegmentsWidth(BuildContext context, List<String> labels) {
  final style = context.text(AvoTextStyle.subhead, weight: FontWeight.w600);
  var widest = 0.0;
  for (final label in labels) {
    widest = math.max(widest, _textWidth(context, label, style));
  }
  final segment = math.max(_segmentMin, widest + 2 * _segmentLabelPad);
  return segment * labels.length + 2 * _segmentTrackPad;
}

/// Quantity: the D2 stepper (step 50 for g and ml), or a number field with
/// comma for amounts that are no whole number (1,5 kg).
class ItemQuantityControl extends StatefulWidget {
  /// Creates the quantity control.
  const ItemQuantityControl({
    super.key,
    required this.quantity,
    required this.unit,
    required this.onChanged,
    required this.semanticLabel,
  });

  /// The current quantity, > 0.
  final double quantity;

  /// The current unit id (null = pieces), for the step.
  final String? unit;

  /// Called with the new quantity.
  final ValueChanged<double> onChanged;

  /// "Menge", for VoiceOver.
  final String semanticLabel;

  @override
  State<ItemQuantityControl> createState() => _ItemQuantityControlState();
}

class _ItemQuantityControlState extends State<ItemQuantityControl> {
  /// Set once when the screen opens with a fractional amount; stays a field
  /// while typing, so the control never swaps under the cursor.
  late final bool _decimal = widget.quantity % 1 != 0;
  TextEditingController? _field;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_decimal && _field == null) {
      final lang = Localizations.localeOf(context).languageCode;
      _field = TextEditingController(
        text: formatItemNumber(widget.quantity, lang),
      );
    }
  }

  @override
  void dispose() {
    _field?.dispose();
    super.dispose();
  }

  void _step(int next) {
    final step = ItemUnits.stepOf(widget.unit);
    final current = widget.quantity.round();
    final delta = next - current;
    if (step == 1) {
      widget.onChanged(next.toDouble());
      return;
    }
    final target = widget.quantity + delta * step;
    if (target <= 0) return;
    widget.onChanged(target);
  }

  @override
  Widget build(BuildContext context) {
    final field = _field;
    if (field != null) {
      final colors = context.colors;
      return Semantics(
        label: widget.semanticLabel,
        textField: true,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minWidth: AvoSizes.hitTarget * 2,
            maxWidth: AvoSizes.hitTarget * 3,
            minHeight: AvoSizes.hitTarget,
          ),
          child: CupertinoTextField(
            controller: field,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
            ],
            textAlign: TextAlign.end,
            style: context.text(
              AvoTextStyle.body,
              weight: FontWeight.w600,
              tabular: true,
            ),
            cursorColor: colors.tint,
            decoration: BoxDecoration(
              color: colors.fill,
              borderRadius: const BorderRadius.all(
                Radius.circular(AvoSizes.hitTarget / 2),
              ),
            ),
            padding: const EdgeInsets.symmetric(
              horizontal: AvoSpacing.m,
              vertical: AvoSpacing.s,
            ),
            onChanged: (text) {
              final value = parseItemNumber(text);
              if (value != null) widget.onChanged(value);
            },
          ),
        ),
      );
    }
    final step = ItemUnits.stepOf(widget.unit);
    final value = widget.quantity.round();
    return ValueStepper(
      value: value,
      // Minus stops at one step (one piece, 50 g).
      min: value <= step ? value : 0,
      max: 99999,
      compact: true,
      semanticLabel: widget.semanticLabel,
      onChanged: _step,
    );
  }
}

/// Unit: D2 segments St. | g | kg and a fourth segment for every other unit
/// ("Mehr", or the chosen one like "Pck."), which opens a menu. Tapping the
/// fourth segment again while it is selected opens the menu too.
class ItemUnitControl extends StatelessWidget {
  /// Creates the unit control.
  const ItemUnitControl({
    super.key,
    required this.unit,
    required this.onChanged,
    required this.onMore,
    required this.semanticLabel,
  });

  /// The current unit id, null for pieces.
  final String? unit;

  /// A main unit was chosen (null for pieces).
  final ValueChanged<String?> onChanged;

  /// Open the menu with all other units.
  final VoidCallback onMore;

  /// "Einheit", for VoiceOver and the fallback dialog.
  final String semanticLabel;

  /// Sentinel value of the fourth segment while it says "Mehr".
  static const String _more = '_more';

  /// The segment values for [unit].
  static List<String> valuesFor(String? unit) {
    final u = ItemUnits.normalize(unit) ?? ItemUnits.pieces;
    return [...ItemUnits.main, ItemUnits.main.contains(u) ? _more : u];
  }

  /// The segment labels for [unit], for measuring.
  static List<String> labelsFor(BuildContext context, String? unit) => [
    for (final v in valuesFor(unit))
      v == _more
          ? context.tr('list_item_unit_more')
          : ItemUnits.shortLabel(context, v),
  ];

  @override
  Widget build(BuildContext context) {
    final values = valuesFor(unit);
    final labels = labelsFor(context, unit);
    final selected = ItemUnits.normalize(unit) ?? ItemUnits.pieces;
    final otherSelected = values.last == selected;
    final control = AppSegmentedControl<String>(
      compact: true,
      semanticLabel: semanticLabel,
      selected: selected,
      segments: [
        for (var i = 0; i < values.length; i++)
          SegmentItem(value: values[i], label: labels[i]),
      ],
      onChanged: (value) {
        if (value == _more || !ItemUnits.main.contains(value)) {
          onMore();
          return;
        }
        onChanged(ItemUnits.normalize(value));
      },
    );
    if (!otherSelected) return control;
    return LayoutBuilder(
      builder: (context, constraints) {
        // Too narrow for the labels: the control is a pull-down button with
        // its own dialog; a second tap target would open both.
        final fits =
            !constraints.hasBoundedWidth ||
            constraints.maxWidth >= compactSegmentsWidth(context, labels);
        if (!fits) return control;
        // The segmented control ignores taps on the selected segment; a tap
        // on the last segment reopens the menu.
        return _LastSegmentTap(
          segments: values.length,
          onTap: onMore,
          child: control,
        );
      },
    );
  }
}

class _LastSegmentTap extends StatefulWidget {
  const _LastSegmentTap({
    required this.segments,
    required this.onTap,
    required this.child,
  });

  final int segments;
  final VoidCallback onTap;
  final Widget child;

  @override
  State<_LastSegmentTap> createState() => _LastSegmentTapState();
}

class _LastSegmentTapState extends State<_LastSegmentTap> {
  Offset? _down;

  bool _onLast(Offset local) {
    final box = context.findRenderObject();
    if (box is! RenderBox || !box.hasSize) return false;
    final width = box.size.width;
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final x = rtl ? width - local.dx : local.dx;
    return x >= width * (widget.segments - 1) / widget.segments;
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (e) => _down = e.localPosition,
      onPointerCancel: (_) => _down = null,
      onPointerUp: (e) {
        final down = _down;
        _down = null;
        if (down == null) return;
        if ((e.localPosition - down).distance > kTouchSlop) return;
        if (_onLast(down) && _onLast(e.localPosition)) widget.onTap();
      },
      child: widget.child,
    );
  }
}

/// A borderless text field whose placeholder wraps like the text: the row
/// grows with a long placeholder at large text sizes instead of letting it
/// run over the next row (`CupertinoTextField` sizes to one line).
class ItemTextField extends StatelessWidget {
  /// Creates the field.
  const ItemTextField({
    super.key,
    required this.controller,
    required this.style,
    required this.placeholder,
    required this.semanticLabel,
    this.textAlign = TextAlign.start,
    this.padding = EdgeInsets.zero,
    this.autofocus = false,
    this.onSubmitted,
  });

  /// The text.
  final TextEditingController controller;

  /// Style of text and placeholder.
  final TextStyle style;

  /// Shown while the field is empty, in [AvoColors.placeholder].
  final String placeholder;

  /// What VoiceOver calls the field ("Artikelname").
  final String semanticLabel;

  /// Alignment of text and placeholder.
  final TextAlign textAlign;

  /// Space around the text.
  final EdgeInsets padding;

  /// Focus when the screen opens.
  final bool autofocus;

  /// Return was pressed.
  final VoidCallback? onSubmitted;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Stack(
      fit: StackFit.passthrough,
      children: [
        ValueListenableBuilder<TextEditingValue>(
          valueListenable: controller,
          builder: (context, value, _) => value.text.isEmpty
              ? IgnorePointer(
                  child: ExcludeSemantics(
                    child: Padding(
                      padding: padding,
                      child: Text(
                        placeholder,
                        textAlign: textAlign,
                        style: style.copyWith(color: colors.placeholder),
                      ),
                    ),
                  ),
                )
              : const SizedBox.shrink(),
        ),
        Semantics(
          label: semanticLabel,
          child: CupertinoTextField(
            controller: controller,
            autofocus: autofocus,
            style: style,
            cursorColor: colors.tint,
            decoration: null,
            padding: padding,
            textAlign: textAlign,
            minLines: 1,
            maxLines: null,
            keyboardType: TextInputType.text,
            textInputAction: TextInputAction.done,
            textCapitalization: TextCapitalization.sentences,
            onSubmitted: (_) => onSubmitted?.call(),
          ),
        ),
      ],
    );
  }
}
