/// The D2 icon set as own vectors.
///
/// Every glyph is redrawn from the SVG paths of the D2 artboards
/// (`D2-Komponenten`, `D2-Home`, `D2-Liste`, `D2-Artikel`, `D2-Rezepte`,
/// `X-Einkaufsmodus`, `X-Profil` and the tab bar block "D2 TAB BAR v2"), so
/// no icon font or third-party licence is involved. A small SVG path parser
/// turns the path data into a [Path] once per shape; [AvoIcon] paints it with
/// a [CustomPainter].
///
/// ```dart
/// AvoIcon(AvoIcons.share); // inside a button that carries the label
/// AvoIcon(AvoIcons.cart, size: 26, filled: true, color: colors.tintIcon);
/// AvoIcon(AvoIcons.tag, size: 12, color: colors.tint, semanticLabel: offer);
/// ```
///
/// Stroke widths are given in view-box units, like SVG `stroke-width`: D2's
/// tab icons use 1.8 on the 24 grid and are drawn at 26 pt, so the line is
/// 1.8 × 26 / 24 ≈ 1.95 pt wide. A D2 snippet such as
/// `<svg width="18" viewBox="0 0 24 24" stroke-width="2.4">` therefore maps to
/// `AvoIcon(icon, size: 18, strokeWidth: 2.4)`.
library;

import 'package:flutter/widgets.dart';
import 'package:shoply/core/design/design.dart';

// ---------------------------------------------------------------------- data

/// How an [AvoIconShape] is painted.
enum AvoIconStyle {
  /// Outline only (round caps and joins).
  stroke,

  /// Solid fill only.
  fill,

  /// Fill and outline in the same colour (D2 active tab icons).
  fillAndStroke,
}

/// One element of an [AvoIconData]: a path, a circle or a rounded rectangle,
/// in the icon's view-box coordinates.
@immutable
sealed class AvoIconShape {
  const AvoIconShape({this.style = AvoIconStyle.stroke, this.filledStyle});

  /// Paint style of the regular (outline) variant.
  final AvoIconStyle style;

  /// Paint style of the filled variant; `null` keeps [style].
  final AvoIconStyle? filledStyle;

  /// The style for the variant [filled].
  AvoIconStyle styleFor({required bool filled}) =>
      filled ? (filledStyle ?? style) : style;

  static final Expando<Path> _cache = Expando<Path>('AvoIconShape.path');

  /// The parsed geometry, built once per shape and shared; never mutate it.
  Path get _path => _cache[this] ??= _build();

  Path _build();

  /// A copy of the shape's geometry in view-box units.
  Path toPath() => Path.from(_path);
}

/// An SVG path (`d` attribute). Supports M L H V C S Q T A Z, absolute and
/// relative, implicit repetition and compact numbers such as `1.5.5` or
/// `-.7-.6`. Throws a [FormatException] on malformed data when first painted.
final class AvoIconPath extends AvoIconShape {
  const AvoIconPath(
    this.data, {
    super.style,
    super.filledStyle,
    this.evenOdd = false,
  });

  /// The SVG path data.
  final String data;

  /// Fill with the even-odd rule (SVG `fill-rule="evenodd"`) instead of
  /// non-zero.
  final bool evenOdd;

  @override
  Path _build() {
    final sink = _PathSink();
    _SvgPathParser(data, sink).parse();
    final path = sink.path;
    if (evenOdd) path.fillType = PathFillType.evenOdd;
    return path;
  }
}

/// A circle (SVG `<circle>`).
final class AvoIconCircle extends AvoIconShape {
  const AvoIconCircle(
    this.cx,
    this.cy,
    this.radius, {
    super.style,
    super.filledStyle,
  });

  /// Centre x.
  final double cx;

  /// Centre y.
  final double cy;

  /// Radius.
  final double radius;

  @override
  Path _build() =>
      Path()..addOval(Rect.fromCircle(center: Offset(cx, cy), radius: radius));
}

/// A rectangle with optional corner radius (SVG `<rect rx>`).
final class AvoIconRect extends AvoIconShape {
  const AvoIconRect(
    this.x,
    this.y,
    this.width,
    this.height, {
    this.radius = 0,
    super.style,
    super.filledStyle,
  });

  /// Left edge.
  final double x;

  /// Top edge.
  final double y;

  /// Width.
  final double width;

  /// Height.
  final double height;

  /// Corner radius.
  final double radius;

  @override
  Path _build() => Path()
    ..addRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(x, y, width, height),
        Radius.circular(radius),
      ),
    );
}

/// A vector icon: shapes on a square view box (24 for the whole D2 set).
///
/// Paths copied from a D2 snippet with a 20 or 10 view box can be used as
/// they are by passing that [viewBox]; [AvoIcon] scales it to its size.
@immutable
class AvoIconData {
  const AvoIconData(
    this.shapes, {
    this.viewBox = 24,
    this.strokeWidth = 1.8,
    this.matchTextDirection = false,
  }) : assert(viewBox > 0);

  /// The shapes, painted in order.
  final List<AvoIconShape> shapes;

  /// Side of the square view box the shapes are drawn on.
  final double viewBox;

  /// Default stroke width in view-box units (D2 value for the icon's main
  /// use); [AvoIcon.strokeWidth] overrides it.
  final double strokeWidth;

  /// Mirror horizontally in right-to-left text (chevrons).
  final bool matchTextDirection;

  /// Whether `filled: true` draws something different (D2 active tab icons).
  bool get hasFilledVariant =>
      shapes.any((s) => s.styleFor(filled: true) != s.style);
}

// --------------------------------------------------------------------- icons

/// The D2 icon set (24 grid, round caps and joins).
///
/// Sizes and strokes in the docs are the D2 values for the main use.
abstract final class AvoIcons {
  /// Home tab (D2 tab bar, 26 pt, stroke 1.8). Has a filled variant.
  static const home = AvoIconData([
    AvoIconPath(
      'M3.5 10.6 12 3.4l8.5 7.2v9.1c0 .7-.6 1.3-1.3 1.3H15v-6.2H9V21H4.8'
      'c-.7 0-1.3-.6-1.3-1.3z',
      filledStyle: AvoIconStyle.fillAndStroke,
    ),
  ]);

