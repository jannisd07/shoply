import 'package:flutter/material.dart' show Theme;
import 'package:flutter/widgets.dart';

import 'package:cached_network_image/cached_network_image.dart';

import 'package:shoply/core/constants/list_background_gradients.dart';
import 'package:shoply/core/design/design.dart';
import 'package:shoply/core/localization/localization_helper.dart';
import 'package:shoply/data/models/shopping_list_model.dart';
import 'package:shoply/presentation/widgets/design/app_button.dart';
import 'package:shoply/presentation/widgets/design/avo_icons.dart';

/// One list colour of Konzept 00 Kap. 4.3 with its four variants. The light
/// value is what a list stores (`background_type = 'color'`).
@immutable
class ListPaletteColor {
  const ListPaletteColor({
    required this.id,
    required this.light,
    required this.dark,
    required this.lightContrast,
    required this.darkContrast,
  });

  /// Name for VoiceOver (`list_ov_color_<id>`).
  final String id;
  final Color light;
  final Color dark;
  final Color lightContrast;
  final Color darkContrast;

  /// `#RRGGBB` of [light], as stored on the list.
  String get hex =>
      '#${(light.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';

  /// The variant for the current brightness and Increase Contrast.
  Color resolve(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final contrast = MediaQuery.maybeHighContrastOf(context) ?? false;
    if (dark) return contrast ? darkContrast : this.dark;
    return contrast ? lightContrast : light;
  }
}

/// The list palette, in the order new lists take it (Konzept 00 Kap. 4.3:
/// the iOS system colours; data, not screen styling).
const List<ListPaletteColor> kListPalette = [
  ListPaletteColor(
    id: 'blue',
    light: Color(0xFF007AFF),
    dark: Color(0xFF0A84FF),
    lightContrast: Color(0xFF0040DD),
    darkContrast: Color(0xFF409CFF),
  ),
  ListPaletteColor(
    id: 'red',
    light: Color(0xFFFF3B30),
    dark: Color(0xFFFF453A),
    lightContrast: Color(0xFFD70015),
    darkContrast: Color(0xFFFF6961),
  ),
  ListPaletteColor(
    id: 'orange',
    light: Color(0xFFFF9500),
    dark: Color(0xFFFF9F0A),
    lightContrast: Color(0xFFC93400),
    darkContrast: Color(0xFFFFB340),
  ),
  ListPaletteColor(
    id: 'yellow',
    light: Color(0xFFFFCC00),
    dark: Color(0xFFFFD60A),
    lightContrast: Color(0xFFB25000),
    darkContrast: Color(0xFFFFD426),
  ),
  ListPaletteColor(
    id: 'green',
    light: Color(0xFF34C759),
    dark: Color(0xFF30D158),
    lightContrast: Color(0xFF248A3D),
    darkContrast: Color(0xFF30DB5B),
  ),
  ListPaletteColor(
    id: 'mint',
    light: Color(0xFF00C7BE),
    dark: Color(0xFF63E6E2),
    lightContrast: Color(0xFF0C817B),
    darkContrast: Color(0xFF66D4CF),
  ),
  ListPaletteColor(
    id: 'indigo',
    light: Color(0xFF5856D6),
    dark: Color(0xFF5E5CE6),
    lightContrast: Color(0xFF3634A3),
    darkContrast: Color(0xFF7D7AFF),
  ),
  ListPaletteColor(
    id: 'purple',
    light: Color(0xFFAF52DE),
    dark: Color(0xFFBF5AF2),
    lightContrast: Color(0xFF8944AB),
    darkContrast: Color(0xFFDA8FFF),
  ),
  ListPaletteColor(
    id: 'pink',
    light: Color(0xFFFF2D55),
    dark: Color(0xFFFF375F),
    lightContrast: Color(0xFFD30F45),
    darkContrast: Color(0xFFFF6482),
  ),
  ListPaletteColor(
    id: 'brown',
    light: Color(0xFFA2845E),
    dark: Color(0xFFAC8E68),
    lightContrast: Color(0xFF7F6545),
    darkContrast: Color(0xFFB59469),
  ),
  ListPaletteColor(
    id: 'graphite',
    light: Color(0xFF8E8E93),
    dark: Color(0xFF98989D),
    lightContrast: Color(0xFF6C6C70),
    darkContrast: Color(0xFFAEAEB2),
  ),
];

