import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shoply/core/constants/app_colors.dart';
import 'package:shoply/core/constants/app_text_styles.dart';
import 'package:shoply/core/constants/paper_colors.dart';
import 'package:shoply/core/localization/localization_helper.dart';
import 'package:shoply/data/models/recipe_offer_highlight.dart';
import 'package:shoply/presentation/providers/recipe_offers_provider.dart';

/// "This recipe is cheaper this week" — current supermarket offers for the
/// recipe's ingredients (Feature 8). Renders nothing while loading, on
/// error, without a real zip code, or when no ingredient is on offer — the
/// recipe page never shows an empty or fake offers section.
class RecipeOffersCard extends ConsumerWidget {
  final RecipeOffersRequest request;

  const RecipeOffersCard({super.key, required this.request});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final result = ref.watch(recipeOffersProvider(request)).valueOrNull;
    if (result == null || result.matches.isEmpty) {
      return const SizedBox.shrink();
    }

    final textColor = AppColors.textPrimary(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textSecondary =
        isDark ? const Color(0xFF6B6B6B) : const Color(0xFF9CA3AF);
    final savings = result.knownSavings;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface(context),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.border(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.local_offer_outlined, size: 18, color: textSecondary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  context.tr('recipe_offers_title'),
                  style: AppTextStyles.h3.copyWith(color: textColor),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            context.tr('recipe_offers_subtitle', params: {
              'count': '${result.matches.length}',
              'total': '${result.checkedIngredientCount}',
            }),
            style: TextStyle(fontSize: 12, color: textSecondary),
          ),
          if (savings >= 0.5) ...[
            const SizedBox(height: 6),
            Text(
              context.tr('recipe_offers_save',
                  params: {'amount': savings.toStringAsFixed(2)}),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.accentColor(context),
              ),
            ),
          ],
          const SizedBox(height: 10),
          for (var i = 0; i < result.matches.length; i++) ...[
            if (i > 0)
              Container(
                height: 0.5,
                margin: const EdgeInsets.symmetric(vertical: 2),
                color: AppColors.divider(context),
              ),
            _IngredientOfferRow(match: result.matches[i]),
          ],
        ],
      ),
    );
  }
}

class _IngredientOfferRow extends StatelessWidget {
  final RecipeIngredientOffer match;

  const _IngredientOfferRow({required this.match});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textSecondary =
        isDark ? const Color(0xFF6B6B6B) : const Color(0xFF9CA3AF);

    final detailParts = <String>[
      match.productName,
      match.retailerName,
      if (match.unitSizeLabel != null) match.unitSizeLabel!,
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(9),
            child: Image.network(
              match.imageUrl,
              width: 38,
              height: 38,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                width: 38,
                height: 38,
                color: isDark ? const Color(0xFF2C2C2E) : PaperColors.cream,
                child: Icon(
                  Icons.shopping_basket_outlined,
                  size: 17,
                  color: isDark ? textSecondary : PaperColors.creamInk,
                ),
              ),
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  match.ingredientName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textPrimary(context),
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  detailParts.join(' · '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11, color: textSecondary),
                ),
                if (match.isBroadMatch) ...[
                  const SizedBox(height: 1),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.info_outline_rounded,
                          size: 9.5, color: AppColors.textTertiary(context)),
                      const SizedBox(width: 3),
                      Text(
                        context.tr('similar_product_match'),
                        maxLines: 1,
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textTertiary(context),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (match.discountPercent != null) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 5, vertical: 1.5),
                      decoration: BoxDecoration(
                        color: AppColors.accentColor(context)
                            .withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '-${match.discountPercent}%',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: AppColors.accentColor(context),
                        ),
                      ),
                    ),
                    const SizedBox(width: 5),
                  ],
                  Text(
                    '${match.price.toStringAsFixed(2)} €',
                    style: PaperTextStyles.serif(
                      15,
                      color: AppColors.textPrimary(context),
                    ),
                  ),
                ],
              ),
              if (match.regularPrice != null)
                Text(
                  context.tr(
                    'instead_of_price',
                    params: {'price': match.regularPrice!.toStringAsFixed(2)},
                  ),
                  style: TextStyle(
                    fontSize: 10,
                    color: AppColors.textTertiary(context),
                  ),
                ),
              if (match.unitPriceLabel != null)
                Text(
                  match.unitPriceLabel!,
                  style: TextStyle(
                    fontSize: 9.5,
                    color: AppColors.textTertiary(context),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
