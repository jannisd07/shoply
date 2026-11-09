import 'dart:async';
import 'dart:convert';

import 'package:flutter/cupertino.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:shoply/core/constants/app_brand.dart';
import 'package:shoply/core/design/design.dart';
import 'package:shoply/core/localization/localization_helper.dart';
import 'package:shoply/core/services/shared_preferences_provider.dart';
import 'package:shoply/data/services/connectivity_service.dart';
import 'package:shoply/data/services/subscription_service.dart';
import 'package:shoply/presentation/providers/account_status_provider.dart';
import 'package:shoply/presentation/providers/subscription_provider.dart';
import 'package:shoply/presentation/screens/profile/settings/data/settings_services.dart';
import 'package:shoply/presentation/screens/profile/settings/legal_settings_screen.dart';
import 'package:shoply/presentation/screens/subscription/widgets/paywall_view.dart';
import 'package:shoply/presentation/widgets/design/pro_gate.dart';
import 'package:shoply/presentation/widgets/design/success_moment.dart';
import 'package:shoply/presentation/widgets/design/undo_toast.dart';

/// Length of the free trial: what `activate_trial` grants on the first
/// purchase. StoreKit's own offer is not read yet (pro-konzept §2.1).
const int kProTrialDays = 14;

/// Apple's page for managing subscriptions ("Abo verwalten").
final Uri kManageSubscriptionsUrl = Uri.parse(
  'https://apps.apple.com/account/subscriptions',
);

/// Whether the device is online; overridden in tests.
final paywallOnlineProvider = Provider<bool>(
  (ref) => ConnectivityService.instance.isOnline,
);

/// The Avo Pro paywall (`/pro?feature=<id>`, Konzept 18 §8). Pops with
/// `true` after a purchase so [ProGate.run] can continue the action.
class PaywallScreen extends ConsumerStatefulWidget {
  /// Creates the paywall; [feature] is the `?feature=` id.
  const PaywallScreen({super.key, this.feature});

  final String? feature;

