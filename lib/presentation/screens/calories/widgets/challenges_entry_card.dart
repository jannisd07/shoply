import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shoply/core/constants/app_colors.dart';
import 'package:shoply/core/localization/localization_helper.dart';
import 'package:shoply/core/widgets/design_system.dart';
import 'package:shoply/presentation/screens/calories/challenges_screen.dart';
import 'package:shoply/presentation/state/diet_challenge_provider.dart';

/// A compact entry point into diet challenges from the calorie dashboard —
/// shows the leading active challenge's streak if the user has one, or a
/// low-key invite to browse the catalog otherwise. Entirely optional; never
/// blocks the rest of the dashboard.
class ChallengesEntryCard extends ConsumerWidget {
  const ChallengesEntryCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeAsync = ref.watch(activeChallengesProvider);
    final textPrimary = AppColors.textPrimary(context);
    final textSecondary = AppColors.textSecondary(context);
    final accent = AppColors.accentColor(context);

    void open() {
      HapticFeedback.selectionClick();
      Navigator.of(context).push(CupertinoPageRoute(builder: (_) => const ChallengesScreen()));
    }

    final active = activeAsync.valueOrNull ?? const [];

    return AppCard(
      margin: EdgeInsets.zero,
      onTap: open,
      child: Row(
        children: [
          Icon(active.isEmpty ? Icons.flag_outlined : Icons.local_fire_department,
              color: accent, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(context.tr('challenges_title'),
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: textPrimary)),
                Text(
                  active.isEmpty
                      ? context.tr('challenges_entry_empty')
                      : context.tr('challenges_entry_active',
                          params: {'count': '${active.length}'}),
                  style: TextStyle(fontSize: 12.5, color: textSecondary),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right, color: textSecondary, size: 20),
        ],
      ),
    );
  }
}