  /// Shopping cart, the Listen tab (26 pt, stroke 1.8). Has a filled variant.
  static const cart = AvoIconData([
    AvoIconPath(
      'M2.6 3.6h2.3l2.3 11.1c.2.8.8 1.3 1.6 1.3h8.8c.8 0 1.4-.5 1.6-1.3'
      'L21 7.1H5.6',
      filledStyle: AvoIconStyle.fillAndStroke,
    ),
    AvoIconCircle(9.3, 19.8, 1.5, style: AvoIconStyle.fill),
    AvoIconCircle(17, 19.8, 1.5, style: AvoIconStyle.fill),
  ]);

  /// Sparkle with a small dot, the Avo tab (26 pt, stroke 1.8). Has a filled
  /// variant.
  static const sparkle = AvoIconData([
    AvoIconPath(
      'M12 3.2c.7 4.6 2.8 6.7 7.4 7.4-4.6.7-6.7 2.8-7.4 7.4-.7-4.6-2.8-6.7'
      '-7.4-7.4 4.6-.7 6.7-2.8 7.4-7.4z',
      filledStyle: AvoIconStyle.fillAndStroke,
    ),
    AvoIconCircle(5.4, 19.4, 1.1, style: AvoIconStyle.fill),
  ]);

  /// Fork and knife, the Rezepte tab (26 pt, stroke 1.8). Filled variant
  /// fills the knife only, as in D2.
  static const forkKnife = AvoIconData([
    AvoIconPath('M5.5 3v5.2c0 1.4 1.1 2.5 2.5 2.5s2.5-1.1 2.5-2.5V3M8 3v18'),
    AvoIconPath(
      'M18 21V3c-2.3 1.5-3.5 4.2-3.5 7.6v3.4H18',
      filledStyle: AvoIconStyle.fillAndStroke,
    ),
  ]);

  /// Person, the Profil tab (26 pt, stroke 1.8). Has a filled variant.
  static const person = AvoIconData([
    AvoIconCircle(12, 8, 4, filledStyle: AvoIconStyle.fillAndStroke),
    AvoIconPath(
      'M4.2 20.6c1.2-3.7 4.2-5.6 7.8-5.6s6.6 1.9 7.8 5.6',
      filledStyle: AvoIconStyle.fillAndStroke,
    ),
  ]);

  /// Back chevron of toolbars (22 pt, stroke 2.2). Mirrors in RTL.
  static const chevronBack = AvoIconData(
    [AvoIconPath('M14.5 5.5 8 12l6.5 6.5')],
    strokeWidth: 2.2,
    matchTextDirection: true,
  );

  /// Disclosure chevron (D2-Artikel: 14 pt, stroke 2.6; settings rows: about
  /// 19 pt with stroke 2.5 gives D2's 8 × 14 pt, 2 pt chevron). Mirrors in
  /// RTL.
  static const chevronRight = AvoIconData(
    [AvoIconPath('M9 5l7 7-7 7')],
    strokeWidth: 2.2,
    matchTextDirection: true,
  );

  /// Pull-down chevron (X-Einkaufsmodus market chip, 10 pt with stroke 3.8;
  /// source on a 10 grid, scaled to 24).
  static const chevronDown = AvoIconData([
    AvoIconPath('M4.8 8.4 12 15.6l7.2-7.2'),
  ], strokeWidth: 2.2);

  /// Share: box with arrow up (toolbar 22 pt, stroke 2).
  static const share = AvoIconData([
    AvoIconPath('M12 3.5v11'),
    AvoIconPath('M8 7.2 12 3.3l4 3.9'),
    AvoIconPath(
      'M8.5 10H7a2 2 0 0 0-2 2v6.5a2 2 0 0 0 2 2h10a2 2 0 0 0 2-2V12'
      'a2 2 0 0 0-2-2h-1.5',
    ),
  ], strokeWidth: 2);

  /// More: three dots (toolbar 22 pt, filled).
  static const more = AvoIconData([
    AvoIconCircle(5.5, 12, 2, style: AvoIconStyle.fill),
    AvoIconCircle(12, 12, 2, style: AvoIconStyle.fill),
    AvoIconCircle(18.5, 12, 2, style: AvoIconStyle.fill),
  ]);

  /// Plus (primary glass button 20 pt, stroke 2.4; add field 16 pt, 2.8;
  /// stepper 18 pt, 2.4).
  static const plus = AvoIconData([
    AvoIconPath('M12 5v14M5 12h14'),
  ], strokeWidth: 2.4);

  /// Minus, the partner of [plus] (stepper 16 to 18 pt, stroke 2.4).
  static const minus = AvoIconData([AvoIconPath('M5 12h14')], strokeWidth: 2.4);

  /// Microphone for dictation (add field 22 pt, stroke 1.8).
  static const mic = AvoIconData([
    AvoIconRect(8.5, 2.5, 7, 12, radius: 3.5, style: AvoIconStyle.fill),
    AvoIconPath('M5.8 11.2a6.2 6.2 0 0 0 12.4 0M12 17.4v3.4M9 20.8h6'),
  ]);

  /// Check mark of the check circle (16 pt, stroke 3).
  static const check = AvoIconData([
    AvoIconPath('M6 12.6l4 4L18 8'),
  ], strokeWidth: 3);

  /// Price tag for offers (12 to 20 pt, filled, with a hole).
  static const tag = AvoIconData([
    AvoIconPath(
      'M3 4.5A1.5 1.5 0 0 1 4.5 3h6.4c.4 0 .8.2 1.1.4l8.6 8.6a1.5 1.5 0 0 1'
      ' 0 2.1l-6.4 6.4a1.5 1.5 0 0 1-2.1 0L3.4 12c-.3-.3-.4-.7-.4-1.1z'
      'M7.5 6a1.5 1.5 0 1 0 0 3 1.5 1.5 0 1 0 0-3z',
      style: AvoIconStyle.fill,
      evenOdd: true,
    ),
  ]);

  /// Trash can (D2-Artikel "delete" row, 18 pt, filled).
  static const trash = AvoIconData([
    AvoIconPath(
      'M9 3h6a1 1 0 0 1 1 1v1h4a1 1 0 1 1 0 2H4a1 1 0 0 1 0-2h4V4'
      'a1 1 0 0 1 1-1zM5.5 8.5h13l-.9 11a2 2 0 0 1-2 1.8H8.4'
      'a2 2 0 0 1-2-1.8z',
      style: AvoIconStyle.fill,
    ),
  ]);

