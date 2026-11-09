import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:shoply/core/design/design.dart';
import 'package:shoply/presentation/widgets/design/avo_icons.dart';

/// Minimum height of a field capsule (Konzept 17 §3.6: capsule `fill`, same
/// height as the sign-in buttons of §3.5).
const double kAuthFieldMinHeight = 50;

/// Inner side padding of a field capsule: half the height, so the text
/// starts where the round end does.
const double _kFieldSidePadding = 20;

/// Outline of a field that shows an error (Konzept 17 §3.7: "Feld wird
/// markiert, nicht geleert").
const double _kErrorOutline = 1.5;

/// Footnote size at the default category, the reference for scaling the
/// error symbol with Dynamic Type.
const double _kFootnoteAtLarge = 13;

/// Error symbol at the default size (SF Symbols next to 13 pt text).
const double _kErrorSymbol = 15;

/// A text field as a `fill` capsule (Konzept 17 §3.6–3.8, §4.4).
///
/// No fixed height: at least 50 pt, it grows with Dynamic Type; long text
/// scrolls sideways inside the field. With [error] the capsule gets a red
/// outline. [label] is the VoiceOver name; [placeholder] the visible hint.
class AuthTextField extends StatelessWidget {
  const AuthTextField({
    super.key,
    required this.controller,
    required this.label,
    this.focusNode,
    this.placeholder,
    this.keyboardType,
    this.textInputAction,
    this.autofillHints,
    this.autofocus = false,
    this.obscureText = false,
    this.autocorrect = false,
    this.textCapitalization = TextCapitalization.none,
    this.inputFormatters,
    this.onChanged,
    this.onSubmitted,
    this.textAlign = TextAlign.start,
    this.style,
    this.placeholderStyle,
    this.suffix,
    this.error = false,
    this.readOnly = false,
  });

  final TextEditingController controller;
  final String label;
  final FocusNode? focusNode;
  final String? placeholder;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final Iterable<String>? autofillHints;
  final bool autofocus;
  final bool obscureText;
  final bool autocorrect;
  final TextCapitalization textCapitalization;
  final List<TextInputFormatter>? inputFormatters;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final TextAlign textAlign;

  /// Text style; `body` by default.
  final TextStyle? style;

  /// Placeholder style; `body` in `placeholder` by default.
  final TextStyle? placeholderStyle;

  /// Trailing widget inside the capsule (eye button, activity indicator).
  final Widget? suffix;

  /// Marks the field with a red outline.
  final bool error;

  final bool readOnly;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textStyle = style ?? context.text(AvoTextStyle.body);
    // Styles carry the unscaled size; the text scaler applies on top.
    final line =
        MediaQuery.textScalerOf(context).scale(textStyle.fontSize ?? 17) *
        (textStyle.height ?? 1.3);
    final vertical = math.max(0.0, (kAuthFieldMinHeight - line) / 2);

    final field = Semantics(
      label: label,
      textField: true,
      child: CupertinoTextField(
        controller: controller,
        focusNode: focusNode,
        placeholder: placeholder,
        placeholderStyle:
            placeholderStyle ??
            context.text(AvoTextStyle.body, color: colors.placeholder),
        style: textStyle,
        cursorColor: colors.tint,
        decoration: null,
        padding: EdgeInsetsDirectional.fromSTEB(
          _kFieldSidePadding,
          vertical,
          suffix == null ? _kFieldSidePadding : AvoSpacing.xs,
          vertical,
        ),
        keyboardType: keyboardType,
        textInputAction: textInputAction,
        autofillHints: autofillHints,
        autofocus: autofocus,
        obscureText: obscureText,
        autocorrect: autocorrect,
        enableSuggestions: autocorrect,
        textCapitalization: textCapitalization,
        inputFormatters: inputFormatters,
        onChanged: onChanged,
        onSubmitted: onSubmitted,
        textAlign: textAlign,
        readOnly: readOnly,
        maxLines: 1,
      ),
    );

    return DecoratedBox(
      decoration: ShapeDecoration(
        color: colors.fill,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(kAuthFieldMinHeight / 2),
          side: error
              ? BorderSide(color: colors.destructive, width: _kErrorOutline)
              : BorderSide.none,
        ),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: kAuthFieldMinHeight),
        child: Row(
          children: [
            Expanded(child: field),
            if (suffix != null) ...[
              suffix!,
              const SizedBox(width: AvoSpacing.xs),
            ],
          ],
        ),
      ),
    );
  }
}

