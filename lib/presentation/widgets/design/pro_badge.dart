import 'package:flutter/widgets.dart';

import 'package:shoply/core/design/design.dart';
import 'package:shoply/core/localization/localization_helper.dart';

/// Vertical padding inside the capsule (D2 X-Pro plan pill: 2 / 8).
const double _kVerticalPadding = 2; // D2

/// Outline width of the [ProBadge.onTint] variant.
const double _kOnTintBorder = 1; // D2 (no value given; one point reads on tint)

/// The badge follows Dynamic Type up to AX2 only, the text next to it keeps
/// growing (Konzept 00 §6.4). Linear factor of AX2: body 33 pt / 17 pt.
const double _kMaxTextScale = 33 / 17;

/// Small "Pro" capsule placed right after a feature name (Konzept 00 §12.30,
/// optics from D2 X-Pro).
///
/// Never used for offers. The badge itself is not tappable: the row or button
/// around it opens the paywall. VoiceOver reads "Pro feature"
/// (`common_pro_feature`) instead of the visible "Pro"; wrap the feature name
/// and the badge in a [MergeSemantics] (or build one label, as `NavRow` does)
/// so the phrase is appended to the name.
class ProBadge extends StatelessWidget {
  /// Creates the badge. Its text comes from `common_pro`.
  const ProBadge({super.key, this.onTint = false});

  /// The badge sits on a tinted fill (a primary button, glass-tint): white
  /// text on a transparent capsule with a white outline instead of tint text
  /// on `tintSoft`.
  final bool onTint;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: context.tr('common_pro_feature'),
      child: ExcludeSemantics(
        child: MediaQuery.withClampedTextScaling(
          maxScaleFactor: _kMaxTextScale,
          child: Builder(builder: _buildCapsule),
        ),
      ),
    );
  }

  Widget _buildCapsule(BuildContext context) {
    final colors = context.colors;
    return DecoratedBox(
      decoration: ShapeDecoration(
        color: onTint ? null : colors.tintSoft,
        shape: StadiumBorder(
          side: onTint
              ? BorderSide(color: colors.onTint, width: _kOnTintBorder)
              : BorderSide.none,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AvoSpacing.s,
          vertical: _kVerticalPadding,
        ),
        child: Text(
          context.tr('common_pro'),
          style: context.text(
            AvoTextStyle.caption2,
            color: onTint ? colors.onTint : colors.tint,
            weight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
