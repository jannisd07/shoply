import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shoply/data/models/recipe.dart';
import 'package:shoply/presentation/state/saved_recipes_provider.dart';

/// A recipe tile in Apple's photo-card style: the image fills the whole card
/// and the title sits on top of it, bottom-left, over a gradient scrim.
///
/// Replaces the previous "image on top, white text block underneath" layout.
/// Two details do the heavy lifting:
///
///  * The scrim is a gradient, not a flat overlay. Photos vary wildly — a
///    bright dish and a dark one both have to keep white text readable — and
///    a uniform veil either greys out the good photos or fails on the bright
///    ones.
///  * Corners use [BorderRadius] with a continuous curve to match the
///    squircle iOS uses everywhere else in the app.
class RecipeImageCard extends ConsumerWidget {
  final Recipe recipe;
  final VoidCallback onTap;

  /// Fixed width for horizontal carousels; null lets the parent decide
  /// (grids pass their own constraints).
  final double? width;

  /// Height of the tile. Carousels use a fixed height; grids rely on their
  /// own aspect ratio and pass null.
  final double? height;

  final EdgeInsets margin;

  /// Whether to show the save/bookmark control.
  final bool showBookmark;

  /// Short chip drawn on the image, e.g. a diet/allergy compatibility badge.
  /// Never omit this to save space — a warning that quietly disappears is
  /// worse than a busier card.
  final String? badgeText;
  final Color? badgeColor;

  /// One line under the title, e.g. "45 min · Wikibooks".
  final String? metaLine;

  const RecipeImageCard({
    super.key,
    required this.recipe,
    required this.onTap,
    this.width,
    this.height,
    this.margin = EdgeInsets.zero,
    this.showBookmark = true,
    this.badgeText,
    this.badgeColor,
    this.metaLine,
  });

  static const double _radius = 18;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isSaved = ref.watch(isRecipeSavedProvider(recipe.id));

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: width,
        height: height,
        margin: margin,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(_radius),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.18),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(_radius),
          child: Stack(
            fit: StackFit.expand,
            children: [
              CachedNetworkImage(
                imageUrl: recipe.imageUrl,
                fit: BoxFit.cover,
                placeholder: (_, __) => const _ImageFallback(),
                errorWidget: (_, __, ___) => const _ImageFallback(),
              ),

              // Readability scrim: only the lower half is darkened, so the
              // photo itself stays as vivid as in the Photos app.
              const Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.center,
                      end: Alignment.bottomCenter,
                      colors: [
                        Color(0x00000000),
                        Color(0x99000000),
                      ],
                    ),
                  ),
                ),
              ),

              Positioned(
                left: 12,
                right: 12,
                bottom: 10,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      recipe.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        height: 1.2,
                        shadows: [
                          // Backstop for the rare photo that is bright right
                          // where the text sits.
                          Shadow(color: Color(0x66000000), blurRadius: 6),
                        ],
                      ),
                    ),
                    if (metaLine != null && metaLine!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        metaLine!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xE6FFFFFF),
                          fontSize: 11.5,
                          height: 1.2,
                          shadows: [
                            Shadow(color: Color(0x66000000), blurRadius: 6),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              if (badgeText != null && badgeText!.isNotEmpty)
                Positioned(
                  top: 10,
                  left: 10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: (badgeColor ?? Colors.black).withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      badgeText!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),

              if (showBookmark)
                Positioned(
                  top: 8,
                  right: 8,
                  child: _BookmarkButton(
                    isSaved: isSaved,
                    onTap: () {
                      HapticFeedback.lightImpact();
                      ref
                          .read(savedRecipesProvider.notifier)
                          .toggleSave(recipe.id);
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ImageFallback extends StatelessWidget {
  const _ImageFallback();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF2C2C2E),
      child: const Center(
        child: Icon(Icons.restaurant_rounded, color: Colors.white38, size: 28),
      ),
    );
  }
}

/// Glass circle over the photo, sized to a 44pt touch target while staying
/// visually small — the same rule the composer's "+" follows.
class _BookmarkButton extends StatelessWidget {
  final bool isSaved;
  final VoidCallback onTap;

  const _BookmarkButton({required this.isSaved, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 44,
        height: 44,
        child: Center(
          child: ClipOval(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
              child: Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: isSaved
                      ? Colors.white
                      : Colors.black.withValues(alpha: 0.28),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.3),
                    width: 0.8,
                  ),
                ),
                child: Icon(
                  isSaved
                      ? Icons.bookmark_rounded
                      : Icons.bookmark_border_rounded,
                  size: 16,
                  color: isSaved ? Colors.black : Colors.white,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