  /// Clock (X-Einkaufsmodus meta, 14 pt, stroke 2.2).
  static const clock = AvoIconData([
    AvoIconPath('M12 2a10 10 0 1 0 0 20 10 10 0 0 0 0-20zm0 4v6l4 2'),
  ], strokeWidth: 2.2);

  /// Magnifying glass (D2-Rezepte search field, 17 pt, stroke 2.6).
  static const search = AvoIconData([
    AvoIconCircle(10.5, 10.5, 6.8),
    AvoIconPath('M15.6 15.6l5.2 5.2'),
  ], strokeWidth: 2.6);

  /// Close cross (X-Pro close button, 18 pt, stroke 2.4).
  static const xmark = AvoIconData([
    AvoIconPath('M6 6l12 12M18 6L6 18'),
  ], strokeWidth: 2.4);

  /// Calendar with days (D2-FuerDich period picker, 22 pt, stroke 1.8).
  static const calendar = AvoIconData([
    AvoIconRect(3.5, 5, 17, 15.5, radius: 3.5),
    AvoIconPath('M3.5 10h17M8 3v4M16 3v4'),
    AvoIconCircle(8.5, 14, 1.1, style: AvoIconStyle.fill),
    AvoIconCircle(12, 14, 1.1, style: AvoIconStyle.fill),
    AvoIconCircle(15.5, 14, 1.1, style: AvoIconStyle.fill),
    AvoIconCircle(8.5, 17.3, 1.1, style: AvoIconStyle.fill),
    AvoIconCircle(12, 17.3, 1.1, style: AvoIconStyle.fill),
  ]);

  /// Keyboard (X-AvoSprache "switch to typing", 24 pt, stroke 1.8).
  static const keyboard = AvoIconData([
    AvoIconRect(3, 6, 18, 12, radius: 3),
    AvoIconPath('M7 10h1M11 10h1M15 10h1M7 14h10'),
  ]);

  /// Two people for members and sharing (D2-Liste toolbar, 22 pt, filled).
  static const people = AvoIconData([
    AvoIconCircle(16.6, 8.4, 2.8, style: AvoIconStyle.fill),
    AvoIconPath(
      'M16.3 13.1c3 0 5.4 1.9 5.4 4.8 0 .6-.4 1-1 1h-3.4c.1-.3.2-.7.2-1.1'
      ' 0-1.9-.8-3.5-2.1-4.6.3 0 .6-.1.9-.1z',
      style: AvoIconStyle.fill,
    ),
    AvoIconCircle(9, 7.8, 3.5, style: AvoIconStyle.fill),
    AvoIconPath(
      'M2.4 18.4c0-3.4 2.9-5.6 6.6-5.6s6.6 2.2 6.6 5.6c0 .6-.4 1-1 1H3.4'
      'c-.6 0-1-.4-1-1z',
      style: AvoIconStyle.fill,
    ),
  ]);

  /// Heart for favourites (X-Pro outline, 24 pt, stroke 2; X-Profil and
  /// X-Essen filled). Has a filled variant.
  static const heart = AvoIconData([
    AvoIconPath(
      'M12 20s-7-4.4-7-10a4 4 0 0 1 7-2.6A4 4 0 0 1 19 10c0 5.6-7 10-7 10z',
      filledStyle: AvoIconStyle.fill,
    ),
  ], strokeWidth: 2);

  /// Bookmark for saved recipes (D2-Rezepte toolbar: 20 pt, filled). The
  /// outline variant is drawn in the same style for "not saved yet".
  static const bookmark = AvoIconData([
    AvoIconPath(
      'M6.5 2.5h11A1.5 1.5 0 0 1 19 4v17.2a.6.6 0 0 1-.95.5L12 17.4'
      'l-6.05 4.3a.6.6 0 0 1-.95-.5V4a1.5 1.5 0 0 1 1.5-1.5z',
      filledStyle: AvoIconStyle.fill,
    ),
  ]);

  // Added for Konzept 17 §9.3 (A7) and B's offer screens (A-C10); drawn on
  // the same 24 grid in the D2 style (round caps, stroke 1.8 to 2.2).

  /// Location arrow ("Standort verwenden", 18 to 20 pt, stroke 2). Has a
  /// filled variant.
  static const location = AvoIconData([
    AvoIconPath(
      'M20.3 3.7 3.9 10.5c-.7.3-.6 1.2.1 1.4l7 1.6 1.6 7c.2.7 1.1.8 1.4.1z',
      filledStyle: AvoIconStyle.fillAndStroke,
    ),
  ], strokeWidth: 2);

  /// Storefront: awning over a shop with a door (market rows, 20 pt,
  /// stroke 1.8).
  static const storefront = AvoIconData([
    AvoIconPath('M3.5 9 5 4.5h14L20.5 9'),
    AvoIconPath(
      'M3.5 9a2.83 2.83 0 0 0 5.67 0 2.83 2.83 0 0 0 5.66 0'
      ' 2.83 2.83 0 0 0 5.67 0',
    ),
    AvoIconPath('M5 12.2V20h14v-7.8M10 20v-4.5h4V20'),
  ]);

  /// Eye: show password (20 pt, stroke 1.8).
  static const eye = AvoIconData([
    AvoIconPath(
      'M2.5 12S6 5.5 12 5.5 21.5 12 21.5 12 18 18.5 12 18.5 2.5 12 2.5 12z',
    ),
    AvoIconCircle(12, 12, 3),
  ]);

  /// Crossed-out eye: hide password, hide offers (20 pt, stroke 1.8).
  static const eyeSlash = AvoIconData([
    AvoIconPath(
      'M2.5 12S6 5.5 12 5.5 21.5 12 21.5 12 18 18.5 12 18.5 2.5 12 2.5 12z',
    ),
    AvoIconCircle(12, 12, 3),
    AvoIconPath('M4 4l16 16'),
  ]);

  /// Plus in a circle (add row, 20 pt, stroke 2).
  static const plusCircle = AvoIconData([
    AvoIconCircle(12, 12, 9),
    AvoIconPath('M12 8v8M8 12h8'),
  ], strokeWidth: 2);

