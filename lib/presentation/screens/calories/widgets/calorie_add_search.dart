import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:shoply/core/design/design.dart';
import 'package:shoply/core/localization/localization_helper.dart';
import 'package:shoply/data/models/food_log_entry.dart';
import 'package:shoply/data/models/food_product.dart';
import 'package:shoply/data/models/user_food.dart';
import 'package:shoply/data/services/connectivity_service.dart';
import 'package:shoply/presentation/screens/calories/widgets/calorie_add_parts.dart';
import 'package:shoply/presentation/screens/calories/widgets/calorie_amount_food.dart';
import 'package:shoply/presentation/screens/calories/widgets/calorie_format.dart';
import 'package:shoply/presentation/screens/calories/widgets/calorie_recent_row.dart';
import 'package:shoply/presentation/screens/calories/widgets/calorie_timing.dart';
import 'package:shoply/presentation/state/calorie_diary_provider.dart';
import 'package:shoply/presentation/state/calorie_entry_provider.dart';
import 'package:shoply/presentation/widgets/design/app_button.dart';
import 'package:shoply/presentation/widgets/design/avo_figure.dart';
import 'package:shoply/presentation/widgets/design/empty_state.dart';
import 'package:shoply/presentation/widgets/design/inset_section.dart';
import 'package:shoply/presentation/widgets/design/search_field.dart';
import 'package:shoply/presentation/widgets/design/settings_rows.dart';
import 'package:shoply/presentation/widgets/design/skeleton.dart';
import 'package:shoply/presentation/widgets/design/status_row.dart';

/// How many foods "Zuletzt gegessen" shows without a search (S3).
const int _kRecentShown = 8;
const double _kManualGlyph = 17; // D2 square.and.pencil

/// S3 "Suche": "Zuletzt gegessen" (plus logs, text opens S7), own foods at
/// once, Open Food Facts after a pause in typing, "Manuell eintragen", and
/// "Nichts gefunden" with Avo thinking.
class CalorieAddSearch extends ConsumerStatefulWidget {
  const CalorieAddSearch({super.key, required this.actions});

  final CalorieAddActions actions;

  @override
  ConsumerState<CalorieAddSearch> createState() => _CalorieAddSearchState();
}

class _CalorieAddSearchState extends ConsumerState<CalorieAddSearch> {
  String _query = '';
  String _onlineQuery = '';
  Timer? _pause;

  @override
  void dispose() {
    _pause?.cancel();
    super.dispose();
  }

