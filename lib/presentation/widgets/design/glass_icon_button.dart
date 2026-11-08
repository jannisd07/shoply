import 'package:flutter/widgets.dart';
import 'package:shoply/core/design/design.dart';
import 'package:shoply/presentation/widgets/design/app_button.dart';
import 'package:shoply/presentation/widgets/design/glass_surface.dart';
import 'package:shoply/presentation/widgets/design/avo_icons.dart';

const double _iconSize = 22; // D2 toolbar icons (chevron, share, more)
const double _disabledOpacity = 0.4; // Konzept 00 §12.20
// D2 group: padding 0 4 around 40 × 44 buttons. The buttons here get the
// full 44 × 44 hit area instead; for two items the capsule stays 88 wide.
const double _groupMinWidth = 48; // D2 4 + 40 + 4 for a single item

/// A 44 pt glass circle with one icon: back, close, "new list" (D2 toolbar).
///
/// [tinted] gives the green `.glass-tint` circle with a white icon for the
/// screen's primary action. The icon is decorative for VoiceOver;
/// [semanticLabel] names the action. Pressed: 0.97 scale on touch down.
/// Disabled ([onPressed] null): 40 % opacity. Never triggers haptics.
class GlassIconButton extends StatelessWidget {
  /// Creates a round glass button.
  const GlassIconButton({
    super.key,
    required this.icon,
    required this.semanticLabel,
    this.onPressed,
    this.tinted = false,
    this.floating = true,
  });

  /// The glyph, drawn 22 pt in [AvoColors.label] (or [AvoColors.onTint]
  /// when [tinted]) unless the widget sets its own size or colour.
  final Widget icon;

  /// What VoiceOver reads, for example "Zurück" or "Neue Liste".
  final String semanticLabel;

  /// Called on tap. Null disables the button.
  final VoidCallback? onPressed;

  /// Green `.glass-tint` circle for the primary action.
  final bool tinted;

  /// True (default) on the floating layer, where the native glass may be
  /// used. False inside scrolling content (on a photo): pseudo glass
  /// without a platform view.
  final bool floating;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final enabled = onPressed != null;
    final face = SizedBox.square(
      dimension: AvoSizes.toolbarButton,
      child: Center(
        child: IconStyleScope(
          size: _iconSize,
          color: tinted ? colors.onTint : colors.label,
          child: icon,
        ),
      ),
    );

    Widget surface = floating
        ? GlassSurface(shape: GlassShape.circle, tinted: tinted, child: face)
        : ContentGlass(
            radius: AvoRadii.capsule(AvoSizes.toolbarButton),
            tinted: tinted,
            child: face,
          );
    if (!enabled) surface = Opacity(opacity: _disabledOpacity, child: surface);

    return Semantics(
      container: true,
      button: true,
      enabled: enabled,
      label: semanticLabel,
      onTap: onPressed,
      excludeSemantics: true,
      child: PressableScale(onPressed: onPressed, child: surface),
    );
  }
}

/// One button of a [GlassButtonGroup].
@immutable
class GlassGroupItem {
  /// Describes one icon button in a group.
  const GlassGroupItem({
    required this.icon,
    required this.semanticLabel,
    this.onPressed,
  });

  /// The glyph, drawn 22 pt in [AvoColors.label] unless it sets its own.
  final Widget icon;

  /// What VoiceOver reads, for example "Teilen" or "Mehr".
  final String semanticLabel;

  /// Called on tap. Null disables this button only.
  final VoidCallback? onPressed;
}

/// Several icon buttons sharing one glass capsule (D2 toolbar "Teilen" +
/// "Mehr"): 44 pt high, radius 22, icons 22 pt.
///
/// Every button has a 44 × 44 pt hit area. Each one is its own VoiceOver
/// button; the capsule is decorative. Lives on the floating layer only.
class GlassButtonGroup extends StatelessWidget {
  /// Creates a capsule of [items].
  const GlassButtonGroup({super.key, required this.items});

  /// The buttons, leading to trailing.
  final List<GlassGroupItem> items;

  @override
  Widget build(BuildContext context) {
    return GlassSurface(
      shape: GlassShape.capsule,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: _groupMinWidth),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [for (final item in items) _GroupButton(item: item)],
        ),
      ),
    );
  }
}

class _GroupButton extends StatelessWidget {
  const _GroupButton({required this.item});

  final GlassGroupItem item;

  @override
  Widget build(BuildContext context) {
    final enabled = item.onPressed != null;
    Widget face = SizedBox.square(
      dimension: AvoSizes.hitTarget,
      child: Center(
        child: IconStyleScope(
          size: _iconSize,
          color: context.colors.label,
          child: item.icon,
        ),
      ),
    );
    if (!enabled) face = Opacity(opacity: _disabledOpacity, child: face);

    return Semantics(
      container: true,
      button: true,
      enabled: enabled,
      label: item.semanticLabel,
      onTap: item.onPressed,
      excludeSemantics: true,
      child: PressableScale(onPressed: item.onPressed, child: face),
    );
  }
}
