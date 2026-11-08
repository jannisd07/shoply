import 'package:flutter/widgets.dart';

import 'package:shoply/core/design/design.dart';
import 'package:shoply/core/localization/localization_helper.dart';
import 'package:shoply/presentation/widgets/design/app_button.dart';
import 'package:shoply/presentation/widgets/design/avo_icons.dart';
import 'package:shoply/presentation/widgets/design/glass_icon_button.dart';
import 'package:shoply/presentation/widgets/design/glass_surface.dart';
import 'package:shoply/presentation/widgets/design/glass_toolbar.dart';

// D2 X-Einkaufsmodus "Bildschirm bleibt an": capsule 32 high, padding 0 12,
// gap 6, clock 14 pt (stroke 2.2), 13 pt semibold.
const double _chipHeight = 32; // D2
const double _chipPadding = AvoSpacing.m; // D2 12
const double _chipGap = 6; // D2
const double _chipIcon = 14; // D2
const double _footnoteAtLarge = 13; // footnote size at the default category

/// Clock in the glass circle from AX1 on (toolbar glyph size).
const double _clockAx = 22;

/// The finish capsule with only its check mark (from AX3 on): D2 height,
/// glyph a little larger than the label icon, dimmed like `AppButton`.
const double _finishHeight = 54; // D2
const double _finishIcon = 26;
const double _disabledOpacity = 0.4; // Konzept 00 §12.20

/// Space between the "+" circle and the finish capsule.
const double _barGap = AvoSpacing.m;

/// D2: the finish capsule rests 28 pt above the bottom edge on a 34 pt home
/// indicator area, 8 pt below where the tab bar would sit.
const double _barAboveTabBarBottom = AvoSpacing.s;

/// The top row of the shopping mode: glass back button and the "Bildschirm
/// bleibt an" capsule (D2 X-Einkaufsmodus). Place it at
/// [GlassToolbar.topOffset].
///
/// [twin] draws the same layout without glass (no platform view) for the
/// invisible spacer at the start of the scroll view.
class ShoppingTopBar extends StatelessWidget {
  /// Creates the top row.
  const ShoppingTopBar({
    super.key,
    required this.onBack,
    this.screenOn = true,
    this.twin = false,
  });

  /// Leaves the shopping mode.
  final VoidCallback onBack;

  /// Whether the screen is kept on (shows the capsule).
  final bool screenOn;

  /// Layout only, for the spacer.
  final bool twin;

  @override
  Widget build(BuildContext context) {
    return GlassToolbar(
      leading: twin
          ? const SizedBox.square(dimension: AvoSizes.toolbarButton)
          : GlassIconButton(
              icon: const AvoIcon(AvoIcons.chevronBack),
              semanticLabel: context.tr('back'),
              onPressed: onBack,
            ),
      trailing: [if (screenOn) ScreenOnChip(twin: twin)],
    );
  }
}

/// The glass capsule "Bildschirm bleibt an" with a clock (D2). Information,
/// not a button: VoiceOver reads "Der Bildschirm bleibt an, solange du
/// einkaufst". From AX1 on only the clock shows, in a 44 pt glass circle, so
/// the top row does not grow into the content.
class ScreenOnChip extends StatelessWidget {
  /// Creates the capsule.
  const ScreenOnChip({super.key, this.twin = false});

  /// Without glass (layout spacer).
  final bool twin;

