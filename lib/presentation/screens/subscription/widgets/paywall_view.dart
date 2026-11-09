import 'package:flutter/cupertino.dart';

import 'package:intl/intl.dart';

import 'package:shoply/core/constants/app_brand.dart';
import 'package:shoply/core/design/design.dart';
import 'package:shoply/core/localization/localization_helper.dart';
import 'package:shoply/presentation/widgets/design/app_button.dart';
import 'package:shoply/presentation/widgets/design/avo_icons.dart';
import 'package:shoply/presentation/widgets/design/glass_icon_button.dart';
import 'package:shoply/presentation/widgets/design/inset_section.dart';
import 'package:shoply/presentation/widgets/design/pro_gate.dart';
import 'package:shoply/presentation/widgets/design/select_circle.dart';
import 'package:shoply/presentation/widgets/design/status_row.dart';

/// What went wrong on the paywall (Konzept 18 §8.5).
enum PaywallProblem {
  /// The products could not be loaded.
  store,

  /// No connection.
  offline,

  /// StoreKit reported an error for the purchase.
  purchase,

  /// Restoring failed.
  restore,
}

/// The two plans of Avo Pro.
enum PaywallPlan { yearly, monthly }

/// Everything the paywall shows, without StoreKit (Konzept 18 §8).
@immutable
class PaywallData {
  /// Creates the state.
  const PaywallData({
    this.feature,
    this.plan = PaywallPlan.yearly,
    this.yearlyPrice,
    this.yearlyPerMonth,
    this.monthlyPrice,
    this.savingPercent,
    this.pricesCached = false,
    this.trialDays,
    this.trialUsed = false,
    this.problem,
    this.purchasing = false,
    this.restoring = false,
    this.pending = false,
    this.active = false,
    this.activeStatus,
    this.today,
  });

  /// The feature that opened the paywall; its row comes first, highlighted.
  final ProFeatureInfo? feature;

  /// The chosen plan (yearly by default).
  final PaywallPlan plan;

  /// Localised store prices; null while unknown ("…").
  final String? yearlyPrice;
  final String? yearlyPerMonth;
  final String? monthlyPrice;

  /// "16 % günstiger", rounded down; null when a price is missing.
  final int? savingPercent;

  /// The prices come from the last opening; StoreKit has not answered yet,
  /// so the main action waits (same label, disabled).
  final bool pricesCached;

  /// Length of the free trial the account may still start; null without one.
  final int? trialDays;

  /// The account already had its trial.
  final bool trialUsed;

  /// The problem to show above the plans, if any.
  final PaywallProblem? problem;

  /// A purchase sheet is open: everything but the store sheet waits.
  final bool purchasing;

  /// "Käufe wiederherstellen" is running.
  final bool restoring;

  /// Ask to Buy waits for approval.
  final bool pending;

  /// The person has Avo Pro: status and "Abo verwalten" instead of plans.
  final bool active;

  /// The status line in [active] ("Testphase bis Sa., 21. Nov.").
  final String? activeStatus;

  /// The day the trial timeline counts from; null is today.
  final DateTime? today;

  /// Whether the main action can start a purchase.
  bool get canBuy =>
      !purchasing &&
      !pending &&
      !pricesCached &&
      problem != PaywallProblem.offline &&
      (plan == PaywallPlan.yearly ? yearlyPrice : monthlyPrice) != null;

  /// A trial runs with the purchase.
  bool get withTrial => trialDays != null && !trialUsed;

  /// Copy with other values.
  PaywallData copyWith({
    PaywallPlan? plan,
    PaywallProblem? problem,
    bool clearProblem = false,
    bool? purchasing,
    bool? restoring,
  }) => PaywallData(
    feature: feature,
    plan: plan ?? this.plan,
    yearlyPrice: yearlyPrice,
    yearlyPerMonth: yearlyPerMonth,
    monthlyPrice: monthlyPrice,
    savingPercent: savingPercent,
    pricesCached: pricesCached,
    trialDays: trialDays,
    trialUsed: trialUsed,
    problem: clearProblem ? null : (problem ?? this.problem),
    purchasing: purchasing ?? this.purchasing,
    restoring: restoring ?? this.restoring,
    pending: pending,
    active: active,
    activeStatus: activeStatus,
    today: today,
  );
}

/// The callbacks of [PaywallView].
@immutable
class PaywallActions {
  /// Creates the callbacks.
  const PaywallActions({
    required this.onClose,
    required this.onPlan,
    required this.onBuy,
    required this.onRestore,
    required this.onRetry,
    required this.onTerms,
    required this.onPrivacy,
    required this.onManage,
  });

