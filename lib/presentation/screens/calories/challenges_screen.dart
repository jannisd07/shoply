import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shoply/core/constants/app_colors.dart';
import 'package:shoply/core/constants/app_dimensions.dart';
import 'package:shoply/core/localization/localization_helper.dart';
import 'package:shoply/core/widgets/design_system.dart';
import 'package:shoply/data/models/diet_challenge.dart';
import 'package:shoply/data/services/diet_challenge_service.dart';
import 'package:shoply/presentation/state/diet_challenge_provider.dart';

/// Diet challenges (16:8 fasting, 30-day no sugar, ...): browse the
/// catalog, start one, check in daily, and see past results. A challenge
/// is entirely opt-in — nothing here is required to use calorie tracking.
class ChallengesScreen extends ConsumerWidget {
  const ChallengesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textPrimary = AppColors.textPrimary(context);
    final textSecondary = AppColors.textSecondary(context);
    final activeAsync = ref.watch(activeChallengesProvider);
    final historyAsync = ref.watch(challengeHistoryProvider);

    return Scaffold(
      backgroundColor: AppColors.background(context),
      appBar: AppBar(
        backgroundColor: AppColors.background(context),
        elevation: 0,
        title: Text(context.tr('challenges_title'),
            style: TextStyle(color: textPrimary, fontWeight: FontWeight.w600)),
      ),
      body: SafeArea(
        top: false,
        child: RefreshIndicator(
          onRefresh: () async => invalidateChallenges(ref),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
                AppDimensions.screenHorizontalPadding, 8, AppDimensions.screenHorizontalPadding, 140),
            children: [
              Text(context.tr('challenges_subtitle'),
                  style: TextStyle(fontSize: 13.5, height: 1.4, color: textSecondary)),
              const SizedBox(height: 20),
              AppSectionHeader(title: context.tr('challenge_active_section')),
              activeAsync.when(
                loading: () => const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (_, __) => Text(context.tr('challenge_empty_active'),
                    style: TextStyle(fontSize: 13, color: textSecondary)),
                data: (active) {
                  if (active.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text(context.tr('challenge_empty_active'),
                          style: TextStyle(fontSize: 13, color: textSecondary)),
                    );
                  }
                  return Column(
                    children: active
                        .map((c) => Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: _ActiveChallengeCard(challenge: c),
                            ))
                        .toList(),
                  );
                },
              ),
              const SizedBox(height: 12),
              AppSectionHeader(title: context.tr('challenge_catalog_section')),
              Consumer(
                builder: (context, ref, _) {
                  final activeTypes =
                      activeAsync.valueOrNull?.map((c) => c.type).toSet() ?? <ChallengeType>{};
                  final catalog = [ChallengeType.fasting16_8, ChallengeType.noSugar30]
                      .where((t) => !activeTypes.contains(t))
                      .toList();
                  if (catalog.isEmpty) {
                    return const SizedBox.shrink();
                  }
                  return Column(
                    children: catalog
                        .map((t) => Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: _CatalogCard(type: t),
                            ))
                        .toList(),
                  );
                },
              ),
              const SizedBox(height: 12),
              AppSectionHeader(title: context.tr('challenge_history_section')),
              historyAsync.when(
                loading: () => const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (_, __) => const SizedBox.shrink(),
                data: (history) {
                  if (history.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text(context.tr('challenge_empty_history'),
                          style: TextStyle(fontSize: 13, color: textSecondary)),
                    );
                  }
                  return Column(
                    children: history
                        .map((c) => Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: _HistoryTile(challenge: c),
                            ))
                        .toList(),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _typeTitle(BuildContext context, ChallengeType type) => switch (type) {
      ChallengeType.fasting16_8 => context.tr('challenge_type_fasting_16_8'),
      ChallengeType.noSugar30 => context.tr('challenge_type_no_sugar_30'),
      ChallengeType.custom => context.tr('challenge_type_custom'),
    };

String _typeDescription(BuildContext context, ChallengeType type) => switch (type) {
      ChallengeType.fasting16_8 => context.tr('challenge_type_fasting_16_8_desc'),
      ChallengeType.noSugar30 => context.tr('challenge_type_no_sugar_30_desc'),
      ChallengeType.custom => '',
    };

IconData _typeIcon(ChallengeType type) => switch (type) {
      ChallengeType.fasting16_8 => Icons.hourglass_bottom,
      ChallengeType.noSugar30 => Icons.no_food_outlined,
      ChallengeType.custom => Icons.flag_outlined,
    };

class _CatalogCard extends ConsumerStatefulWidget {
  final ChallengeType type;
  const _CatalogCard({required this.type});

  @override
  ConsumerState<_CatalogCard> createState() => _CatalogCardState();
}

class _CatalogCardState extends ConsumerState<_CatalogCard> {
  bool _starting = false;

  Future<void> _start() async {
    if (_starting) return;
    setState(() => _starting = true);
    HapticFeedback.mediumImpact();
    try {
      await ref.read(dietChallengeServiceProvider).startChallenge(widget.type);
      invalidateChallenges(ref);
    } on ChallengeAlreadyActiveException {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.tr('challenge_already_active'))),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.tr('error_generic', params: {'error': '$e'}))),
        );
      }
    } finally {
      if (mounted) setState(() => _starting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textPrimary = AppColors.textPrimary(context);
    final textSecondary = AppColors.textSecondary(context);
    final accent = AppColors.accentColor(context);

    return AppCard(
      margin: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(_typeIcon(widget.type), color: accent, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Text(_typeTitle(context, widget.type),
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: textPrimary)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(_typeDescription(context, widget.type),
              style: TextStyle(fontSize: 13, height: 1.4, color: textSecondary)),
          const SizedBox(height: 14),
          AppOutlineButton(
            text: context.tr('challenge_start_cta'),
            onPressed: _starting ? null : _start,
          ),
        ],
      ),
    );
  }
}