/// The default value `ShoppingListModel.getBackgroundValue` reports for a
/// list that never had a background: treated as "no colour yet".
const String _kUnsetHex = '#000000';

Color? _parseHex(String? value) {
  final hex = value?.trim().replaceFirst('#', '');
  if (hex == null || hex.length != 6) return null;
  final parsed = int.tryParse(hex, radix: 16);
  return parsed == null ? null : Color(0xFF000000 | parsed);
}

/// The palette entry a stored `#RRGGBB` belongs to, or null.
ListPaletteColor? paletteColorOfHex(String? value) {
  final color = _parseHex(value);
  if (color == null) return null;
  for (final p in kListPalette) {
    if (p.light.toARGB32() == color.toARGB32()) return p;
  }
  return null;
}

/// The stored colour of [list] when it is one of the palette colours.
ListPaletteColor? paletteColorOf(ShoppingListModel list) =>
    list.getBackgroundType() == 'color'
    ? paletteColorOfHex(list.getBackgroundValue())
    : null;

/// A stable palette colour for a list without one, so the overview never
/// shows black squares (Konzept 11 §13: "Ohne Hintergrund: Farbe nach
/// Erstellreihenfolge"; the id stands in for the order here).
ListPaletteColor fallbackPaletteColor(String listId) {
  var sum = 0;
  for (final unit in listId.codeUnits) {
    sum = (sum + unit) % 9973;
  }
  return kListPalette[sum % kListPalette.length];
}

/// The URL of the list's photo (owner decision: the cover of the big card),
/// or null.
String? listCoverUrl(ShoppingListModel list) {
  if (list.getBackgroundType() != 'image') return null;
  final url = list.backgroundImageUrl?.trim();
  return url == null || url.isEmpty ? null : url;
}

/// The colour a list is drawn in, resolved for the current appearance:
/// a palette colour (with its dark and contrast variants), another stored
/// `#RRGGBB`, the first colour of an old gradient, blue for a photo list
/// (Konzept 11 §13), else [fallbackPaletteColor].
Color listDisplayColor(BuildContext context, ShoppingListModel list) {
  final type = list.getBackgroundType();
  final value = list.getBackgroundValue();
  if (type == 'color' && value != null && value != _kUnsetHex) {
    final palette = paletteColorOfHex(value);
    if (palette != null) return palette.resolve(context);
    final raw = _parseHex(value);
    if (raw != null) return raw;
  }
  if (type == 'gradient' && value != null) {
    final gradient = ListBackgroundGradients.gradients[value];
    if (gradient != null && gradient.colors.isNotEmpty) {
      return gradient.colors.first;
    }
  }
  if (type == 'image') return kListPalette.first.resolve(context);
  return fallbackPaletteColor(list.id).resolve(context);
}

/// The first palette colour no list uses yet (Konzept 00 Kap. 4.3), else
/// the one after the most used.
ListPaletteColor nextFreePaletteColor(List<ShoppingListModel> lists) {
  final used = <String>{};
  for (final l in lists) {
    final p = paletteColorOf(l);
    if (p != null) used.add(p.id);
  }
  for (final p in kListPalette) {
    if (!used.contains(p.id)) return p;
  }
  return kListPalette[lists.length % kListPalette.length];
}

