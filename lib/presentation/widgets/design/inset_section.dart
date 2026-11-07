import 'package:flutter/widgets.dart';

import 'package:shoply/core/design/design.dart';

/// Space between a section heading and its group (D2 `.hd` / aisle heads:
/// padding 20 32 6).
const double _kCapsBottom = 6; // D2

/// Gap between the heading text and its trailing widget.
const double _kCapsTrailingGap = AvoSpacing.s;

/// Upper-cases [text] for display without breaking German or Turkish:
/// Dart's `toUpperCase` leaves "ß" alone and maps "i" to "I" everywhere.
String _localeUpperCase(String text, Locale? locale) {
  var source = text;
  final language = locale?.languageCode;
  if (language == 'tr' || language == 'az') {
    source = source.replaceAll('i', 'İ');
  }
  return source.toUpperCase().replaceAll('ß', 'SS');
}

/// Section and aisle heading of D2: 13/18 semibold, upper case, +0.3 pt
/// tracking, `secondaryLabel` (the one place where D2 upper-cases text,
/// Konflikt 9.10).
///
/// The upper-casing is display only: VoiceOver reads [text] as given, as a
/// heading. From AX1 on a [trailing] widget moves below the text.
class SectionCaps extends StatelessWidget {
  /// Creates a heading. Pass [text] in normal spelling.
  const SectionCaps(
    this.text, {
    super.key,
    this.trailing,
    this.padding = SectionCaps.insetPadding,
  });

  /// Above an inset group: 20 top, 32 left and right (16 screen margin + 16
  /// row inset), 6 bottom (D2).
  static const EdgeInsetsGeometry insetPadding = EdgeInsets.fromLTRB(
    AvoSpacing.xxxl,
    AvoSpacing.xl,
    AvoSpacing.xxxl,
    _kCapsBottom,
  );

  /// Above a plain (edge-to-edge) section: like [insetPadding] with the text
  /// at 16 pt.
  static const EdgeInsetsGeometry plainPadding = EdgeInsets.fromLTRB(
    AvoSpacing.l,
    AvoSpacing.xl,
    AvoSpacing.l,
    _kCapsBottom,
  );

  /// Inside a card or panel that already has its own padding (D2 `0 16`).
  static const EdgeInsetsGeometry compactPadding = EdgeInsets.symmetric(
    horizontal: AvoSpacing.l,
  );

  /// The heading in normal spelling ("Obst & Gemüse").
  final String text;

  /// Optional widget at the end, e.g. a count ("3") or a text button. Text in
  /// it gets the caps style in regular weight with tabular figures.
  final Widget? trailing;

  /// Outer padding; see [insetPadding], [plainPadding], [compactPadding].
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final heading = Semantics(
      header: true,
      label: text,
      child: ExcludeSemantics(
        child: Text(
          _localeUpperCase(text, Localizations.maybeLocaleOf(context)),
          style: context.text(
            AvoTextStyle.sectionCaps,
            color: colors.secondaryLabel,
          ),
        ),
      ),
    );
    final end = trailing;
    if (end == null) {
      return Padding(
        padding: padding,
        child: Align(
          alignment: AlignmentDirectional.centerStart,
          heightFactor: 1,
          child: heading,
        ),
      );
    }
    final trailingStyled = DefaultTextStyle(
      style: context.text(
        AvoTextStyle.sectionCaps,
        color: colors.secondaryLabel,
        weight: FontWeight.w400,
        tabular: true,
      ),
      child: end,
    );
    return Padding(
      padding: padding,
      child: context.isAccessibilityText
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [heading, trailingStyled],
            )
          : Row(
              children: [
                Expanded(child: heading),
                const SizedBox(width: _kCapsTrailingGap),
                trailingStyled,
              ],
            ),
    );
  }
}

/// A white group with rounded corners on the grouped background, D2 style
/// (radius 26, 16 pt from the screen edges), optionally with a [SectionCaps]
/// heading and a footnote (Konzept 00 §12.5).
///
/// Rows inside bring their own padding (`NavRow`, `ToggleRow`, `ItemRow`).
/// Between rows the group draws 0.5 pt hairlines from [separatorIndent]; pass
/// the text edge of the rows (for example 58 with a 30 pt icon). From AX1 on
/// the group is always [plain]. With no [children] nothing is rendered, so an
/// empty section simply disappears. The group adds no outer spacing besides
/// its heading and footer; space sections without a heading on the screen.
class InsetSection extends StatelessWidget {
  /// Creates a section around [children].
  const InsetSection({
    super.key,
    this.header,
    this.headerTrailing,
    this.footer,
    required this.children,
    this.plain = false,
    this.showSeparators = true,
    this.separatorIndent = AvoSpacing.l,
  });

  /// Heading above the group in normal spelling; shown as [SectionCaps].
  final String? header;

  /// Optional widget at the end of the heading (count, "Alle anzeigen").
  final Widget? headerTrailing;

  /// Footnote below the group (13/18, `secondaryLabel`).
  final String? footer;

  /// The rows. An empty list renders nothing.
  final List<Widget> children;

  /// Edge to edge without rounding (shopping mode). Forced from AX1 on.
  final bool plain;

  /// Hairlines between the rows.
  final bool showSeparators;

  /// Start inset of the hairlines in points.
  final double separatorIndent;

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty) return const SizedBox.shrink();
    final colors = context.colors;
    final isPlain = plain || context.isAccessibilityText;

    final rows = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      rows.add(children[i]);
      if (showSeparators && i < children.length - 1) {
        rows.add(
          Padding(
            padding: EdgeInsetsDirectional.only(start: separatorIndent),
            child: SizedBox(
              height: AvoSizes.hairline,
              width: double.infinity,
              child: ColoredBox(color: colors.separator),
            ),
          ),
        );
      }
    }

    final column = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: rows,
    );

    final group = isPlain
        ? ColoredBox(color: colors.surface, child: column)
        : Padding(
            padding: const EdgeInsets.symmetric(horizontal: AvoSpacing.screen),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AvoRadii.group),
              child: ColoredBox(color: colors.surface, child: column),
            ),
          );

    final heading = header;
    final note = footer;
    if (heading == null && note == null) return group;

    final textInset = isPlain ? AvoSpacing.l : AvoSpacing.xxxl;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (heading != null)
          SectionCaps(
            heading,
            trailing: headerTrailing,
            padding: isPlain
                ? SectionCaps.plainPadding
                : SectionCaps.insetPadding,
          ),
        group,
        if (note != null)
          Padding(
            padding: EdgeInsets.fromLTRB(textInset, AvoSpacing.s, textInset, 0),
            child: Text(
              note,
              style: context.text(
                AvoTextStyle.footnote,
                color: colors.secondaryLabel,
              ),
            ),
          ),
      ],
    );
  }
}
