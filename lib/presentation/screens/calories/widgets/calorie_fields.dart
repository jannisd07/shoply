import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

import 'package:shoply/core/design/design.dart';

/// D2 row: single line at least 52 high, inner margin 16, 9 above and below.
const double _kRowMinHeight = 52; // D2
const double _kRowVertical = 9; // D2

/// Share of the row a label may take beside its field.
const double _kLabelShare = 0.45;

/// Digits, one decimal mark and both separators (comma and point): every
/// number field takes "450", "450,5" and "450.5" (`kalorien.md` §3.3).
final List<TextInputFormatter> calorieNumberFormatters = [
  FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
];

/// Digits, spaces and dashes for a barcode ("4 056489 123457").
final TextInputFormatter calorieDigitsFormatter = FilteringTextInputFormatter.allow(RegExp(r'[0-9 \-]'));

/// Labels move above their field from xxL on (`kalorien.md` S8).
bool calorieLabelsAbove(BuildContext context) =>
    context.typography.category.index >= ContentSizeCategory.xxLarge.index;

/// A field row in an inset group: visible label at the start (above the
/// field from xxL on), the field, its unit ("kcal", "g") after it, and an
/// error line under it that is part of the field for VoiceOver ("Bitte eine
/// Zahl, zum Beispiel 450 oder 450,5"). Never a placeholder as the label.
class CalorieFieldRow extends StatelessWidget {
  const CalorieFieldRow({
    super.key,
    required this.label,
    required this.controller,
    this.unit,
    this.spokenUnit,
    this.placeholder,
    this.error,
    this.number = true,
    this.integer = false,
    this.onChanged,
    this.onSubmitted,
    this.focusNode,
    this.textInputAction,
    this.autofocus = false,
    this.fieldKey,
    this.enabled = true,
  });

  final String label;
  final TextEditingController controller;

  /// Shown after the field ("kcal", "g").
  final String? unit;

  /// The unit as VoiceOver says it ("Kilokalorien", "Gramm").
  final String? spokenUnit;
  final String? placeholder;

  /// The message under the field; null when the value is fine.
  final String? error;

  /// A number field (decimal keyboard, comma and point); false for text.
  final bool number;

  /// Whole numbers only (number pad without a decimal mark).
  final bool integer;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final FocusNode? focusNode;
  final TextInputAction? textInputAction;
  final bool autofocus;
  final Key? fieldKey;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final above = calorieLabelsAbove(context);
    final unitText = unit;
    final style = context.text(AvoTextStyle.body, tabular: number);

    final field = CupertinoTextField(
      key: fieldKey,
      controller: controller,
      focusNode: focusNode,
      enabled: enabled,
      autofocus: autofocus,
      decoration: null,
      padding: EdgeInsets.zero,
      style: style,
      placeholder: placeholder,
      placeholderStyle: context.text(AvoTextStyle.body, color: colors.placeholder),
      textAlign: above ? TextAlign.start : TextAlign.end,
      keyboardType: number ? TextInputType.numberWithOptions(decimal: !integer) : TextInputType.text,
      inputFormatters: number ? calorieNumberFormatters : null,
      textInputAction: textInputAction ?? TextInputAction.done,
      textCapitalization: number ? TextCapitalization.none : TextCapitalization.sentences,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      maxLines: number ? 1 : null,
      minLines: 1,
    );

    final fieldWithUnit = Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(child: field),
        if (unitText != null) ...[
          const SizedBox(width: AvoSpacing.xs),
          ExcludeSemantics(
            child: Text(unitText, style: context.text(AvoTextStyle.body, color: colors.secondaryLabel)),
          ),
        ],
      ],
    );

    final labelText = ExcludeSemantics(child: Text(label, style: context.text(AvoTextStyle.body)));
    final message = error;

    final Widget content = above
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [labelText, const SizedBox(height: AvoSpacing.xs), fieldWithUnit],
          )
        : LayoutBuilder(
            builder: (context, box) => Row(
              children: [
                ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: box.maxWidth * _kLabelShare),
                  child: labelText,
                ),
                const SizedBox(width: AvoSpacing.m),
                Expanded(child: fieldWithUnit),
              ],
            ),
          );

    return MergeSemantics(
      child: Semantics(
        label: [label, if (spokenUnit != null) spokenUnit!].join(', '),
        hint: message,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: _kRowMinHeight),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AvoSpacing.l, vertical: _kRowVertical),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                content,
                if (message != null) ...[
                  const SizedBox(height: AvoSpacing.xs),
                  ExcludeSemantics(
                    child: Text(message, style: context.text(AvoTextStyle.footnote, color: colors.destructive)),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A sentence inside a group (footnote-like body text with an optional
/// leading symbol): "Für dieses Produkt sind keine Nährwerte hinterlegt.",
/// the warning under 1.200 kcal.
class CalorieGroupNote extends StatelessWidget {
  const CalorieGroupNote({
    super.key,
    required this.text,
    this.icon,
    this.color,
    this.liveRegion = false,
  });

  final String text;
  final Widget? icon;
  final Color? color;

  /// Announced when it appears (warnings).
  final bool liveRegion;

  @override
  Widget build(BuildContext context) {
    final lead = icon;
    return Semantics(
      container: true,
      liveRegion: liveRegion,
      label: text,
      excludeSemantics: true,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: _kRowMinHeight),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AvoSpacing.l, vertical: AvoSpacing.m),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (lead != null) ...[lead, const SizedBox(width: AvoSpacing.s)],
              Expanded(
                child: Text(text, style: context.text(AvoTextStyle.subhead, color: color)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
