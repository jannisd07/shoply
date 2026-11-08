import 'package:flutter/physics.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/widgets.dart';

import 'package:shoply/core/design/design.dart';
import 'package:shoply/core/localization/localization_helper.dart';
import 'package:shoply/presentation/widgets/design/app_button.dart';
import 'package:shoply/presentation/widgets/design/avatar.dart';
import 'package:shoply/presentation/widgets/design/avo_icons.dart';
import 'package:shoply/presentation/widgets/design/glass_surface.dart';
import 'package:shoply/presentation/widgets/design/item_row.dart';
import 'package:shoply/presentation/widgets/design/progress.dart';

// D2 list card (D2-Komponenten "Listenkarte · Cover + Fortschritt").
const double _coverHeight = 72; // D2
const double _chipInset = 10; // D2 `right:10px; top:10px`
const double _chipMinHeight = 28; // D2
const double _chipRadius = 14; // D2
const double _chipGap = 6; // D2
const double _chipStart = 4; // D2 padding 0 10 0 4
const double _chipEnd = 10; // D2
const double _chipVertical = AvoSpacing.xs; // room for a wrapped chip text
const double _coverItemGap = AvoSpacing.s; // badge and chip side by side
const EdgeInsets _bodyPadding = EdgeInsets.fromLTRB(16, 12, 16, 14); // D2
const double _counterGap = AvoSpacing.s;
const double _metaGap = 2; // D2 margin-top 2
const double _progressGap = 10; // D2 margin-top 10

// D2 card shadow: `0 0 0 .5px rgba(0,0,0,.07), 0 6px 18px rgba(0,0,0,.07)`.
const double _ringSpread = 0.5; // D2
const double _shadowAlpha = 0.07; // D2
const Offset _dropOffset = Offset(0, 6); // D2
const double _dropBlur = 18; // D2

/// Chips on the cover follow Dynamic Type up to AX2 only, like other badges
/// (Konzept 00 §6.4); the card's text keeps growing. AX2 = 33 / 17.
const double _chipMaxTextScale = 33 / 17;

// D2 list rows (D2-Home "Andere Listen", D2-FuerDich "Top-Listen").
const double _rowMinHeight = 60; // D2-Home (D2-FuerDich: 64)
const double _rowVertical = 8; // D2-Home padding 8 16
const double _rowGap = AvoSpacing.m; // D2 gap 12
const double _leading = AvoSizes.thumbSmall; // D2 44
const double _colorRadius = AvoRadii.imageMedium; // D2 colour square r12
const double _glyphSize = 22; // D2
const double _ringSize = 28; // D2-FuerDich progress ring
const double _ringStroke = 3.5; // D2
const double _doneIcon = 15; // D2 "Alles erledigt" check disc
const double _doneGap = 5; // D2
const double _doneMarkStroke = 2.7; // D2 1.8 on a 16 grid = 2.7 on 24
const double _accessoryGap = AvoSpacing.s;

/// Disclosure chevron (D2: 8 × 14, stroke 2, #C7C7CC, drawn like NavRow).
const Size _chevronSize = Size(8, 14); // D2
const double _chevronStroke = 2; // D2
const double _chevronAlpha = 0.6; // secondaryLabel at 60 % ≈ #C7C7CC

String _join(Iterable<String?> parts) => parts
    .whereType<String>()
    .map((p) => p.trim())
    .where((p) => p.isNotEmpty)
    .join(', ');

/// "8 von 12" for VoiceOver (`common_progress`).
String _progressPhrase(BuildContext context, int done, int total) =>
    context.tr('common_progress', params: {'done': '$done', 'total': '$total'});

/// A D2 list card (Home): a 72 pt cover photo or colour band, a glass chip
/// "mit Lena" on it, the name with a "8/12" counter, a meta line and the
/// progress line.
///
/// The whole card is one button that scales down while pressed
/// ([PressableScale]). VoiceOver reads one sentence: name, meta, "8 von 12",
/// shared label and the label of [badge]. From AX1 the counter moves below
/// the name; the cover chips stop growing at AX2.
class ListCard extends StatelessWidget {
  /// Creates a list card.
  const ListCard({
    super.key,
    required this.title,
    required this.done,
    required this.total,
    this.meta,
    this.cover,
    this.color,
    this.sharedLabel,
    this.sharedName,
    this.badge,
    this.onTap,
  });

