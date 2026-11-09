import 'package:flutter/cupertino.dart';
import 'package:flutter/physics.dart';
import 'package:shoply/core/design/design.dart';
import 'package:shoply/presentation/widgets/design/glass_surface.dart';
import 'package:shoply/presentation/widgets/design/avo_icons.dart';

// Konzept 00 §12.20.
const double _pressedOpacity = 0.9;
const double _disabledOpacity = 0.4;

// D2 "Buttons": capsule 44 high, padding 0 18 0 14, gap 6, icon 18.
const double _largeHeight = 54; // D2 cover buttons ("Einkauf abschließen")
const double _sidePadding = 18; // D2
const double _iconSidePadding = 14; // D2
const double _largeSidePadding = 24; // D2 has no padding for 54 pt; derived
const double _largeIconSidePadding = 20; // derived like 18 -> 14
const double _iconGap = 6; // D2
const double _iconRegular = 18; // D2 (with 15 pt label)
const double _iconLarge = 20; // derived (with 17 pt label)
// Vertical padding = (height - line height) / 2 at the default text size.
const double _verticalRegular = 12; // D2 (44 - 20) / 2
const double _verticalLarge = 16; // D2 (54 - 22) / 2

/// Shrinks its child to [AvoMotion.pressedScale] at 90 % opacity the moment
/// a finger goes down, and springs back on release or cancel.
///
/// The motion is an [AvoMotion.quick] spring that always starts from the
/// current value and velocity, so it can be interrupted at any frame. With
/// Reduce Motion only the opacity changes, as a short fade. Never triggers
/// haptics. Adds no semantics: wrap it in a [Semantics] with the action.
class PressableScale extends StatefulWidget {
  /// Creates a pressable area around [child].
  const PressableScale({
    super.key,
    required this.child,
    required this.onPressed,
    this.enabled = true,
  });

  /// What shrinks while pressed.
  final Widget child;

  /// Called on tap. Null makes the area inert.
  final VoidCallback? onPressed;

  /// False blocks taps without changing the look (busy buttons).
  final bool enabled;

  @override
  State<PressableScale> createState() => _PressableScaleState();
}

class _PressableScaleState extends State<PressableScale>
    with SingleTickerProviderStateMixin {
  late final AnimationController _press = AnimationController(vsync: this);
  bool _reduceMotion = false;

  bool get _active => widget.enabled && widget.onPressed != null;

  @override
  void didUpdateWidget(covariant PressableScale oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_active && _press.value > 0) _animateTo(0);
  }

  @override
  void dispose() {
    _press.dispose();
    super.dispose();
  }

  void _animateTo(double target) {
    if (_reduceMotion) {
      _press.animateTo(
        target,
        duration: AvoMotion.fadeReduced,
        curve: Curves.easeOut,
      );
    } else {
      _press
          .animateWith(
            SpringSimulation(
              AvoMotion.quick,
              _press.value,
              target,
              _press.velocity,
            ),
          )
          // A spring stops within its tolerance; land exactly on the target
          // so the resting button carries no transform. An interrupted
          // spring never completes, so this cannot fight a newer one.
          .then((_) {
            if (mounted) _press.value = target;
          });
    }
  }

  @override
  Widget build(BuildContext context) {
    _reduceMotion = context.reduceMotion;
    final active = _active;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      excludeFromSemantics: true,
      onTapDown: active ? (_) => _animateTo(1) : null,
      onTapUp: active ? (_) => _animateTo(0) : null,
      onTapCancel: active ? () => _animateTo(0) : null,
      onTap: active ? widget.onPressed : null,
      child: AnimatedBuilder(
        animation: _press,
        child: widget.child,
        builder: (context, child) {
          final t = _press.value;
          final scale = _reduceMotion
              ? 1.0
              : 1 - (1 - AvoMotion.pressedScale) * t;
          final opacity = 1 - (1 - _pressedOpacity) * t;
          return Transform.scale(
            scale: scale,
            child: Opacity(opacity: opacity, child: child),
          );
        },
      ),
    );
  }
}

/// Height and type size of an [AppButton].
enum AppButtonSize {
  /// At least 44 pt high, 15/20 semibold label, 18 pt icon (D2 "Zutaten auf
  /// die Liste").
  regular,

  /// At least 54 pt high, 17/22 semibold label (D2 "Einkauf abschließen").
  large,
}

enum _AppButtonVariant {
  primary,
  secondary,
  plain,
  destructive,
  filledNeutral,
  destructiveFilled,
}