/// The red line under a field (Konzept 17 §3.6, §3.7): symbol and one
/// sentence in `footnote` `destructive`, announced when it appears.
class FieldErrorLine extends StatelessWidget {
  const FieldErrorLine(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final line = typography.lineHeightOf(AvoTextStyle.footnote);
    final symbol =
        _kErrorSymbol *
        typography.sizeOf(AvoTextStyle.footnote) /
        _kFootnoteAtLarge;
    return Semantics(
      liveRegion: true,
      container: true,
      label: text,
      child: ExcludeSemantics(
        child: Padding(
          padding: const EdgeInsets.only(top: AvoSpacing.s),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: line,
                child: Center(
                  widthFactor: 1,
                  child: AvoIcon(
                    AvoIcons.exclamationmarkCircle,
                    size: symbol,
                    color: colors.destructive,
                  ),
                ),
              ),
              const SizedBox(width: AvoSpacing.xs + AvoSpacing.xxs),
              Expanded(
                child: Text(
                  text,
                  style: context.text(
                    AvoTextStyle.footnote,
                    color: colors.destructive,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A trailing 44 pt symbol button inside a field ("Passwort anzeigen").
class FieldSymbolButton extends StatelessWidget {
  const FieldSymbolButton({
    super.key,
    required this.icon,
    required this.semanticLabel,
    required this.onPressed,
  });

  final AvoIconData icon;
  final String semanticLabel;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final size = context.typography.sizeOf(AvoTextStyle.body) * 1.15;
    return Semantics(
      button: true,
      label: semanticLabel,
      onTap: onPressed,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        excludeFromSemantics: true,
        onTap: onPressed,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minWidth: AvoSizes.hitTarget,
            minHeight: AvoSizes.hitTarget,
          ),
          child: Center(
            widthFactor: 1,
            heightFactor: 1,
            child: AvoIcon(
              icon,
              size: size,
              color: context.colors.secondaryLabel,
            ),
          ),
        ),
      ),
    );
  }
}

/// Lets [child] reach [bleed] points past both side edges, for components
/// that bring their own page margin (`StatusRow`, `InsetSection`) inside the
/// already padded content of `OnboardingStepPage`. Without it they would sit
/// 32 pt from the screen edge instead of 16.
class FullBleed extends SingleChildRenderObjectWidget {
  const FullBleed({super.key, this.bleed = AvoSpacing.screen, super.child});

  final double bleed;

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderBleed(bleed);

  @override
  void updateRenderObject(
    BuildContext context,
    covariant RenderObject renderObject,
  ) {
    (renderObject as _RenderBleed).bleed = bleed;
  }
}

class _RenderBleed extends RenderShiftedBox {
  _RenderBleed(this._bleed) : super(null);

  double _bleed;
  set bleed(double value) {
    if (value == _bleed) return;
    _bleed = value;
    markNeedsLayout();
  }

  BoxConstraints _childConstraints(BoxConstraints c) => BoxConstraints(
    minWidth: c.minWidth + 2 * _bleed,
    maxWidth: c.maxWidth + 2 * _bleed,
    minHeight: c.minHeight,
    maxHeight: c.maxHeight,
  );

  @override
  double computeMinIntrinsicHeight(double width) =>
      child?.getMinIntrinsicHeight(width + 2 * _bleed) ?? 0;

  @override
  double computeMaxIntrinsicHeight(double width) =>
      child?.getMaxIntrinsicHeight(width + 2 * _bleed) ?? 0;

  @override
  double computeMinIntrinsicWidth(double height) =>
      math.max(0, (child?.getMinIntrinsicWidth(height) ?? 0) - 2 * _bleed);

  @override
  double computeMaxIntrinsicWidth(double height) =>
      math.max(0, (child?.getMaxIntrinsicWidth(height) ?? 0) - 2 * _bleed);

  @override
  Size computeDryLayout(covariant BoxConstraints constraints) {
    final child = this.child;
    if (child == null) return constraints.smallest;
    final size = child.getDryLayout(_childConstraints(constraints));
    return constraints.constrain(Size(size.width - 2 * _bleed, size.height));
  }

  @override
  void performLayout() {
    final child = this.child;
    if (child == null) {
      size = constraints.smallest;
      return;
    }
    child.layout(_childConstraints(constraints), parentUsesSize: true);
    (child.parentData! as BoxParentData).offset = Offset(-_bleed, 0);
    size = constraints.constrain(
      Size(child.size.width - 2 * _bleed, child.size.height),
    );
  }

  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) {
    // The bleed areas belong to the child too.
    final inside =
        position.dx >= -_bleed &&
        position.dx < size.width + _bleed &&
        position.dy >= 0 &&
        position.dy < size.height;
    if (!inside) return false;
    if (hitTestChildren(result, position: position)) {
      result.add(BoxHitTestEntry(this, position));
      return true;
    }
    return false;
  }
}
