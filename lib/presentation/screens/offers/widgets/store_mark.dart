import 'dart:math' as math;

import 'package:flutter/material.dart' show Theme;
import 'package:flutter/widgets.dart';

import 'package:shoply/core/design/design.dart';
import 'package:shoply/core/localization/localization_helper.dart';
import 'package:shoply/data/models/store_info.dart';
import 'package:shoply/data/services/store_chain_directory.dart';
import 'package:shoply/presentation/providers/store_for_list_provider.dart';

/// Letters on a light brand colour (Edeka, Netto): D2 `label` light, fixed in
/// dark mode too, because the tile keeps its brand colour there.
const Color _kInkOnLight = Color(0xFF1C1C1E); // D2
const Color _kInkOnDark = Color(0xFFFFFFFF); // D2

/// Lidl's letter is its brand yellow on the brand blue (D2, 6,0:1).
const Map<String, Color> _kBrandInk = {'lidl': Color(0xFFFFE500)}; // D2

/// Above this relative luminance a brand colour takes the dark letter.
const double _kLightBrand = 0.4; // D2 letter rule (angebote.md 3.8)

/// D2 tile: radius and letter size relative to the side (18 → 5 and 10).
const double _kRadiusRatio = 5 / 18; // D2
const double _kLetterRatio = 10 / 18; // D2
const double _kOutline = 1; // D2 inner outline of light tiles

/// Fallback for a brand colour without a directory entry: outline above
/// this luminance (as `StoreChain.needsOutlineOn`).
const double _kOutlineLuminance = 0.6; // D2 outline rule (2.3)

/// Side padding of the letters inside the tile, relative to its side.
const double _kLetterInset = 0.08; // D2 "AS" fits an 18-pt tile

/// The tile grows with Dynamic Type up to AX2 (33 / 17), then stays.
const double _kMaxScale = 33 / 17; // D2 AX2 cap (angebote.md 2.3)

/// The D2 letter tile of a market (`angebote.md` 2.3): the brand colour with
/// one or two letters ("L", "AS"), heavy. Light brand colours get a 1-pt
/// inner outline in [AvoColors.uncheckedRing]; a market of the person's own
/// is a [AvoColors.fill] tile with its first letter in [AvoColors.label].
///
/// [size] is 18 (lists, rows), 20 (chips in settings) or 28 (store picker);
/// it grows with Dynamic Type up to AX2. Decorative: the name beside it
/// carries the information, so VoiceOver skips the tile.
class StoreMark extends StatelessWidget {
  /// A tile with [letters] on [color]; [chainId] picks the D2 letter colour.
  const StoreMark({
    super.key,
    required this.letters,
    this.color,
    this.chainId,
    this.size = 18,
  });

  /// The tile of a chain from the directory; an unknown id is a market of
  /// the person's own named [chainId].
  factory StoreMark.chain(String chainId, {Key? key, double size = 18}) {
    final info = storeInfoForChain(chainId);
    return StoreMark(
      key: key,
      letters: info?.shortLabel ?? storeShortLabel(chainId),
      color: info?.brandColor,
      chainId: info?.id,
      size: size,
    );
  }

  /// The tile of [store].
  factory StoreMark.info(StoreInfo store, {Key? key, double size = 18}) =>
      StoreMark(
        key: key,
        letters: store.shortLabel,
        color: store.brandColor,
        chainId: store.id,
        size: size,
      );

  /// A market of the person's own ("Bio Kaiser"): grey tile, first letter.
  factory StoreMark.custom(String name, {Key? key, double size = 18}) =>
      StoreMark(
        key: key,
        letters: name.trim().characters.take(1).toString().toUpperCase(),
        size: size,
      );

  final String letters;

  /// Brand colour; null draws a market of the person's own.
  final Color? color;

  /// Directory id, for the letter colour and the outline rule.
  final String? chainId;

  /// Side at the default text size.
  final double size;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final scale = math.min(
      MediaQuery.textScalerOf(context).scale(size) / size,
      _kMaxScale,
    );
    final side = size * scale;
    final brand = color;
    final Color fill;
    final Color ink;
    var outline = false;
    if (brand == null) {
      fill = colors.fill;
      ink = colors.label;
    } else {
      fill = brand;
      ink =
          _kBrandInk[chainId] ??
          (brand.computeLuminance() > _kLightBrand
              ? _kInkOnLight
              : _kInkOnDark);
      final chain = chainId == null ? null : StoreChainDirectory.byId(chainId!);
      outline =
          chain?.needsOutlineOn(Theme.of(context).brightness) ??
          brand.computeLuminance() > _kOutlineLuminance;
    }
    return ExcludeSemantics(
      child: Container(
        width: side,
        height: side,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: fill,
          borderRadius: BorderRadius.circular(side * _kRadiusRatio),
          border: outline
              ? Border.all(
                  color: colors.uncheckedRing,
                  width: _kOutline,
                  strokeAlign: BorderSide.strokeAlignInside,
                )
              : null,
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: side * _kLetterInset),
            child: Text(
              letters,
              textScaler: TextScaler.noScaling,
              maxLines: 1,
              style: TextStyle(
                inherit: false,
                fontFamily: 'CupertinoSystemText',
                fontSize: side * _kLetterRatio, // D2 letters scale with the mark
                height: 1,
                fontWeight: FontWeight.w900,
                color: ink,
                letterSpacing: 0, // D2
                decoration: TextDecoration.none,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A market as text (Konzept E-01): [StoreMark] 18 and the name in the
/// style of the surrounding row, no capsule, no chevron, not tappable.
/// VoiceOver reads "Markt Lidl".
class StoreLabel extends StatelessWidget {
  const StoreLabel({
    super.key,
    required this.chainId,
    required this.name,
    this.style,
  });

  /// Directory id; an unknown id draws a market of the person's own.
  final String? chainId;

  /// "Lidl".
  final String name;

  /// Text style of the name; defaults to body in `label`.
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final id = chainId;
    final mark = id != null && StoreChainDirectory.byId(id) != null
        ? StoreMark.chain(id)
        : StoreMark.custom(name);
    return Semantics(
      label: '${context.tr('offer_detail_store')} $name',
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          mark,
          const SizedBox(width: AvoSpacing.xs + AvoSpacing.xxs),
          Flexible(
            child: Text(name, style: style ?? context.text(AvoTextStyle.body)),
          ),
        ],
      ),
    );
  }
}