  /// Question mark in a circle (help, 20 pt, stroke 2).
  static const questionmarkCircle = AvoIconData([
    AvoIconCircle(12, 12, 9),
    AvoIconPath('M9.6 9.4a2.5 2.5 0 0 1 4.8.9c0 1.7-2.4 2.2-2.4 3.7'),
    AvoIconCircle(12, 17, 1.1, style: AvoIconStyle.fill),
  ], strokeWidth: 2);

  /// Exclamation mark in a circle (error rows, 18 pt, stroke 2).
  static const exclamationmarkCircle = AvoIconData([
    AvoIconCircle(12, 12, 9),
    AvoIconPath('M12 7.5v5.5'),
    AvoIconCircle(12, 16.3, 1.1, style: AvoIconStyle.fill),
  ], strokeWidth: 2);

  /// Filled warning triangle with the mark cut out (allergy and offer
  /// caveats, 16 to 18 pt; colour `warning`).
  static const exclamationmarkTriangleFill = AvoIconData([
    AvoIconPath(
      'M10.3 3.9 2.4 17.6a2 2 0 0 0 1.7 3h15.8a2 2 0 0 0 1.7-3L13.7 3.9'
      'a2 2 0 0 0-3.4 0zM11 8.8h2v5.6h-2zM12 15.8a1.2 1.2 0 1 0 0 2.4'
      ' 1.2 1.2 0 1 0 0-2.4z',
      style: AvoIconStyle.fill,
      evenOdd: true,
    ),
  ]);

  /// Three lines: drag handle of sortable rows (18 pt, stroke 2).
  static const line3Horizontal = AvoIconData([
    AvoIconPath('M4 7h16M4 12h16M4 17h16'),
  ], strokeWidth: 2);

  /// Empty circle: a rule not met yet (16 pt, stroke 2).
  static const circle = AvoIconData([AvoIconCircle(12, 12, 9)], strokeWidth: 2);

  /// Filled circle with the check cut out: a rule met, a selected row
  /// (16 to 22 pt).
  static const checkmarkCircleFill = AvoIconData([
    AvoIconPath(
      'M12 2.5a9.5 9.5 0 1 0 0 19 9.5 9.5 0 1 0 0-19zM10.6 16.2 6.7 12.3'
      'l1.4-1.4 2.5 2.5 5.3-5.3 1.4 1.4z',
      style: AvoIconStyle.fill,
      evenOdd: true,
    ),
  ]);

  /// Light bulb of tip rows (16 pt, stroke 1.8).
  static const lightbulb = AvoIconData([
    AvoIconPath(
      'M12 3a6 6 0 0 0-3.6 10.8c.7.6 1.1 1.4 1.1 2.2v.5h5V16'
      'c0-.8.4-1.6 1.1-2.2A6 6 0 0 0 12 3z',
    ),
    AvoIconPath('M9.5 19h5M10.5 21.5h3'),
  ]);

  /// Envelope: continue with e-mail (20 pt, stroke 1.8).
  static const envelope = AvoIconData([
    AvoIconRect(3, 5.5, 18, 13, radius: 2.5),
    AvoIconPath('M3.8 7.5 12 13l8.2-5.5'),
  ]);

  /// Person with a plus: invite (toolbar 22 pt, stroke 1.8).
  static const personBadgePlus = AvoIconData([
    AvoIconCircle(10, 8, 3.6),
    AvoIconPath('M3.2 20c1-3.3 3.7-5 6.8-5 1.4 0 2.7.3 3.8 1'),
    AvoIconPath('M18.5 13v6M15.5 16h6'),
  ]);

  /// Crossed-out bookmark: remove from saved (menu rows, 20 pt, stroke 1.8).
  static const bookmarkSlash = AvoIconData([
    AvoIconPath(
      'M6.5 2.5h11A1.5 1.5 0 0 1 19 4v17.2a.6.6 0 0 1-.95.5L12 17.4'
      'l-6.05 4.3a.6.6 0 0 1-.95-.5V4a1.5 1.5 0 0 1 1.5-1.5z',
    ),
    AvoIconPath('M3.5 3.5l17 17'),
  ]);

  /// SF Symbol `photo`: frame, hill, sun.
  static const photo = AvoIconData([
    AvoIconRect(3, 4.5, 18, 15, radius: 3),
    AvoIconPath('M3.6 16.4l4.6-4.5a1.5 1.5 0 0 1 2.1 0l5.6 5.6'),
    AvoIconPath('M14 15.4l1.7-1.7a1.5 1.5 0 0 1 2.1 0l2.7 2.7'),
    AvoIconCircle(15.6, 9.4, 1.6, style: AvoIconStyle.fill),
  ]);

  /// SF Symbol `camera`.
  static const camera = AvoIconData([
    AvoIconPath(
      'M3.5 8.6a2 2 0 0 1 2-2h2.2l1.5-2.1h5.6l1.5 2.1h2.2a2 2 0 0 1 2 2'
      'V17a2 2 0 0 1-2 2h-13a2 2 0 0 1-2-2z',
    ),
    AvoIconCircle(12, 12.6, 3.4),
  ]);

  /// SF Symbol `checklist`: three ticks and lines.
  static const checklist = AvoIconData([
    AvoIconPath('M3.5 6.5l1.5 1.5 2.7-3'),
    AvoIconPath('M3.5 12.5l1.5 1.5 2.7-3'),
    AvoIconPath('M3.5 18.5l1.5 1.5 2.7-3'),
    AvoIconPath('M11 6.5h9.5M11 12.5h9.5M11 18.5h9.5'),
  ]);

  /// SF Symbol `clock.arrow.circlepath`: history.
  static const history = AvoIconData([
    AvoIconPath('M4.1 13.4A8 8 0 0 0 19.9 11.7A8 8 0 0 0 6 6.3'),
    AvoIconPath('M3.6 3.6v4.2h4.2'),
    AvoIconPath('M12 8v4.4l3 1.8'),
  ]);

