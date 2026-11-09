import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shoply/presentation/screens/profile/account/account_local_data.dart';
import 'package:shoply/presentation/screens/subscription/paywall_screen.dart';
import 'package:shoply/presentation/screens/subscription/widgets/paywall_view.dart';
import 'package:shoply/presentation/widgets/design/pro_gate.dart';

import '../../layout/layout_matrix.dart';

final _today = DateTime(2026, 11, 7);

const _prices = PaywallData(
  yearlyPrice: '29,99 €',
  yearlyPerMonth: '2,49 €',
  monthlyPrice: '2,99 €',
  savingPercent: 16,
  trialDays: 14,
);

PaywallData _with({
  ProFeatureInfo? feature,
  PaywallPlan plan = PaywallPlan.yearly,
  bool prices = true,
  bool trial = true,
  bool trialUsed = false,
  PaywallProblem? problem,
  bool purchasing = false,
  bool pending = false,
  bool active = false,
}) => PaywallData(
  feature: feature,
  plan: plan,
  yearlyPrice: prices ? _prices.yearlyPrice : null,
  yearlyPerMonth: prices ? _prices.yearlyPerMonth : null,
  monthlyPrice: prices ? _prices.monthlyPrice : null,
  savingPercent: prices ? 16 : null,
  trialDays: trial ? 14 : null,
  trialUsed: trialUsed,
  problem: problem,
  purchasing: purchasing,
  pending: pending,
  active: active,
  activeStatus: active ? 'Testphase bis Sa., 21. Nov. 2026' : null,
  today: _today,
);

const _std = LayoutCase(width: 390, scale: 1);

