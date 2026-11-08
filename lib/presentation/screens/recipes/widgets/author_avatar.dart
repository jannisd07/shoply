import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/widgets.dart';

import 'package:shoply/core/design/design.dart';
import 'package:shoply/presentation/widgets/design/avatar.dart';

/// Glyph size of the initial relative to the circle (D2 avatars: 11 pt in
/// 24 pt, 15 pt in 32 pt).
const double _kInitialFactor = 0.42;

/// A recipe creator as a round photo, or as their initial in the D2
/// [Avatar] look (accent on the soft accent fill) while there is no photo,
/// while it loads and when it fails (Konzept 00 §12.29, 13 §8.6).
///
/// At 20, 24 and 32 pt without a photo it is the design-system [Avatar]
/// itself. Other sizes (36 in rows, 64 on the creator page) draw the same
/// circle. The glyph keeps its size under Dynamic Type like iOS avatars; the
/// text next to it grows. Decorative for VoiceOver unless [semanticLabel] is
/// set, because rows and headers already say the name.
class AuthorAvatar extends StatelessWidget {
  /// Creates an avatar for [name].
  const AuthorAvatar({
    super.key,
    required this.name,
    this.avatarUrl,
    required this.size,
    this.backgroundColor,
    this.border,
    this.initialStyle,
    this.semanticLabel,
  });

  /// Display name; its first letter is the fallback.
  final String name;

  /// Photo URL; null or empty shows the initial.
  final String? avatarUrl;

  /// Diameter in points.
  final double size;

  /// Fill behind the initial; defaults to [AvoColors.tintSoft].
  final Color? backgroundColor;

  /// Optional ring.
  final BoxBorder? border;

  /// Style of the initial; defaults to semibold in [AvoColors.tint].
  final TextStyle? initialStyle;

  /// VoiceOver text; null hides the avatar from VoiceOver.
  final String? semanticLabel;

  /// Upper-cased first character of [name], or '?' when it is empty.
  static String initialOf(String name) {
    final trimmed = name.trim();
    return trimmed.isEmpty ? '?' : trimmed.characters.first.toUpperCase();
  }

  static AvatarSize? _designSize(double size) {
    for (final s in AvatarSize.values) {
      if (s.dimension == size) return s;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final url = avatarUrl;
    final hasPhoto = url != null && url.isNotEmpty;
    final designSize = _designSize(size);
    final plain =
        backgroundColor == null && border == null && initialStyle == null;

    final Widget visual;
    if (!hasPhoto && designSize != null && plain) {
      visual = Avatar(name: name, size: designSize);
    } else {
      final initial = _Initial(
        name: name,
        size: size,
        background: backgroundColor,
        style: initialStyle,
      );
      final cacheSize = (size * MediaQuery.devicePixelRatioOf(context)).round();
      visual = Container(
        width: size,
        height: size,
        decoration: BoxDecoration(shape: BoxShape.circle, border: border),
        child: ClipOval(
          child: hasPhoto
              ? CachedNetworkImage(
                  imageUrl: url,
                  fit: BoxFit.cover,
                  memCacheWidth: cacheSize,
                  fadeInDuration: AvoMotion.fadeReduced,
                  fadeOutDuration: Duration.zero,
                  placeholder: (_, _) => initial,
                  errorWidget: (_, _, _) => initial,
                )
              : initial,
        ),
      );
    }

    final label = semanticLabel;
    if (label == null) return ExcludeSemantics(child: visual);
    return Semantics(
      label: label,
      image: true,
      child: ExcludeSemantics(child: visual),
    );
  }
}

/// The initial on the soft accent fill.
class _Initial extends StatelessWidget {
  const _Initial({
    required this.name,
    required this.size,
    this.background,
    this.style,
  });

  final String name;
  final double size;
  final Color? background;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final glyph =
        style ??
        context
            .text(
              AvoTextStyle.body,
              weight: FontWeight.w600,
              color: colors.tint,
            )
            .copyWith(fontSize: size * _kInitialFactor, height: 1);
    return ColoredBox(
      color: background ?? colors.tintSoft,
      child: SizedBox.square(
        dimension: size,
        child: Center(
          child: MediaQuery.withNoTextScaling(
            child: Text(
              AuthorAvatar.initialOf(name),
              maxLines: 1,
              softWrap: false,
              textAlign: TextAlign.center,
              style: glyph,
            ),
          ),
        ),
      ),
    );
  }
}
