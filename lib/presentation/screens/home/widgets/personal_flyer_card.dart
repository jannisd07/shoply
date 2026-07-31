import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shoply/core/constants/app_colors.dart';
import 'package:shoply/core/constants/paper_colors.dart';
import 'package:shoply/core/localization/localization_helper.dart';
import 'package:shoply/data/services/avo_nudge_service.dart';
import 'package:shoply/presentation/state/avo_nudge_provider.dart';

/// "Dein Prospekt": the things this user buys on a rhythm that happen to be
/// on offer right now, grouped by shop.
///
/// Deliberately quiet when there is nothing to say — an empty or one-item
/// flyer is worse than no flyer, so it only appears once there is a real
/// handful of deals. It shares the offer computation (and its 6h cache) with
/// the Avo nudge card, so showing it costs no additional lookups.
class PersonalFlyerCard extends ConsumerWidget {
  /// Called when a deal is tapped, so the caller can add it to a list.
  final void Function(OfferNudge offer)? onSelect;

  const PersonalFlyerCard({super.key, this.onSelect});

  /// Below this the flyer framing ("your deals this week") overpromises.
  static const int _minDeals = 3;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sections = ref.watch(personalFlyerProvider).valueOrNull;
    if (sections == null) return const SizedBox.shrink();

    final dealCount =
        sections.fold<int>(0, (sum, s) => sum + s.offers.length);
    if (dealCount < _minDeals) return const SizedBox.shrink();

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        color: AppColors.surface(context),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border(context)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.28 : 0.05),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Header(dealCount: dealCount),
          for (var i = 0; i < sections.length; i++)
            _Section(
              section: sections[i],
              isLast: i == sections.length - 1,
              onSelect: onSelect,
            ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final int dealCount;
  const _Header({required this.dealCount});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.tr('flyer_title'),
                  style: PaperTextStyles.serif(
                    20,
                    color: AppColors.textPrimary(context),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  context.tr('flyer_subtitle', params: {'count': '$dealCount'}),
                  style: TextStyle(
                    fontSize: 12.5,
                    height: 1.35,
                    color: AppColors.textSecondary(context),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: AppColors.accentColor(context).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              '$dealCount',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.accentColor(context),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final FlyerSection section;
  final bool isLast;
  final void Function(OfferNudge offer)? onSelect;

  const _Section({
    required this.section,
    required this.isLast,
    this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final savings = section.disclosedSavings;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 6, 20, 6),
          child: Row(
            children: [
              Text(
                section.retailerName.toUpperCase(),
                style: TextStyle(
                  fontSize: 10,
                  letterSpacing: 1.4,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary(context),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  height: 0.5,
                  color: AppColors.divider(context),
                ),
              ),
              if (savings >= 0.20) ...[
                const SizedBox(width: 8),
                Text(
                  context.tr(
                    'flyer_section_savings',
                    params: {'amount': savings.toStringAsFixed(2)},
                  ),
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.accentColor(context),
                  ),
                ),
              ],
            ],
          ),
        ),
        for (final offer in section.offers)
          _DealRow(offer: offer, onSelect: onSelect),
        SizedBox(height: isLast ? 14 : 8),
      ],
    );
  }
}

class _DealRow extends StatelessWidget {
  final OfferNudge offer;
  final void Function(OfferNudge offer)? onSelect;

  const _DealRow({required this.offer, this.onSelect});

  @override
  Widget build(BuildContext context) {
    final discount = offer.discountPercent;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onSelect == null
          ? null
          : () {
              HapticFeedback.lightImpact();
              onSelect!(offer);
            },
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    offer.displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary(context),
                    ),
                  ),
                  if (offer.productName.isNotEmpty &&
                      offer.productName.toLowerCase() !=
                          offer.displayName.toLowerCase())
                    Text(
                      offer.productName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11.5,
                        color: AppColors.textSecondary(context),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${offer.price.toStringAsFixed(2)} €',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary(context),
                  ),
                ),
                // Only shown when the shop disclosed a real previous price;
                // most flyer data does not, and inventing one would be a lie.
                if (offer.regularPrice != null && discount != null)
                  Text(
                    '−$discount %',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.accentColor(context),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
