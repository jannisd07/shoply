import 'package:flutter/widgets.dart';

import 'package:shoply/core/design/design.dart';
import 'package:shoply/presentation/widgets/design/app_button.dart';

/// Soft card shadow (D2 `.card`: 0 1px 2px rgba(0,0,0,.04)).
const double _kShadowAlpha = 0.04; // D2
const double _kShadowBlur = 2; // D2
const Offset _kShadowOffset = Offset(0, 1); // D2

/// Shortcut tiles on Home (D2 `.wtile`: height 148, radius 22, padding 14).
const double _kTileMinHeight = 148; // D2
const double _kTileRadius = 22; // D2
const double _kTilePadding = 14; // D2

/// Icon square of a tile (D2 `.wicon`: 32 pt, radius 9).
const double _kTileIcon = 32; // D2
const double _kTileIconRadius = 9; // D2

/// Gap between two tiles in the grid (D2: 12).
const double _kTileGap = AvoSpacing.m;

/// Background of an [AvoCard].
enum AvoCardTone {
  /// Plain surface (D2 `.card`).
  plain,

  /// Green wash from the top left (D2 Avo card and "Dein November").
  tint,
}

/// The white card of D2 Home: radius 26, a faint shadow, 16 pt padding by
/// default. Teil A and Teil B build their Home sections in it.
///
/// The card takes its height from its content. With [onTap] the whole card
/// is one button (pressed scale), and [semanticLabel] replaces the text of
/// the content for VoiceOver.
class AvoCard extends StatelessWidget {
  /// Creates a card around [child].
  const AvoCard({
    super.key,
    required this.child,
    this.tone = AvoCardTone.plain,
    this.padding = const EdgeInsets.all(AvoSpacing.l),
    this.onTap,
    this.semanticLabel,
    this.clip = false,
  });

  /// The content.
  final Widget child;

  /// Plain or green wash.
  final AvoCardTone tone;

  /// Space between the edge and [child].
  final EdgeInsetsGeometry padding;

  /// Makes the whole card a button.
  final VoidCallback? onTap;

  /// VoiceOver label for a tappable card.
  final String? semanticLabel;

  /// Clips [child] to the rounded outline (for rows or photos that touch the
  /// edge).
  final bool clip;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final radius = BorderRadius.circular(AvoRadii.group);
    final decoration = BoxDecoration(
      color: colors.surface,
      gradient: tone == AvoCardTone.tint
          ? LinearGradient(
              // D2: linear-gradient(160deg, #E4F4E7, #F4FAF5 55%, #FFF).
              begin: const Alignment(-0.35, -1),
              end: const Alignment(0.35, 1),
              colors: [
                colors.tintSoft,
                Color.lerp(colors.tintSoft, colors.surface, 0.6)!,
                colors.surface,
              ],
              stops: const [0, 0.55, 1],
            )
          : null,
      borderRadius: radius,
      boxShadow: [
        BoxShadow(
          color: colors.shadow.withValues(alpha: _kShadowAlpha),
          offset: _kShadowOffset,
          blurRadius: _kShadowBlur,
        ),
      ],
    );

    Widget card = DecoratedBox(
      decoration: decoration,
      child: Padding(padding: padding, child: child),
    );
    if (clip) card = ClipRRect(borderRadius: radius, child: card);
    if (onTap == null) return card;

    return Semantics(
      button: true,
      label: semanticLabel,
      excludeSemantics: semanticLabel != null,
      onTap: onTap,
      child: PressableScale(onPressed: onTap, child: card),
    );
  }
}

/// A shortcut tile of the Home grid "Für dich" (D2 `.wtile`): an icon square
/// at the top, a small grey title and the value at the bottom.
///
/// At least 148 pt tall, taller when the text needs it. [trailing] sits top
/// right (for example a tinted plus button with its own 44 pt target).
class AvoTile extends StatelessWidget {
  /// Creates a tile.
  const AvoTile({
    super.key,
    required this.title,
    required this.child,
    this.icon,
    this.iconBackground,
    this.trailing,
    this.onTap,
    this.semanticLabel,
  });

  /// Small grey title above the value ("Weiter einkaufen").
  final String title;

  /// The value block below [title].
  final Widget child;

  /// Glyph inside the icon square; no square without it.
  final Widget? icon;

  /// Colour of the icon square; [AvoColors.tintSoft] by default.
  final Color? iconBackground;

  /// Action top right.
  final Widget? trailing;