  void _search(String q) {
    setState(() => _query = q);
    _pause?.cancel();
    _pause = Timer(CalorieTiming.searchPause, () {
      if (mounted) setState(() => _onlineQuery = q.trim());
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final recents = ref.watch(recentFoodsProvider);
    final own = ref.watch(userFoodsProvider);
    final offline = ref.watch(isOfflineProvider);
    final query = _query.trim().toLowerCase();
    final recentMatches = query.isEmpty
        ? recents.foods.take(_kRecentShown).toList()
        : recents.foods
            .where((f) =>
                f.template.foodName.toLowerCase().contains(query) ||
                (f.template.brand?.toLowerCase().contains(query) ?? false))
            .toList();
    final ownMatches = query.isEmpty ? const <UserFood>[] : own.where((f) => f.name.toLowerCase().contains(query)).toList();

    final online = _onlineQuery.length >= 2 && !offline && _onlineQuery.toLowerCase() == query;
    final hits = online ? ref.watch(calorieFoodSearchProvider(_onlineQuery)) : null;
    final onlineDone = hits != null && !hits.isLoading;
    final hitList = hits?.valueOrNull ?? const <FoodProduct>[];
    final searchedAll = offline || onlineDone;
    final nothing = query.isNotEmpty && recentMatches.isEmpty && ownMatches.isEmpty && hitList.isEmpty && searchedAll && !(hits?.hasError ?? false);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: AvoSpacing.screen),
        child: AvoSearchField(hint: context.tr('cal_search_placeholder'), onChanged: _search),
      ),
      if (offline) ...[
        const SizedBox(height: AvoSpacing.s),
        StatusRow(kind: StatusKind.offline, text: context.tr('cal_search_offline')),
      ] else if (hits?.hasError ?? false) ...[
        const SizedBox(height: AvoSpacing.s),
        StatusRow(
          kind: StatusKind.sectionError,
          text: context.tr('cal_search_error'),
          actionLabel: context.tr('retry'),
          onAction: () => ref.invalidate(calorieFoodSearchProvider(_onlineQuery)),
        ),
      ] else if (recents.failed) ...[
        const SizedBox(height: AvoSpacing.s),
        StatusRow(
          kind: StatusKind.sectionError,
          text: context.tr('cal_recent_error'),
          actionLabel: context.tr('retry'),
          onAction: () => retryRecentFoods(ref),
        ),
      ],
      if (recentMatches.isNotEmpty)
        InsetSection(
          header: context.tr('cal_sec_recent'),
          children: [
            for (final f in recentMatches)
              RecentFoodRow(
                key: ValueKey('cal-recent-${f.key}'),
                food: f,
                onLog: () => widget.actions.logAgain(f),
                onOtherAmount: () => widget.actions.openAmount(CalorieAmountFood.fromEntry(f.template)),
                onRemove: () => ref.read(recentFoodsHiddenProvider.notifier).hide(f.key),
              ),
          ],
        )
      else if (query.isEmpty && !recents.failed && !recents.known)
        Padding(
          padding: const EdgeInsets.only(top: AvoSpacing.section),
          child: InsetSection(children: [
            SkeletonSection(rows: 3, withImage: false, loadingLabel: context.tr('cal_loading')),
          ]),
        )
      else if (query.isEmpty && !recents.failed)
        Padding(
          padding: const EdgeInsets.fromLTRB(AvoSpacing.xxxl, AvoSpacing.xl, AvoSpacing.xxxl, 0),
          child: Text(
            context.tr('cal_recent_first_run'),
            style: context.text(AvoTextStyle.footnote, color: colors.secondaryLabel),
          ),
        ),
      if (ownMatches.isNotEmpty)
        InsetSection(
          header: context.tr('cal_sec_own'),
          children: [
            for (final f in ownMatches)
              CalorieFoodRow(
                key: ValueKey('cal-own-${f.id}'),
                name: f.name,
                subtitle: context.tr('cal_kcal_per_100g', params: {'kcal': context.kcal(f.kcal100)}),
                onTap: () => widget.actions.openAmount(CalorieAmountFood.fromUserFood(f)),
              ),
          ],
        ),
      if (hitList.isNotEmpty) ...[
        InsetSection(
          header: context.tr('cal_sec_foods'),
          separatorIndent: context.isAccessibilityText ? AvoSpacing.l : AvoSpacing.l + AvoSizes.thumbSmall + AvoSpacing.m,
          children: [
            for (final p in hitList)
              CalorieFoodRow(
                key: ValueKey('cal-off-${p.barcode}'),
                name: p.name,
                imageUrl: p.imageUrl,
                reserveImage: true,
                subtitle: calorieProductLine(context, p),
                onTap: () => widget.actions.openAmount(CalorieAmountFood.fromProduct(p, origin: FoodEntryOrigin.search)),
              ),
          ],
        ),
        OffSourceLink(color: colors.secondaryLabel),
      ],
      if (nothing)
        Padding(
          padding: const EdgeInsets.only(top: AvoSpacing.l),
          child: Column(
            children: [
              EmptyState(
                pose: AvoPose.thinking,
                title: context.tr('cal_search_none', params: {'query': _query.trim()}),
              ),
              const SizedBox(height: AvoSpacing.l),
              AppButton.primary(label: context.tr('cal_manual_row'), onPressed: () => widget.actions.openManual(name: _query)),
            ],
          ),
        )
      else ...[
        const SizedBox(height: AvoSpacing.section),
        InsetSection(children: [
          NavRow(
            leading: ExcludeSemantics(
              child: Icon(CupertinoIcons.square_pencil, size: _kManualGlyph, color: colors.secondaryLabel),
            ),
            title: context.tr('cal_manual_row'),
            subtitle: context.tr('cal_manual_row_sub'),
            onTap: () => widget.actions.openManual(name: _query),
          ),
        ]),
      ],
    ]);
  }

}