  /// The list name, 17/22 semibold; wraps.
  final String title;

  /// Checked items; with [total] the counter and the progress line.
  final int done;

  /// All items. With 0 or less the counter and the progress line are left
  /// out.
  final int total;

  /// Meta line, 15/20 [AvoColors.secondaryLabel] ("12 Artikel · 4 offen ·
  /// vor 2 Std.").
  final String? meta;

  /// The cover photo, laid out at the card width and 72 pt (taller if the
  /// chips need it). Give an `Image` with `BoxFit.cover`. Decorative.
  final Widget? cover;

  /// Fill of the cover band without [cover]: the list colour. Without both
  /// the band is [AvoColors.fill].
  final Color? color;

  /// Text of the glass chip at the top end of the cover ("mit Lena"); null
  /// shows no chip.
  final String? sharedLabel;

  /// Whose initial the chip shows ("Lena"); defaults to no avatar.
  final String? sharedName;

  /// At the top start of the cover (Teil B's `ListOfferCountBadge`). Its
  /// VoiceOver label joins the card's.
  final Widget? badge;

  /// Opens the list. Null shows the card without press feedback.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final ax = context.isAccessibilityText;
    final hasProgress = total > 0;
    final value = hasProgress ? (done / total).clamp(0.0, 1.0) : 0.0;

    final titleText = Text(title, style: context.text(AvoTextStyle.headline));
    final counter = hasProgress
        ? Text(
            '$done/$total',
            style: context.text(
              AvoTextStyle.footnote,
              color: colors.secondaryLabel,
              tabular: true,
            ),
          )
        : null;
    final Widget heading;
    if (counter == null) {
      heading = titleText;
    } else if (ax) {
      heading = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [titleText, counter],
      );
    } else {
      heading = Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Expanded(child: titleText),
          const SizedBox(width: _counterGap),
          counter,
        ],
      );
    }

    final metaText = meta;
    final body = Padding(
      padding: _bodyPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          heading,
          if (metaText != null && metaText.isNotEmpty) ...[
            const SizedBox(height: _metaGap),
            Text(
              metaText,
              style: context.text(
                AvoTextStyle.subhead,
                color: colors.secondaryLabel,
              ),
            ),
          ],
          if (hasProgress) ...[
            const SizedBox(height: _progressGap),
            ProgressLine(value: value),
          ],
        ],
      ),
    );

    final card = DecoratedBox(
      decoration: ShapeDecoration(
        color: colors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AvoRadii.group),
        ),
        shadows: [
          BoxShadow(
            color: colors.shadow.withValues(alpha: _shadowAlpha),
            spreadRadius: _ringSpread,
          ),
          BoxShadow(
            color: colors.shadow.withValues(alpha: _shadowAlpha),
            offset: _dropOffset,
            blurRadius: _dropBlur,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AvoRadii.group),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            _CoverBand(
              cover: cover,
              color: color ?? colors.fill,
              badge: badge,
              chip: sharedLabel == null
                  ? null
                  : _SharedChip(label: sharedLabel!, name: sharedName),
            ),
            ExcludeSemantics(child: body),
          ],
        ),
      ),
    );

    return Semantics(
      container: true,
      button: onTap != null,
      label: _join([
        title,
        meta,
        if (hasProgress) _progressPhrase(context, done, total),
        sharedLabel,
      ]),
      onTap: onTap,
      child: PressableScale(onPressed: onTap, child: card),
    );
  }
}

/// The 72 pt cover with the badge at the top start and the chip at the top
/// end; grows when the chips need more room, never clips them.
class _CoverBand extends StatelessWidget {
  const _CoverBand({
    required this.cover,
    required this.color,
    required this.badge,
    required this.chip,
  });

  final Widget? cover;
  final Color color;
  final Widget? badge;
  final Widget? chip;

