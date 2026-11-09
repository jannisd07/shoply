import 'package:flutter/widgets.dart';

import 'package:shoply/core/design/design.dart';

/// Minimum row height and vertical padding, as the settings rows of Teil A
/// (D2 X-Profil `.row`: min-height 52, 60 pt with a second line).
const double _kRowMinHeight = 52; // D2
const double _kRowVerticalPadding = 9; // D2

/// Space between a wrapped title and the value below it.
const double _kRunSpacing = AvoSpacing.xxs;

/// A read-only settings row with a second line: a Siri sentence and what it
/// does, a widget and its sizes. Teil A's `ValueRow` has no second line and
/// `NavRow` is a button; this row does nothing when tapped.
///
/// Title `body` in `label`, [subtitle] `subhead` in `secondaryLabel`, an
/// optional [value] at the end (`body`, `secondaryLabel`) that wraps below
/// the title when both do not fit and always sits below from AX1 on.
/// VoiceOver reads one element: "title, subtitle, value".
class SettingsInfoRow extends StatelessWidget {
  const SettingsInfoRow({
    super.key,
    required this.title,
    this.subtitle,
    this.value,
  });

  final String title;
  final String? subtitle;
  final String? value;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final sub = subtitle;
    final v = value;
    final titleBlock = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(title, style: context.text(AvoTextStyle.body, color: colors.label)),
        if (sub != null && sub.isNotEmpty)
          Text(
            sub,
            style: context.text(
              AvoTextStyle.subhead,
              color: colors.secondaryLabel,
            ),
          ),
      ],
    );
    Widget content = titleBlock;
    if (v != null && v.isNotEmpty) {
      final valueText = Text(
        v,
        style: context.text(AvoTextStyle.body, color: colors.secondaryLabel),
      );
      content = context.isAccessibilityText
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [titleBlock, valueText],
            )
          : Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: AvoSpacing.m,
              runSpacing: _kRunSpacing,
              children: [titleBlock, valueText],
            );
    }
    return Semantics(
      container: true,
      label: [
        title,
        if (sub != null && sub.isNotEmpty) sub,
        if (v != null && v.isNotEmpty) v,
      ].join(', '),
      child: ExcludeSemantics(
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: _kRowMinHeight),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AvoSpacing.l,
              vertical: _kRowVerticalPadding,
            ),
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              heightFactor: 1,
              child: content,
            ),
          ),
        ),
      ),
    );
  }
}