class _ActiveChallengeCard extends ConsumerStatefulWidget {
  final DietChallenge challenge;
  const _ActiveChallengeCard({required this.challenge});

  @override
  ConsumerState<_ActiveChallengeCard> createState() => _ActiveChallengeCardState();
}

class _ActiveChallengeCardState extends ConsumerState<_ActiveChallengeCard> {
  bool _busy = false;

  Future<void> _checkIn(bool kept) async {
    if (_busy) return;
    setState(() => _busy = true);
    HapticFeedback.selectionClick();
    await ref.read(dietChallengeServiceProvider).checkIn(widget.challenge, kept: kept);
    invalidateChallenges(ref);
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _endChallenge({required bool asCompleted}) async {
    if (!asCompleted) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(context.tr('challenge_give_up_confirm_title')),
          content: Text(context.tr('challenge_give_up_confirm_body')),
          actions: [
            TextButton(
                onPressed: () => Navigator.of(context).pop(false), child: Text(context.tr('cancel'))),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(context.tr('challenge_give_up_confirm_cta'),
                  style: const TextStyle(color: AppColors.error)),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }
    setState(() => _busy = true);
    final service = ref.read(dietChallengeServiceProvider);
    if (asCompleted) {
      await service.completeChallenge(widget.challenge);
    } else {
      await service.abandonChallenge(widget.challenge);
    }
    invalidateChallenges(ref);
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final challenge = widget.challenge;
    final textPrimary = AppColors.textPrimary(context);
    final textSecondary = AppColors.textSecondary(context);
    final accent = AppColors.accentColor(context);
    final checkedInToday = challenge.isCheckedInToday;
    final keptToday = challenge.checkinFor(DateTime.now());

    return AppCard(
      margin: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(_typeIcon(challenge.type), color: accent, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Text(_typeTitle(context, challenge.type),
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: textPrimary)),
              ),
              if (challenge.currentStreak > 0)
                AppChip(
                  icon: Icons.local_fire_department,
                  label: context.tr('challenge_streak', params: {'count': '${challenge.currentStreak}'}),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            challenge.fixedDurationDays != null
                ? context.tr('challenge_day_x_of_y',
                    params: {'day': '${challenge.daysElapsed}', 'total': '${challenge.fixedDurationDays}'})
                : context.tr('challenge_day_x', params: {'day': '${challenge.daysElapsed}'}),
            style: TextStyle(fontSize: 13, color: textSecondary),
          ),
          if (challenge.daysRemaining != null) ...[
            const SizedBox(height: 2),
            Text(context.tr('challenge_days_remaining', params: {'days': '${challenge.daysRemaining}'}),
                style: TextStyle(fontSize: 12, color: textSecondary)),
          ],
          if (challenge.totalCheckins > 0) ...[
            const SizedBox(height: 2),
            Text(
                context.tr('challenge_adherence',
                    params: {'percent': '${(challenge.adherenceRate * 100).round()}'}),
                style: TextStyle(fontSize: 12, color: textSecondary)),
          ],
          const SizedBox(height: 14),
          if (checkedInToday)
            Row(
              children: [
                Icon(keptToday == true ? Icons.check_circle : Icons.cancel_outlined,
                    size: 18, color: keptToday == true ? accent : textSecondary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    keptToday == true
                        ? context.tr('challenge_checked_in_kept')
                        : context.tr('challenge_checked_in_missed'),
                    style: TextStyle(fontSize: 13, color: textSecondary),
                  ),
                ),
                TextButton(
                  onPressed: _busy ? null : () => _checkIn(!(keptToday ?? false)),
                  child: Text(context.tr('challenge_change_checkin')),
                ),
              ],
            )
          else
            Row(
              children: [
                Expanded(
                  child: AppOutlineButton(
                    text: context.tr('challenge_checkin_skip'),
                    onPressed: _busy ? null : () => _checkIn(false),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: AppButton(
                    text: context.tr('challenge_checkin_kept'),
                    onPressed: _busy ? null : () => _checkIn(true),
                    size: ButtonSize.small,
                  ),
                ),
              ],
            ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: _busy ? null : () => _endChallenge(asCompleted: false),
                child: Text(context.tr('challenge_give_up'),
                    style: TextStyle(fontSize: 12.5, color: textSecondary)),
              ),
              TextButton(
                onPressed: _busy ? null : () => _endChallenge(asCompleted: true),
                child: Text(context.tr('challenge_finish'), style: TextStyle(fontSize: 12.5, color: accent)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HistoryTile extends StatelessWidget {
  final DietChallenge challenge;
  const _HistoryTile({required this.challenge});

  @override
  Widget build(BuildContext context) {
    final textPrimary = AppColors.textPrimary(context);
    final textSecondary = AppColors.textSecondary(context);
    final completed = challenge.status == ChallengeStatus.completed;

    return AppCard(
      margin: EdgeInsets.zero,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Icon(_typeIcon(challenge.type), color: textSecondary, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_typeTitle(context, challenge.type),
                    style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: textPrimary)),
                Text(
                  completed
                      ? context.tr('challenge_result_completed')
                      : context.tr('challenge_result_abandoned'),
                  style: TextStyle(fontSize: 12, color: textSecondary),
                ),
              ],
            ),
          ),
          if (challenge.totalCheckins > 0)
            Text('${(challenge.adherenceRate * 100).round()}%',
                style: TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w600, color: completed ? textPrimary : textSecondary)),
        ],
      ),
    );
  }
}