  @override
  Widget build(BuildContext context) {
    final b = badge;
    final c = chip;
    Widget? items;
    if (b != null && c != null) {
      items = Wrap(
        alignment: WrapAlignment.spaceBetween,
        spacing: _coverItemGap,
        runSpacing: _coverItemGap,
        children: [b, c],
      );
    } else if (b != null) {
      items = Align(alignment: AlignmentDirectional.topStart, child: b);
    } else if (c != null) {
      items = Align(alignment: AlignmentDirectional.topEnd, child: c);
    }
    return Stack(
      children: [
        Positioned.fill(
          child: ExcludeSemantics(child: cover ?? ColoredBox(color: color)),
        ),
        ConstrainedBox(
          constraints: const BoxConstraints(
            minHeight: _coverHeight,
            minWidth: double.infinity,
          ),
          child: items == null
              ? null
              : Padding(
                  padding: const EdgeInsets.all(_chipInset),
                  child: MediaQuery.withClampedTextScaling(
                    maxScaleFactor: _chipMaxTextScale,
                    child: items,
                  ),
                ),
        ),
      ],
    );
  }
}

/// D2 "mit Lena": pseudo glass on the photo, avatar 20 pt and 12/16
/// semibold text. Its text is part of the card's label.
class _SharedChip extends StatelessWidget {
  const _SharedChip({required this.label, this.name});

  final String label;
  final String? name;

