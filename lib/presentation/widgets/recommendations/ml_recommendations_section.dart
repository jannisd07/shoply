import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shoply/core/constants/app_colors.dart';
import 'package:shoply/core/constants/paper_colors.dart';
import 'package:shoply/core/localization/localization_helper.dart';
import 'package:shoply/presentation/providers/ml_recommendations_provider.dart';
import 'package:shoply/presentation/widgets/recommendations/recommendation_card.dart';

/// ML-powered AI Recommendations Section — paper surface card with a
/// serif header, collapsed by default.
/// Uses hybrid ML approach: Sequential History + Item Associations +
/// Collaborative Filtering.
class MLRecommendationsSection extends ConsumerStatefulWidget {
  final String? listId;
  final Function(String itemName, String? category, double? quantity) onAddItem;

  const MLRecommendationsSection({
    super.key,
    required this.listId,
    required this.onAddItem,
  });

  @override
  ConsumerState<MLRecommendationsSection> createState() =>
      _MLRecommendationsSectionState();
}

class _MLRecommendationsSectionState
    extends ConsumerState<MLRecommendationsSection> {
  bool _isExpanded = false; // Start collapsed

  BoxDecoration _card(BuildContext context) => BoxDecoration(
        color: AppColors.surface(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border(context)),
      );

  Widget _header(BuildContext context, {required Widget trailing}) {
    return Row(
      children: [
        Icon(
          Icons.auto_awesome,
          size: 16,
          color: AppColors.accentColor(context),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.tr('ai_recommendations'),
                style: PaperTextStyles.serif(
                  15,
                  color: AppColors.textPrimary(context),
                ),
              ),
              const SizedBox(height: 1),
              Text(
                context.tr('based_on_purchases'),
                style: TextStyle(
                  fontSize: 11,
                  color: AppColors.textSecondary(context),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        trailing,
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.listId == null) {
      return const SizedBox.shrink();
    }

    final recommendationsAsync =
        ref.watch(mlRecommendationsProvider(widget.listId));

    return recommendationsAsync.when(
      data: (recommendations) {
        if (recommendations.isEmpty) {
          return const SizedBox.shrink();
        }

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: _card(context),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              InkWell(
                onTap: () => setState(() => _isExpanded = !_isExpanded),
                borderRadius: BorderRadius.circular(14),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
                  child: _header(
                    context,
                    trailing: AnimatedRotation(
                      turns: _isExpanded ? 0.5 : 0,
                      duration: const Duration(milliseconds: 250),
                      child: Icon(
                        Icons.keyboard_arrow_down_rounded,
                        size: 20,
                        color: AppColors.textSecondary(context),
                      ),
                    ),
                  ),
                ),
              ),
              AnimatedCrossFade(
                firstChild: Column(
                  children: [
                    Container(
                      height: 0.5,
                      margin: const EdgeInsets.symmetric(horizontal: 16),
                      color: AppColors.divider(context),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                      child: Column(
                        children: recommendations.map((recommendation) {
                          return RecommendationCard(
                            recommendation: recommendation,
                            onAdd: () => widget.onAddItem(
                              recommendation.itemName,
                              recommendation.category,
                              recommendation.quantity,
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
                secondChild: const SizedBox.shrink(),
                crossFadeState: _isExpanded
                    ? CrossFadeState.showFirst
                    : CrossFadeState.showSecond,
                duration: const Duration(milliseconds: 250),
                sizeCurve: Curves.easeInOut,
              ),
            ],
          ),
        );
      },
      loading: () => Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
        decoration: _card(context),
        child: _header(
          context,
          trailing: CupertinoActivityIndicator(
            radius: 8,
            color: AppColors.textSecondary(context),
          ),
        ),
      ),
      error: (error, stack) {
        return const SizedBox.shrink();
      },
    );
  }
}
