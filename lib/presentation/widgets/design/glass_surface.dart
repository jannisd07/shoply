import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shoply/core/design/design.dart';
import 'package:shoply/presentation/widgets/common/liquid_glass_container.dart';

/// Outline of a [GlassSurface].
enum GlassShape {
  /// Fully rounded ends: the radius is half the height (button groups,
  /// text buttons on glass, the tab bar).
  capsule,

  /// A circle. Give the surface a square child (44 pt glass buttons).
  circle,

  /// A rounded rectangle with [GlassSurface.radius] (info panels).
  rounded,
}

// D2 `.glass` shadow: `0 0 0 .5px rgba(0,0,0,.05), 0 6px 20px rgba(0,0,0,.10)`.
const double _ringSpread = 0.5; // D2
const double _ringAlpha = 0.05; // D2
const Offset _dropOffset = Offset(0, 6); // D2
const double _dropBlur = 20; // D2
const double _dropAlpha = 0.10; // D2

// D2 `.glass-tint` shadow: `0 6px 18px rgba(31,122,58,.30)`.
const double _tintDropBlur = 18; // D2
const double _tintDropAlpha = 0.30; // D2

// ContentGlass: cheap pseudo glass on photos inside content (A2 spec).
const double _contentLightAlpha = 0.78; // D2 (white .78)
const double _contentDarkAlpha = 0.85; // D2 (glassFallback .85)

/// The floating glass layer: toolbar buttons, the tab bar, the add-item
/// accessory, buttons that float over content.
///
/// On iOS, without Reduce Transparency or Increase Contrast, the native
/// Liquid Glass ([LiquidGlassContainer]) is drawn behind [child]; the surface
/// takes its size from [child], never a fixed height. Everywhere else it
/// falls back to a translucent decoration with the D2 hairline and shadow,
/// and with Reduce Transparency to an opaque surface with a clear outline.
///
/// Only the floating layer may use this. Inside scrolling content use
/// [ContentGlass], which never creates a platform view.
class GlassSurface extends StatelessWidget {
  /// Creates a glass surface around [child].
  const GlassSurface({
    super.key,
    required this.child,
    this.shape = GlassShape.capsule,
    this.radius = AvoRadii.card,
    this.tinted = false,
    this.interactive = false,
    this.padding = EdgeInsets.zero,
  });

  /// The content. Its size decides the size of the surface.
  final Widget child;

  /// The outline; [GlassShape.capsule] by default.
  final GlassShape shape;

  /// Corner radius for [GlassShape.rounded]; ignored by the other shapes.
  final double radius;

  /// Green `.glass-tint` for the one primary action on glass. Content on it
  /// must use [AvoColors.onTint].
  final bool tinted;

  /// Lets the native glass react to touches (highlight, flex). Off by
  /// default: the Avo buttons give their own pressed feedback.
  final bool interactive;

  /// Space between the edge of the glass and [child].
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final reduceTransparency = context.reduceTransparency;
    final content = padding == EdgeInsets.zero
        ? child
        : Padding(padding: padding, child: child);

    if (!reduceTransparency && defaultTargetPlatform == TargetPlatform.iOS) {
      return Stack(
        fit: StackFit.passthrough,
        children: [
          Positioned.fill(
            child: ExcludeSemantics(
              child: LiquidGlassContainer(
                cornerRadius: shape == GlassShape.rounded ? radius : 0,
                isCircle: shape != GlassShape.rounded,
                interactive: interactive,
                tint: tinted ? colors.glassTintFill : null,
                child: const SizedBox.expand(),
              ),
            ),
          ),
          content,
        ],
      );
    }

