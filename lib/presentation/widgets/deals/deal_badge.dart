import 'package:flutter/material.dart';
import 'package:shoply/data/models/extracted_deal_model.dart';

/// Badge-Widget das Angebote bei Produkten anzeigt
class DealBadge extends StatelessWidget {
  final ExtractedDeal deal;
  final bool compact;

  const DealBadge({
    super.key,
    required this.deal,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return _buildCompactBadge(context);
    }
    return _buildFullBadge(context);
  }

  Widget _buildCompactBadge(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.red[600],
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.local_offer,
            color: Colors.white,
            size: 12,
          ),
          const SizedBox(width: 4),
          Text(
            deal.formattedDiscount,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFullBadge(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.red[600]!, Colors.orange[600]!],
        ),
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.red.withValues(alpha: 0.3),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.local_offer,
                color: Colors.white,
                size: 14,
              ),
              const SizedBox(width: 4),
              Text(
                deal.formattedDiscount,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                deal.formattedOriginalPrice,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                  decoration: TextDecoration.lineThrough,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                deal.formattedDiscountedPrice,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            '@ ${deal.supermarket}',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

/// Kleines Angebots-Icon für Listen
class DealIndicator extends StatelessWidget {
  final int dealCount;
  final VoidCallback? onTap;

  const DealIndicator({
    super.key,
    required this.dealCount,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (dealCount == 0) return const SizedBox.shrink();

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: Colors.orange[600],
          shape: BoxShape.circle,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.local_offer,
              color: Colors.white,
              size: 16,
            ),
            if (dealCount > 1) ...[
              const SizedBox(width: 2),
              Text(
                '$dealCount',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Deal-Liste Widget für Bottom Sheet
class DealsList extends StatelessWidget {
  final String productName;
  final List<ExtractedDeal> deals;

  const DealsList({
    super.key,
    required this.productName,
    required this.deals,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.local_offer, color: Colors.orange),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Angebote für "$productName"',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (deals.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Text('Keine Angebote gefunden'),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: deals.length,
              separatorBuilder: (context, index) => const Divider(),
              itemBuilder: (context, index) {
                final deal = deals[index];
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    backgroundColor: Colors.red[600],
                    child: Text(
                      deal.formattedDiscount,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  title: Text(
                    deal.productName,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),
                      Text('${deal.supermarket}${deal.unit != null ? " • ${deal.unit}" : ""}'),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Text(
                            deal.formattedOriginalPrice,
                            style: const TextStyle(
                              decoration: TextDecoration.lineThrough,
                              color: Colors.grey,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            deal.formattedDiscountedPrice,
                            style: TextStyle(
                              color: Colors.green[700],
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                      if (deal.daysRemaining > 0 && deal.daysRemaining <= 7) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Noch ${deal.daysRemaining} Tag${deal.daysRemaining == 1 ? "" : "e"} gültig',
                          style: TextStyle(
                            color: deal.daysRemaining <= 2 ? Colors.red : Colors.orange,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ],
                  ),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
                      const SizedBox(height: 4),
                      Text(
                        'Spare ${deal.formattedSavings}',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  /// Zeigt die Deals in einem Bottom Sheet
  static void show(
    BuildContext context, {
    required String productName,
    required List<ExtractedDeal> deals,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DealsList(
        productName: productName,
        deals: deals,
      ),
    );
  }
}
