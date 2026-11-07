import 'package:flutter/material.dart';

/// Colour tokens of the D2 "Glas" design (light values read off the
/// `D2-Komponenten` artboard; dark and Increase Contrast derived so every
/// text pair keeps at least 4.5:1, see test/core/design/avo_colors_test.dart).
///
/// Screens never use hex values: they read `context.colors.<token>` (see
/// `design.dart`). Works under the CupertinoApp that `AdaptiveApp` builds on
/// iOS, because it resolves from `Theme.of(context).brightness` and
/// `MediaQuery.highContrastOf(context)`, not from a Material theme.
@immutable
class AvoColors extends ThemeExtension<AvoColors> {
  const AvoColors({
    required this.background,
    required this.backgroundPlain,
    required this.surface,
    required this.surfaceRaised,
    required this.label,
    required this.secondaryLabel,
    required this.tertiaryLabel,
    required this.placeholder,
    required this.separator,
    required this.fill,
    required this.fillStrong,
    required this.tint,
    required this.tintPressed,
    required this.tintFill,
    required this.onTint,
    required this.tintSoft,
    required this.tintIcon,
    required this.destructive,
    required this.red,
    required this.uncheckedRing,
    required this.chipSelected,
    required this.onChipSelected,
    required this.glassFill,
    required this.glassBorder,
    required this.glassTintFill,
    required this.glassTintBorder,
    required this.glassFallback,
    required this.shadow,
    required this.scrim,
    required this.presence,
  });

  /// Grouped screen background (D2 `groupedBg`).
  final Color background;

  /// Plain screen background (D2 Rezepte).
  final Color backgroundPlain;

  /// Groups, cards, rows.
  final Color surface;

  /// Surfaces on top of [surface] (menus, dark-mode cards on cards).
  final Color surfaceRaised;

  /// Primary text and glyphs.
  final Color label;

  /// Meta text, section caps.
  final Color secondaryLabel;

  /// Inactive tab items, meta text on glass.
  final Color tertiaryLabel;

  /// Text-field placeholder.
  final Color placeholder;

  /// Hairlines (0.5 pt) and progress tracks.
  final Color separator;

  /// Inactive chips, stepper and segment tracks.
  final Color fill;

  /// Pressed state of [fill].
  final Color fillStrong;

  /// Accent for text, links, icons, progress.
  final Color tint;

  /// Pressed accent text.
  final Color tintPressed;

  /// Accent fills carrying white text (primary buttons, check fill).
  final Color tintFill;

  /// Text and glyphs on [tintFill] and [glassTintFill].
  final Color onTint;

  /// Light accent surface (offer pill, initials).
  final Color tintSoft;

  /// Filled icon of the active tab.
  final Color tintIcon;

  /// Destructive text ("Liste löschen").
  final Color destructive;

  /// Error and badge fills.
  final Color red;

  /// Ring of an unchecked check circle.
  final Color uncheckedRing;

  final Color chipSelected;
  final Color onChipSelected;

  /// `.glass`: translucent white over content.
  final Color glassFill;
  final Color glassBorder;

  /// `.glass-tint`: the one primary action on glass.
  final Color glassTintFill;
  final Color glassTintBorder;

  /// Opaque replacement for glass (Reduce Transparency, older iOS).
  final Color glassFallback;

  /// Base colour of soft shadows.
  final Color shadow;

  /// Dimming behind centred dialogs.
  final Color scrim;

  /// "Someone is shopping right now" dot.
  final Color presence;

  // --------------------------------------------------------------- variants