/// The list's symbol on its colour: a circle (Konzept 11 §8/§10: glyph 64 or
/// 36 pt) with a white cart, or the list photo. Decorative for VoiceOver.
class ListGlyph extends StatelessWidget {
  const ListGlyph({
    super.key,
    required this.color,
    this.coverUrl,
    this.size = 64,
  });

  /// Fill of the circle (already resolved, see [listDisplayColor]).
  final Color color;

  /// Shows the list photo instead of the coloured circle.
  final String? coverUrl;

  /// Diameter; the cart is 45 % of it.
  final double size;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final url = coverUrl;
    final circle = DecoratedBox(
      decoration: ShapeDecoration(color: color, shape: const CircleBorder()),
      child: SizedBox.square(
        dimension: size,
        child: Center(
          child: AvoIcon(AvoIcons.cart, size: size * 0.45, color: colors.onTint),
        ),
      ),
    );
    final Widget visual = url == null
        ? circle
        : ClipOval(
            child: SizedBox.square(
              dimension: size,
              child: Image(
                image: CachedNetworkImageProvider(url),
                fit: BoxFit.cover,
                excludeFromSemantics: true,
                errorBuilder: (context, error, stack) => circle,
              ),
            ),
          );
    return ExcludeSemantics(child: visual);
  }
}

/// Colour circles to pick a list colour (Konzept 11 §8/§10: 30 pt circles
/// on 44 pt targets in a `Wrap`, the chosen one with a 2 pt ring in `label`
/// at 2 pt distance). With [photoUrl] a first circle shows the list photo
/// ("Foto"), chosen while the list keeps its photo.
class ListColorPicker extends StatelessWidget {
  const ListColorPicker({
    super.key,
    required this.selectedId,
    required this.onSelected,
    this.photoUrl,
    this.onPhotoSelected,
  });

  /// Palette id of the chosen colour; null while the photo (or a colour from
  /// outside the palette) is in use.
  final String? selectedId;

  final ValueChanged<ListPaletteColor> onSelected;

  /// The list's photo; adds the "Foto" choice.
  final String? photoUrl;

  /// Keeps the photo (only with [photoUrl]).
  final VoidCallback? onPhotoSelected;

  static const double _circle = 30; // Konzept 11 §8
  static const double _ring = 2; // Konzept 11 §8
  static const double _ringGap = 2; // Konzept 11 §8

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final photo = photoUrl;
    Widget choice({
      required String label,
      required bool selected,
      required VoidCallback onTap,
      required Widget face,
    }) {
      return Semantics(
        button: true,
        selected: selected,
        inMutuallyExclusiveGroup: true,
        label: label,
        onTap: onTap,
        excludeSemantics: true,
        child: PressableScale(
          onPressed: onTap,
          child: SizedBox.square(
            dimension: AvoSizes.hitTarget,
            child: Center(
              child: DecoratedBox(
                decoration: ShapeDecoration(
                  shape: CircleBorder(
                    side: selected
                        ? BorderSide(color: colors.label, width: _ring)
                        : BorderSide.none,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(_ring + _ringGap),
                  child: SizedBox.square(dimension: _circle, child: face),
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AvoSpacing.s,
        vertical: AvoSpacing.xs,
      ),
      child: Wrap(
        children: [
          if (photo != null)
            choice(
              label: context.tr('list_ov_photo'),
              selected: selectedId == null,
              onTap: onPhotoSelected ?? () {},
              face: ClipOval(
                child: Image(
                  image: CachedNetworkImageProvider(photo),
                  fit: BoxFit.cover,
                  excludeFromSemantics: true,
                  errorBuilder: (context, error, stack) =>
                      ColoredBox(color: colors.fill),
                ),
              ),
            ),
          for (final p in kListPalette)
            choice(
              label: context.tr('list_ov_color_${p.id}'),
              selected: p.id == selectedId,
              onTap: () => onSelected(p),
              face: DecoratedBox(
                decoration: ShapeDecoration(
                  color: p.resolve(context),
                  shape: const CircleBorder(),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