/// The app's text buttons (Konzept 00 §12.20, D2 "Buttons").
///
/// - [AppButton.primary]: green `.glass-tint` capsule, the one main action.
/// - [AppButton.secondary]: white glass capsule.
/// - [AppButton.plain]: tint text, 17/22 ("Alle anzeigen").
/// - [AppButton.destructive]: red text, 17/22 ("Liste löschen").
/// - [AppButton.filledNeutral]: grey fill, `label` text ("Abbrechen").
/// - [AppButton.destructiveFilled]: red fill, white text ("Löschen").
///
/// States: pressed (0.97 scale and 90 % opacity on touch down), disabled
/// ([onPressed] null: 40 % opacity, VoiceOver "dimmed"), working (a small
/// activity indicator replaces the icon, the width stays, taps are blocked).
/// Long labels and accessibility text sizes wrap instead of being cut; the
/// capsule then becomes a rounded rectangle with a 22 pt radius.
/// Never triggers haptics.
class AppButton extends StatelessWidget {
  /// Green `.glass-tint` capsule for the one primary action of a screen.
  ///
  /// Inside content it is an opaque tint fill; set [floating] when it floats
  /// over content (toolbar, bottom of a cover) to get the native glass.
  const AppButton.primary({
    super.key,
    required this.label,
    this.icon,
    this.onPressed,
    this.working = false,
    this.size = AppButtonSize.regular,
    this.expand = false,
    this.floating = false,
    this.workingLabel,
  }) : _variant = _AppButtonVariant.primary;

  /// White glass capsule with a [AvoColors.label] text ("Teilen").
  ///
  /// Inside content it uses [ContentGlass]; set [floating] when it floats
  /// over content to get the native glass.
  const AppButton.secondary({
    super.key,
    required this.label,
    this.icon,
    this.onPressed,
    this.working = false,
    this.size = AppButtonSize.regular,
    this.expand = false,
    this.floating = false,
    this.workingLabel,
  }) : _variant = _AppButtonVariant.secondary;

  /// Text-only button in [AvoColors.tint], 17/22 ("Alle anzeigen").
  const AppButton.plain({
    super.key,
    required this.label,
    this.icon,
    this.onPressed,
    this.working = false,
    this.size = AppButtonSize.regular,
    this.expand = false,
    this.workingLabel,
  }) : floating = false,
       _variant = _AppButtonVariant.plain;

  /// Text-only button in [AvoColors.destructive], 17/22 ("Liste löschen").
  /// Pair it with a confirmation dialog only for final actions.
  const AppButton.destructive({
    super.key,
    required this.label,
    this.icon,
    this.onPressed,
    this.working = false,
    this.size = AppButtonSize.regular,
    this.expand = false,
    this.workingLabel,
  }) : floating = false,
       _variant = _AppButtonVariant.destructive;

  /// Grey capsule ([AvoColors.fill]) with [AvoColors.label] text, same sizes
  /// as [AppButton.primary]. Opaque (the grey is blended onto
  /// [AvoColors.surface]), no glass ("Abbrechen").
  const AppButton.filledNeutral({
    super.key,
    required this.label,
    this.icon,
    this.onPressed,
    this.working = false,
    this.size = AppButtonSize.regular,
    this.expand = false,
    this.workingLabel,
  }) : floating = false,
       _variant = _AppButtonVariant.filledNeutral;

  /// Red capsule ([AvoColors.destructiveFill]) with white text, same sizes as
  /// [AppButton.primary] ("Löschen"). Pair it with a confirmation only for
  /// final actions.
  const AppButton.destructiveFilled({
    super.key,
    required this.label,
    this.icon,
    this.onPressed,
    this.working = false,
    this.size = AppButtonSize.regular,
    this.expand = false,
    this.workingLabel,
  }) : floating = false,
       _variant = _AppButtonVariant.destructiveFilled;

  /// The visible text, also the VoiceOver label.
  final String label;

  /// Optional leading glyph, drawn at the label colour and a size that
  /// follows Dynamic Type. Decorative for VoiceOver.
  final Widget? icon;

  /// Called on tap. Null disables the button.
  final VoidCallback? onPressed;

  /// Shows a small activity indicator in place of the icon (over the label
  /// when there is no icon), keeps the width and blocks taps.
  final bool working;

  /// [AppButtonSize.regular] (44 pt) or [AppButtonSize.large] (54 pt).
  final AppButtonSize size;

  /// Fills the available width. Needs a bounded width.
  final bool expand;

  /// Primary and secondary only: the button floats over content and may use
  /// the native glass ([GlassSurface]). Leave false inside scrolling content.
  final bool floating;

  /// VoiceOver value while [working], for example "In progress". Announced
  /// through a live region. Pass a translated text from the screen.
  final String? workingLabel;

  final _AppButtonVariant _variant;