  @override
  Widget build(BuildContext context) {
    final ax = context.isAccessibilityText;
    final Widget face;
    if (ax) {
      face = const SizedBox.square(
        dimension: AvoSizes.toolbarButton,
        child: Center(child: AvoIcon(AvoIcons.clock, size: _clockAx)),
      );
    } else {
      final icon =
          _chipIcon *
          context.typography.sizeOf(AvoTextStyle.footnote) /
          _footnoteAtLarge;
      face = ConstrainedBox(
        constraints: const BoxConstraints(minHeight: _chipHeight),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: _chipPadding,
            vertical: AvoSpacing.xs,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AvoIcon(AvoIcons.clock, size: icon),
              const SizedBox(width: _chipGap),
              Flexible(
                child: Text(
                  context.tr('list_shop_screen_on'),
                  style: context.text(
                    AvoTextStyle.footnote,
                    weight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }
    return Semantics(
      container: true,
      label: context.tr('list_shop_screen_on_label'),
      child: ExcludeSemantics(
        child: twin
            ? face
            : GlassSurface(
                shape: ax ? GlassShape.circle : GlassShape.capsule,
                child: face,
              ),
      ),
    );
  }
}

/// The floating bottom of the shopping mode: a glass "+" to add an item and
/// the tinted capsule "Einkauf abschließen" (D2, 54 pt). [onFinish] null
/// dims the capsule (nothing checked yet). From AX1 on the capsule says
/// "Abschließen", from AX3 on it shows only the check mark; VoiceOver keeps
/// the full label.
///
/// [twin] draws the same layout without glass for the spacer at the end of
/// the scroll view.
class ShoppingBottomBar extends StatelessWidget {
  /// Creates the bottom bar.
  const ShoppingBottomBar({
    super.key,
    required this.onAdd,
    required this.onFinish,
    this.twin = false,
  });

  /// Adds an item (Konzept 11 §5.3).
  final VoidCallback onAdd;

  /// Opens the checkout; null while nothing is checked.
  final VoidCallback? onFinish;

  /// Layout only, for the spacer.
  final bool twin;

  /// Distance of the bar's bottom edge from the screen bottom.
  static double bottomOffset(BuildContext context) =>
      ShellInsets.tabBarBottom(context) + _barAboveTabBarBottom;

  @override
  Widget build(BuildContext context) {
    final full = context.tr('list_shop_finish');
    final category = context.typography.category;
    final Widget finish;
    if (category.index >= ContentSizeCategory.ax3.index) {
      finish = _FinishIconCapsule(label: full, onPressed: onFinish, twin: twin);
    } else {
      final short = category.isAccessibility;
      final button = AppButton.primary(
        label: short ? context.tr('list_shop_finish_short') : full,
        // AvoIcon does not read the IconTheme: colour it like the label.
        icon: AvoIcon(AvoIcons.check, color: context.colors.onTint),
        onPressed: onFinish,
        size: AppButtonSize.large,
        expand: true,
        floating: !twin,
      );
      finish = short
          ? Semantics(
              container: true,
              button: true,
              enabled: onFinish != null,
              label: full,
              onTap: onFinish,
              excludeSemantics: true,
              child: button,
            )
          : button;
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AvoSpacing.screen),
      child: Row(
        children: [
          GlassIconButton(
            icon: const AvoIcon(AvoIcons.plus),
            semanticLabel: context.tr('list_shop_add'),
            onPressed: onAdd,
            floating: !twin,
          ),
          const SizedBox(width: _barGap),
          Expanded(child: finish),
        ],
      ),
    );
  }
}

/// The tinted 54 pt capsule with only the check mark, from AX3 on (Konzept
/// 11 §5.2, E-08): the label would wrap into a tall block over the list.
/// VoiceOver reads [label].
class _FinishIconCapsule extends StatelessWidget {
  const _FinishIconCapsule({
    required this.label,
    required this.onPressed,
    required this.twin,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool twin;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    final face = SizedBox(
      height: _finishHeight,
      width: double.infinity,
      child: Center(
        child: AvoIcon(
          AvoIcons.check,
          size: _finishIcon,
          color: context.colors.onTint,
        ),
      ),
    );
    final radius = AvoRadii.capsule(_finishHeight);
    Widget surface = twin
        ? ContentGlass(radius: radius, tinted: true, child: face)
        : GlassSurface(
            shape: GlassShape.rounded,
            radius: radius,
            tinted: true,
            child: face,
          );
    if (!enabled) surface = Opacity(opacity: _disabledOpacity, child: surface);
    return Semantics(
      container: true,
      button: true,
      enabled: enabled,
      label: label,
      onTap: onPressed,
      excludeSemantics: true,
      child: PressableScale(onPressed: onPressed, child: surface),
    );
  }
}
