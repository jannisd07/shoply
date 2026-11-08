import 'package:flutter/widgets.dart';

import 'package:shoply/core/design/design.dart';
import 'package:shoply/core/localization/localization_helper.dart';
import 'package:shoply/presentation/widgets/design/app_button.dart';
import 'package:shoply/presentation/widgets/design/avo_figure.dart';
import 'package:shoply/presentation/widgets/design/avo_icons.dart';
import 'package:shoply/presentation/widgets/design/glass_surface.dart';
import 'package:shoply/presentation/widgets/design/pro_badge.dart';

// ------------------------------------------------------------ recipe card

/// Photo aspect ratio of grid tiles and rail cards (D2 `aspect-ratio: 4 / 3`,
/// rail 148 × 111).
const double _kPhotoAspect = 4 / 3; // D2

/// Grid tile: 8 above the title, 2 above the meta line (D2-Rezepte).
const double _kGridTitleGap = AvoSpacing.s; // D2
const double _kGridMetaGap = AvoSpacing.xxs; // D2

/// Gap between the meta line and the [RecipeCard.badge] slot (no D2 value).
const double _kBadgeGap = AvoSpacing.xs;

/// Gap between the title and the [ProBadge].
const double _kProGap = AvoSpacing.s;

/// Rail card (D2-Komponenten "Rezeptkarte"): 148 wide, photo 148 × 111,
/// text padding 8 10 10.
const double _kRailWidth = 148; // D2
const EdgeInsets _kRailPadding = EdgeInsets.fromLTRB(10, 8, 10, 10); // D2

/// Rail card shadow: `0 0 0 .5px rgba(0,0,0,.07), 0 6px 18px rgba(0,0,0,.07)`.
const double _kRailRingSpread = 0.5; // D2
const double _kRailShadowAlpha = 0.07; // D2
const Offset _kRailDropOffset = Offset(0, 6); // D2
const double _kRailDropBlur = 18; // D2

/// Visual form of a [RecipeCard].
enum RecipeCardStyle {
  /// D2-Rezepte grid tile: photo 4:3 with radius 20, below it the title
  /// (17/22 semibold, up to two lines) and the meta line, no card surface.
  /// Takes the width of its grid column.
  grid,

  /// D2-Komponenten rail card for horizontal rows: a white card 148 pt wide
  /// with radius 20 and a soft shadow, photo 148 × 111, one-line title.
  rail,
}

/// A recipe as a grid tile or a rail card (Konzept 00 §12.13, optics D2).
///
/// Model-free: photo, texts and callbacks come from the screen. The photo
/// fills a 4:3 box (pass an image with `BoxFit.cover`); until it loads the
/// box shows [placeholderColor] (`photo_color`). With [onTap] the whole card
/// is one button that shrinks while pressed. VoiceOver reads one element:
/// title, "Pro feature" when [pro] is set, and the meta line, then anything
/// [badge] says.
///
/// Large text: the title keeps its line limit (2 in the grid, 1 in the rail)
/// up to xxxL; from AX1 on it shows in full and the [ProBadge] moves below
/// it. Screens switch rails and two-column grids to one column from AX1
/// (Konzept 13 §2.7); the card itself never clips its text.
class RecipeCard extends StatelessWidget {
  /// Creates a recipe card.
  const RecipeCard({
    super.key,
    required this.image,
    required this.title,
    this.meta,
    this.style = RecipeCardStyle.grid,
    this.pro = false,
    this.badge,
    this.onTap,
    this.placeholderColor,
    this.semanticLabel,
  });

  /// The photo, laid out to fill the 4:3 box. Decorative for VoiceOver.
  final Widget image;

  /// Recipe name ("Ofengemüse mit Halloumi").
  final String title;

  /// Meta line in tabular figures ("35 Min · ★ 4,6"); kcal only with the
  /// calories module (the screen builds the string).
  final String? meta;

  /// [RecipeCardStyle.grid] (default) or [RecipeCardStyle.rail].
  final RecipeCardStyle style;

  /// Shows a [ProBadge] after the title (below it from AX1 on).
  final bool pro;