  /// SF Symbol `person.crop.circle`.
  static const personCircle = AvoIconData([
    AvoIconCircle(12, 12, 8.8),
    AvoIconCircle(12, 10, 3.2),
    AvoIconPath('M6.2 18.3c1.3-2 3.4-3.1 5.8-3.1s4.5 1.1 5.8 3.1'),
  ]);

  /// SF Symbol `flame` (D2 X-Profil "Kalorien" glyph as an outline).
  static const flame = AvoIconData([
    AvoIconPath(
      'M12 3c1 4 6 6 6 11a6 6 0 0 1-12 0c0-3 2-4 2-7 2 1 3 3 3 4 1-2 1-5 '
      '1-8z',
    ),
  ]);

  /// SF Symbol `arrow.triangle.2.circlepath`: the sync sign (Konzept 00
  /// §12.7) on the avatar and behind the name while a change waits.
  static const sync = AvoIconData([
    AvoIconPath('M19.5 11a7.5 7.5 0 0 0-13.4-4.1'),
    AvoIconPath('M6.4 3.4v3.8h3.8'),
    AvoIconPath('M4.5 13a7.5 7.5 0 0 0 13.4 4.1'),
    AvoIconPath('M17.6 20.6v-3.8h-3.8'),
  ], strokeWidth: 2.2);

  /// SF Symbol `stop.fill`: the square of "Antwort anhalten" (Avo composer).
  static const stopFill = AvoIconData([
    AvoIconRect(6.5, 6.5, 11, 11, radius: 2.5, style: AvoIconStyle.fill),
  ]);

  // AB1 (part "Menüs"): glyphs B's screens asked for. The ones with a D2
  // source are copied from the artboards; the SF Symbol look-alikes follow
  // the same grid, round caps and the 1.8 to 2 stroke.

  /// SF Symbol `plus.bubble`: speech bubble with a plus (Avo suggestion
  /// "new list", 20 pt, stroke 1.8).
  static const plusBubble = AvoIconData([
    AvoIconPath(
      'M5.5 3.5h13A2.5 2.5 0 0 1 21 6v8.5a2.5 2.5 0 0 1-2.5 2.5h-6.2'
      'l-4.1 3.5c-.5.4-1.2.1-1.2-.5V17H5.5A2.5 2.5 0 0 1 3 14.5V6'
      'a2.5 2.5 0 0 1 2.5-2.5z',
    ),
    AvoIconPath('M12 7.3v6M9 10.3h6'),
  ]);

  /// SF Symbol `leaf`: a leaf with its stem (allergies, vegetarian, 18 pt,
  /// stroke 1.8).
  static const leaf = AvoIconData([
    AvoIconPath(
      'M20 4C10 4 5 9 5 15c0 1.6.4 3 1 4 1.5.6 3 .9 4.5.9C16.5 19.9 20 14 '
      '20 4z',
    ),
    AvoIconPath('M4.5 20.5C7 15 10 11.5 14 9'),
  ]);

  /// SF Symbol `switch.2`: two toggles, one on and one off (modules, 18 pt,
  /// stroke 1.8).
  static const switch2 = AvoIconData([
    AvoIconRect(3, 3.5, 18, 7, radius: 3.5),
    AvoIconCircle(17.5, 7, 2, style: AvoIconStyle.fill),
    AvoIconRect(3, 13.5, 18, 7, radius: 3.5),
    AvoIconCircle(6.5, 17, 2, style: AvoIconStyle.fill),
  ]);

  /// SF Symbol `eurosign.circle`: euro sign in a circle (prices and savings,
  /// 20 pt, stroke 1.8).
  static const eurosignCircle = AvoIconData([
    AvoIconCircle(12, 12, 9),
    AvoIconPath('M14.9 9.3a3.4 3.4 0 1 0 0 5.4M7.6 10.7h5.2M7.6 13.3h5.2'),
  ]);

  /// SF Symbol `line.3.horizontal.decrease`: three shrinking lines, the
  /// plain filter sign (toolbar 20 pt, stroke 2).
  static const filter = AvoIconData([
    AvoIconPath('M4 7h16M7 12h10M10 17h4'),
  ], strokeWidth: 2);

  /// SF Symbol `line.3.horizontal.decrease.circle`: the filter lines in a
  /// circle (20 pt, stroke 1.8). Use [filterCircleFill] for "filter is
  /// active".
  static const filterCircle = AvoIconData([
    AvoIconCircle(12, 12, 9),
    AvoIconPath('M7.5 9h9M9.5 12h5M11.3 15h1.4'),
  ]);

  /// SF Symbol `line.3.horizontal.decrease.circle.fill`: solid circle with
  /// the three lines cut out (20 pt).
  static const filterCircleFill = AvoIconData([
    AvoIconPath(
      'M12 2.5a9.5 9.5 0 1 0 0 19 9.5 9.5 0 1 0 0-19zM7.5 8.3h9v1.4h-9z'
      'M9.5 11.3h5v1.4h-5zM11.2 14.3h1.6v1.4h-1.6z',
      style: AvoIconStyle.fill,
      evenOdd: true,
    ),
  ]);

  /// SF Symbol `checkmark.circle`: the outline partner of
  /// [checkmarkCircleFill] (20 pt, stroke 1.8).
  static const checkmarkCircle = AvoIconData([
    AvoIconCircle(12, 12, 9),
    AvoIconPath('M8 12.4l2.7 2.7 5.3-5.6'),
  ]);

  /// SF Symbol `cart.badge.plus`: cart with a plus at its corner ("Zur Liste
  /// hinzufügen", 20 pt, stroke 1.8).
  static const cartBadgePlus = AvoIconData([
    AvoIconPath(
      'M2.6 3.8h2.3l2.2 10.8c.2.8.8 1.4 1.6 1.4h7.4c.8 0 1.4-.5 1.6-1.3'
      'l.6-2.8',
    ),
    AvoIconPath('M5.6 7.3h8.4'),
    AvoIconPath('M18 2.2v5.6M15.2 5h5.6'),
    AvoIconCircle(9.3, 19.8, 1.5, style: AvoIconStyle.fill),
    AvoIconCircle(15.8, 19.8, 1.5, style: AvoIconStyle.fill),
  ]);

