import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shoply/core/constants/app_colors.dart';
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
                  
                  // ── Hero ──
                  Center(
                    child: Text(
                      'Pro',
                      style: TextStyle(
                        fontSize: 56,
                        fontWeight: FontWeight.w800,
                        color: fg,
                        letterSpacing: -2,
                        height: 1.0,
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 8),
                  
                  Center(
                    child: Text(
                      context.tr('unlock_premium_features'),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w400,
                        color: muted,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 48),
                  
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
      (Icons.auto_awesome_rounded, context.tr('premium_feature_ai')),
      (Icons.restaurant_menu_rounded, context.tr('premium_feature_cooking_mode')),
      (Icons.calendar_month_rounded, context.tr('premium_feature_meal_planning')),
      (Icons.block_rounded, context.tr('premium_feature_no_ads')),
    ];

    return Column(
      children: features.map((f) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 20),
          child: Row(
            children: [
              Icon(f.$1, color: muted, size: 22),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  f.$2,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: fg,
                    letterSpacing: -0.2,
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  // ── Plan cards ──
  Widget _buildPlans(
    BuildContext context, bool isDark, Color fg, Color muted, Color dim,
    List<ProductDetails> products,
  ) {
    final sorted = List<ProductDetails>.from(products)
      ..sort((a, b) => a.id == SubscriptionProducts.yearlyId ? -1 : 1);

    return Column(
      children: sorted.map((product) {
        final isSelected = _selectedProductId == product.id;
        final isYearly = product.id == SubscriptionProducts.yearlyId;
        
        String savingText = context.tr('save_percent', params: {'percent': '50'});
        if (isYearly) {
          try {
            final monthlyProduct = products.firstWhere((p) => p.id == SubscriptionProducts.monthlyId);
            final savings = (monthlyProduct.rawPrice * 12) - product.rawPrice;
            if (savings > 0) {
              final symbol = product.price.replaceAll(RegExp(r'[0-9.,\s]'), '');
              final formattedSavings = savings.truncateToDouble() == savings 
                  ? savings.toInt().toString() 
                  : savings.toStringAsFixed(2);
                  
              final isGerman = Localizations.localeOf(context).languageCode == 'de';
              savingText = isGerman ? '$formattedSavings$symbol sparen' : 'Save $symbol$formattedSavings';
            }
          } catch (_) {}
        }
        
        return GestureDetector(
          onTap: () {
            HapticFeedback.selectionClick();
            setState(() => _selectedProductId = product.id);
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
            decoration: BoxDecoration(
              color: isSelected
                  ? (isDark
                      ? Colors.white.withValues(alpha: 0.08)
                      : Colors.black.withValues(alpha: 0.04))
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isSelected
                    ? (isDark
                        ? Colors.white.withValues(alpha: 0.25)
                        : Colors.black.withValues(alpha: 0.15))
                    : (isDark
                        ? Colors.white.withValues(alpha: 0.08)
                        : Colors.black.withValues(alpha: 0.06)),
                width: isSelected ? 1.5 : 1,
              ),
            ),
            child: Row(
              children: [
                // Selection dot
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isSelected ? fg : Colors.transparent,
                    border: Border.all(
                      color: isSelected ? fg : dim,
                      width: 1.5,
                    ),
                  ),
                  child: isSelected
                      ? Icon(Icons.check_rounded, size: 12,
                          color: isDark ? Colors.black : Colors.white)
                      : null,
                ),
                const SizedBox(width: 16),
                
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            isYearly ? context.tr('yearly') : context.tr('monthly'),
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w600,
                              color: fg,
                              letterSpacing: -0.3,
                            ),
                          ),
                          if (isYearly) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? Colors.white.withValues(alpha: 0.12)
                                    : Colors.black.withValues(alpha: 0.06),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                savingText,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: fg,
                                  letterSpacing: -0.2,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        isYearly
                            ? context.tr('billed_yearly')
                            : context.tr('billed_monthly'),
                        style: TextStyle(
                          fontSize: 13,
                          color: muted,
                        ),
                      ),
                    ],
                  ),
                ),
                
                Text(
                  product.price,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: fg,
                    letterSpacing: -0.5,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
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

    return GestureDetector(
      onTap: canTap ? () => _subscribe(selectedProduct) : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: double.infinity,
        height: 56,
        decoration: BoxDecoration(
          color: canTap ? bg : bg.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Center(
          child: _isLoading
              ? CupertinoActivityIndicator(radius: 10, color: fg)
              : Text(
                  context.tr('subscribe_now'),
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: fg,
                    letterSpacing: -0.3,
                  ),
                ),
        ),
      ),
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

/// Show subscription screen as a full-screen modal
Future<bool?> showSubscriptionSheet(BuildContext context) {
  return Navigator.of(context).push<bool>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (context) => const SubscriptionScreen(),
    ),
  );
}