  /// Optional line below the meta line: "Für dich angepasst", an allergen
  /// warning, or a slot of Teil B. Its semantics are appended to the card's.
  final Widget? badge;

  /// Opens the recipe. Null makes the card plain content.
  final VoidCallback? onTap;

  /// Fill behind the photo while it loads (`photo_color`); defaults to
  /// [AvoColors.fill].
  final Color? placeholderColor;

  /// Replaces the spoken summary, for example "Avocado-Pasta, 15 Minuten,
  /// Bewertung 4,5" instead of the visible "15 Min · ★ 4,5".
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final rail = style == RecipeCardStyle.rail;
    final ax = context.isAccessibilityText;
    final placeholder = placeholderColor ?? colors.fill;
    final metaText = meta;
    final extra = badge;

    final titleStyle = context.text(AvoTextStyle.headline);
    final titleLines = ax ? null : (rail ? 1 : 2);
    final titleText = Text(
      title,
      style: titleStyle,
      maxLines: titleLines,
      overflow: titleLines == null ? null : TextOverflow.ellipsis,
    );
    final Widget titleBlock;
    if (!pro) {
      titleBlock = titleText;
    } else if (ax) {
      titleBlock = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          titleText,
          const SizedBox(height: _kBadgeGap),
          const ProBadge(),
        ],
      );
    } else {
      titleBlock = Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Flexible(child: titleText),
          const SizedBox(width: _kProGap),
          const ProBadge(),
        ],
      );
    }

    final photo = ColoredBox(
      color: placeholder,
      child: SizedBox.expand(child: image),
    );

    final text = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        ExcludeSemantics(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              titleBlock,
              if (metaText != null)
                Padding(
                  padding: EdgeInsets.only(top: rail ? 0 : _kGridMetaGap),
                  child: Text(
                    metaText,
                    style: context.text(
                      AvoTextStyle.footnote,
                      color: colors.secondaryLabel,
                      tabular: true,
                    ),
                  ),
                ),
            ],
          ),
        ),
        if (extra != null)
          Padding(
            padding: const EdgeInsets.only(top: _kBadgeGap),
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: extra,
            ),
          ),
      ],
    );

    Widget card;
    if (rail) {
      card = SizedBox(
        width: _kRailWidth,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(AvoRadii.card),
            boxShadow: [
              BoxShadow(
                color: colors.shadow.withValues(alpha: _kRailShadowAlpha),
                spreadRadius: _kRailRingSpread,
              ),
              BoxShadow(
                color: colors.shadow.withValues(alpha: _kRailShadowAlpha),
                offset: _kRailDropOffset,
                blurRadius: _kRailDropBlur,
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AvoRadii.card),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                ExcludeSemantics(
                  child: AspectRatio(aspectRatio: _kPhotoAspect, child: photo),
                ),
                Padding(padding: _kRailPadding, child: text),
              ],
            ),
          ),
        ),
      );
    } else {
      card = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          ExcludeSemantics(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AvoRadii.card),
              child: AspectRatio(aspectRatio: _kPhotoAspect, child: photo),
            ),
          ),
          const SizedBox(height: _kGridTitleGap),
          text,
        ],
      );
    }

    final tap = onTap;
    if (tap != null) card = PressableScale(onPressed: tap, child: card);

    return Semantics(
      container: true,
      button: tap != null,
      label:
          semanticLabel ??
          _joinLabel([
            title,
            if (pro) context.tr('common_pro_feature'),
            metaText,
          ]),
      onTap: tap,
      child: card,
    );
  }
}

// ------------------------------------------------------------- hero card

/// Inset of the chip and the info panel from the photo edge (D2 12).
const double _kHeroInset = AvoSpacing.m; // D2

/// Minimum heights: D2-Rezepte hero 248, D2-Komponenten hero 270.
const double _kHeroBrowseHeight = 248; // D2
const double _kHeroFeatureHeight = 270; // D2

/// Info panel padding: D2-Rezepte `12 14 12 16`, D2-Komponenten `14 16 16`.
const EdgeInsetsDirectional _kPanelRegularPadding =
    EdgeInsetsDirectional.fromSTEB(16, 12, 14, 12); // D2
