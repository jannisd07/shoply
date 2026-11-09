import 'package:flutter/widgets.dart';

import 'package:shoply/core/design/design.dart';
import 'package:shoply/presentation/widgets/design/app_button.dart';
import 'package:shoply/presentation/widgets/design/inset_section.dart';
import 'package:shoply/presentation/widgets/design/row_highlight.dart';

/// Gap between chips in a row (D2 "Filter-Chips": gap 8).
const double _kChipGap = AvoSpacing.s; // D2

/// A section whose content is a block of chips (Konzept 18 E18-05): an
/// [InsetSection] with a heading and a footnote, inside it a [Wrap] of
/// `AppFilterChip`s with 16 pt padding, and at the end an optional plain
/// "Weitere anzeigen".
///
/// The chips always wrap as a whole into the next line, never scroll
/// sideways, so no choice hides behind the screen edge (allergies). From AX1
/// on the section is edge to edge like every [InsetSection]; a chip that is
/// wider than the line wraps its label. The same section is used in
/// Ernährung & Allergien and can replace the onboarding's own wrap.
class ChipSection extends StatelessWidget {
  /// Creates a chip section.
  const ChipSection({
    super.key,
    this.header,
    this.footer,
    required this.chips,
    this.moreLabel,
    this.onMore,
    this.highlightId,
  });

  /// Heading above the group in normal spelling ("Allergien").
  final String? header;

  /// Footnote below the group.
  final String? footer;

  /// The chips, usually `AppFilterChip`s. An empty list renders nothing.
  final List<Widget> chips;

  /// Label of the plain button after the chips ("Weitere anzeigen"); shown
  /// only together with [onMore].
  final String? moreLabel;

  /// Shows more chips. Null hides the button.
  final VoidCallback? onMore;

  /// Settings row id for the search highlight (`diet.allergies`): the
  /// content of the group lights up once like a row (`HighlightableRow`).
  final String? highlightId;

  @override
  Widget build(BuildContext context) {
    if (chips.isEmpty) return const SizedBox.shrink();
    final label = moreLabel;
    final more = onMore;
    Widget content = Padding(
      padding: const EdgeInsets.fromLTRB(
        AvoSpacing.l,
        AvoSpacing.s,
        AvoSpacing.l,
        AvoSpacing.s,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Wrap(spacing: _kChipGap, children: chips),
          if (label != null && more != null)
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: AppButton.plain(label: label, onPressed: more),
            ),
        ],
      ),
    );
    final id = highlightId;
    if (id != null) content = HighlightableRow(id: id, child: content);
    return InsetSection(
      header: header,
      footer: footer,
      showSeparators: false,
      children: [content],
    );
  }
}
