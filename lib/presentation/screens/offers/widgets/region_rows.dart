import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

import 'package:shoply/core/design/design.dart';
import 'package:shoply/presentation/widgets/design/avo_icons.dart';

const double _kRowMinTwoLines = 60; // D2 with a second line
const double _kRowVertical = AvoSpacing.s; // D2
const double _kIcon = 22; // D2 location glyph in rows

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

/// Digits only, at most five: the postcode field's formatters (S11, S14),
/// for a `TextFieldRow` with the number pad and postcode autofill.
final List<TextInputFormatter> postcodeInputFormatters = [
  FilteringTextInputFormatter.digitsOnly,
  LengthLimitingTextInputFormatter(5),
];