  final VoidCallback onClose;
  final ValueChanged<PaywallPlan> onPlan;
  final VoidCallback onBuy;
  final VoidCallback onRestore;
  final VoidCallback onRetry;
  final VoidCallback onTerms;
  final VoidCallback onPrivacy;
  final VoidCallback onManage;
}

/// The Avo Pro paywall as a full screen (Konzept 18 §8): close, title,
/// benefits, plans, trial timeline, a pinned action bar with the legal
/// links. Never a sheet, never a countdown, no mascot.
class PaywallView extends StatelessWidget {
  /// Creates the paywall for [data].
  const PaywallView({super.key, required this.data, required this.actions});

  final PaywallData data;
  final PaywallActions actions;

  /// The action bar stops being pinned from this text scale on (AX1): it
  /// would take more than a quarter of the screen (Konzept 18 §8.10).
  static const double _pinnedMaxScale = 1.6;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final scale = MediaQuery.textScalerOf(context).scale(17) / 17;
    final pinned = scale < _pinnedMaxScale;
    final bar = _ActionBar(data: data, actions: actions);
    final top = MediaQuery.paddingOf(context).top;

    final content = <Widget>[
      SizedBox(height: top + AvoSizes.toolbarButton + AvoSpacing.l),
      _Header(data: data),
      const SizedBox(height: AvoSpacing.section),
      _Benefits(data: data),
      if (!data.active) ...[
        if (data.problem != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AvoSpacing.screen,
              AvoSpacing.section,
              AvoSpacing.screen,
              0,
            ),
            child: _Problem(data: data, onRetry: actions.onRetry),
          ),
        const SizedBox(height: AvoSpacing.section),
        _Plans(data: data, onPlan: actions.onPlan),
        const SizedBox(height: AvoSpacing.section),
        _Trial(data: data),
      ],
      if (!pinned) ...[const SizedBox(height: AvoSpacing.section), bar],
      const SizedBox(height: AvoSpacing.section),
    ];

    return ColoredBox(
      color: colors.background,
      child: Stack(
        children: [
          Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: content,
                  ),
                ),
              ),
              if (pinned) bar,
            ],
          ),
          Positioned(
            top: top + AvoSpacing.xs,
            left: AvoSpacing.screen,
            child: GlassIconButton(
              icon: const AvoIcon(AvoIcons.xmark),
              semanticLabel: context.tr('pro_close'),
              onPressed: data.purchasing ? null : actions.onClose,
            ),
          ),
        ],
      ),
    );
  }
}

String _proText(BuildContext context, String key, [Map<String, String>? p]) =>
    context.tr(key, params: {'pro': AppBrand.proName, ...?p});

class _Header extends StatelessWidget {
  const _Header({required this.data});

  final PaywallData data;

  @override
  Widget build(BuildContext context) {
    final status = data.activeStatus;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AvoSpacing.screen),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            header: true,
            child: Text(
              data.active
                  ? _proText(context, 'pro_active_title')
                  : AppBrand.proName,
              style: context.text(AvoTextStyle.title1, weight: FontWeight.w700),
            ),
          ),
          const SizedBox(height: AvoSpacing.xs),
          Text(
            data.active && status != null ? status : context.tr('pro_tagline'),
            style: context.text(AvoTextStyle.body),
          ),
        ],
      ),
    );
  }
}

class _Benefits extends StatelessWidget {
  const _Benefits({required this.data});

  final PaywallData data;

  @override
  Widget build(BuildContext context) {
    final lead = data.active ? null : data.feature;
    final rows = [
      if (lead != null) lead,
      for (final f in ProFeatures.all)
        if (f.id != lead?.id) f,
    ];
    return InsetSection(
      children: [
        for (final f in rows) _BenefitRow(info: f, highlighted: f == lead),
      ],
    );
  }
}

class _BenefitRow extends StatelessWidget {
  const _BenefitRow({required this.info, required this.highlighted});

