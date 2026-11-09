import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import 'package:shoply/core/design/design.dart';
import 'package:shoply/data/services/trip_split_math.dart';
import 'package:shoply/presentation/widgets/design/avo_icons.dart';

export 'package:shoply/data/services/trip_split_math.dart' show AmountInput;

/// The large variant never grows past this size (A-V3: at most 51 pt).
const double _kLargeMaxSize = 51; // D2

/// Space between a row title and the field.
const double _kLabelGap = AvoSpacing.m; // D2 12

/// Vertical padding of a compact row with [AmountField.label].
const double _kRowVertical = AvoSpacing.xs + AvoSpacing.xxs; // D2 6

/// The error mark next to 13 pt footnote text (D2 15 pt).
const double _kErrorIcon = 15; // D2
const double _kFootnoteDefaultSize = 13;

/// Longest input (enough for "100.000,00 €" with spaces).
const int _kMaxLength = 14;

/// How big an [AmountField] is.
enum AmountFieldSize {
  /// In a row: body 17/22, right aligned, tabular figures.
  compact,

  /// On its own: the large-number style, left aligned, at most 51 pt.
  large,
}

/// An amount in money, typed with the number pad (Konzept A-V3).
///
/// Takes what people type in their locale: "42,8", "42,80", "42.80",
/// "1.234,56", "1,234.56", with or without "€" (the rule of
/// `parseAmountCents`). When the field loses focus a valid amount is
/// rewritten in the locale's notation with the currency sign: "42,8" becomes
/// "42,80 €" in German and "€42.80" in English. While the field has focus the
/// sign is left out, so only digits are edited.
///
/// No fixed width: the field takes the width it gets. [errorText] shows a
/// red mark and the sentence under the field and is announced. With [label]
/// the compact variant is a whole row (title left, amount right); from
/// xxxLarge on the title stacks above a full-width field.
class AmountField extends StatefulWidget {
  /// Creates an amount field.
  const AmountField({
    super.key,
    required this.onChanged,
    this.size = AmountFieldSize.compact,
    this.initialCents,
    this.placeholder,
    this.label,
    this.errorText,
    this.onInputChanged,
    this.onSubmitted,
    this.semanticLabel,
    this.semanticHint,
    this.languageCode,
    this.focusNode,
    this.autofocus = false,
    this.textInputAction,
    this.enabled = true,
  });

  /// Called with every change: the amount in cents, null when the field is
  /// empty or not an amount (see [onInputChanged] to tell the two apart).
  final ValueChanged<int?> onChanged;

  /// Compact (in rows) or large (on its own).
  final AmountFieldSize size;

  /// The amount to start with, in cents.
  final int? initialCents;

  /// Shown while the field is empty ("optional", "0,00").
  final String? placeholder;

  /// Row title ("Betrag"); compact variant only. Without it the field is
  /// only the amount, for a row the caller builds.
  final String? label;

  /// An error under the field ("Gib den Betrag als Zahl ein."); null for
  /// none.
  final String? errorText;

  /// Called with every change as an [AmountInput] (valid, empty or invalid).
  final ValueChanged<AmountInput>? onInputChanged;

  /// Called with the amount when the keyboard's action key is pressed.
  final ValueChanged<int?>? onSubmitted;

  /// VoiceOver label; defaults to [label], else [placeholder].
  final String? semanticLabel;

  /// Read after the label ("Für deinen Monatsrückblick.").
  final String? semanticHint;

  /// `de` or `en`; defaults to the app locale.
  final String? languageCode;

  /// Optional focus node (to move on to the next field).
  final FocusNode? focusNode;

  /// Whether the field takes focus when it appears.
  final bool autofocus;

  /// The keyboard's action key.
  final TextInputAction? textInputAction;

  /// False dims the field and ignores input.
  final bool enabled;

  @override
  State<AmountField> createState() => _AmountFieldState();
}

class _AmountFieldState extends State<AmountField> {
  TextEditingController? _controllerOrNull;
  FocusNode? _ownFocus;

