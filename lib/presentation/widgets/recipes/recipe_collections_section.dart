import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:go_router/go_router.dart';
import 'package:shoply/core/constants/app_colors.dart';
import 'package:shoply/core/localization/localization_helper.dart';
import 'package:shoply/data/models/recipe_collection.dart';
import 'package:shoply/data/services/recipe_features_service.dart';

/// Horizontal scrolling section showing recipe collections
class RecipeCollectionsSection extends StatefulWidget {
  const RecipeCollectionsSection({super.key});

  @override
  State<RecipeCollectionsSection> createState() => _RecipeCollectionsSectionState();
}

class _RecipeCollectionsSectionState extends State<RecipeCollectionsSection> {
  final RecipeFeaturesService _service = RecipeFeaturesService.instance;
  List<RecipeCollection> _collections = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCollections();
  }

  Future<void> _loadCollections() async {
    final collections = await _service.getFeaturedCollections();
    if (mounted) {
      setState(() {
        _collections = collections;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final textPrimary = AppColors.textPrimary(context);

    if (_isLoading) {
      return const SizedBox(
        height: 140,
        child: Center(child: CupertinoActivityIndicator()),
      );
    }

    if (_collections.isEmpty) {
      return const SizedBox.shrink();
    }

    // Get language code
    final languageCode = Localizations.localeOf(context).languageCode;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Icon(Icons.collections_bookmark_rounded, size: 20, color: AppColors.recipeAccentColor(context)),
              const SizedBox(width: 8),
              Text(
                context.tr('collections'),
                style: TextStyle(
                  color: textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 120,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _collections.length,
            itemBuilder: (context, index) {
              final collection = _collections[index];
              return _CollectionCard(
                collection: collection,
                languageCode: languageCode,
                onTap: () => context.push('/recipes/collection/${collection.id}'),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _CollectionCard extends StatelessWidget {
  final RecipeCollection collection;
  final String languageCode;
  final VoidCallback onTap;

  const _CollectionCard({
    required this.collection,
    required this.languageCode,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cardColor = AppColors.recipeSurface(context);
    final textPrimary = AppColors.textPrimary(context);
    final textSecondary = AppColors.textSecondary(context);
    final borderColor = AppColors.recipeBorderColor(context);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 160,
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Icon
            Text(
              collection.icon,
              style: const TextStyle(fontSize: 32),
            ),
            const SizedBox(height: 8),
            // Name
            Text(
              collection.getLocalizedName(languageCode),
              style: TextStyle(
                color: textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const Spacer(),
            // Description
            if (collection.getLocalizedDescription(languageCode) != null)
              Text(
                collection.getLocalizedDescription(languageCode)!,
                style: TextStyle(
                  color: textSecondary,
                  fontSize: 11,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
          ],
        ),
      ),
    );
  }
}