  /// Shopping bag with a handle (D2-FuerDich "Dein November", 22 pt,
  /// stroke 1.8).
  static const bag = AvoIconData([
    AvoIconPath(
      'M5.2 8h13.6l-1 11.4c-.1 1-.9 1.6-1.8 1.6H8c-.9 0-1.7-.7-1.8-1.6z',
    ),
    AvoIconPath('M8.8 10.5V7a3.2 3.2 0 0 1 6.4 0v3.5'),
  ]);

  /// Three bars on a baseline (D2-FuerDich "Dein November" savings, 22 pt,
  /// stroke 1.8).
  static const chartBar = AvoIconData([
    AvoIconPath('M4 20.5h16'),
    AvoIconRect(5, 11, 3.4, 6.5, radius: 1),
    AvoIconRect(10.3, 6.5, 3.4, 11, radius: 1),
    AvoIconRect(15.6, 3.5, 3.4, 14, radius: 1),
  ]);

  /// SF Symbol `list.bullet`: three bullets with lines (18 to 20 pt,
  /// stroke 2).
  static const listBullet = AvoIconData([
    AvoIconPath('M9.5 6.5h11M9.5 12h11M9.5 17.5h11'),
    AvoIconCircle(4.5, 6.5, 1.2, style: AvoIconStyle.fill),
    AvoIconCircle(4.5, 12, 1.2, style: AvoIconStyle.fill),
    AvoIconCircle(4.5, 17.5, 1.2, style: AvoIconStyle.fill),
  ], strokeWidth: 2);

  /// Arrow down (D2-FuerDich price comparison "cheaper", 14 pt; the D2
  /// source is on a 16 grid with stroke 2, here scaled to 24 with 3).
  static const arrowDown = AvoIconData([
    AvoIconPath('M12 3.75v16.5M5.25 13.5 12 20.25l6.75-6.75'),
  ], strokeWidth: 3);

  /// SF Symbol `chevron.up.chevron.down`: the picker sign of rows that open
  /// a menu (14 to 16 pt, stroke 2.2).
  static const chevronUpChevronDown = AvoIconData([
    AvoIconPath('M7.5 9.2 12 4.7l4.5 4.5M7.5 14.8l4.5 4.5 4.5-4.5'),
  ], strokeWidth: 2.2);

  /// Every icon by name, for the component gallery and tests.
  static const Map<String, AvoIconData> all = {
    'home': home,
    'cart': cart,
    'sparkle': sparkle,
    'forkKnife': forkKnife,
    'person': person,
    'chevronBack': chevronBack,
    'chevronRight': chevronRight,
    'chevronDown': chevronDown,
    'share': share,
    'more': more,
    'plus': plus,
    'minus': minus,
    'mic': mic,
    'check': check,
    'tag': tag,
    'trash': trash,
    'clock': clock,
    'search': search,
    'xmark': xmark,
    'calendar': calendar,
    'keyboard': keyboard,
    'people': people,
    'heart': heart,
    'bookmark': bookmark,
    'location': location,
    'storefront': storefront,
    'eye': eye,
    'eyeSlash': eyeSlash,
    'plusCircle': plusCircle,
    'questionmarkCircle': questionmarkCircle,
    'exclamationmarkCircle': exclamationmarkCircle,
    'exclamationmarkTriangleFill': exclamationmarkTriangleFill,
    'line3Horizontal': line3Horizontal,
    'circle': circle,
    'checkmarkCircleFill': checkmarkCircleFill,
    'lightbulb': lightbulb,
    'envelope': envelope,
    'personBadgePlus': personBadgePlus,
    'bookmarkSlash': bookmarkSlash,
    'photo': photo,
    'camera': camera,
    'checklist': checklist,
    'history': history,
    'personCircle': personCircle,
    'flame': flame,
    'sync': sync,
    'stopFill': stopFill,
    'plusBubble': plusBubble,
    'leaf': leaf,
    'switch2': switch2,
    'eurosignCircle': eurosignCircle,
    'filter': filter,
    'filterCircle': filterCircle,
    'filterCircleFill': filterCircleFill,
    'checkmarkCircle': checkmarkCircle,
    'cartBadgePlus': cartBadgePlus,
    'bag': bag,
    'chartBar': chartBar,
    'listBullet': listBullet,
    'arrowDown': arrowDown,
    'chevronUpChevronDown': chevronUpChevronDown,
  };
}

// -------------------------------------------------------------------- widget

/// Paints an [AvoIconData] in a square of [size] points.
///
/// - Colour defaults to `context.colors.label`, so dark mode and Increase
///   Contrast follow automatically.
/// - The size does not follow Dynamic Type; the caller decides (tab icons
///   stay at 26).
/// - Without [semanticLabel] the icon is hidden from VoiceOver (put the label
///   on the button around it). With it, VoiceOver reads the label.
class AvoIcon extends StatelessWidget {
  const AvoIcon(
    this.icon, {
    super.key,
    this.size,
    this.color,
    this.filled = false,
    this.strokeWidth,
    this.semanticLabel,
  });

  /// Default side when neither [size] nor an [AvoIconTheme] sets one.
  static const double defaultSize = 22;

  /// The glyph.
  final AvoIconData icon;

  /// Side of the square in logical points; defaults to the nearest
  /// [AvoIconTheme], then [defaultSize].
  final double? size;

  /// Fill and stroke colour; defaults to the nearest [AvoIconTheme], then
  /// `context.colors.label`.
  final Color? color;

  /// Draw the filled variant if the icon has one (active tab, saved).
  final bool filled;

  /// Stroke width in view-box units; defaults to [AvoIconData.strokeWidth].
  /// It scales with [size] like the rest of the glyph.
  final double? strokeWidth;

  /// Text for VoiceOver; `null` hides the icon from it.
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final flip =
        icon.matchTextDirection &&
        Directionality.maybeOf(context) == TextDirection.rtl;
    final scope = AvoIconTheme.maybeOf(context);
    final painted = ExcludeSemantics(
      child: SizedBox.square(
        dimension: size ?? scope?.size ?? defaultSize,
        child: CustomPaint(
          painter: _AvoIconPainter(
            icon: icon,
            color: color ?? scope?.color ?? context.colors.label,
            filled: filled,
            strokeWidth: strokeWidth ?? icon.strokeWidth,
            flip: flip,
          ),
        ),
      ),
    );
    final label = semanticLabel;
    if (label == null) return painted;
    return Semantics(label: label, child: painted);
  }
}