  @override
  ConsumerState<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends ConsumerState<PaywallScreen> {
  PaywallPlan _plan = PaywallPlan.yearly;
  bool _purchasing = false;
  bool _restoring = false;
  PaywallProblem? _problem;

  @override
  Widget build(BuildContext context) {
    ref.listen(subscriptionNotifierProvider, (_, next) {
      if (!_purchasing || next is AsyncLoading) return;
      final status = next.valueOrNull;
      if (status == SubscriptionStatus.pending) {
        setState(() => _purchasing = false);
        return;
      }
      setState(() => _purchasing = false);
      if (status == SubscriptionStatus.subscribed) _purchased();
      if (next is AsyncError) _failed();
    });
    ref.listen(subscriptionErrorProvider, (_, next) {
      final error = next.valueOrNull;
      if (error == null || error.isEmpty || !_purchasing) return;
      setState(() => _purchasing = false);
      _failed();
    });

    final products =
        ref.watch(subscriptionProductsProvider).valueOrNull ??
        const <ProductDetails>[];
    final service = ref.watch(subscriptionServiceProvider);
    final online = ref.watch(paywallOnlineProvider);
    final active = ref.watch(isSubscribedProvider);
    final status = ref.watch(subscriptionStatusProvider).valueOrNull;
    final details = ref.watch(proSubscriptionDetailsProvider).valueOrNull;

    final locale = Localizations.localeOf(context).toLanguageTag();
    final live = PaywallPrices.from(products, locale);
    final cache = ref.watch(paywallPriceCacheProvider);
    // The last store prices at once (K18-10); StoreKit's answer replaces
    // them and is saved for the next opening.
    final cached = live.isComplete ? null : cache?.read(locale);
    final prices = cached ?? live;
    if (live.isComplete) cache?.write(locale, live);

    final problem =
        _problem ??
        (!online
            ? PaywallProblem.offline
            : products.isEmpty && !service.isLoading
            ? PaywallProblem.store
            : null);

    final data = PaywallData(
      feature: ProFeatures.info(widget.feature),
      plan: _plan,
      yearlyPrice: prices.yearly,
      yearlyPerMonth: prices.yearlyPerMonth,
      monthlyPrice: prices.monthly,
      savingPercent: prices.savingPercent,
      pricesCached: cached != null,
      trialDays: details?.trialEligible == true ? kProTrialDays : null,
      trialUsed: details != null && details.trialEndsAt != null,
      problem: problem,
      purchasing: _purchasing,
      restoring: _restoring,
      pending: status == SubscriptionStatus.pending,
      active: active,
      activeStatus: active ? paywallActiveStatus(context, details) : null,
    );

    return PaywallView(
      data: data,
      actions: PaywallActions(
        onClose: () => Navigator.of(context).maybePop(),
        onPlan: (plan) => setState(() => _plan = plan),
        onBuy: () => _buy(products),
        onRestore: _restore,
        onRetry: _retry,
        onTerms: () => _openLegal(LegalDocument.terms),
        onPrivacy: () => _openLegal(LegalDocument.privacy),
        onManage: () => unawaited(
          ref
              .read(settingsExternalActionsProvider)
              .openUrl(kManageSubscriptionsUrl),
        ),
      ),
    );
  }

  Future<void> _buy(List<ProductDetails> products) async {
    final id = _plan == PaywallPlan.yearly
        ? SubscriptionProducts.yearlyId
        : SubscriptionProducts.monthlyId;
    ProductDetails? product;
    for (final p in products) {
      if (p.id == id) product = p;
    }
    if (product == null) return;
    setState(() {
      _purchasing = true;
      _problem = null;
    });
    final opened = await ref
        .read(subscriptionNotifierProvider.notifier)
        .purchase(product);
    if (!opened && mounted) setState(() => _purchasing = false);
  }

  void _purchased() {
    unawaited(AvoHaptics.success());
    // The moment lives on the root overlay, so it stays after the pop.
    unawaited(
      showSuccessMoment(
        context,
        title: context.tr(
          'pro_success_title',
          params: {'pro': AppBrand.proName},
        ),
      ),
    );
    Navigator.of(context).pop(true);
  }

  void _failed() {
    unawaited(AvoHaptics.error());
    setState(() => _problem = PaywallProblem.purchase);
  }

  Future<void> _restore() async {
    setState(() {
      _restoring = true;
      _problem = null;
    });
    try {
      await ref.read(subscriptionNotifierProvider.notifier).restore();
    } catch (e) {
      debugPrint('❌ [PAYWALL] Restore failed: ${e.runtimeType}');
      if (mounted) {
        unawaited(AvoHaptics.error());
        setState(() {
          _restoring = false;
          _problem = PaywallProblem.restore;
        });
      }
      return;
    }
    if (!mounted) return;
    setState(() => _restoring = false);
    final restored = ref.read(isSubscribedProvider);
    if (restored) unawaited(AvoHaptics.success());
    AvoToast.show(
      context,
      message: context.tr(
        restored ? 'pro_restored' : 'pro_restore_none',
        params: {'pro': AppBrand.proName},
      ),
    );
  }

  void _retry() {
    final problem = _problem;
    setState(() => _problem = null);
    if (problem == PaywallProblem.restore) {
      unawaited(_restore());
    } else {
      unawaited(ref.read(subscriptionServiceProvider).retryLoadProducts());
    }
  }

  void _openLegal(LegalDocument document) {
    Navigator.of(context).push(
      CupertinoPageRoute<void>(
        builder: (_) => LegalDocumentScreen(document: document),
      ),
    );
  }
}

/// The status line of "Du hast {pro}" (Konzept 18 §8.6).
String paywallActiveStatus(
  BuildContext context,
  ProSubscriptionDetails? details,
) {
  final locale = Localizations.localeOf(context).toLanguageTag();
  final date = DateFormat('EEE, d. MMM y', locale);
  final trialEnd = details?.trialEndsAt;
  final expires = details?.expiresAt;
  if (details != null && details.isTrial && trialEnd != null) {
    return context.tr(
      'pro_active_trial',
      params: {'date': date.format(trialEnd)},
    );
  }
  if (details?.status == 'cancelled' && expires != null) {
    return context.tr(
      'pro_active_cancelled',
      params: {'date': date.format(expires)},
    );
  }
  if (expires != null) {
    return context.tr(
      'pro_active_until',
      params: {'date': date.format(expires)},
    );
  }
  return context.tr('pro_active');
}

/// The prices the plan rows show, from the StoreKit products.
class PaywallPrices {
  /// Creates the prices.
  const PaywallPrices({
    this.yearly,
    this.yearlyPerMonth,
    this.monthly,
    this.savingPercent,
  });