  bool get _filled =>
      _variant != _AppButtonVariant.plain &&
      _variant != _AppButtonVariant.destructive;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final large = size == AppButtonSize.large;
    final filled = _filled;
    final enabled = onPressed != null;

    final foreground = switch (_variant) {
      _AppButtonVariant.primary => colors.onTint,
      _AppButtonVariant.secondary => colors.label,
      _AppButtonVariant.plain => colors.tint,
      _AppButtonVariant.destructive => colors.destructive,
      _AppButtonVariant.filledNeutral => colors.label,
      _AppButtonVariant.destructiveFilled => colors.onTint,
    };
    final textKind = filled && !large
        ? AvoTextStyle.subhead
        : AvoTextStyle.body;
    final textStyle = context.text(
      textKind,
      color: foreground,
      weight: filled ? FontWeight.w600 : null,
    );

    // Icons follow Dynamic Type like SF Symbols next to text.
    final baseIcon = filled && !large ? _iconRegular : _iconLarge;
    final iconSize =
        baseIcon *
        context.typography.sizeOf(textKind) /
        AvoTypography.forFactor(1).sizeOf(textKind);

    final indicator = SizedBox.square(
      dimension: iconSize,
      child: Center(
        child: CupertinoActivityIndicator(
          radius: iconSize / 2,
          color: foreground,
        ),
      ),
    );

    Widget? leading;
    if (icon != null) {
      leading = working
          ? indicator
          : SizedBox.square(
              dimension: iconSize,
              child: Center(
                child: IconStyleScope(
                  size: iconSize,
                  color: foreground,
                  child: icon!,
                ),
              ),
            );
    }

    Widget text = Text(label, style: textStyle, textAlign: TextAlign.center);
    if (working && icon == null) {
      // No icon to replace: the indicator sits where the label was, and the
      // invisible label keeps the width.
      text = Stack(
        alignment: Alignment.center,
        children: [
          Opacity(opacity: 0, child: text),
          Positioned.fill(child: Center(child: indicator)),
        ],
      );
    }

    final EdgeInsetsGeometry padding;
    if (filled) {
      final vertical = large ? _verticalLarge : _verticalRegular;
      final side = large ? _largeSidePadding : _sidePadding;
      final iconSide = large ? _largeIconSidePadding : _iconSidePadding;
      padding = EdgeInsetsDirectional.fromSTEB(
        leading != null ? iconSide : side,
        vertical,
        side,
        vertical,
      );
    } else {
      padding = const EdgeInsets.symmetric(vertical: AvoSpacing.s);
    }

    Widget box = ConstrainedBox(
      constraints: BoxConstraints(
        minHeight: large ? _largeHeight : AvoSizes.hitTarget,
        minWidth: expand ? double.infinity : AvoSizes.hitTarget,
      ),
      child: Padding(
        padding: padding,
        child: Center(
          widthFactor: 1,
          heightFactor: 1,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (leading != null) ...[
                leading,
                const SizedBox(width: _iconGap),
              ],
              Flexible(child: text),
            ],
          ),
        ),
      ),
    );

    if (filled) {
      final tinted = _variant == _AppButtonVariant.primary;
      final radius = _radius(context, large);
      final solid = switch (_variant) {
        _AppButtonVariant.filledNeutral => Color.alphaBlend(
          colors.fill,
          colors.surface,
        ),
        _AppButtonVariant.destructiveFilled => colors.destructiveFill,
        _ => null,
      };
      if (solid != null) {
        box = DecoratedBox(
          decoration: BoxDecoration(
            color: solid,
            borderRadius: BorderRadius.circular(radius),
          ),
          child: box,
        );
      } else {
        box = floating
            ? GlassSurface(
                shape: GlassShape.rounded,
                radius: radius,
                tinted: tinted,
                child: box,
              )
            : ContentGlass(radius: radius, tinted: tinted, child: box);
      }
    }

    if (!enabled) box = Opacity(opacity: _disabledOpacity, child: box);

    return Semantics(
      container: true,
      button: true,
      enabled: enabled,
      label: label,
      value: working ? workingLabel : null,
      liveRegion: working ? true : null,
      onTap: enabled && !working ? onPressed : null,
      excludeSemantics: true,
      child: PressableScale(
        onPressed: onPressed,
        enabled: !working,
        child: box,
      ),
    );
  }

  /// Half the minimum height, so a one-line button is a capsule. Taller
  /// buttons (wrapped labels) keep it as a rounded rectangle; at
  /// accessibility sizes the large button drops to 22 pt as well.
  static double _radius(BuildContext context, bool large) =>
      large && !context.isAccessibilityText
      ? AvoRadii.capsule(_largeHeight)
      : AvoRadii.capsule(AvoSizes.hitTarget);
}
