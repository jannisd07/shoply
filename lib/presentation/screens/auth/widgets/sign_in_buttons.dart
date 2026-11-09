import 'package:flutter/cupertino.dart';
import 'package:shoply/core/design/design.dart';
import 'package:shoply/presentation/screens/auth/widgets/google_logo.dart';
import 'package:shoply/presentation/widgets/design/app_button.dart';
import 'package:shoply/presentation/widgets/design/avo_icons.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart' show AppleLogoPainter;

/// The three sign-in buttons of Konzept 17 §3.5: at least 50 pt high, full
/// width, capsule, text `headline`. They wrap from AX3 with the symbol at
/// the first line and never cut the label.
const double _kMinHeight = 50;
const double _kRadius = _kMinHeight / 2;
const double _kSidePadding = 20;
const double _kIconGap = AvoSpacing.s;

/// Symbol size next to the 17 pt label at the default text size.
const double _kIconSize = 20;

/// Headline size at the default category, the reference for scaling the
/// symbol with Dynamic Type.
const double _kHeadlineAtLarge = 17;

/// Disabled look of the other buttons while one is working (Konzept 00
/// §12.20).
const double _kDisabledOpacity = 0.4;

// Google's button colours (Konzept 17 §9.9: partner brand data, not tokens).
const Color _kGoogleFillLight = Color(0xFFFFFFFF); // brand data
const Color _kGoogleStrokeLight = Color(0xFF747775); // brand data
const Color _kGoogleFillDark = Color(0xFF131314); // brand data
const Color _kGoogleStrokeDark = Color(0xFF8E918F); // brand data
const double _kGoogleStroke = 1; // brand data

// Apple's button: black in light mode, white in dark mode (Apple HIG).
const Color _kAppleBlack = Color(0xFF000000); // brand data
const Color _kAppleWhite = Color(0xFFFFFFFF); // brand data

/// Width-to-height ratio of the Apple logo of `AppleLogoPainter`.
const double _kAppleLogoRatio = 25 / 31;

bool _isDark(BuildContext context) =>
    context.colors.background.computeLuminance() < 0.5;

/// "Mit Apple fortfahren": black in light mode, white in dark mode, the
/// Apple logo from the `sign_in_with_apple` package.
class AppleSignInButton extends StatelessWidget {
  const AppleSignInButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.working = false,
    this.workingLabel,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool working;
  final String? workingLabel;

  @override
  Widget build(BuildContext context) {
    final dark = _isDark(context);
    final foreground = dark ? _kAppleBlack : _kAppleWhite;
    return _SignInButtonShell(
      label: label,
      onPressed: onPressed,
      working: working,
      workingLabel: workingLabel,
      fill: dark ? _kAppleWhite : _kAppleBlack,
      foreground: foreground,
      icon: (size) => SizedBox(
        width: size * _kAppleLogoRatio,
        height: size,
        child: CustomPaint(painter: AppleLogoPainter(color: foreground)),
      ),
    );
  }
}

/// "Mit Google fortfahren" after Google's brand rules: white with a grey
/// outline (dark: near black with a lighter outline), the coloured "G".
class GoogleSignInButton extends StatelessWidget {
  const GoogleSignInButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.working = false,
    this.workingLabel,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool working;
  final String? workingLabel;

  @override
  Widget build(BuildContext context) {
    final dark = _isDark(context);
    return _SignInButtonShell(
      label: label,
      onPressed: onPressed,
      working: working,
      workingLabel: workingLabel,
      fill: dark ? _kGoogleFillDark : _kGoogleFillLight,
      outline: dark ? _kGoogleStrokeDark : _kGoogleStrokeLight,
      foreground: context.colors.label,
      icon: (size) => GoogleMark(size: size),
    );
  }
}

/// "Mit E-Mail fortfahren": grey `fill` capsule with the envelope.
class EmailSignInButton extends StatelessWidget {
  const EmailSignInButton({
    super.key,
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return _SignInButtonShell(
      label: label,
      onPressed: onPressed,
      fill: colors.fill,
      foreground: colors.label,
      icon: (size) =>
          AvoIcon(AvoIcons.envelope, size: size, color: colors.label),
    );
  }
}

class _SignInButtonShell extends StatelessWidget {
  const _SignInButtonShell({
    required this.label,
    required this.onPressed,
    required this.fill,
    required this.foreground,
    required this.icon,
    this.outline,
    this.working = false,
    this.workingLabel,
  });

  final String label;
  final VoidCallback? onPressed;
  final Color fill;
  final Color foreground;
  final Color? outline;
  final Widget Function(double size) icon;
  final bool working;
  final String? workingLabel;

  @override
  Widget build(BuildContext context) {
    final typography = context.typography;
    final enabled = onPressed != null;
    final line = typography.lineHeightOf(AvoTextStyle.headline);
    final iconSize =
        _kIconSize * typography.sizeOf(AvoTextStyle.headline) / _kHeadlineAtLarge;
    final vertical = ((_kMinHeight - line) / 2).clamp(0.0, _kMinHeight);

    final leading = SizedBox(
      height: line,
      width: iconSize,
      child: Center(
        child: working
            ? CupertinoActivityIndicator(radius: iconSize / 2, color: foreground)
            : icon(iconSize),
      ),
    );

    Widget box = DecoratedBox(
      decoration: ShapeDecoration(
        color: fill,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(_kRadius),
          side: outline == null
              ? BorderSide.none
              : BorderSide(color: outline!, width: _kGoogleStroke),
        ),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          minHeight: _kMinHeight,
          minWidth: double.infinity,
        ),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: _kSidePadding,
            vertical: vertical,
          ),
          child: Center(
            widthFactor: 1,
            heightFactor: 1,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                leading,
                const SizedBox(width: _kIconGap),
                Flexible(
                  child: Text(
                    label,
                    textAlign: TextAlign.center,
                    style: context.text(
                      AvoTextStyle.headline,
                      color: foreground,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (!enabled && !working) {
      box = Opacity(opacity: _kDisabledOpacity, child: box);
    }

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
}
