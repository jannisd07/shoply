import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shoply/core/design/design.dart';

/// The cooking mode is always dark, also on a light iPhone (Konzept 13
/// §16.1, K-25): the D2 dark tokens (black background, white text, dark
/// surfaces), with Increase Contrast honoured. Wrap every screen the
/// cooking mode opens (overview, servings) in it.
class CookingModeTheme extends StatelessWidget {
  const CookingModeTheme({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final highContrast = MediaQuery.maybeHighContrastOf(context) ?? false;
    final colors = AvoColors.resolve(
      Brightness.dark,
      highContrast: highContrast,
    );
    final base = Theme.of(context);
    final theme = base.copyWith(
      brightness: Brightness.dark,
      colorScheme: base.colorScheme.copyWith(brightness: Brightness.dark),
      scaffoldBackgroundColor: colors.background,
      extensions: [
        for (final e in base.extensions.values)
          if (e is! AvoColors) e,
        colors,
      ],
    );
    return Theme(
      data: theme,
      child: CupertinoTheme(
        data: CupertinoThemeData(
          brightness: Brightness.dark,
          primaryColor: colors.tint,
          scaffoldBackgroundColor: colors.background,
        ),
        child: MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(platformBrightness: Brightness.dark),
          child: AnnotatedRegion<SystemUiOverlayStyle>(
            value: SystemUiOverlayStyle.light,
            child: child,
          ),
        ),
      ),
    );
  }
}