  /// Makes the tile a button.
  final VoidCallback? onTap;

  /// VoiceOver label of the tappable tile; built from the texts otherwise.
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final top = (icon != null || trailing != null)
        ? Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (icon != null)
                ExcludeSemantics(
                  child: Container(
                    width: _kTileIcon,
                    height: _kTileIcon,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: iconBackground ?? colors.tintSoft,
                      borderRadius: BorderRadius.circular(_kTileIconRadius),
                    ),
                    child: icon,
                  ),
                ),
              const Spacer(),
              if (trailing != null) trailing!,
            ],
          )
        : null;

    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title,
          style: context.text(
            AvoTextStyle.footnote,
            color: colors.secondaryLabel,
            weight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: AvoSpacing.xxs),
        child,
      ],
    );

    Widget tile = DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(_kTileRadius),
        boxShadow: [
          BoxShadow(
            color: colors.shadow.withValues(alpha: _kShadowAlpha),
            offset: _kShadowOffset,
            blurRadius: _kShadowBlur,
          ),
        ],
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: _kTileMinHeight),
        child: Padding(
          padding: const EdgeInsets.all(_kTilePadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (top != null) top,
              if (top != null) const SizedBox(height: AvoSpacing.s),
              body,
            ],
          ),
        ),
      ),
    );

    if (onTap == null) return tile;
    return Semantics(
      button: true,
      label: semanticLabel,
      excludeSemantics: semanticLabel != null,
      onTap: onTap,
      child: PressableScale(onPressed: onTap, child: tile),
    );
  }
}

/// Lays [AvoTile]s out two per row (D2 grid, gap 12), the tiles of a row as
/// tall as the tallest. From AX1 on one tile per row.
class AvoTileGrid extends StatelessWidget {
  /// Creates the grid.
  const AvoTileGrid({super.key, required this.children});

  /// The tiles; an odd last tile takes half the width.
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty) return const SizedBox.shrink();
    if (context.isAccessibilityText) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const SizedBox(height: _kTileGap),
            children[i],
          ],
        ],
      );
    }
    final rows = <Widget>[];
    for (var i = 0; i < children.length; i += 2) {
      final second = i + 1 < children.length ? children[i + 1] : null;
      rows.add(IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: children[i]),
            const SizedBox(width: _kTileGap),
            Expanded(child: second ?? const SizedBox.shrink()),
          ],
        ),
      ));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < rows.length; i++) ...[
          if (i > 0) const SizedBox(height: _kTileGap),
          rows[i],
        ],
      ],
    );
  }
}

/// Heading of a Home section (D2 `.sec-h`): title 20/25 semibold, an
/// optional text action on the right ("Alle", "Alle anzeigen") with a 44 pt
/// target. From AX1 on the action moves below the title.
class AvoSectionHeader extends StatelessWidget {
  /// Creates a heading.
  const AvoSectionHeader(
    this.title, {
    super.key,
    this.actionLabel,
    this.onAction,
    this.padding = const EdgeInsets.symmetric(horizontal: AvoSpacing.screen),
  });

  /// The heading text.
  final String title;

  /// Text of the action; no action without it.
  final String? actionLabel;

  /// Called when the action is tapped.
  final VoidCallback? onAction;

  /// Outer padding; 16 pt left and right by default.
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final heading = Semantics(
      header: true,
      child: Text(title, style: context.text(AvoTextStyle.title3)),
    );
    final label = actionLabel;
    if (label == null) return Padding(padding: padding, child: heading);

    final action = _HeaderAction(label: label, onPressed: onAction);
    if (context.isAccessibilityText) {
      return Padding(
        padding: padding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [heading, action],
        ),
      );
    }
    return Padding(
      padding: padding,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(child: heading),
          const SizedBox(width: AvoSpacing.s),
          action,
        ],
      ),
    );
  }
}

/// The text action of [AvoSectionHeader]: 15/20 in tint (D2 `.sec-h a`),
/// at least 44 pt tall.
class _HeaderAction extends StatelessWidget {
  const _HeaderAction({required this.label, required this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: onPressed != null,
      onTap: onPressed,
      child: PressableScale(
        onPressed: onPressed,
        enabled: onPressed != null,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: AvoSizes.hitTarget),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AvoSpacing.s),
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              widthFactor: 1,
              heightFactor: 1,
              child: Text(
                label,
                style: context.text(
                  AvoTextStyle.subhead,
                  color: context.colors.tint,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
