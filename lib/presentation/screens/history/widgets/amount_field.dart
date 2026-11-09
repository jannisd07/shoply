import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

import 'package:shoply/core/design/design.dart';
import 'package:shoply/data/services/trip_money_format.dart';
import 'package:shoply/data/services/trip_split_math.dart';
import 'package:shoply/presentation/widgets/design/avo_icons.dart';

// D2 row of an inset group: 17/22, padding 16 at the sides (V1 "Betrag").
const double _kRowVertical = AvoSpacing.xs + AvoSpacing.xxs; // D2 6
const double _kLabelGap = AvoSpacing.m; // D2 12
const double _kErrorIcon = 15; // D2 exclamationmark.circle 15

/// The compact amount row of V1 (and later V6, V7) until Teil A ships
/// `AmountField` (request A-V3): title left, the amount right aligned in
/// tabular figures, the number pad with a decimal key.
///
/// Takes "42,8", "42,80", "42.80", "1.234,56" ([parseAmountCents]) and shows
/// "42,80 €" when the field loses focus. Reports every change as an
/// [AmountInput] (cents, empty or invalid; invalid is never 0). No fixed
/// width: from xxxLarge the title stacks above a full-width field.
class HistoryAmountField extends StatefulWidget {
  const HistoryAmountField({
    super.key,
    required this.title,
    required this.placeholder,
    required this.languageCode,
    required this.onChanged,
    this.initialCents,
    this.semanticHint,
    this.semanticLabel,
    this.focusNode,
  });

  /// "Betrag".
  final String title;

  /// "optional".
  final String placeholder;

  /// `de` or `en`: how the amount is read and shown.
  final String languageCode;

  /// Called with every change.
  final ValueChanged<AmountInput> onChanged;

  /// An amount to start with, in cents.
  final int? initialCents;

  /// Read after the label ("Für deinen Monatsrückblick.").
  final String? semanticHint;

  /// VoiceOver label when [title] is not shown ("Anteil von Lena").
  final String? semanticLabel;

  final FocusNode? focusNode;

  @override
  State<HistoryAmountField> createState() => _HistoryAmountFieldState();
}

class _HistoryAmountFieldState extends State<HistoryAmountField> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initialCents == null
        ? ''
        : formatEuroCents(widget.initialCents!, widget.languageCode),
  );
  FocusNode? _ownFocus;

  FocusNode get _focus =>
      widget.focusNode ?? (_ownFocus ??= FocusNode(debugLabel: 'Amount'));

  @override
  void initState() {
    super.initState();
    _focus.addListener(_onFocus);
  }

  @override
  void dispose() {
    _focus.removeListener(_onFocus);
    _ownFocus?.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _onFocus() {
    if (_focus.hasFocus) return;
    // "42,8" becomes "42,80 €" when the field is left (Bug 14).
    final input = parseAmountCents(
      _controller.text,
      languageCode: widget.languageCode,
    );
    final cents = input.cents;
    if (cents == null) return;
    final shown = formatEuroCents(cents, widget.languageCode);
    if (_controller.text != shown) _controller.text = shown;
  }

  void _changed(String text) => widget.onChanged(
    parseAmountCents(text, languageCode: widget.languageCode),
  );

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final stacked =
        context.typography.category.index >= ContentSizeCategory.xxxLarge.index;
    final style = context.text(
      AvoTextStyle.body,
      color: colors.label,
      tabular: true,
    );
    final line = context.typography.lineHeightOf(AvoTextStyle.body);
    final pad = ((AvoSizes.hitTarget - line) / 2).clamp(
      0.0,
      AvoSizes.hitTarget,
    );

    Widget field(TextAlign align) => ConstrainedBox(
      constraints: const BoxConstraints(minHeight: AvoSizes.hitTarget),
      child: Center(
        child: Semantics(
          label:
              widget.semanticLabel ??
              [
                widget.title,
                widget.placeholder,
              ].where((t) => t.isNotEmpty).join(', '),
          hint: widget.semanticHint,
          textField: true,
          child: CupertinoTextField(
            controller: _controller,
            focusNode: _focus,
            placeholder: widget.placeholder,
            placeholderStyle: context.text(
              AvoTextStyle.body,
              color: colors.placeholder,
            ),
            style: style,
            cursorColor: colors.tint,
            textAlign: align,
            decoration: null,
            padding: EdgeInsets.symmetric(vertical: pad),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.,\s€]')),
              LengthLimitingTextInputFormatter(14),
            ],
            onChanged: _changed,
          ),
        ),
      ),
    );

    final title = ExcludeSemantics(
      child: Text(widget.title, style: context.text(AvoTextStyle.body)),
    );

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      excludeFromSemantics: true,
      onTap: _focus.requestFocus,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AvoSpacing.l,
          vertical: _kRowVertical,
        ),
        child: stacked
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  title,
                  const SizedBox(height: AvoSpacing.xs),
                  field(TextAlign.start),
                ],
              )
            : Row(
                children: [
                  title,
                  const SizedBox(width: _kLabelGap),
                  Expanded(child: field(TextAlign.end)),
                ],
              ),
      ),
    );
  }
}

/// The sentence under an amount group: an error with the red mark
/// ("Gib den Betrag als Zahl ein …") or a quiet check ("Stimmt der Betrag?").
class AmountNote extends StatelessWidget {
  const AmountNote({super.key, required this.text, this.error = false});

  final String text;
  final bool error;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textStyle = context.text(
      AvoTextStyle.footnote,
      color: error ? colors.label : colors.secondaryLabel,
    );
    // The mark grows with the text (13 pt footnote at the default size).
    final size =
        _kErrorIcon * context.typography.sizeOf(AvoTextStyle.footnote) / 13;
    return Semantics(
      liveRegion: true,
      container: true,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AvoSpacing.xxxl,
          AvoSpacing.s,
          AvoSpacing.xxxl,
          0,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (error) ...[
              ExcludeSemantics(
                child: AvoIcon(
                  AvoIcons.exclamationmarkCircle,
                  size: size,
                  color: colors.destructive,
                ),
              ),
              const SizedBox(width: AvoSpacing.xs + AvoSpacing.xxs),
            ],
            Expanded(child: Text(text, style: textStyle)),
          ],
        ),
      ),
    );
  }
}
