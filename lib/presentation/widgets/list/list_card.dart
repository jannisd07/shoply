import 'package:flutter/material.dart';
import 'package:shoply/core/constants/app_colors.dart';
import 'package:shoply/core/constants/app_dimensions.dart';
import 'package:shoply/core/constants/app_text_styles.dart';
import 'package:shoply/core/utils/date_formatter.dart';
import 'package:shoply/data/models/shopping_list_model.dart';

class ListCard extends StatelessWidget {
  final ShoppingListModel list;
  final VoidCallback onTap;
  final VoidCallback? onDelete;
  final VoidCallback? onShare;

  const ListCard({
    super.key,
    required this.list,
    required this.onTap,
    this.onDelete,
    this.onShare,
  });

  @override
  Widget build(BuildContext context) {
    final itemCount = list.itemCount ?? 0;
    final uncheckedCount = list.uncheckedCount ?? 0;

    return Card(
      margin: const EdgeInsets.only(bottom: AppDimensions.cardMargin),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppDimensions.cardBorderRadius),
        child: Padding(
          padding: const EdgeInsets.all(AppDimensions.cardPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                list.name,
                                style: AppTextStyles.h3,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (list.isShared)
                              Container(
                                margin: const EdgeInsets.only(
                                  left: AppDimensions.spacingSmall,
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.accentLight,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.people,
                                      size: 14,
                                      color: AppColors.accent,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Shared',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: AppColors.accent,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: AppDimensions.spacingSmall),
                        Text(
                          itemCount > 0
                              ? '$uncheckedCount of $itemCount items'
                              : 'No items yet',
                          style: AppTextStyles.caption.copyWith(
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right),
                ],
              ),
              const SizedBox(height: AppDimensions.spacingSmall),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Updated ${DateFormatter.formatRelativeDate(list.updatedAt)}',
                    style: AppTextStyles.caption.copyWith(
                      color: Colors.grey.shade500,
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (onShare != null)
                        IconButton(
                          icon: const Icon(Icons.ios_share, size: 20),
                          onPressed: onShare,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      if (onDelete != null) ...[
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, size: 20),
                          onPressed: onDelete,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          color: Colors.red,
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