Future<void> _pump(WidgetTester tester, Widget view) async {
  await loadLayoutFonts();
  tester.view.physicalSize = const Size(390 * 3, kLayoutHeight * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(layoutHarness(_std, view));
  await tester.pump();
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pump();
  await tester.tap(finder, warnIfMissed: false);
  await tester.pump();
}

class _Log {
  final calls = <String>[];
  PaywallActions get actions => PaywallActions(
    onClose: () => calls.add('close'),
    onPlan: (p) => calls.add('plan ${p.name}'),
    onBuy: () => calls.add('buy'),
    onRestore: () => calls.add('restore'),
    onRetry: () => calls.add('retry'),
    onTerms: () => calls.add('terms'),
    onPrivacy: () => calls.add('privacy'),
    onManage: () => calls.add('manage'),
  );
}

Widget _view(PaywallData data, [_Log? log]) => SizedBox(
  height: kLayoutHeight,
  child: PaywallView(data: data, actions: (log ?? _Log()).actions),
);

ProductDetails _product(String id, String price, double raw) => ProductDetails(
  id: id,
  title: id,
  description: '',
  price: price,
  rawPrice: raw,
  currencyCode: 'EUR',
);

void main() {
  final cook = ProFeatures.info(ProFeatures.cookMode);

  layoutMatrix('paywall', (_) => _view(_with()), checkTapTargets: true);
  layoutMatrix(
    'paywall from the cooking mode',
    (_) => _view(_with(feature: cook)),
  );
  layoutMatrix(
    'paywall loading, monthly, no trial',
    (_) => _view(_with(prices: false, trial: false, plan: PaywallPlan.monthly)),
  );
  layoutMatrix(
    'paywall store error',
    (_) => _view(_with(problem: PaywallProblem.store, trialUsed: true)),
  );
  layoutMatrix('paywall pending', (_) => _view(_with(pending: true)));
  layoutMatrix('paywall active', (_) => _view(_with(active: true)));

  testWidgets(
    'the feature that opened the paywall comes first, with "Danach"',
    (tester) async {
      await _pump(tester, _view(_with(feature: cook)));
      final cookTop = tester.getTopLeft(find.text('Cooking mode')).dy;
      final aiTop = tester.getTopLeft(find.text('More from Avo')).dy;
      expect(cookTop, lessThan(aiTop));
      expect(find.text('Then you go straight on to step 2.'), findsOneWidget);
    },
  );

  testWidgets('plans, trial, buy and links call back', (tester) async {
    final log = _Log();
    await _pump(tester, _view(_with(), log));
    expect(find.text('29,99 € a year · 2,49 € a month'), findsOneWidget);
    expect(find.text('16 % cheaper'), findsOneWidget);
    expect(
      find.text('Sat, 21. Nov: subscription starts, 29,99 €'),
      findsOneWidget,
    );
    expect(find.textContaining('Then 29,99 € a year.'), findsOneWidget);

    await _tap(tester, find.text('Monthly'));
    await _tap(tester, find.text('Try 14 days free'));
    await _tap(tester, find.text('Terms of use'));
    await _tap(tester, find.text('Privacy'));
    await _tap(tester, find.text('Restore purchases'));
    await _tap(tester, find.bySemanticsLabel('Close'));
    expect(log.calls, [
      'plan monthly',
      'buy',
      'terms',
      'privacy',
      'restore',
      'close',
    ]);
  });

  testWidgets('without prices or offline nothing can be bought', (
    tester,
  ) async {
    final log = _Log();
    await _pump(tester, _view(_with(prices: false), log));
    await _tap(tester, find.text('Try 14 days free'));
    expect(log.calls, isEmpty);
    expect(find.text('…'), findsWidgets);

    await tester.pumpWidget(
      layoutHarness(_std, _view(_with(problem: PaywallProblem.offline), log)),
    );
    await tester.pump();
    expect(
      find.text('You’re offline. Buying needs a connection.'),
      findsOneWidget,
    );
    await _tap(tester, find.text('Try 14 days free'));
    expect(log.calls, isEmpty);
  });

  testWidgets('trial used: no timeline, "Subscribe"', (tester) async {
    await _pump(tester, _view(_with(trialUsed: true)));
    expect(find.text('You have already used the trial.'), findsOneWidget);
    expect(find.text('How the trial works'), findsNothing);
    expect(find.text('Subscribe'), findsOneWidget);
  });

  testWidgets('active: status and "Manage subscription", no plans', (
    tester,
  ) async {
    final log = _Log();
    await _pump(tester, _view(_with(active: true), log));
    expect(find.text('You have Avo Pro'), findsOneWidget);
    expect(find.text('Choose a plan'), findsNothing);
    await _tap(tester, find.text('Manage subscription'));
    expect(log.calls, ['manage']);
  });

  test('prices: monthly share and saving are rounded down', () {
    final prices = PaywallPrices.from([
      _product('shoply_premium_yearly', '29,99 €', 29.99),
      _product('shoply_premium_monthly', '2,99 €', 2.99),
    ], 'de-DE');
    expect(prices.yearly, '29,99 €');
    expect(prices.monthly, '2,99 €');
    expect(prices.yearlyPerMonth, '2,49\u00a0€');
    expect(prices.savingPercent, 16);

    final onlyYearly = PaywallPrices.from([
      _product('shoply_premium_yearly', '29,99 €', 29.99),
    ], 'de-DE');
    expect(onlyYearly.savingPercent, isNull);
    expect(PaywallPrices.from(const [], 'de-DE').yearly, isNull);
  });

  test('cached prices show but cannot buy until StoreKit answers', () {
    const cached = PaywallData(
      yearlyPrice: '29,99 €',
      yearlyPerMonth: '2,49 €',
      monthlyPrice: '2,99 €',
      pricesCached: true,
    );
    expect(cached.canBuy, isFalse);
    expect(cached.copyWith(plan: PaywallPlan.monthly).canBuy, isFalse);
    const live = PaywallData(yearlyPrice: '29,99 €', monthlyPrice: '2,99 €');
    expect(live.canBuy, isTrue);
  });

  test('price cache: saved per language, read back, ignored elsewhere',
      () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final cache = PaywallPriceCache(prefs);
    expect(cache.read('de-DE'), isNull);
    const prices = PaywallPrices(
      yearly: '29,99 €',
      yearlyPerMonth: '2,49 €',
      monthly: '2,99 €',
      savingPercent: 16,
    );
    cache.write('de-DE', prices);
    expect(cache.read('de-DE'), prices);
    expect(cache.read('en-US'), isNull);
    // Incomplete prices are never saved.
    cache.write('en-US', const PaywallPrices(yearly: r'$29.99'));
    expect(cache.read('en-US'), isNull);
    // Prices belong to the App Store country, not the account.
    expect(isDeviceBoundPreference(PaywallPriceCache.key), isTrue);
  });
}
