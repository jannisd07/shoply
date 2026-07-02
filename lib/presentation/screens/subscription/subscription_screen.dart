import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shoply/core/constants/app_colors.dart';
import 'package:shoply/core/constants/paper_colors.dart';
import 'package:shoply/core/localization/localization_helper.dart';
import 'package:shoply/data/services/subscription_service.dart';
import 'package:shoply/presentation/providers/subscription_provider.dart';

/// Premium subscription screen — bold minimalist design.
/// Monochrome palette, generous whitespace, subtle accent touches.
class SubscriptionScreen extends ConsumerStatefulWidget {
  final bool showCloseButton;
  
  const SubscriptionScreen({
    super.key,
    this.showCloseButton = true,
  });

  @override
  ConsumerState<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends ConsumerState<SubscriptionScreen> {
  String _selectedProductId = SubscriptionProducts.yearlyId;
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final productsAsync = ref.watch(subscriptionProductsProvider);
    ref.watch(subscriptionNotifierProvider);

    ref.listen(subscriptionErrorProvider, (_, asyncError) {
      asyncError.whenData((error) {
        if (error.isNotEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(error), backgroundColor: Colors.red),
          );
        }
      });
    });

    final products = productsAsync.when(
      data: (p) => p,
      loading: () => <ProductDetails>[],
      error: (_, __) => <ProductDetails>[],
    );

    final bg = AppColors.background(context);
    final fg = AppColors.textPrimary(context);
    final muted = AppColors.textSecondary(context);
    final dim = AppColors.textTertiary(context);

    return Scaffold(
      backgroundColor: bg,
      body: Column(
        children: [
          // ── Top bar ──
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                children: [
                  if (widget.showCloseButton)
                    GestureDetector(
                      onTap: () => Navigator.of(context).pop(),
                      child: Icon(Icons.close_rounded, color: muted, size: 24),
                    )
                  else
                    const SizedBox(width: 24),
                  const Spacer(),
                  GestureDetector(
                    onTap: _isLoading ? null : _restorePurchases,
                    child: Text(
                      context.tr('restore_purchases'),
                      style: TextStyle(
                        color: dim,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // ── Content ──
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 32),
                  
                  // ── Hero: paper kicker + serif headline ──
                  Text(
                    'SHOPLY PREMIUM',
                    style: TextStyle(
                      fontSize: 11,
                      letterSpacing: 2,
                      fontWeight: FontWeight.w600,
                      color: AppColors.accentColor(context),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    context.tr('premium_headline'),
                    style: PaperTextStyles.serif(28, color: fg, height: 1.25),
                  ),

                  const SizedBox(height: 26),
                  
                  // ── Features ──
                  _buildFeatures(context, isDark, fg, muted),
                  
                  const SizedBox(height: 48),
                  
                  // ── Plans ──
                  if (products.isNotEmpty)
                    _buildPlans(context, isDark, fg, muted, dim, products)
                  else
                    _buildLoadingPlans(context, muted, dim),
                  
                  const SizedBox(height: 28),
                  
                  // ── CTA ──
                  _buildCTA(context, isDark, products),
                  
                  const SizedBox(height: 20),
                  
                  // ── Terms ──
                  Center(
                    child: Text(
                      context.tr('subscription_terms'),
                      style: TextStyle(
                        fontSize: 11,
                        color: dim,
                        height: 1.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  
                  const SizedBox(height: 48),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Features list ──
  Widget _buildFeatures(BuildContext context, bool isDark, Color fg, Color muted) {
    final features = [
      context.tr('premium_feat_lists'),
      context.tr('premium_feat_avo'),
      context.tr('premium_feat_deals'),
      context.tr('premium_feat_stats'),
    ];

    return Column(
      children: features.map((f) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Row(
            children: [
              Icon(
                Icons.check,
                color: AppColors.accentColor(context),
                size: 17,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  f,
                  style: TextStyle(fontSize: 14, color: fg),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  // ── Plan cards: paper side-by-side per mockup ──
  Widget _buildPlans(
    BuildContext context, bool isDark, Color fg, Color muted, Color dim,
    List<ProductDetails> products,
  ) {
    final yearly = products
        .where((p) => p.id == SubscriptionProducts.yearlyId)
        .firstOrNull;
    final monthly = products
        .where((p) => p.id == SubscriptionProducts.monthlyId)
        .firstOrNull;

    String? perMonth;
    if (yearly != null) {
      final symbol = yearly.price.replaceAll(RegExp(r'[0-9.,\s]'), '');
      final val = yearly.rawPrice / 12;
      perMonth =
          '${val.toStringAsFixed(2).replaceAll('.', ',')} $symbol ${context.tr('per_month_suffix')}';
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (yearly != null)
          Expanded(
            child: _PlanCard(
              label: context.tr('yearly_label'),
              price: yearly.price,
              subline: perMonth ?? '',
              sublineAccent: true,
              badge: context.tr('best_choice').toUpperCase(),
              selected: _selectedProductId == yearly.id,
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() => _selectedProductId = yearly.id);
              },
            ),
          ),
        if (yearly != null && monthly != null) const SizedBox(width: 12),
        if (monthly != null)
          Expanded(
            child: _PlanCard(
              label: context.tr('monthly_label'),
              price: monthly.price,
              subline: context.tr('cancel_anytime'),
              sublineAccent: false,
              selected: _selectedProductId == monthly.id,
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() => _selectedProductId = monthly.id);
              },
            ),
          ),
      ],
    );
  }

  // ── Loading state ──
  Widget _buildLoadingPlans(BuildContext context, Color muted, Color dim) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Column(
        children: [
          CupertinoActivityIndicator(radius: 10, color: muted),
          const SizedBox(height: 16),
          Text(
            context.tr('loading_subscriptions'),
            style: TextStyle(color: muted, fontSize: 14),
          ),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: () async {
              await SubscriptionService.instance.retryLoadProducts();
              if (mounted) setState(() {});
            },
            child: Text(
              'Retry',
              style: TextStyle(
                color: dim,
                fontSize: 14,
                fontWeight: FontWeight.w600,
                decoration: TextDecoration.underline,
                decorationColor: dim,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── CTA button ──
  Widget _buildCTA(BuildContext context, bool isDark, List<ProductDetails> products) {
    final selectedProduct = products.where((p) => p.id == _selectedProductId).firstOrNull;
    final canTap = !_isLoading && selectedProduct != null;
    final fg = isDark ? Colors.black : Colors.white;
    final bg = isDark ? Colors.white : Colors.black;

    final yearlyPrice = products
            .where((p) => p.id == SubscriptionProducts.yearlyId)
            .firstOrNull
            ?.price ??
        '';

    return Column(
      children: [
        GestureDetector(
          onTap: canTap ? () => _subscribe(selectedProduct) : null,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: double.infinity,
            height: 54,
            decoration: BoxDecoration(
              color: canTap
                  ? PaperColors.ink
                  : PaperColors.ink.withValues(alpha: 0.45),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Center(
              child: _isLoading
                  ? const CupertinoActivityIndicator(
                      radius: 10,
                      color: PaperColors.paper,
                    )
                  : Text(
                      context.tr('trial_cta'),
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: PaperColors.paper,
                      ),
                    ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          context.tr('trial_footnote', params: {'price': yearlyPrice}),
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 11,
            color: AppColors.textTertiary(context),
          ),
        ),
      ],
    );
  }

  Future<void> _subscribe(ProductDetails product) async {
    HapticFeedback.mediumImpact();
    setState(() => _isLoading = true);
    
    debugPrint('💳 [UI] Starting purchase for: ${product.id}');
    
    final success = await ref.read(subscriptionNotifierProvider.notifier).purchase(product);
    
    debugPrint('💳 [UI] Purchase initiated: $success');
    
    if (mounted) {
      if (!success) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _restorePurchases() async {
    HapticFeedback.mediumImpact();
    setState(() => _isLoading = true);
    
    await ref.read(subscriptionNotifierProvider.notifier).restore();
    
    if (mounted) {
      setState(() => _isLoading = false);
      
      if (ref.read(isSubscribedProvider)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.tr('purchases_restored')),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop(true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.tr('no_purchases_found')),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }
}

/// Paper price card with optional "best choice" badge.
class _PlanCard extends StatelessWidget {
  final String label;
  final String price;
  final String subline;
  final bool sublineAccent;
  final String? badge;
  final bool selected;
  final VoidCallback onTap;

  const _PlanCard({
    required this.label,
    required this.price,
    required this.subline,
    required this.sublineAccent,
    this.badge,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final accent = AppColors.accentColor(context);

    return GestureDetector(
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(14, 18, 14, 14),
            decoration: BoxDecoration(
              color: selected
                  ? AppColors.surface(context)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: selected ? accent : AppColors.border(context),
                width: selected ? 1.5 : 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary(context),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  price,
                  style: PaperTextStyles.serif(
                    21,
                    color: AppColors.textPrimary(context),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subline,
                  style: TextStyle(
                    fontSize: 11,
                    color: sublineAccent
                        ? accent
                        : AppColors.textSecondary(context),
                  ),
                ),
              ],
            ),
          ),
          if (badge != null)
            Positioned(
              top: -9,
              left: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: accent,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  badge!,
                  style: const TextStyle(
                    fontSize: 9,
                    letterSpacing: 1,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Show subscription screen as a full-screen modal
Future<bool?> showSubscriptionSheet(BuildContext context) {
  return Navigator.of(context).push<bool>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (context) => const SubscriptionScreen(),
    ),
  );
}