/// Colour and size for the [AvoIcon]s below that set none themselves.
/// Buttons and containers set it through [IconStyleScope].
class AvoIconTheme extends InheritedWidget {
  const AvoIconTheme({super.key, this.color, this.size, required super.child});

  final Color? color;
  final double? size;

  static AvoIconTheme? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AvoIconTheme>();

  @override
  bool updateShouldNotify(AvoIconTheme oldWidget) =>
      color != oldWidget.color || size != oldWidget.size;
}

/// Gives the icons below a colour and size: Flutter's [IconTheme] for
/// [Icon]s and the [AvoIconTheme] for [AvoIcon]s.
class IconStyleScope extends StatelessWidget {
  const IconStyleScope({super.key, this.color, this.size, required this.child});

  final Color? color;
  final double? size;
  final Widget child;

  @override
  Widget build(BuildContext context) => IconTheme.merge(
    data: IconThemeData(size: size, color: color),
    child: AvoIconTheme(color: color, size: size, child: child),
  );
}

class _AvoIconPainter extends CustomPainter {
  const _AvoIconPainter({
    required this.icon,
    required this.color,
    required this.filled,
    required this.strokeWidth,
    required this.flip,
  });

  final AvoIconData icon;
  final Color color;
  final bool filled;
  final double strokeWidth;
  final bool flip;