    final Color fill;
    final Color outline;
    if (reduceTransparency) {
      fill = tinted ? colors.tintFill : colors.glassFallback;
      outline = _opaqueOutline(context, colors, tinted: tinted);
    } else {
      fill = tinted ? colors.glassTintFill : colors.glassFill;
      outline = tinted ? colors.glassTintBorder : colors.glassBorder;
    }
    return DecoratedBox(
      decoration: ShapeDecoration(
        color: fill,
        shape: _border(shape, radius, outline),
        shadows: _glassShadows(colors, tinted: tinted),
      ),
      child: content,
    );
  }
}

/// Cheap pseudo glass for chips and panels that sit on photos inside
/// scrolling content (list card cover, recipe hero): no blur, no platform
/// view, so it costs no more than a coloured box.
///
/// Light: white at 78 %; dark: [AvoColors.glassFallback] at 85 %; a hairline
/// and the soft D2 glass shadow. With Reduce Transparency or Increase
/// Contrast it turns opaque with a clear outline.
class ContentGlass extends StatelessWidget {
  /// Creates pseudo glass around [child].
  const ContentGlass({
    super.key,
    required this.child,
    this.radius = AvoRadii.card,
    this.padding = EdgeInsets.zero,
    this.tinted = false,
  });

  /// The content. Its size decides the size of the panel.
  final Widget child;

  /// Corner radius. Half the height gives a capsule.
  final double radius;

  /// Space between the edge of the panel and [child].
  final EdgeInsetsGeometry padding;

  /// Opaque [AvoColors.tintFill] with the `.glass-tint` edge and shadow: the
  /// primary action inside content (D2 hero "Zutaten auf die Liste"). Content
  /// on it must use [AvoColors.onTint].
  final bool tinted;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final Color fill;
    final Color outline;
    if (tinted) {
      fill = colors.tintFill;
      outline = colors.glassTintBorder;
    } else if (context.reduceTransparency) {
      fill = colors.glassFallback;
      outline = _opaqueOutline(context, colors, tinted: false);
    } else {
      final dark = Theme.of(context).brightness == Brightness.dark;
      fill = dark
          ? colors.glassFallback.withValues(alpha: _contentDarkAlpha)
          : colors.surface.withValues(alpha: _contentLightAlpha);
      outline = colors.glassBorder;
    }
    return DecoratedBox(
      decoration: ShapeDecoration(
        color: fill,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius),
          side: BorderSide(color: outline, width: AvoSizes.hairline),
        ),
        shadows: _glassShadows(colors, tinted: tinted),
      ),
      child: padding == EdgeInsets.zero
          ? child
          : Padding(padding: padding, child: child),
    );
  }
}

ShapeBorder _border(GlassShape shape, double radius, Color outline) {
  final side = BorderSide(color: outline, width: AvoSizes.hairline);
  return switch (shape) {
    GlassShape.capsule || GlassShape.circle => StadiumBorder(side: side),
    GlassShape.rounded => RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(radius),
      side: side,
    ),
  };
}

List<BoxShadow> _glassShadows(AvoColors colors, {required bool tinted}) {
  if (tinted) {
    return [
      BoxShadow(
        color: colors.tintFill.withValues(alpha: _tintDropAlpha),
        offset: _dropOffset,
        blurRadius: _tintDropBlur,
      ),
    ];
  }
  return [
    BoxShadow(
      color: colors.shadow.withValues(alpha: _ringAlpha),
      spreadRadius: _ringSpread,
    ),
    BoxShadow(
      color: colors.shadow.withValues(alpha: _dropAlpha),
      offset: _dropOffset,
      blurRadius: _dropBlur,
    ),
  ];
}

/// Outline of an opaque (Reduce Transparency) surface: the strong
/// [AvoColors.glassBorder] under Increase Contrast, else the separator,
/// since the translucent white glass edge would vanish on an opaque fill.
Color _opaqueOutline(
  BuildContext context,
  AvoColors colors, {
  required bool tinted,
}) {
  if (tinted) return colors.glassTintBorder;
  final highContrast = MediaQuery.maybeHighContrastOf(context) ?? false;
  return highContrast ? colors.glassBorder : colors.separator;
}
