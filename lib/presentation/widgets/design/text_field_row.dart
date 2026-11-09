import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

import 'package:shoply/core/design/design.dart';
import 'package:shoply/core/localization/localization_helper.dart';

/// Minimum row height (D2 X-Profil `.row` min-height 52).
const double _kRowMinHeight = 52; // D2

/// Vertical padding of a row: the field is a 44 pt target inside a 52 pt row.
const double _kRowVerticalPadding = (_kRowMinHeight - AvoSizes.hitTarget) / 2;

/// Gap between the label and the field.
const double _kLabelGap = AvoSpacing.m;

/// The label takes at most this share of the row before the field, so a
/// long label wraps instead of squeezing the field out.
const double _kLabelMaxShare = 0.5;

/// Konzept 00 §12.20: unavailable controls at 40 %.
const double _kDisabledOpacity = 0.4;

/// Space between the field line and the error or hint line.
const double _kNoteGap = AvoSpacing.xxs;

/// A row of an `InsetSection` with a text field: the label on the left, the
/// field right-aligned (Konzept 18, D2 X-Profil rows), and below them an
/// error or hint line.
///
/// - The row has a minimum height of 52 pt and grows with Dynamic Type and
///   wrapped lines; the whole row focuses the field.
/// - From AX1 on the label sits above the field and the field is
///   left-aligned. Below that a long label wraps inside the left half of the
///   row, so the field keeps the other half.
/// - [errorText] (in the destructive colour) wins over [hintText]
///   (secondary colour). VoiceOver reads the error as the hint of the field:
///   "Fehler: …"; the visible line is not read twice.
/// - [controller] and [onChanged] work like on a text field; the row never
///   clears or validates anything itself.
class TextFieldRow extends StatefulWidget {
  /// Creates a text field row.
  const TextFieldRow({
    super.key,
    required this.label,
    this.controller,
    this.focusNode,
    this.placeholder,
    this.onChanged,
    this.onSubmitted,
    this.keyboardType,
    this.textInputAction,
    this.textCapitalization = TextCapitalization.none,
    this.autofillHints,
    this.inputFormatters,
    this.maxLength,
    this.autofocus = false,
    this.autocorrect = true,
    this.obscureText = false,
    this.enabled = true,
    this.errorText,
    this.hintText,
    this.semanticLabel,
  });

  /// The label (17/22), also the VoiceOver label of the field.
  final String label;

  /// Text controller; one is created when null.
  final TextEditingController? controller;

  /// Focus node; one is created when null.
  final FocusNode? focusNode;

  /// Shown in the field while it is empty, right-aligned like the text.
  final String? placeholder;

  /// Called on every edit.
  final ValueChanged<String>? onChanged;

  /// Called when the keyboard's action key is pressed.
  final ValueChanged<String>? onSubmitted;

  /// The keyboard: [TextInputType.number], [TextInputType.emailAddress] …
  final TextInputType? keyboardType;

  /// The keyboard's action key.
  final TextInputAction? textInputAction;

  /// Capitalisation of what is typed.
  final TextCapitalization textCapitalization;

  /// Autofill hints, for example [AutofillHints.postalCode].
  final Iterable<String>? autofillHints;

  /// Filters and formatters, for example digits only.
  final List<TextInputFormatter>? inputFormatters;

  /// Longest text; the field takes no more.
  final int? maxLength;

  /// Focus the field when the row first appears.
  final bool autofocus;

  /// False for codes, postcodes and addresses.
  final bool autocorrect;

  /// Hides the characters.
  final bool obscureText;

  /// False greys the row and keeps the keyboard away.
  final bool enabled;

  /// A problem with the input, shown below in the destructive colour and
  /// read by VoiceOver as the field's hint. Wins over [hintText].
  final String? errorText;

  /// A quiet line below the field ("Fünf Ziffern").
  final String? hintText;

  /// VoiceOver label of the field; defaults to [label].
  final String? semanticLabel;

  @override
  State<TextFieldRow> createState() => _TextFieldRowState();
}