  @override
  void paint(Canvas canvas, Size size) {
    final side = size.shortestSide;
    if (side <= 0) return;
    final scale = side / icon.viewBox;
    final dx = (size.width - side) / 2 + (flip ? side : 0);
    final dy = (size.height - side) / 2;

    canvas.save();
    if (dx != 0 || dy != 0) canvas.translate(dx, dy);
    canvas.scale(flip ? -scale : scale, scale);

    // Two Paint objects: one per style, never reused for the other.
    final fill = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    for (final shape in icon.shapes) {
      final style = shape.styleFor(filled: filled);
      final path = shape._path;
      if (style != AvoIconStyle.stroke) canvas.drawPath(path, fill);
      if (style != AvoIconStyle.fill && strokeWidth > 0) {
        canvas.drawPath(path, stroke);
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_AvoIconPainter old) =>
      !identical(old.icon, icon) ||
      old.color != color ||
      old.filled != filled ||
      old.strokeWidth != strokeWidth ||
      old.flip != flip;
}

// ----------------------------------------------------------------- SVG parser

/// The commands of SVG path [data], normalised to absolute `M`, `L`, `C`,
/// `Q`, `A` and `Z` (H/V become L, S/T get their reflected control point),
/// numbers rounded to three decimals. Only for tests of the path parser.
@visibleForTesting
List<String> debugDescribeSvgPath(String data) {
  final sink = _DescribingSink();
  _SvgPathParser(data, sink).parse();
  return sink.commands;
}

/// Receives the absolute segments of a parsed SVG path.
abstract class _SvgPathSink {
  void moveTo(double x, double y);
  void lineTo(double x, double y);
  void cubicTo(double x1, double y1, double x2, double y2, double x, double y);
  void quadTo(double x1, double y1, double x, double y);
  void arcTo(
    double rx,
    double ry,
    double rotation,
    bool largeArc,
    bool sweep,
    double x,
    double y,
  );
  void close();
}

class _PathSink implements _SvgPathSink {
  final Path path = Path();

  @override
  void moveTo(double x, double y) => path.moveTo(x, y);

  @override
  void lineTo(double x, double y) => path.lineTo(x, y);

  @override
  void cubicTo(
    double x1,
    double y1,
    double x2,
    double y2,
    double x,
    double y,
  ) => path.cubicTo(x1, y1, x2, y2, x, y);

  @override
  void quadTo(double x1, double y1, double x, double y) =>
      path.quadraticBezierTo(x1, y1, x, y);

  // SVG's sweep flag 1 is the positive-angle direction, which is clockwise
  // on screen (y points down), exactly Flutter's `clockwise`.
  @override
  void arcTo(
    double rx,
    double ry,
    double rotation,
    bool largeArc,
    bool sweep,
    double x,
    double y,
  ) => path.arcToPoint(
    Offset(x, y),
    radius: Radius.elliptical(rx, ry),
    rotation: rotation,
    largeArc: largeArc,
    clockwise: sweep,
  );

  @override
  void close() => path.close();
}

class _DescribingSink implements _SvgPathSink {
  final List<String> commands = [];

  static String _n(double v) {
    var s = v.toStringAsFixed(3);
    s = s.replaceFirst(RegExp(r'\.?0+$'), '');
    return s == '-0' ? '0' : s;
  }

  void _add(String command, List<double> values) =>
      commands.add([command, ...values.map(_n)].join(' '));

  @override
  void moveTo(double x, double y) => _add('M', [x, y]);

  @override
  void lineTo(double x, double y) => _add('L', [x, y]);

  @override
  void cubicTo(
    double x1,
    double y1,
    double x2,
    double y2,
    double x,
    double y,
  ) => _add('C', [x1, y1, x2, y2, x, y]);

  @override
  void quadTo(double x1, double y1, double x, double y) =>
      _add('Q', [x1, y1, x, y]);

  @override
  void arcTo(
    double rx,
    double ry,
    double rotation,
    bool largeArc,
    bool sweep,
    double x,
    double y,
  ) => _add('A', [rx, ry, rotation, largeArc ? 1 : 0, sweep ? 1 : 0, x, y]);

  @override
  void close() => commands.add('Z');
}

enum _Previous { other, cubic, quad }

/// A small parser for the SVG path grammar (SVG 1.1, 8.3.9), enough for
/// hand-written icon paths.
class _SvgPathParser {
  _SvgPathParser(this._source, this._sink);

  final String _source;
  final _SvgPathSink _sink;
  int _pos = 0;

  double _x = 0;
  double _y = 0;
  double _startX = 0;
  double _startY = 0;

  /// Control point of the previous C/S or Q/T segment, for reflection.
  double _ctrlX = 0;
  double _ctrlY = 0;
  _Previous _previous = _Previous.other;

  void parse() {
    var first = true;
    while (true) {
      _skipSeparators();
      if (_pos >= _source.length) return;
      final command = _source[_pos];
      if (!_isCommand(command)) {
        throw FormatException('Expected a path command', _source, _pos);
      }
      if (first && command != 'M' && command != 'm') {
        throw FormatException('A path must start with M', _source, _pos);
      }
      first = false;
      _pos++;
      _run(command);
    }
  }

  void _run(String command) {
    final relative = command.toLowerCase() == command;
    switch (command.toUpperCase()) {
      case 'Z':
        _sink.close();
        _x = _startX;
        _y = _startY;
        _previous = _Previous.other;
      case 'M':
        var (x, y) = _point(relative);
        _sink.moveTo(x, y);
        _startX = _x = x;
        _startY = _y = y;
        _previous = _Previous.other;
        while (_hasMoreArguments()) {
          (x, y) = _point(relative);
          _line(x, y);
        }
      case 'L':
        do {
          final (x, y) = _point(relative);
          _line(x, y);
        } while (_hasMoreArguments());
      case 'H':
        do {
          final x = _number() + (relative ? _x : 0);
          _line(x, _y);
        } while (_hasMoreArguments());
      case 'V':
        do {
          final y = _number() + (relative ? _y : 0);
          _line(_x, y);
        } while (_hasMoreArguments());
      case 'C':
        do {
          final (x1, y1) = _point(relative);
          final (x2, y2) = _point(relative);
          final (x, y) = _point(relative);
          _cubic(x1, y1, x2, y2, x, y);
        } while (_hasMoreArguments());
      case 'S':
        do {
          final (x1, y1) = _reflected(_Previous.cubic);
          final (x2, y2) = _point(relative);
          final (x, y) = _point(relative);
          _cubic(x1, y1, x2, y2, x, y);
        } while (_hasMoreArguments());
      case 'Q':
        do {
          final (x1, y1) = _point(relative);
          final (x, y) = _point(relative);
          _quad(x1, y1, x, y);
        } while (_hasMoreArguments());
      case 'T':
        do {
          final (x1, y1) = _reflected(_Previous.quad);
          final (x, y) = _point(relative);
          _quad(x1, y1, x, y);
        } while (_hasMoreArguments());
      case 'A':
        do {
          final rx = _number().abs();
          final ry = _number().abs();
          final rotation = _number();
          final largeArc = _flag();
          final sweep = _flag();
          final (x, y) = _point(relative);
          if (x == _x && y == _y) {
            // Same end point: SVG omits the segment.
          } else if (rx == 0 || ry == 0) {
            _sink.lineTo(x, y);
          } else {
            _sink.arcTo(rx, ry, rotation, largeArc, sweep, x, y);
          }
          _x = x;
          _y = y;
          _previous = _Previous.other;
        } while (_hasMoreArguments());
    }
  }

  void _line(double x, double y) {
    _sink.lineTo(x, y);
    _x = x;
    _y = y;
    _previous = _Previous.other;
  }

  void _cubic(double x1, double y1, double x2, double y2, double x, double y) {
    _sink.cubicTo(x1, y1, x2, y2, x, y);
    _ctrlX = x2;
    _ctrlY = y2;
    _x = x;
    _y = y;
    _previous = _Previous.cubic;
  }

  void _quad(double x1, double y1, double x, double y) {
    _sink.quadTo(x1, y1, x, y);
    _ctrlX = x1;
    _ctrlY = y1;
    _x = x;
    _y = y;
    _previous = _Previous.quad;
  }

  /// The first control point of S/T: the previous one mirrored at the current
  /// point, or the current point after any other kind of segment.
  (double, double) _reflected(_Previous kind) =>
      _previous == kind ? (2 * _x - _ctrlX, 2 * _y - _ctrlY) : (_x, _y);

  (double, double) _point(bool relative) {
    final x = _number();
    final y = _number();
    return relative ? (_x + x, _y + y) : (x, y);
  }

  static bool _isCommand(String c) => 'MmLlHhVvCcSsQqTtAaZz'.contains(c);

  static bool _isDigit(String c) {
    final u = c.codeUnitAt(0);
    return u >= 0x30 && u <= 0x39;
  }

  static bool _isSeparator(String c) =>
      c == ' ' || c == ',' || c == '\n' || c == '\r' || c == '\t' || c == '\f';

  void _skipSeparators() {
    while (_pos < _source.length && _isSeparator(_source[_pos])) {
      _pos++;
    }
  }

  /// Whether another argument set follows (implicit command repetition).
  bool _hasMoreArguments() {
    _skipSeparators();
    if (_pos >= _source.length) return false;
    final c = _source[_pos];
    return _isDigit(c) || c == '-' || c == '+' || c == '.';
  }

  double _number() {
    _skipSeparators();
    final start = _pos;
    final s = _source;
    if (_pos < s.length && (s[_pos] == '-' || s[_pos] == '+')) _pos++;
    var digits = 0;
    while (_pos < s.length && _isDigit(s[_pos])) {
      _pos++;
      digits++;
    }
    // A second '.' starts the next number: "1.5.5" is 1.5 and .5.
    if (_pos < s.length && s[_pos] == '.') {
      _pos++;
      while (_pos < s.length && _isDigit(s[_pos])) {
        _pos++;
        digits++;
      }
    }
    if (digits == 0) {
      throw FormatException('Expected a number', s, start);
    }
    if (_pos < s.length && (s[_pos] == 'e' || s[_pos] == 'E')) {
      var p = _pos + 1;
      if (p < s.length && (s[p] == '-' || s[p] == '+')) p++;
      if (p < s.length && _isDigit(s[p])) {
        _pos = p;
        while (_pos < s.length && _isDigit(s[_pos])) {
          _pos++;
        }
      }
    }
    final value = double.parse(s.substring(start, _pos));
    if (!value.isFinite) {
      throw FormatException('Number out of range', s, start);
    }
    return value;
  }

  /// Arc flags are single characters and need no separator: "a1 1 0 011 1".
  bool _flag() {
    _skipSeparators();
    if (_pos < _source.length) {
      final c = _source[_pos];
      if (c == '0' || c == '1') {
        _pos++;
        return c == '1';
      }
    }
    throw FormatException('Expected an arc flag (0 or 1)', _source, _pos);
  }
}
