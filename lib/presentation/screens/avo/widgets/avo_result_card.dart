import 'package:flutter/semantics.dart';
import 'package:flutter/widgets.dart';

import 'package:shoply/core/design/design.dart';
import 'package:shoply/core/localization/localization_helper.dart';
import 'package:shoply/presentation/screens/avo/widgets/avo_status_line.dart';
import 'package:shoply/presentation/widgets/design/app_button.dart';
import 'package:shoply/presentation/widgets/design/avo_icons.dart';

// D2 X-Avo result card (Kap. 2.5).
const double _leadingSize = 36; // D2 object image 36 × 36
const double _leadingRadius = 10; // D2
const double _leadingGlyph = 20; // D2 SF Symbol 20
const double _headGap = 10; // D2
const double _headTop = 12; // D2 padding 12 16 2
const double _headBottom = 2; // D2
const double _footTop = 10; // D2 padding 10 16 14
const double _footBottom = 14; // D2
const double _footGap = 18; // D2 gap between the text buttons
const double _bodyBottom = 12; // a section without a footer ends 12 below

/// One white group per answer (D2 X-Avo, radius 26): every change or read
/// result is an [AvoResultSection] in it, divided by full-width hairlines.
/// Never several equal cards under each other.
class AvoResultCard extends StatelessWidget {
  const AvoResultCard({super.key, required this.sections});

  final List<Widget> sections;

  @override
  Widget build(BuildContext context) {
    if (sections.isEmpty) return const SizedBox.shrink();
    final colors = context.colors;
    return ClipRRect(
      borderRadius: BorderRadius.circular(AvoRadii.group),
      child: ColoredBox(
        color: colors.surface,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < sections.length; i++) ...[
              if (i > 0) const AvoHairline(),
              sections[i],
            ],
          ],
        ),
      ),
    );
  }
}

/// A 0.5 pt separator, from [indent] to the end.
class AvoHairline extends StatelessWidget {
  const AvoHairline({super.key, this.indent = 0});

  final double indent;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsetsDirectional.only(start: indent),
    child: SizedBox(
      height: AvoSizes.hairline,
      width: double.infinity,
      child: ColoredBox(color: context.colors.separator),
    ),
  );
}

/// The 36 pt object square of a section head: an SF-style glyph on the
/// light accent (or on `fill` when [neutral]).
class AvoSymbolTile extends StatelessWidget {
  const AvoSymbolTile({super.key, required this.icon, this.neutral = false});

  /// An [AvoIcon] or [Icon]; drawn 20 pt in the accent (secondary when
  /// [neutral]).
  final Widget icon;
  final bool neutral;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return ExcludeSemantics(
      child: SizedBox.square(
        dimension: _leadingSize,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: neutral ? colors.fill : colors.tintSoft,
            borderRadius: BorderRadius.circular(_leadingRadius),
          ),
          child: Center(
            child: IconStyleScope(
              size: _leadingGlyph,
              color: neutral ? colors.secondaryLabel : colors.tint,
              child: icon,
            ),
          ),
        ),
      ),
    );
  }
}

/// A text button in a section footer ("Liste öffnen", "Widerrufen").
@immutable
class AvoCardAction {
  const AvoCardAction({
    required this.label,
    required this.onPressed,
    this.isUndo = false,
    this.working = false,
  });

  final String label;
  final VoidCallback? onPressed;

  /// "Widerrufen": dropped once undone or changed since.
  final bool isUndo;

  /// Shows a small activity indicator in place of the label.
  final bool working;
}

/// Where a section stands (table in Kap. 2.5).
enum AvoSectionState {
  /// The tool runs: dots instead of the object image, no footer.
  running,

  /// Done.
  done,

  /// Taken back: title secondary, "Rückgängig gemacht", no "Widerrufen".
  undone,

  /// Someone changed the data since: "Widerrufen" goes, the subtitle says
  /// "Inzwischen geändert".
  changedSince,
}

/// One section of an [AvoResultCard]: the head names **the object** (title)
/// and **what happened** (subtitle), optional detail rows, up to two text
/// buttons (the destination first, then "Widerrufen").
///
/// VoiceOver reads the head as one sentence ([semanticLabel]) with the
/// buttons as custom actions too; detail rows stay their own elements (check
/// circles are switches). From AX1 the object image goes and the buttons
/// stack, left aligned.
class AvoResultSection extends StatelessWidget {
  const AvoResultSection({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.details = const [],
    this.detailIndent = AvoSpacing.l,
    this.actions = const [],
    this.state = AvoSectionState.done,
    this.footnote,
    this.titleColor,
    this.semanticLabel,
    this.trailingTitle,
  });