class _TextFieldRowState extends State<TextFieldRow> {
  FocusNode? _ownFocus;

  FocusNode get _focus =>
      widget.focusNode ?? (_ownFocus ??= FocusNode(debugLabel: 'TextFieldRow'));

  @override
  void didUpdateWidget(covariant TextFieldRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.focusNode != widget.focusNode && widget.focusNode != null) {
      _ownFocus?.dispose();
      _ownFocus = null;
    }
  }

  @override
  void dispose() {
    _ownFocus?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final stacked = context.isAccessibilityText;
    final error = widget.errorText;
    final hint = widget.hintText;
    final note = error ?? hint;
    final enabled = widget.enabled;

    // The field carries the label for VoiceOver; the visible one is not read
    // a second time.
    final labelText = ExcludeSemantics(
      child: Text(
        widget.label,
        style: context.text(
          AvoTextStyle.body,
          color: enabled ? colors.label : colors.secondaryLabel,
        ),
      ),
    );

    final semanticHint = error != null
        ? '${context.tr('common_field_error_hint')}: $error'
        : hint;

    final line22 = context.typography.lineHeightOf(AvoTextStyle.body);
    final fieldPad = ((AvoSizes.hitTarget - line22) / 2).clamp(0.0, 44.0);

    Widget field(TextAlign align) => ConstrainedBox(
      constraints: const BoxConstraints(minHeight: AvoSizes.hitTarget),
      child: Center(
        child: Semantics(
          label: widget.semanticLabel ?? widget.label,
          hint: semanticHint,
          child: CupertinoTextField(
            controller: widget.controller,
            focusNode: _focus,
            placeholder: widget.placeholder,
            placeholderStyle: context.text(
              AvoTextStyle.body,
              color: colors.placeholder,
            ),
            style: context.text(AvoTextStyle.body, color: colors.label),
            cursorColor: colors.tint,
            textAlign: align,
            decoration: null,
            // The field itself is the 44 pt target, not just its line of text.
            padding: EdgeInsets.symmetric(vertical: fieldPad),
            enabled: enabled,
            autofocus: widget.autofocus && enabled,
            autocorrect: widget.autocorrect,
            obscureText: widget.obscureText,
            keyboardType: widget.keyboardType,
            textInputAction: widget.textInputAction,
            textCapitalization: widget.textCapitalization,
            autofillHints: widget.autofillHints,
            inputFormatters: widget.inputFormatters,
            maxLength: widget.maxLength,
            maxLengthEnforcement: MaxLengthEnforcement.enforced,
            onChanged: widget.onChanged,
            onSubmitted: widget.onSubmitted,
          ),
        ),
      ),
    );

    final Widget line;
    if (stacked) {
      line = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          labelText,
          const SizedBox(height: AvoSpacing.xs),
          field(TextAlign.start),
        ],
      );
    } else {
      line = LayoutBuilder(
        builder: (context, constraints) => Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: constraints.maxWidth * _kLabelMaxShare,
              ),
              child: labelText,
            ),
            const SizedBox(width: _kLabelGap),
            Expanded(child: field(TextAlign.end)),
          ],
        ),
      );
    }

    final noteWidget = note == null
        ? null
        : Padding(
            padding: const EdgeInsets.only(top: _kNoteGap),
            child: ExcludeSemantics(
              child: Text(
                note,
                style: context.text(
                  AvoTextStyle.footnote,
                  color: error != null
                      ? colors.destructive
                      : colors.secondaryLabel,
                ),
              ),
            ),
          );

    Widget row = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: _kRowMinHeight),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AvoSpacing.l,
          vertical: _kRowVerticalPadding,
        ),
        child: Align(
          alignment: AlignmentDirectional.centerStart,
          heightFactor: 1,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [line, ?noteWidget],
          ),
        ),
      ),
    );
    if (!enabled) row = Opacity(opacity: _kDisabledOpacity, child: row);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      excludeFromSemantics: true,
      onTap: enabled ? _focus.requestFocus : null,
      child: row,
    );
  }
}