  static const light = AvoColors(
    background: Color(0xFFF2F2F7),
    backgroundPlain: Color(0xFFFFFFFF),
    surface: Color(0xFFFFFFFF),
    surfaceRaised: Color(0xFFFFFFFF),
    label: Color(0xFF1C1C1E),
    secondaryLabel: Color(0xFF6C6C70),
    tertiaryLabel: Color(0xFF3A3A3C),
    placeholder: Color(0xFF6C6C70),
    separator: Color(0xFFE5E5EA),
    fill: Color(0x1F787880), // rgba(120,120,128,.12)
    fillStrong: Color(0x33787880),
    tint: Color(0xFF1F7A3A),
    tintPressed: Color(0xFF165C2B),
    tintFill: Color(0xFF1F7A3A),
    onTint: Color(0xFFFFFFFF),
    tintSoft: Color(0xFFE7F3EA),
    tintIcon: Color(0xFF2E8B47),
    destructive: Color(0xFFD70015),
    red: Color(0xFFFF3B30),
    // D2 value; 1.68:1 on white. The owner decides whether it may darken
    // (status-A.md, "Fragen an den Owner"). Increase Contrast uses a 3:1 ring.
    uncheckedRing: Color(0xFFC7C7CC),
    chipSelected: Color(0xFF1C1C1E),
    onChipSelected: Color(0xFFFFFFFF),
    glassFill: Color(0xA3FFFFFF), // .64
    glassBorder: Color(0xBFFFFFFF), // .75
    glassTintFill: Color(0xE01F7A3A), // .88
    glassTintBorder: Color(0x59FFFFFF), // .35
    glassFallback: Color(0xFFF9F9FB),
    shadow: Color(0xFF000000),
    scrim: Color(0x66000000),
    presence: Color(0xFF34C759),
  );

  static const dark = AvoColors(
    background: Color(0xFF000000),
    backgroundPlain: Color(0xFF000000),
    surface: Color(0xFF1C1C1E),
    surfaceRaised: Color(0xFF2C2C2E),
    label: Color(0xFFFFFFFF),
    secondaryLabel: Color(0xFFAEAEB2),
    tertiaryLabel: Color(0xFFD1D1D6),
    placeholder: Color(0xFFAEAEB2),
    separator: Color(0xFF38383A),
    fill: Color(0x3D787880), // rgba(120,120,128,.24)
    fillStrong: Color(0x52787880),
    tint: Color(0xFF4CC46E),
    tintPressed: Color(0xFF6FD58A),
    tintFill: Color(0xFF1F7A3A),
    onTint: Color(0xFFFFFFFF),
    tintSoft: Color(0xFF16301E),
    tintIcon: Color(0xFF4CC46E),
    destructive: Color(0xFFFF6961),
    red: Color(0xFFFF453A),
    uncheckedRing: Color(0xFF7C7C80),
    chipSelected: Color(0xFFFFFFFF),
    onChipSelected: Color(0xFF000000),
    glassFill: Color(0x8C2C2C2E), // .55
    glassBorder: Color(0x26FFFFFF), // .15
    glassTintFill: Color(0xE01F7A3A),
    glassTintBorder: Color(0x40FFFFFF),
    glassFallback: Color(0xFF2C2C2E),
    shadow: Color(0xFF000000),
    scrim: Color(0x8C000000),
    presence: Color(0xFF30D158),
  );

  static const lightHighContrast = AvoColors(
    background: Color(0xFFF2F2F7),
    backgroundPlain: Color(0xFFFFFFFF),
    surface: Color(0xFFFFFFFF),
    surfaceRaised: Color(0xFFFFFFFF),
    label: Color(0xFF000000),
    secondaryLabel: Color(0xFF3A3A3C),
    tertiaryLabel: Color(0xFF1C1C1E),
    placeholder: Color(0xFF3A3A3C),
    separator: Color(0xFFAEAEB2),
    fill: Color(0x33787880),
    fillStrong: Color(0x4D787880),
    tint: Color(0xFF145A28),
    tintPressed: Color(0xFF0E441E),
    tintFill: Color(0xFF145A28),
    onTint: Color(0xFFFFFFFF),
    tintSoft: Color(0xFFE7F3EA),
    tintIcon: Color(0xFF145A28),
    destructive: Color(0xFFA50011),
    red: Color(0xFFD70015),
    uncheckedRing: Color(0xFF6C6C70),
    chipSelected: Color(0xFF000000),
    onChipSelected: Color(0xFFFFFFFF),
    glassFill: Color(0xF2FFFFFF),
    glassBorder: Color(0xFF6C6C70),
    glassTintFill: Color(0xFF145A28),
    glassTintBorder: Color(0xFF0E441E),
    glassFallback: Color(0xFFFFFFFF),
    shadow: Color(0xFF000000),
    scrim: Color(0x80000000),
    presence: Color(0xFF248A3D),
  );

