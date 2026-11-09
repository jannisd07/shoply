import 'package:flutter/cupertino.dart';
import 'package:flutter/semantics.dart';

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
/// - At most [maxCollapsed] detail rows show; tapping the head unfolds up to
///   [maxExpanded] (with [onSeeAll] "Alle in {Liste} ansehen" beyond that).
///   Without more rows a tap on the head runs [onOpen] (Kap. 3.5).
/// - [partialText] adds the "2 Artikel nicht verschoben · Erneut versuchen"
///   row, [pendingOffline] the sync mark with "Wird gesendet, sobald du
///   online bist" (Kap. 2.5).
///
/// VoiceOver reads the head as one sentence ([semanticLabel]); double tap
/// unfolds or opens. The footer buttons are their own buttons (heard once),
/// detail rows stay their own elements (check circles are switches). From
/// AX1 the object image goes and the buttons stack, left aligned.
class AvoResultSection extends StatefulWidget {
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
    this.maxCollapsed = 8,
    this.maxExpanded = 20,
    this.onOpen,
    this.seeAllLabel,
    this.onSeeAll,
    this.partialText,
    this.onRetryPartial,
    this.partialWorking = false,
    this.pendingOffline = false,
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

  /// Rows shown folded and unfolded (Kap. 2.5: 8, Kap. 3.5: 20).
  final int maxCollapsed;
  final int maxExpanded;

  /// A tap on the head when there is nothing to unfold (open the list).
  final VoidCallback? onOpen;

  /// "Alle in {Liste} ansehen" under the unfolded rows beyond [maxExpanded].
  final String? seeAllLabel;
  final VoidCallback? onSeeAll;

  /// "2 Artikel nicht verschoben"; with [onRetryPartial] "Erneut versuchen".
  final String? partialText;
  final VoidCallback? onRetryPartial;
  final bool partialWorking;

  /// The change waits in the offline queue.
  final bool pendingOffline;

  @override
  State<AvoResultSection> createState() => _AvoResultSectionState();
}

// Kap. 3.5: details unfold on the standard spring (0.35 s, no overshoot).
const Duration _unfold = Duration(milliseconds: 350); // D2 AvoMotion.standard
const double _syncGlyph = 13; // D2 arrow.triangle.2.circlepath 13 pt

class _AvoResultSectionState extends State<AvoResultSection> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final w = widget;
    final colors = context.colors;
    final ax = context.isAccessibilityText;
    final undone = w.state == AvoSectionState.undone;
    final changed = w.state == AvoSectionState.changedSince;

    var sub = w.subtitle;
    if (undone) sub = context.tr('avo_row_undone');
    if (changed) {
      final note = context.tr('avo_row_changed_since');
      sub = sub == null || sub.isEmpty ? note : '$sub · $note';
    }
    final pendingNote = w.pendingOffline && !undone
        ? context.tr('avo_row_pending_offline')
        : null;
    final visibleActions = [
      for (final a in w.actions)
        if (!(a.isUndo && (undone || changed))) a,
    ];
    final showFooter =
        w.state != AvoSectionState.running && visibleActions.isNotEmpty;
    final canExpand = w.details.length > w.maxCollapsed;
    final shownCount = _expanded
        ? w.details.length.clamp(0, w.maxExpanded)
        : w.details.length.clamp(0, w.maxCollapsed);
    final showSeeAll =
        _expanded &&
        w.details.length > w.maxExpanded &&
        w.seeAllLabel != null &&
        w.onSeeAll != null;

    final Widget? lead = w.state == AvoSectionState.running
        ? const SizedBox.square(
            dimension: _leadingSize,
            child: Center(child: AvoActivityDots()),
          )
        : w.leading;

    final titleText = Text(
      w.title,
      style: context.text(
        AvoTextStyle.subhead,
        weight: FontWeight.w600,
        color: w.titleColor ?? (undone ? colors.secondaryLabel : colors.label),
      ),
    );
    final footnoteStyle = context.text(
      AvoTextStyle.footnote,
      color: colors.secondaryLabel,
      tabular: true,
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
                if (w.trailingTitle == null)
                  titleText
                else
                  Wrap(
                    spacing: AvoSpacing.s,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [titleText, w.trailingTitle!],
                  ),
                if (sub != null && sub.isNotEmpty)
                  Text(sub, style: footnoteStyle),
                if (pendingNote != null)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(
                          top: AvoSpacing.xxs,
                          right: AvoSpacing.xs,
                        ),
                        child: AvoIcon(
                          AvoIcons.sync,
                          size: _syncGlyph,
                          color: colors.secondaryLabel,
                        ),
                      ),
                      Flexible(child: Text(pendingNote, style: footnoteStyle)),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );

    final sentence =
        w.semanticLabel ??
        [w.title, if (sub != null && sub.isNotEmpty) sub].join(', ');
    void toggle() => setState(() => _expanded = !_expanded);
    final VoidCallback? headTap = canExpand ? toggle : w.onOpen;
    final customActions = <CustomSemanticsAction, VoidCallback>{
      if (canExpand && !_expanded)
        CustomSemanticsAction(label: context.tr('avo_show_details')): toggle,
    };

    final buttons = [
      for (final a in visibleActions)
        AppButton.plain(
          label: a.label,
          onPressed: a.onPressed,
          working: a.working,
        ),
    ];

    final partial = w.partialText;
    final rows = <Widget>[
      for (var i = 0; i < shownCount; i++) ...[
        if (i > 0) AvoHairline(indent: w.detailIndent),
        w.details[i],
      ],
      if (showSeeAll)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AvoSpacing.l),
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            child: AppButton.plain(
              label: w.seeAllLabel!,
              onPressed: w.onSeeAll,
            ),
          ),
        ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Semantics(
          container: true,
          button: headTap != null,
          label: sentence,
          onTap: headTap,
          customSemanticsActions: customActions.isEmpty ? null : customActions,
          excludeSemantics: true,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: headTap,
            child: ConstrainedBox(
              // A tappable head keeps a 44 pt target.
              constraints: BoxConstraints(
                minHeight: headTap == null ? 0 : AvoSizes.hitTarget,
              ),
              child: head,
            ),
          ),
        ),
        if (rows.isNotEmpty) ...[
          const SizedBox(height: AvoSpacing.xs),
          AnimatedSize(
            duration: context.reduceMotion ? Duration.zero : _unfold,
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: rows,
            ),
          ),
        ],
        if (partial != null && !undone)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AvoSpacing.l,
              AvoSpacing.xs,
              AvoSpacing.l,
              0,
            ),
            child: Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: AvoSpacing.s,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      CupertinoIcons.exclamationmark_circle,
                      size: _syncGlyph + AvoSpacing.xs,
                      color: colors.destructive,
                    ),
                    const SizedBox(width: AvoSpacing.xs),
                    Flexible(
                      child: Text(
                        partial,
                        style: context.text(
                          AvoTextStyle.footnote,
                          color: colors.destructive,
                        ),
                      ),
                    ),
                  ],
                ),
                if (w.onRetryPartial != null)
                  AppButton.plain(
                    label: context.tr('avo_retry'),
                    working: w.partialWorking,
                    onPressed: w.partialWorking ? null : w.onRetryPartial,
                  ),
              ],
            ),
          ),
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
        if (w.footnote != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AvoSpacing.l,
              0,
              AvoSpacing.l,
              _bodyBottom,
            ),
            child: Text(w.footnote!, style: footnoteStyle),
          ),
      ],
    );
  }
}