const EdgeInsetsDirectional _kPanelLargePadding =
    EdgeInsetsDirectional.fromSTEB(16, 14, 16, 16); // D2

/// Eyebrow "Passt zu deiner Liste": 11/13 semibold, upper case, +0.4.
const double _kEyebrowTracking = 0.4; // D2
const double _kEyebrowGap = AvoSpacing.xxs; // D2 title margin-top 2

/// D2-Komponenten meta line sits 2 below the 22/28 title.
const double _kLargeMetaGap = AvoSpacing.xxs; // D2

/// Compact action (D2-Rezepte): 6 below the meta, a 36 pt `.glass-tint`
/// capsule (padding 0 16 0 12, 16 pt plus) centred in a 44 pt target.
const double _kCompactActionGap = 6; // D2
const double _kCompactCapsuleHeight = 36; // D2
const double _kCompactIcon = 16; // D2
const double _kCompactIconStart = AvoSpacing.m; // D2 12
const double _kCompactSide = AvoSpacing.l; // D2 16
const double _kCompactVertical = 8; // D2 (36 − 20) / 2

/// Full-width action: 44 pt, 18 pt plus; 12 below the meta in
/// D2-Komponenten, 10 in D2-FuerDich "Heute kochen".
const double _kExpandedIcon = 18; // D2
const double _kExpandedGapLarge = AvoSpacing.m; // D2
const double _kExpandedGapRegular = 10; // D2

/// Plus glyph of the action: stroke 2.6, 6 before the label.
const double _kActionStroke = 2.6; // D2
const double _kActionIconGap = 6; // D2

/// Konzept 00 §12.20.
const double _kDisabledOpacity = 0.4;

/// Hero chip "4 von 6 Zutaten da": `.glass` capsule 32 high, padding 0 12 0 6,
/// gap 6, the figure 22 × 27 in a 22 × 28 box, 13/18 semibold.
const double _kChipMinHeight = 32; // D2
const double _kChipRadius = 16; // D2
const double _kChipFigure = 28; // D2
const double _kChipStart = 6; // D2
const double _kChipEnd = AvoSpacing.m; // D2 12
const double _kChipGap = 6; // D2
const double _kChipVertical = 7; // D2 (32 − 18) / 2

/// [AvoFigure] fits the art into a square: a 28 pt figure is about 22 wide,
/// so 3 pt of its box are empty on each side.
const double _kChipFigureSlack = 3;

/// Title size and action form of a [RecipeHeroCard].
enum RecipeHeroStyle {
  /// D2-Rezepte: title 20/25 semibold, panel padding 12 14 12 16, a compact
  /// capsule action that hugs its label; at least 248 pt high.
  regular,

  /// D2-Komponenten: title 22/28 bold, panel padding 14 16 16, a full-width
  /// 44 pt action; at least 270 pt high.
  large,
}

/// The info panel on a photo (D2 hero `.glass`, radius 20): [ContentGlass]
/// with the D2 padding, for recipe heroes and other photos in scrolling
/// content.
///
/// It takes the width its parent gives (stretch it in a column) and grows
/// with its content. Text on it uses [AvoColors.label] and, for meta text,
/// [AvoColors.tertiaryLabel].
class GlassInfoPanel extends StatelessWidget {
  /// Creates an info panel around [child].
  const GlassInfoPanel({
    super.key,
    required this.child,
    this.padding = GlassInfoPanel.regularPadding,
  });

  /// D2-Rezepte: 12 top and bottom, 16 start, 14 end.
  static const EdgeInsetsGeometry regularPadding = _kPanelRegularPadding;

  /// D2-Komponenten: 14 top, 16 at the sides and the bottom.
  static const EdgeInsetsGeometry largePadding = _kPanelLargePadding;

  /// The content, usually a column of texts and one action.
  final Widget child;

  /// Space between the glass edge and [child]; see [regularPadding] and
  /// [largePadding].
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) =>
      ContentGlass(radius: AvoRadii.card, padding: padding, child: child);
}