  final ProFeatureInfo info;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final next = highlighted ? info.continueKey : null;
    return MergeSemantics(
      child: Container(
        color: highlighted ? colors.tintFill : null,
        padding: const EdgeInsets.symmetric(
          horizontal: AvoSpacing.l,
          vertical: AvoSpacing.m,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ExcludeSemantics(
              child: AvoIcon(info.icon, size: 22, color: colors.tint),
            ),
            const SizedBox(width: AvoSpacing.m),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.tr(info.titleKey),
                    style: context.text(AvoTextStyle.headline),
                  ),
                  const SizedBox(height: AvoSpacing.xxs),
                  Text(
                    context.tr(info.bodyKey),
                    style: context.text(
                      AvoTextStyle.subhead,
                      color: colors.secondaryLabel,
                    ),
                  ),
                  if (next != null) ...[
                    const SizedBox(height: AvoSpacing.xs),
                    Text(
                      context.tr(next),
                      style: context.text(AvoTextStyle.subhead),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Problem extends StatelessWidget {
  const _Problem({required this.data, required this.onRetry});

  final PaywallData data;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final (kind, key, retry) = switch (data.problem!) {
      PaywallProblem.store => (
        StatusKind.sectionError,
        'pro_error_store',
        true,
      ),
      PaywallProblem.offline => (
        StatusKind.offline,
        'pro_error_offline',
        false,
      ),
      PaywallProblem.purchase => (
        StatusKind.failed,
        'pro_error_purchase',
        true,
      ),
      PaywallProblem.restore => (StatusKind.failed, 'pro_restore_failed', true),
    };
    return StatusRow(
      kind: kind,
      text: context.tr(key),
      actionLabel: retry ? context.tr('pro_retry') : null,
      onAction: retry ? onRetry : null,
    );
  }
}

class _Plans extends StatelessWidget {
  const _Plans({required this.data, required this.onPlan});

  final PaywallData data;
  final ValueChanged<PaywallPlan> onPlan;

  @override
  Widget build(BuildContext context) {
    final loading = context.tr('pro_price_loading');
    final yearly = data.yearlyPrice;
    final perMonth = data.yearlyPerMonth;
    final monthly = data.monthlyPrice;
    final saving = data.savingPercent;
    final enabled = !data.purchasing;
    return InsetSection(
      header: context.tr('pro_plans_header'),
      children: [
        _PlanRow(
          title: context.tr('pro_plan_yearly'),
          price: yearly == null || perMonth == null
              ? loading
              : context.tr(
                  'pro_plan_yearly_price',
                  params: {'price': yearly, 'monthly': perMonth},
                ),
          saving: saving == null
              ? null
              : context.tr('pro_plan_saving', params: {'percent': '$saving'}),
          selected: data.plan == PaywallPlan.yearly,
          onTap: enabled ? () => onPlan(PaywallPlan.yearly) : null,
        ),
        _PlanRow(
          title: context.tr('pro_plan_monthly'),
          price: monthly == null
              ? loading
              : context.tr(
                  'pro_plan_monthly_price',
                  params: {'price': monthly},
                ),
          selected: data.plan == PaywallPlan.monthly,
          onTap: enabled ? () => onPlan(PaywallPlan.monthly) : null,
        ),
      ],
    );
  }
}

class _PlanRow extends StatelessWidget {
  const _PlanRow({
    required this.title,
    required this.price,
    required this.selected,
    required this.onTap,
    this.saving,
  });

  final String title;
  final String price;
  final String? saving;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final badge = saving;
    return Semantics(
      inMutuallyExclusiveGroup: true,
      selected: selected,
      button: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: AvoSizes.hitTarget),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AvoSpacing.l,
              vertical: AvoSpacing.m,
            ),
            child: Row(
              children: [
                ExcludeSemantics(
                  child: SelectCircle(
                    selected: selected,
                    onChanged: onTap == null ? null : (_) => onTap!(),
                    semanticLabel: title,
                  ),
                ),
                const SizedBox(width: AvoSpacing.m),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: context.text(AvoTextStyle.headline)),
                      const SizedBox(height: AvoSpacing.xxs),
                      Text(
                        price,
                        style: context.text(
                          AvoTextStyle.subhead,
                          color: colors.secondaryLabel,
                          tabular: true,
                        ),
                      ),
                      if (badge != null) ...[
                        const SizedBox(height: AvoSpacing.xs),
                        _SavingCapsule(text: badge),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SavingCapsule extends StatelessWidget {
  const _SavingCapsule({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return DecoratedBox(
      decoration: ShapeDecoration(
        color: colors.tintFill,
        shape: const StadiumBorder(),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AvoSpacing.s,
          vertical: AvoSpacing.xxs,
        ),
        child: Text(
          text,
          style: context.text(
            AvoTextStyle.caption2,
            color: colors.tint,
            weight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _Trial extends StatelessWidget {
  const _Trial({required this.data});

  final PaywallData data;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    if (data.trialUsed) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: AvoSpacing.screen),
        child: Text(
          context.tr('pro_trial_used'),
          style: context.text(
            AvoTextStyle.subhead,
            color: colors.secondaryLabel,
          ),
        ),
      );
    }
    final days = data.trialDays;
    if (days == null) return const SizedBox.shrink();
    final locale = Localizations.localeOf(context).toLanguageTag();
    final day = DateFormat('EEE, d. MMM', locale);
    final today = data.today ?? DateTime.now();
    final start = DateTime(today.year, today.month, today.day + days);
    final yearly = data.plan == PaywallPlan.yearly;
    final price =
        (yearly ? data.yearlyPrice : data.monthlyPrice) ??
        context.tr('pro_price_loading');
    // No "Erinnerung per Mitteilung" step until the reminder is really
    // scheduled (Konzept 18 §8.7.6): a promise on the paywall must hold.
    final steps = [
      context.tr('pro_trial_today'),
      context.tr(
        yearly ? 'pro_trial_start_yearly' : 'pro_trial_start_monthly',
        params: {'date': day.format(start), 'price': price},
      ),
    ];
    return InsetSection(
      header: context.tr('pro_trial_header'),
      children: [
        for (var i = 0; i < steps.length; i++)
          _TrialStep(text: steps[i], first: i == 0),
      ],
    );
  }
}

class _TrialStep extends StatelessWidget {
  const _TrialStep({required this.text, required this.first});

  final String text;
  final bool first;

  /// Dot of the timeline. // D2
  static const double _dot = 10;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AvoSpacing.l,
        vertical: AvoSpacing.m,
      ),
      child: Row(
        children: [
          ExcludeSemantics(
            child: Container(
              width: _dot,
              height: _dot,
              decoration: BoxDecoration(
                color: first ? colors.tint : colors.fillStrong,
                shape: BoxShape.circle,
              ),
            ),
          ),
          const SizedBox(width: AvoSpacing.m),
          Expanded(child: Text(text, style: context.text(AvoTextStyle.body))),
        ],
      ),
    );
  }
}

class _ActionBar extends StatelessWidget {
  const _ActionBar({required this.data, required this.actions});

  final PaywallData data;
  final PaywallActions actions;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final bottom = MediaQuery.paddingOf(context).bottom;
    final yearly = data.plan == PaywallPlan.yearly;
    final price = yearly ? data.yearlyPrice : data.monthlyPrice;

    final Widget main;
    if (data.active) {
      main = AppButton.filledNeutral(
        label: context.tr('pro_manage'),
        expand: true,
        size: AppButtonSize.large,
        onPressed: actions.onManage,
      );
    } else if (data.pending) {
      main = Row(
        children: [
          AvoIcon(AvoIcons.clock, size: 20, color: colors.secondaryLabel),
          const SizedBox(width: AvoSpacing.s),
          Expanded(
            child: Text(
              _proText(context, 'pro_pending'),
              style: context.text(AvoTextStyle.subhead),
            ),
          ),
        ],
      );
    } else {
      final label = data.withTrial
          ? context.tr('pro_cta_trial', params: {'days': '${data.trialDays}'})
          : !yearly && price != null
          ? context.tr('pro_cta_monthly', params: {'price': price})
          : context.tr('pro_cta_subscribe');
      main = AppButton.primary(
        label: label,
        expand: true,
        size: AppButtonSize.large,
        working: data.purchasing,
        workingLabel: context.tr('pro_cta_working'),
        onPressed: data.canBuy ? actions.onBuy : null,
      );
    }

    final footKey = data.withTrial
        ? (yearly ? 'pro_footnote_yearly' : 'pro_footnote_monthly')
        : (yearly ? 'pro_footnote_yearly_now' : 'pro_footnote_monthly_now');
    final linksEnabled = !data.purchasing;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        AvoSpacing.screen,
        AvoSpacing.m,
        AvoSpacing.screen,
        bottom + AvoSpacing.s,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          main,
          if (!data.active && price != null) ...[
            const SizedBox(height: AvoSpacing.s),
            Text(
              context.tr(footKey, params: {'price': price}),
              textAlign: TextAlign.center,
              style: context.text(
                AvoTextStyle.footnote,
                color: colors.secondaryLabel,
              ),
            ),
          ],
          Wrap(
            alignment: WrapAlignment.center,
            children: [
              _FootLink(
                label: context.tr('pro_restore'),
                working: data.restoring,
                onTap: linksEnabled && !data.restoring
                    ? actions.onRestore
                    : null,
              ),
              _FootLink(
                label: context.tr('pro_terms'),
                onTap: linksEnabled ? actions.onTerms : null,
              ),
              _FootLink(
                label: context.tr('pro_privacy'),
                onTap: linksEnabled ? actions.onPrivacy : null,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FootLink extends StatelessWidget {
  const _FootLink({required this.label, this.onTap, this.working = false});

  final String label;
  final VoidCallback? onTap;
  final bool working;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Semantics(
      button: true,
      enabled: onTap != null,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minHeight: AvoSizes.hitTarget,
            minWidth: AvoSizes.hitTarget,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AvoSpacing.s),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (working) ...[
                  const CupertinoActivityIndicator(radius: 6),
                  const SizedBox(width: AvoSpacing.xs),
                ],
                Flexible(
                  child: Text(
                    label,
                    textAlign: TextAlign.center,
                    style: context.text(
                      AvoTextStyle.footnote,
                      color: onTap == null && !working
                          ? colors.tertiaryLabel
                          : colors.tint,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