  @override
  Widget build(BuildContext context) {
    final n = name?.trim() ?? '';
    return ExcludeSemantics(
      child: ContentGlass(
        radius: _chipRadius,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: _chipMinHeight),
          child: Padding(
            padding: EdgeInsetsDirectional.fromSTEB(
              n.isEmpty ? _chipEnd : _chipStart,
              _chipVertical,
              _chipEnd,
              _chipVertical,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (n.isNotEmpty) ...[
                  Avatar(name: n, size: AvatarSize.small),
                  const SizedBox(width: _chipGap),
                ],
                Flexible(
                  child: Text(
                    label,
                    style: context.text(
                      AvoTextStyle.caption1,
                      weight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// How a [ListRow] shows its progress.
enum ListRowProgress {
  /// "8/12" in 15/20 [AvoColors.secondaryLabel] (D2-Home).
  counter,

  /// A 28 pt [ProgressRing] (D2-FuerDich "Top-Listen").
  ring,
}

/// A compact list row for the list overview (D2-Home "Andere Listen",
/// D2-FuerDich "Top-Listen"): colour square with a white glyph or a small
/// cover, name, meta line, an [accessory] (avatar stack) and the progress,
/// chevron.
///
/// At least 60 pt high, grows with the text. The accessory and progress
/// move below the text when the row gets narrow and always from AX1; the
/// chevron stays on the first line. One VoiceOver element ("Wocheneinkauf,
/// 4 offen, 8 von 12", then the accessory's and [badge]'s labels). Highlights
/// while pressed, like settings rows. Put rows in an `InsetSection` with
/// `separatorIndent: ListRow.separatorIndent`.
class ListRow extends StatefulWidget {
  /// Creates a list row.
  const ListRow({
    super.key,
    required this.title,
    this.meta,
    this.cover,
    this.color,
    this.glyph,
    this.done,
    this.total,
    this.progress = ListRowProgress.counter,
    this.complete = false,
    this.accessory,
    this.badge,
    this.onTap,
    this.showChevron = true,
    this.semanticActions = const {},
  });

  /// Hairline inset for rows with a leading square: the text edge, 72 pt
  /// (D2 `.sep` left 72).
  static const double separatorIndent = AvoSpacing.l + _leading + _rowGap;

  /// List name, 17/22 semibold; wraps.
  final String title;

  /// Second line, 15/20 [AvoColors.secondaryLabel] ("4 offen · mit Lena").
  final String? meta;

  /// A small cover, laid out at 44 pt and clipped to radius 10 (an
  /// [ItemThumb]). Decorative.
  final Widget? cover;

  /// Colour of the 44 pt square (radius 12) without [cover]: the list
  /// colour. Without both there is no leading square.
  final Color? color;

  /// Symbol on the colour square, 22 pt; draw it in [AvoColors.onTint]
  /// (for example `AvoIcon(AvoIcons.cart, color: colors.onTint)`).
  final Widget? glyph;

  /// Checked items; with [total] the progress.
  final int? done;

  /// All items; null or 0 shows no progress.
  final int? total;

  /// Counter or ring.
  final ListRowProgress progress;

  /// Everything is done: the meta line turns [AvoColors.tint] with a check
  /// disc in front (D2 "Alles erledigt").
  final bool complete;

  /// Before the progress, for example an [AvatarStack]. Its VoiceOver label
  /// joins the row's.
  final Widget? accessory;

  /// Below the meta line (Teil B's `ListOfferCountBadge`). Its label joins
  /// the row's.
  final Widget? badge;

  /// Opens the list. Null shows the row without highlight.
  final VoidCallback? onTap;

  /// The disclosure chevron at the end (off in menus).
  final bool showChevron;

  /// VoiceOver custom actions by label (swipe and menu actions: "Teilen",
  /// "Löschen").
  final Map<String, VoidCallback> semanticActions;

  @override
  State<ListRow> createState() => _ListRowState();
}

class _ListRowState extends State<ListRow> with SingleTickerProviderStateMixin {
  /// 0 = resting, 1 = highlighted. Created eagerly so that dispose is never
  /// its first access.
  late final AnimationController _highlight;

  @override
  void initState() {
    super.initState();
    _highlight = AnimationController.unbounded(vsync: this);
  }

  @override
  void dispose() {
    _highlight.dispose();
    super.dispose();
  }

  void _press() {
    _highlight
      ..stop()
      ..value = 1;
  }

  void _release() {
    if (!mounted) return;
    _highlight.animateWith(
      SpringSimulation(
        AvoMotion.quick,
        _highlight.value,
        0,
        _highlight.velocity,
        snapToEnd: true,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final ax = context.isAccessibilityText;
    final w = widget;
    final total = w.total ?? 0;
    final done = w.done ?? 0;
    final hasProgress = total > 0;

    // ---- leading square
    Widget? leading;
    if (w.cover != null) {
      leading = SizedBox.square(
        dimension: _leading,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AvoRadii.imageSmall),
          child: w.cover,
        ),
      );
    } else if (w.color != null) {
      leading = DecoratedBox(
        decoration: ShapeDecoration(
          color: w.color,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(_colorRadius),
          ),
        ),
        child: SizedBox.square(
          dimension: _leading,
          child: w.glyph == null
              ? null
              : Center(
                  child: IconStyleScope(
                    size: _glyphSize,
                    color: colors.onTint,
                    child: SizedBox.square(
                      dimension: _glyphSize,
                      child: FittedBox(child: w.glyph),
                    ),
                  ),
                ),
        ),
      );
    }

    // ---- text
    final meta = w.meta;
    final metaStyle = context.text(
      AvoTextStyle.subhead,
      color: w.complete ? colors.tint : colors.secondaryLabel,
    );
    Widget? metaLine;
    if (meta != null && meta.isNotEmpty) {
      final metaText = Text(meta, style: metaStyle);
      metaLine = w.complete
          ? Row(
              children: [
                const _DoneDisc(),
                const SizedBox(width: _doneGap),
                Flexible(child: metaText),
              ],
            )
          : metaText;
    }
    final text = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        ExcludeSemantics(
          child: Text(w.title, style: context.text(AvoTextStyle.headline)),
        ),
        if (metaLine != null) ExcludeSemantics(child: metaLine),
        ?w.badge,
      ],
    );

    // ---- accessory and progress
    Widget? progressView;
    if (hasProgress) {
      progressView = ExcludeSemantics(
        child: w.progress == ListRowProgress.ring
            ? ProgressRing(
                value: done / total,
                size: _ringSize,
                strokeWidth: _ringStroke,
              )
            : Text(
                '$done/$total',
                style: context.text(
                  AvoTextStyle.subhead,
                  color: colors.secondaryLabel,
                  tabular: true,
                ),
              ),
      );
    }
    Widget? trailing;
    final accessory = w.accessory;
    if (accessory != null && progressView != null) {
      trailing = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          accessory,
          const SizedBox(width: _accessoryGap),
          progressView,
        ],
      );
    } else {
      trailing = accessory ?? progressView;
    }

    final chevron = w.showChevron
        ? Padding(
            padding: const EdgeInsetsDirectional.only(start: _rowGap),
            child: ax
                ? SizedBox(
                    height: context.typography.lineHeightOf(
                      AvoTextStyle.headline,
                    ),
                    child: const Center(widthFactor: 1, child: _Chevron()),
                  )
                : const _Chevron(),
          )
        : null;

    final row = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: _rowMinHeight),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AvoSpacing.l,
          vertical: _rowVertical,
        ),
        child: Row(
          crossAxisAlignment: ax
              ? CrossAxisAlignment.start
              : CrossAxisAlignment.center,
          children: [
            if (leading != null) ...[
              ExcludeSemantics(child: leading),
              const SizedBox(width: _rowGap),
            ],
            Expanded(
              child: AdaptiveTrailing(
                gap: _rowGap,
                stacked: ax,
                trailing: trailing,
                child: text,
              ),
            ),
            ?chevron,
          ],
        ),
      ),
    );