/// The big recipe photo with a glass info panel (D2-Rezepte hero,
/// D2-Komponenten "Hero", D2-FuerDich "Heute kochen").
///
/// The photo fills the card (radius 26; pass an image with `BoxFit.cover`).
/// At the bottom, 12 pt in, sits a [GlassInfoPanel] with an optional
/// [eyebrow] in tinted capitals, the [title], the [meta] line and one main
/// action as a tinted capsule. An optional glass chip with a small
/// [AvoFigure] sits in the top corner.
///
/// The card is at least [minHeight] tall. With large text the panel grows
/// upwards over the photo, and once chip and panel need more room the card
/// grows instead of clipping. Give it a bounded width and an unbounded (or
/// loose) height, as a scrolling column does.
///
/// With [onTap] the whole card opens the recipe and shrinks while pressed;
/// pressing the action does not press the card. VoiceOver reads the card as
/// one element (title, eyebrow, meta, chip) and the action as its own button.
class RecipeHeroCard extends StatefulWidget {
  /// Creates a hero card.
  const RecipeHeroCard({
    super.key,
    required this.image,
    required this.title,
    this.eyebrow,
    this.meta,
    this.actionLabel,
    this.actionIcon = AvoIcons.plus,
    this.onAction,
    this.expandAction,
    this.chipLabel,
    this.chipPose = AvoPose.excited,
    this.style = RecipeHeroStyle.regular,
    this.minHeight,
    this.onTap,
    this.placeholderColor,
    this.semanticLabel,
  });

  /// D2-Rezepte minimum height.
  static const double browseHeight = _kHeroBrowseHeight;

  /// D2-Komponenten minimum height.
  static const double featureHeight = _kHeroFeatureHeight;

  /// The photo, laid out to fill the card. Decorative for VoiceOver.
  final Widget image;

  /// Recipe name ("Shakshuka mit Feta").
  final String title;

  /// Small line above the title in normal spelling ("Passt zu deiner
  /// Liste"); shown in capitals, read as given.
  final String? eyebrow;

  /// Meta line in tabular figures ("25 Min · ★ 4,8 (126) · vegetarisch").
  final String? meta;

  /// Label of the one main action ("Zutaten auf die Liste"). Null hides it.
  final String? actionLabel;

  /// Glyph before [actionLabel], drawn in [AvoColors.onTint]; null for none.
  /// Left out from AX1 on (decorative), so the label keeps the full width.
  final AvoIconData? actionIcon;

  /// Runs the action. Null shows it disabled (40 %).
  final VoidCallback? onAction;

  /// True: the action fills the panel width (44 pt, D2-Komponenten and
  /// "Heute kochen"); false: a compact capsule that hugs its label
  /// (D2-Rezepte). Defaults to true for [RecipeHeroStyle.large].
  final bool? expandAction;

  /// Text of the glass chip in the top corner ("4 von 6 Zutaten da"). Null
  /// hides the chip.
  final String? chipLabel;

  /// Small figure in the chip; null shows the text only. Mind the figure
  /// rules of [AvoFigure] (one per screen height, never next to warnings).
  final AvoPose? chipPose;

  /// [RecipeHeroStyle.regular] (default) or [RecipeHeroStyle.large].
  final RecipeHeroStyle style;

  /// Minimum card height; defaults to [browseHeight] (regular) or
  /// [featureHeight] (large). "Heute kochen" uses 220.
  final double? minHeight;

  /// Opens the recipe. Null makes the photo inert.
  final VoidCallback? onTap;

  /// Fill behind the photo while it loads (`photo_color`); defaults to
  /// [AvoColors.fill].
  final Color? placeholderColor;

  /// Replaces the spoken summary of the card (not of the action).
  final String? semanticLabel;

  @override
  State<RecipeHeroCard> createState() => _RecipeHeroCardState();
}

class _RecipeHeroCardState extends State<RecipeHeroCard> {
  /// Fingers currently down on the action. While any is, the card itself
  /// does not react, so pressing the action never shrinks the whole card.
  int _actionPointers = 0;

  void _actionDown(PointerDownEvent event) => setState(() => _actionPointers++);