  final String title;
  final String? subtitle;

  /// 36 × 36 object square ([AvoSymbolTile] or a picture); none from AX1.
  final Widget? leading;

  /// Rows under the head (item rows, list rows), with hairlines from
  /// [detailIndent].
  final List<Widget> details;
  final double detailIndent;

  final List<AvoCardAction> actions;
  final AvoSectionState state;

  /// A note under the section ("Stand 14:05").
  final String? footnote;

  /// Overrides the title colour (secondary for answered or stale rows).
  final Color? titleColor;

  /// The full sentence VoiceOver reads; defaults to title and subtitle.
  final String? semanticLabel;

  /// After the title on its line (the Pro badge).
  final Widget? trailingTitle;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final ax = context.isAccessibilityText;
    final undone = state == AvoSectionState.undone;
    final changed = state == AvoSectionState.changedSince;

    var sub = subtitle;
    if (undone) sub = context.tr('avo_row_undone');
    if (changed) {
      final note = context.tr('avo_row_changed_since');
      sub = sub == null || sub.isEmpty ? note : '$sub · $note';
    }
    final visibleActions = [
      for (final a in actions)
        if (!(a.isUndo && (undone || changed))) a,
    ];
    final showFooter =
        state != AvoSectionState.running && visibleActions.isNotEmpty;

    final Widget? lead = state == AvoSectionState.running
        ? const SizedBox.square(
            dimension: _leadingSize,
            child: Center(child: AvoActivityDots()),
          )
        : leading;

    final titleText = Text(
      title,
      style: context.text(
        AvoTextStyle.subhead,
        weight: FontWeight.w600,
        color: titleColor ?? (undone ? colors.secondaryLabel : colors.label),
      ),
    );
    final head = Padding(
      padding: const EdgeInsets.fromLTRB(
        AvoSpacing.l,
        _headTop,
        AvoSpacing.l,
        _headBottom,
      ),
      child: Row(
        children: [
          if (lead != null && !ax) ...[lead, const SizedBox(width: _headGap)],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (trailingTitle == null)
                  titleText
                else
                  Wrap(
                    spacing: AvoSpacing.s,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [titleText, trailingTitle!],
                  ),
                if (sub != null && sub.isNotEmpty)
                  Text(
                    sub,
                    style: context.text(
                      AvoTextStyle.footnote,
                      color: colors.secondaryLabel,
                      tabular: true,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );

    final sentence =
        semanticLabel ??
        [title, if (sub != null && sub.isNotEmpty) sub].join(', ');
    final customActions = <CustomSemanticsAction, VoidCallback>{
      for (final a in visibleActions)
        if (a.onPressed != null)
          CustomSemanticsAction(label: a.label): a.onPressed!,
    };

    final buttons = [
      for (final a in visibleActions)
        AppButton.plain(
          label: a.label,
          onPressed: a.onPressed,
          working: a.working,
        ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Semantics(
          container: true,
          label: sentence,
          customSemanticsActions: customActions,
          child: ExcludeSemantics(child: head),
        ),
        if (details.isNotEmpty) ...[
          const SizedBox(height: AvoSpacing.xs),
          for (var i = 0; i < details.length; i++) ...[
            if (i > 0) AvoHairline(indent: detailIndent),
            details[i],
          ],
        ],
        if (showFooter)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AvoSpacing.l,
              _footTop - AvoSpacing.s,
              AvoSpacing.l,
              _footBottom - AvoSpacing.s,
            ),
            child: ax
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: buttons,
                  )
                : Wrap(spacing: _footGap, children: buttons),
          )
        else
          const SizedBox(height: _bodyBottom),
        if (footnote != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AvoSpacing.l,
              0,
              AvoSpacing.l,
              _bodyBottom,
            ),
            child: Text(
              footnote!,
              style: context.text(
                AvoTextStyle.footnote,
                color: colors.secondaryLabel,
                tabular: true,
              ),
            ),
          ),
      ],
    );
  }
}
