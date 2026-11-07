import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// Round author picture with an initial-letter fallback.
///
/// One place for the "first letter of the name" logic, which used to be
/// `name[0]` in several screens and crashed on an empty display name.
class AuthorAvatar extends StatelessWidget {
  final String name;
  final String? avatarUrl;
  final double size;
  final Color? backgroundColor;
  final BoxBorder? border;

  /// Style of the fallback initial. Defaults to a bold letter at ~36% of
  /// [size] in the theme's secondary text colour.
  final TextStyle? initialStyle;

  const AuthorAvatar({
    super.key,
    required this.name,
    this.avatarUrl,
    required this.size,
    this.backgroundColor,
    this.border,
    this.initialStyle,
  });

  /// Upper-cased first character of [name], or '?' when it is empty.
  static String initialOf(String name) {
    final trimmed = name.trim();
    return trimmed.isEmpty ? '?' : trimmed.characters.first.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final initial = Center(
      child: Text(
        initialOf(name),
        style: initialStyle ??
            TextStyle(
              fontSize: size * 0.36,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).textTheme.bodySmall?.color,
            ),
      ),
    );
    final url = avatarUrl;
    final cacheSize = (size * MediaQuery.devicePixelRatioOf(context)).round();

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: backgroundColor,
        border: border,
      ),
      child: url != null && url.isNotEmpty
          ? ClipOval(
              child: CachedNetworkImage(
                imageUrl: url,
                fit: BoxFit.cover,
                memCacheWidth: cacheSize,
                placeholder: (_, __) => initial,
                errorWidget: (_, __, ___) => initial,
              ),
            )
          : initial,
    );
  }
}
