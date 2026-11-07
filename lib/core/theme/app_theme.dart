import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:shoply/core/design/avo_colors.dart';

/// Material and Cupertino themes built from the D2 tokens ([AvoColors]).
///
/// On iOS `AdaptiveApp` builds a `CupertinoApp`, which ignores Material
/// themes. `app.dart` therefore passes [cupertinoLight]/[cupertinoDark] to it
/// and additionally wraps every route in a Material `Theme` with [light]/
/// [dark], so leftover Material widgets (TextField, InkWell, dialogs) follow
/// the tokens too. Screens themselves read `context.colors` and
/// `context.text(...)` (lib/core/design/design.dart), never this theme.
abstract final class AppTheme {
  static final ThemeData lightTheme = _material(
    AvoColors.light,
    Brightness.light,
  );
  static final ThemeData darkTheme = _material(AvoColors.dark, Brightness.dark);

  static final CupertinoThemeData cupertinoLight = _cupertino(
    AvoColors.light,
    Brightness.light,
  );
  static final CupertinoThemeData cupertinoDark = _cupertino(
    AvoColors.dark,
    Brightness.dark,
  );

  /// The Material theme for [brightness].
  static ThemeData of(Brightness brightness) =>
      brightness == Brightness.dark ? darkTheme : lightTheme;

  static ThemeData _material(AvoColors c, Brightness brightness) {
    final scheme = ColorScheme(
      brightness: brightness,
      primary: c.tintFill,
      onPrimary: c.onTint,
      primaryContainer: c.tintSoft,
      onPrimaryContainer: c.tint,
      secondary: c.tint,
      onSecondary: c.onTint,
      error: c.destructive,
      onError: c.onTint,
      surface: c.surface,
      onSurface: c.label,
      onSurfaceVariant: c.secondaryLabel,
      surfaceContainerLowest: c.background,
      surfaceContainerHighest: c.surfaceRaised,
      outline: c.separator,
      outlineVariant: c.separator,
      shadow: c.shadow,
      scrim: c.scrim,
    );
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: c.background,
      canvasColor: c.background,
      dividerColor: c.separator,
      splashFactory: NoSplash.splashFactory,
      highlightColor: Colors.transparent,
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: c.tint,
        selectionColor: c.tint.withValues(alpha: 0.25),
        selectionHandleColor: c.tint,
      ),
      dividerTheme: DividerThemeData(
        color: c.separator,
        thickness: 0.5,
        space: 0.5,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: c.background,
        foregroundColor: c.label,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: c.surfaceRaised,
        surfaceTintColor: Colors.transparent,
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.android: CupertinoPageTransitionsBuilder(),
        },
      ),
      extensions: const [],
    );
  }

  static CupertinoThemeData _cupertino(AvoColors c, Brightness brightness) =>
      CupertinoThemeData(
        brightness: brightness,
        primaryColor: c.tint,
        primaryContrastingColor: c.onTint,
        scaffoldBackgroundColor: c.background,
        barBackgroundColor: c.glassFallback,
        textTheme: CupertinoTextThemeData(primaryColor: c.tint),
      );
}