    final onTap = w.onTap;
    final fill = colors.fillStrong;
    final Widget interactive = onTap == null
        ? row
        : GestureDetector(
            behavior: HitTestBehavior.opaque,
            excludeFromSemantics: true,
            onTapDown: (_) => _press(),
            onTapUp: (_) => _release(),
            onTapCancel: _release,
            onTap: onTap,
            child: AnimatedBuilder(
              animation: _highlight,
              child: row,
              builder: (context, child) {
                final t = _highlight.value.clamp(0.0, 1.0);
                if (t == 0) return child!;
                return ColoredBox(
                  color: fill.withValues(alpha: fill.a * t),
                  child: child,
                );
              },
            ),
          );

    final actions = <CustomSemanticsAction, VoidCallback>{
      for (final entry in w.semanticActions.entries)
        CustomSemanticsAction(label: entry.key): entry.value,
    };
    return Semantics(
      container: true,
      button: onTap != null,
      label: _join([
        w.title,
        meta,
        if (hasProgress) _progressPhrase(context, done, total),
      ]),
      onTap: onTap,
      customSemanticsActions: actions.isEmpty ? null : actions,
      child: interactive,
    );
  }
}

/// D2 "Alles erledigt": a 15 pt tint disc with a white check.
class _DoneDisc extends StatelessWidget {
  const _DoneDisc();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return DecoratedBox(
      decoration: ShapeDecoration(
        color: colors.tintFill,
        shape: const CircleBorder(),
      ),
      child: SizedBox.square(
        dimension: _doneIcon,
        child: AvoIcon(
          AvoIcons.check,
          size: _doneIcon,
          strokeWidth: _doneMarkStroke,
          color: colors.onTint,
        ),
      ),
    );
  }
}

/// The disclosure chevron, drawn like D2's SVG and mirrored in RTL.
class _Chevron extends StatelessWidget {
  const _Chevron();

  @override
  Widget build(BuildContext context) {
    final color = context.colors.secondaryLabel.withValues(
      alpha: _chevronAlpha,
    );
    final rtl = Directionality.maybeOf(context) == TextDirection.rtl;
    return ExcludeSemantics(
      child: Transform.flip(
        flipX: rtl,
        child: CustomPaint(size: _chevronSize, painter: _ChevronPainter(color)),
      ),
    );
  }
}

class _ChevronPainter extends CustomPainter {
  const _ChevronPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    // D2 path "M1.5 1.5 6.5 7l-5 5.5" in an 8 × 14 box.
    final sx = size.width / _chevronSize.width;
    final sy = size.height / _chevronSize.height;
    final path = Path()
      ..moveTo(1.5 * sx, 1.5 * sy)
      ..lineTo(6.5 * sx, 7 * sy)
      ..lineTo(1.5 * sx, 12.5 * sy);
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = _chevronStroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_ChevronPainter old) => old.color != color;
}