  TextEditingController get _controller => _controllerOrNull!;

  FocusNode get _focus =>
      widget.focusNode ?? (_ownFocus ??= FocusNode(debugLabel: 'AmountField'));

  /// `en` for English, `de` for everything else (the app is bilingual).
  String _language(BuildContext context) {
    final code =
        widget.languageCode ??
        Localizations.maybeLocaleOf(context)?.languageCode;
    return code == 'en' ? 'en' : 'de';
  }

  String _languageCode = 'de';

  @override
  void initState() {
    super.initState();
    _focus.addListener(_onFocus);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _languageCode = _language(context);
    if (_controllerOrNull == null) {
      final cents = widget.initialCents;
      _controllerOrNull = TextEditingController(
        text: cents == null ? '' : formatAmount(cents, _languageCode),
      );
    }
  }

  @override
  void didUpdateWidget(AmountField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.focusNode != widget.focusNode) {
      (oldWidget.focusNode ?? _ownFocus)?.removeListener(_onFocus);
      _focus.addListener(_onFocus);
    }
    if (oldWidget.languageCode != widget.languageCode) {
      _languageCode = _language(context);
    }
  }

  @override
  void dispose() {
    _focus.removeListener(_onFocus);
    _ownFocus?.dispose();
    _controllerOrNull?.dispose();
    super.dispose();
  }

  AmountInput _parse(String text) =>
      parseAmountCents(text, languageCode: _languageCode);

  /// Focus gained: digits only ("42,80"); focus lost: with the sign
  /// ("42,80 €"). The amount stays the same, so nothing is reported.
  void _onFocus() {
    final cents = _parse(_controller.text).cents;
    if (cents == null) return;
    final shown = _focus.hasFocus
        ? formatAmountNumber(cents, _languageCode)
        : formatAmount(cents, _languageCode);
    if (_controller.text == shown) return;
    _controller.value = TextEditingValue(
      text: shown,
      selection: TextSelection.collapsed(offset: shown.length),
    );
  }

  void _changed(String text) {
    final input = _parse(text);
    widget.onInputChanged?.call(input);
    widget.onChanged(input.cents);
  }

  TextStyle _style(BuildContext context, Color color) {
    if (widget.size == AmountFieldSize.compact) {
      return context.text(AvoTextStyle.body, color: color, tabular: true);
    }
    final style = context.text(
      AvoTextStyle.largeTitle,
      color: color,
      tabular: true,
    );
    final size = context.typography.sizeOf(AvoTextStyle.largeTitle);
    if (size <= _kLargeMaxSize) return style;
    return style.copyWith(fontSize: style.fontSize! * _kLargeMaxSize / size);
  }

  double _lineHeight(BuildContext context) {
    final typography = context.typography;
    if (widget.size == AmountFieldSize.compact) {
      return typography.lineHeightOf(AvoTextStyle.body);
    }
    final size = typography.sizeOf(AvoTextStyle.largeTitle);
    final line = typography.lineHeightOf(AvoTextStyle.largeTitle);
    return size <= _kLargeMaxSize
        ? line
        : (line * _kLargeMaxSize / size).roundToDouble();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final compact = widget.size == AmountFieldSize.compact;
    final label = compact ? widget.label : null;
    final stacked =
        label != null &&
        context.typography.category.index >= ContentSizeCategory.xxxLarge.index;
    final color = widget.enabled ? colors.label : colors.secondaryLabel;
    final style = _style(context, color);
    final line = _lineHeight(context);
    final pad = ((AvoSizes.hitTarget - line) / 2).clamp(
      0.0,
      AvoSizes.hitTarget,
    );
    final end = compact && !stacked;
    final error = widget.errorText;

    final input = CupertinoTextField(
      controller: _controller,
      focusNode: _focus,
      enabled: widget.enabled,
      autofocus: widget.autofocus,
      placeholder: widget.placeholder,
      placeholderStyle: _style(context, colors.placeholder),
      style: style,
      cursorColor: colors.tint,
      textAlign: end ? TextAlign.end : TextAlign.start,
      decoration: null,
      padding: EdgeInsets.symmetric(vertical: pad),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      textInputAction: widget.textInputAction,
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'[0-9.,\s€]')),
        LengthLimitingTextInputFormatter(_kMaxLength),
      ],
      onChanged: _changed,
      onSubmitted: widget.onSubmitted == null
          ? null
          : (text) => widget.onSubmitted!(_parse(text).cents),
    );

    final semanticsLabel =
        widget.semanticLabel ??
        [
          label,
          widget.placeholder,
        ].whereType<String>().where((t) => t.isNotEmpty).join(', ');
    final hint = [
      widget.semanticHint,
      error,
    ].whereType<String>().where((t) => t.isNotEmpty).join('. ');

    final field = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: AvoSizes.hitTarget),
      child: Center(
        child: Semantics(
          label: semanticsLabel.isEmpty ? null : semanticsLabel,
          hint: hint.isEmpty ? null : hint,
          textField: true,
          child: input,
        ),
      ),
    );

    Widget body = field;
    if (label != null) {
      final title = ExcludeSemantics(
        child: Text(
          label,
          style: context.text(
            AvoTextStyle.body,
            color: widget.enabled ? colors.label : colors.secondaryLabel,
          ),
        ),
      );
      body = stacked
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                title,
                const SizedBox(height: AvoSpacing.xs),
                field,
              ],
            )
          : Row(
              children: [
                // A long title wraps; it never takes more than half the row.
                Flexible(child: title),
                const SizedBox(width: _kLabelGap),
                Expanded(child: field),
              ],
            );
      body = GestureDetector(
        behavior: HitTestBehavior.opaque,
        excludeFromSemantics: true,
        onTap: widget.enabled ? _focus.requestFocus : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AvoSpacing.l,
            vertical: _kRowVertical,
          ),
          child: body,
        ),
      );
    }

    if (error == null || error.isEmpty) return body;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        body,
        Padding(
          padding: EdgeInsetsDirectional.only(
            start: label != null ? AvoSpacing.l : 0,
            end: label != null ? AvoSpacing.l : 0,
            top: AvoSpacing.xs,
          ),
          child: _ErrorLine(text: error),
        ),
      ],
    );
  }
}