  static const darkHighContrast = AvoColors(
    background: Color(0xFF000000),
    backgroundPlain: Color(0xFF000000),
    surface: Color(0xFF1C1C1E),
    surfaceRaised: Color(0xFF2C2C2E),
    label: Color(0xFFFFFFFF),
    secondaryLabel: Color(0xFFE5E5EA),
    tertiaryLabel: Color(0xFFF2F2F7),
    placeholder: Color(0xFFE5E5EA),
    separator: Color(0xFF8E8E93),
    fill: Color(0x52787880),
    fillStrong: Color(0x66787880),
    tint: Color(0xFF7EE29A),
    tintPressed: Color(0xFFA3EDB8),
    tintFill: Color(0xFF145A28),
    onTint: Color(0xFFFFFFFF),
    tintSoft: Color(0xFF16301E),
    tintIcon: Color(0xFF7EE29A),
    destructive: Color(0xFFFF8A84),
    red: Color(0xFFFF6961),
    uncheckedRing: Color(0xFFAEAEB2),
    chipSelected: Color(0xFFFFFFFF),
    onChipSelected: Color(0xFF000000),
    glassFill: Color(0xF22C2C2E),
    glassBorder: Color(0xFFAEAEB2),
    glassTintFill: Color(0xFF145A28),
    glassTintBorder: Color(0xFF7EE29A),
    glassFallback: Color(0xFF2C2C2E),
    shadow: Color(0xFF000000),
    scrim: Color(0xA6000000),
    presence: Color(0xFF30DB5B),
  );

  /// Picks the variant for [brightness] and Increase Contrast.
  static AvoColors resolve(Brightness brightness, {bool highContrast = false}) {
    if (brightness == Brightness.dark) {
      return highContrast ? darkHighContrast : dark;
    }
    return highContrast ? lightHighContrast : light;
  }

  /// The tokens for [context]. A [ThemeExtension] in the nearest Material
  /// `Theme` wins (gallery, tests); otherwise brightness and contrast decide.
  static AvoColors of(BuildContext context) {
    final theme = Theme.of(context);
    final fromTheme = theme.extension<AvoColors>();
    if (fromTheme != null) return fromTheme;
    return resolve(
      theme.brightness,
      highContrast: MediaQuery.maybeHighContrastOf(context) ?? false,
    );
  }

  @override
  AvoColors copyWith() => this;

  @override
  AvoColors lerp(covariant AvoColors? other, double t) {
    if (other == null) return this;
    Color l(Color a, Color b) => Color.lerp(a, b, t)!;
    return AvoColors(
      background: l(background, other.background),
      backgroundPlain: l(backgroundPlain, other.backgroundPlain),
      surface: l(surface, other.surface),
      surfaceRaised: l(surfaceRaised, other.surfaceRaised),
      label: l(label, other.label),
      secondaryLabel: l(secondaryLabel, other.secondaryLabel),
      tertiaryLabel: l(tertiaryLabel, other.tertiaryLabel),
      placeholder: l(placeholder, other.placeholder),
      separator: l(separator, other.separator),
      fill: l(fill, other.fill),
      fillStrong: l(fillStrong, other.fillStrong),
      tint: l(tint, other.tint),
      tintPressed: l(tintPressed, other.tintPressed),
      tintFill: l(tintFill, other.tintFill),
      onTint: l(onTint, other.onTint),
      tintSoft: l(tintSoft, other.tintSoft),
      tintIcon: l(tintIcon, other.tintIcon),
      destructive: l(destructive, other.destructive),
      red: l(red, other.red),
      uncheckedRing: l(uncheckedRing, other.uncheckedRing),
      chipSelected: l(chipSelected, other.chipSelected),
      onChipSelected: l(onChipSelected, other.onChipSelected),
      glassFill: l(glassFill, other.glassFill),
      glassBorder: l(glassBorder, other.glassBorder),
      glassTintFill: l(glassTintFill, other.glassTintFill),
      glassTintBorder: l(glassTintBorder, other.glassTintBorder),
      glassFallback: l(glassFallback, other.glassFallback),
      shadow: l(shadow, other.shadow),
      scrim: l(scrim, other.scrim),
      presence: l(presence, other.presence),
    );
  }
}