  void _actionUp(PointerEvent event) {
    if (_actionPointers > 0) setState(() => _actionPointers--);
  }

  @override
  Widget build(BuildContext context) {
    final w = widget;
    final colors = context.colors;
    final large = w.style == RecipeHeroStyle.large;
    final expand = w.expandAction ?? large;
    final eyebrow = w.eyebrow;
    final meta = w.meta;
    final chipLabel = w.chipLabel;
    final label = w.actionLabel;
    final tap = w.onTap;
    // The plus is decorative: from AX1 on it gives its width to the label,
    // which would otherwise break inside words on narrow screens.
    final actionIcon = context.isAccessibilityText ? null : w.actionIcon;

    final texts = ExcludeSemantics(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (eyebrow != null)
            Text(
              _localeUpperCase(eyebrow, Localizations.maybeLocaleOf(context)),
              style: context
                  .text(
                    AvoTextStyle.caption2,
                    color: colors.tint,
                    weight: FontWeight.w600,
                  )
                  .copyWith(letterSpacing: _kEyebrowTracking),
            ),
          Padding(
            padding: EdgeInsets.only(top: eyebrow != null ? _kEyebrowGap : 0),
            child: Text(
              w.title,
              style: context.text(
                large ? AvoTextStyle.title2 : AvoTextStyle.title3,
              ),
            ),
          ),
          if (meta != null)
            Padding(
              padding: EdgeInsets.only(top: large ? _kLargeMetaGap : 0),
              child: Text(
                meta,
                style: context.text(
                  AvoTextStyle.footnote,
                  color: colors.tertiaryLabel,
                  tabular: true,
                ),
              ),
            ),
        ],
      ),
    );

    Widget? action;
    if (label != null) {
      final Widget button;
      final double gap;
      if (expand) {
        final icon = actionIcon;
        button = AppButton.primary(
          label: label,
          icon: icon == null
              ? null
              : AvoIcon(
                  icon,
                  size: _kExpandedIcon * _iconScale(context),
                  color: colors.onTint,
                  strokeWidth: _kActionStroke,
                ),
          onPressed: w.onAction,
          expand: true,
        );
        gap = large ? _kExpandedGapLarge : _kExpandedGapRegular;
      } else {
        button = Align(
          alignment: AlignmentDirectional.centerStart,
          child: _CompactAction(
            label: label,
            icon: actionIcon,
            onPressed: w.onAction,
          ),
        );
        gap = _kCompactActionGap;
      }
      action = Padding(
        padding: EdgeInsets.only(top: gap),
        child: Listener(
          onPointerDown: _actionDown,
          onPointerUp: _actionUp,
          onPointerCancel: _actionUp,
          child: button,
        ),
      );
    }

    final panel = GlassInfoPanel(
      padding: large
          ? GlassInfoPanel.largePadding
          : GlassInfoPanel.regularPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [texts, ?action],
      ),
    );

    // The column is exactly max(minHeight, content): IntrinsicHeight keeps
    // it from filling a loose parent, spaceBetween pins the chip to the top
    // and the panel to the bottom.
    final content = ConstrainedBox(
      constraints: BoxConstraints(
        minHeight:
            w.minHeight ?? (large ? _kHeroFeatureHeight : _kHeroBrowseHeight),
      ),
      child: IntrinsicHeight(
        child: Padding(
          padding: const EdgeInsets.all(_kHeroInset),
          child: Column(
            mainAxisAlignment: chipLabel != null
                ? MainAxisAlignment.spaceBetween
                : MainAxisAlignment.end,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (chipLabel != null) ...[
                Align(
                  alignment: AlignmentDirectional.topStart,
                  child: ExcludeSemantics(
                    child: _HeroChip(label: chipLabel, pose: w.chipPose),
                  ),
                ),
                const SizedBox(height: _kHeroInset),
              ],
              panel,
            ],
          ),
        ),
      ),
    );

    Widget card = ClipRRect(
      borderRadius: BorderRadius.circular(AvoRadii.group),
      child: Stack(
        children: [
          Positioned.fill(
            child: ExcludeSemantics(
              child: ColoredBox(
                color: w.placeholderColor ?? colors.fill,
                child: SizedBox.expand(child: w.image),
              ),
            ),
          ),
          content,
        ],
      ),
    );

    if (tap != null) {
      card = PressableScale(
        onPressed: tap,
        enabled: _actionPointers == 0,
        child: card,
      );
    }

    return Semantics(
      container: true,
      button: tap != null,
      label: w.semanticLabel ?? _joinLabel([w.title, eyebrow, meta, chipLabel]),
      onTap: tap,
      child: card,
    );
  }
}