/// The red mark and the error sentence under the field, announced when it
/// appears.
class _ErrorLine extends StatelessWidget {
  const _ErrorLine({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final iconSize =
        _kErrorIcon *
        typography.sizeOf(AvoTextStyle.footnote) /
        _kFootnoteDefaultSize;
    final line = typography.lineHeightOf(AvoTextStyle.footnote);
    return Semantics(
      liveRegion: true,
      container: true,
      label: text,
      child: ExcludeSemantics(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: line < iconSize ? iconSize : line,
              child: Center(
                widthFactor: 1,
                child: AvoIcon(
                  AvoIcons.exclamationmarkCircle,
                  size: iconSize,
                  color: colors.destructive,
                ),
              ),
            ),
            const SizedBox(width: AvoSpacing.xs + AvoSpacing.xxs),
            Expanded(
              child: Text(
                text,
                style: context.text(AvoTextStyle.footnote, color: colors.label),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// [cents] as the number of an [AmountField] in [languageCode]: "1.234,56"
/// in German, "1,234.56" in English (always two decimals, no currency sign).
String formatAmountNumber(int cents, String languageCode) {
  final locale = languageCode == 'de' ? 'de_DE' : 'en_US';
  return NumberFormat.decimalPatternDigits(
    locale: locale,
    decimalDigits: 2,
  ).format(cents / 100);
}

/// [cents] with the currency sign as an [AmountField] shows it after
/// editing: "1.234,56 €" (no-break space) in German, "€1,234.56" in English.
String formatAmount(int cents, String languageCode) {
  final locale = languageCode == 'de' ? 'de_DE' : 'en_US';
  return NumberFormat.currency(
    locale: locale,
    symbol: '€',
    decimalDigits: 2,
  ).format(cents / 100);
}