  /// Reads [products] (store-formatted prices; the monthly share of the
  /// yearly plan rounded down to the cent, the saving rounded down).
  factory PaywallPrices.from(List<ProductDetails> products, String locale) {
    ProductDetails? yearly;
    ProductDetails? monthly;
    for (final p in products) {
      if (p.id == SubscriptionProducts.yearlyId) yearly = p;
      if (p.id == SubscriptionProducts.monthlyId) monthly = p;
    }
    String? perMonth;
    int? saving;
    if (yearly != null) {
      final format = NumberFormat.simpleCurrency(
        locale: locale,
        name: yearly.currencyCode,
      );
      perMonth = format.format((yearly.rawPrice / 12 * 100).floor() / 100);
    }
    if (yearly != null && monthly != null && monthly.rawPrice > 0) {
      final percent = ((1 - yearly.rawPrice / (monthly.rawPrice * 12)) * 100)
          .floor();
      if (percent > 0) saving = percent;
    }
    return PaywallPrices(
      yearly: yearly?.price,
      yearlyPerMonth: perMonth,
      monthly: monthly?.price,
      savingPercent: saving,
    );
  }

  final String? yearly;
  final String? yearlyPerMonth;
  final String? monthly;
  final int? savingPercent;

  /// Both plans have a price.
  bool get isComplete => yearly != null && monthly != null;

  Map<String, Object?> _toJson(String locale) => {
    'locale': locale,
    'yearly': yearly,
    'yearlyPerMonth': yearlyPerMonth,
    'monthly': monthly,
    'savingPercent': savingPercent,
  };

  @override
  bool operator ==(Object other) =>
      other is PaywallPrices &&
      other.yearly == yearly &&
      other.yearlyPerMonth == yearlyPerMonth &&
      other.monthly == monthly &&
      other.savingPercent == savingPercent;

  @override
  int get hashCode =>
      Object.hash(yearly, yearlyPerMonth, monthly, savingPercent);
}

/// The prices of the last StoreKit answer on this device (Konzept 18 §8.5,
/// K18-10), so the paywall never opens with "…" twice. Kept per language:
/// another locale formats differently and is read as no cache. The prices
/// belong to the App Store country, not the account, so they survive a
/// sign-out (`account_local_data.dart`).
class PaywallPriceCache {
  /// A cache in [prefs].
  PaywallPriceCache(this._prefs);

  /// The SharedPreferences key.
  static const key = 'pro_price_cache_v1';

  final SharedPreferences _prefs;

  /// The cached prices for [locale], or null.
  PaywallPrices? read(String locale) {
    final raw = _prefs.getString(key);
    if (raw == null) return null;
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      if (json['locale'] != locale) return null;
      final prices = PaywallPrices(
        yearly: json['yearly'] as String?,
        yearlyPerMonth: json['yearlyPerMonth'] as String?,
        monthly: json['monthly'] as String?,
        savingPercent: json['savingPercent'] as int?,
      );
      return prices.isComplete ? prices : null;
    } catch (e) {
      debugPrint('⚠️ [PAYWALL] Price cache unreadable: ${e.runtimeType}');
      return null;
    }
  }

  /// Saves [prices] for [locale] when they are complete and changed.
  void write(String locale, PaywallPrices prices) {
    if (!prices.isComplete || read(locale) == prices) return;
    unawaited(_prefs.setString(key, jsonEncode(prices._toJson(locale))));
  }
}

/// The price cache once the preferences are loaded (null before).
final paywallPriceCacheProvider = Provider<PaywallPriceCache?>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider).valueOrNull;
  return prefs == null ? null : PaywallPriceCache(prefs);
});
