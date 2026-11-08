import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

import 'package:shoply/core/design/design.dart';
import 'package:shoply/presentation/widgets/design/avo_icons.dart';

const double _kRowMin = 52; // D2 one line
const double _kRowMinTwoLines = 60; // D2 with a second line
const double _kRowVertical = AvoSpacing.s; // D2
const double _kIcon = 22; // D2 location glyph in rows
const double _kNoteIcon = 13; // D2 glyph before the footnote line
const double _kFieldMinWidth = 96; // D2 five digits at the default size

/// Above and below the digits, so the field itself is a 44-pt target
/// (22 pt of text at the default size).
const double _kFieldPad = 11;

/// "Standort verwenden" (`angebote.md` 2.3, S11, S14): the `location` glyph
/// and the title in `tint`, a second line that explains before the system
/// asks (or says what was found), and a small activity indicator at the end
/// while locating (at the trigger, never a full-screen spinner).
///
/// One VoiceOver button; while locating its value is "Standort wird
/// ermittelt". [onTap] null (while locating) ignores taps.
class UseLocationRow extends StatelessWidget {
  const UseLocationRow({
    super.key,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.locating = false,
    this.locatingLabel,
  });

  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final bool locating;
  final String? locatingLabel;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final tap = locating ? null : onTap;
    return Semantics(
      container: true,
      button: true,
      enabled: tap != null || locating,
      label: '$title, $subtitle',
      value: locating ? locatingLabel : null,
      onTap: tap,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: tap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: _kRowMinTwoLines),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AvoSpacing.l,
              vertical: _kRowVertical,
            ),
            child: Row(
              children: [
                AvoIcon(AvoIcons.location, size: _kIcon, color: colors.tint),
                const SizedBox(width: AvoSpacing.m),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        style: context.text(
                          AvoTextStyle.body,
                          color: colors.tint,
                        ),
                      ),
                      Text(
                        subtitle,
                        style: context.text(
                          AvoTextStyle.subhead,
                          color: colors.secondaryLabel,
                        ),
                      ),
                    ],
                  ),
                ),
                if (locating) ...[
                  const SizedBox(width: AvoSpacing.m),
                  const CupertinoActivityIndicator(),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// "Postleitzahl" with a five-digit field (`angebote.md` 2.3, S11, S14):
/// the label at the start, the digits at the end, side by side; from AX1 on
/// the label sits above the field. Number pad, postcode autofill, digits
/// only. The field grows with the text size (no fixed height) and its
/// placeholder wraps instead of being cut.
///
/// VoiceOver reads the field with its label, its value and [error] ("Bitte
/// 5 Ziffern eingeben.") or [place]. Put a [PostcodeNote] under the group.
class PostcodeFieldRow extends StatelessWidget {
  const PostcodeFieldRow({
    super.key,
    required this.controller,
    required this.label,
    required this.placeholder,
    this.focusNode,
    this.error,
    this.place,
    this.onChanged,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final String label;
  final String placeholder;
  final FocusNode? focusNode;
  final String? error;

  /// "79098 · Freiburg": read with the field when there is no [error] (the
  /// [PostcodeNote] under the group is hidden from VoiceOver).
  final String? place;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onSubmitted;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final ax = context.isAccessibilityText;
    final style = context.text(AvoTextStyle.body, tabular: true);
    final align = ax ? TextAlign.start : TextAlign.end;

    final field = Stack(
      fit: StackFit.passthrough,
      children: [
        ValueListenableBuilder<TextEditingValue>(
          valueListenable: controller,
          builder: (context, value, _) => value.text.isEmpty
              ? IgnorePointer(
                  child: ExcludeSemantics(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: _kFieldPad),
                      child: Text(
                        placeholder,
                        textAlign: align,
                        style: style.copyWith(color: colors.placeholder),
                      ),
                    ),
                  ),
                )
              : const SizedBox.shrink(),
        ),
        Semantics(
          label: label,
          hint: error ?? place,
          child: CupertinoTextField(
            controller: controller,
            focusNode: focusNode,
            style: style,
            cursorColor: colors.tint,
            decoration: null,
            padding: const EdgeInsets.symmetric(vertical: _kFieldPad),
            textAlign: align,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.postalCode],
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(5),
            ],
            onChanged: onChanged,
            onSubmitted: (_) => onSubmitted?.call(),
          ),
        ),
      ],
    );
    final title = ExcludeSemantics(
      child: Text(label, style: context.text(AvoTextStyle.body)),
    );

    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: _kRowMin),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AvoSpacing.l,
          vertical: AvoSpacing.xs,
        ),
        child: ax
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: AvoSpacing.s),
                    child: title,
                  ),
                  field,
                ],
              )
            : Row(
                children: [
                  title,
                  const SizedBox(width: AvoSpacing.l),
                  Expanded(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(
                        minWidth: _kFieldMinWidth,
                      ),
                      child: field,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

/// The line under the postcode group: the place ("79098 · Freiburg im
/// Breisgau"), or the error with `exclamationmark.circle`, both 13/18; the
/// error in `destructive`. The field itself carries both for VoiceOver, so
/// this line is hidden from it.
class PostcodeNote extends StatelessWidget {
  const PostcodeNote({super.key, this.place, this.error, this.side});

  final String? place;
  final String? error;

  /// Distance from the edges; defaults to the screen footnote's (32, 16
  /// from AX1 on).
  final double? side;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final problem = error;
    final text = problem ?? place;
    if (text == null) return const SizedBox.shrink();
    final side =
        this.side ??
        (context.isAccessibilityText ? AvoSpacing.l : AvoSpacing.xxxl);
    final color = problem != null ? colors.destructive : colors.secondaryLabel;
    return ExcludeSemantics(
      child: Padding(
        padding: EdgeInsets.fromLTRB(side, 6, side, 0), // D2 .ft
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (problem != null) ...[
              Padding(
                padding: const EdgeInsets.only(top: AvoSpacing.xxs),
                child: AvoIcon(
                  AvoIcons.exclamationmarkCircle,
                  size: MediaQuery.textScalerOf(context).scale(_kNoteIcon),
                  color: color,
                ),
              ),
              const SizedBox(width: AvoSpacing.xs),
            ],
            Expanded(
              child: Text(
                text,
                style: context.text(AvoTextStyle.footnote, color: color),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