/// The D2-Rezepte action: a 36 pt tinted capsule hugging its label, inside a
/// 44 pt high target.
class _CompactAction extends StatelessWidget {
  const _CompactAction({
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  final String label;
  final AvoIconData? icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final enabled = onPressed != null;
    final glyph = icon;
    final capsule = ContentGlass(
      tinted: true,
      radius: AvoRadii.capsule(_kCompactCapsuleHeight),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: _kCompactCapsuleHeight),
        child: Padding(
          padding: EdgeInsetsDirectional.fromSTEB(
            glyph != null ? _kCompactIconStart : _kCompactSide,
            _kCompactVertical,
            _kCompactSide,
            _kCompactVertical,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (glyph != null) ...[
                AvoIcon(
                  glyph,
                  size: _kCompactIcon * _iconScale(context),
                  color: colors.onTint,
                  strokeWidth: _kActionStroke,
                ),
                const SizedBox(width: _kActionIconGap),
              ],
              Flexible(
                child: Text(
                  label,
                  style: context.text(
                    AvoTextStyle.subhead,
                    color: colors.onTint,
                    weight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    Widget target = ConstrainedBox(
      constraints: const BoxConstraints(
        minHeight: AvoSizes.hitTarget,
        minWidth: AvoSizes.hitTarget,
      ),
      child: Align(
        alignment: AlignmentDirectional.centerStart,
        widthFactor: 1,
        child: capsule,
      ),
    );
    if (!enabled) target = Opacity(opacity: _kDisabledOpacity, child: target);

    return Semantics(
      container: true,
      button: true,
      enabled: enabled,
      label: label,
      onTap: onPressed,
      excludeSemantics: true,
      child: PressableScale(onPressed: onPressed, child: target),
    );
  }
}

/// The glass chip in the top corner of the hero.
class _HeroChip extends StatelessWidget {
  const _HeroChip({required this.label, required this.pose});

  final String label;
  final AvoPose? pose;

  @override
  Widget build(BuildContext context) {
    final figure = pose;
    return ContentGlass(
      radius: _kChipRadius,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: _kChipMinHeight),
        child: Padding(
          padding: EdgeInsetsDirectional.fromSTEB(
            figure != null ? _kChipStart - _kChipFigureSlack : _kChipEnd,
            0,
            _kChipEnd,
            0,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (figure != null) ...[
                AvoFigure(pose: figure, size: _kChipFigure),
                const SizedBox(width: _kChipGap - _kChipFigureSlack),
              ],
              // Only the text is padded: the 28 pt figure fits the 32 pt
              // capsule as in D2.
              Flexible(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: _kChipVertical),
                  child: Text(
                    label,
                    style: context.text(
                      AvoTextStyle.footnote,
                      weight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- helpers

/// Icons next to text follow Dynamic Type like SF Symbols (as in AppButton).
double _iconScale(BuildContext context) =>
    context.typography.sizeOf(AvoTextStyle.subhead) /
    AvoTypography.forFactor(1).sizeOf(AvoTextStyle.subhead);

String _joinLabel(List<String?> parts) =>
    parts.whereType<String>().where((p) => p.isNotEmpty).join(', ');

/// Upper-cases [text] for display without breaking German or Turkish (same
/// rule as `SectionCaps`): "ß" becomes "SS", Turkish "i" becomes "İ".
String _localeUpperCase(String text, Locale? locale) {
  var source = text;
  final language = locale?.languageCode;
  if (language == 'tr' || language == 'az') {
    source = source.replaceAll('i', 'İ');
  }
  return source.toUpperCase().replaceAll('ß', 'SS');
}
