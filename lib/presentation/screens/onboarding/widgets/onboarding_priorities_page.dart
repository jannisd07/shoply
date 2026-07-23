import 'package:flutter/material.dart';
import 'package:shoply/core/constants/app_priorities.dart';
import 'package:shoply/core/constants/paper_colors.dart';
import 'package:shoply/core/localization/localization_helper.dart';
import 'package:shoply/core/widgets/paper/paper_widgets.dart';

/// Onboarding page: "what brings you to Shoply?" — a persona/motivation
/// question, distinct from the diet-preference page that follows it. Feeds
/// `users.app_priorities`, which only ever reorders the home screen's
/// existing proactive nudge cards (see `orderedHomeNudgeCards`) — picking
/// nothing here, or skipping the page, leaves the app's default behavior
/// untouched.
class OnboardingPrioritiesPage extends StatelessWidget {
  final Set<String> selected;
  final ValueChanged<Set<String>> onChanged;

  const OnboardingPrioritiesPage({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 26),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          PaperKicker(context.tr('onb_priorities_kicker'),
              color: PaperColors.terracotta),
          const SizedBox(height: 10),
          Text(context.tr('onb_priorities_title'),
              style: PaperTextStyles.serif(28)),
          const SizedBox(height: 12),
          Text(
            context.tr('onb_priorities_sub'),
            style: PaperTextStyles.body(color: PaperColors.muted),
          ),
          const SizedBox(height: 24),
          ...kAppPriorities.map((priority) {
            final isSelected = selected.contains(priority.id);
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _PriorityRow(
                icon: priority.icon,
                label: context.tr('priority_${priority.id}'),
                selected: isSelected,
                onTap: () {
                  final next = Set<String>.from(selected);
                  if (isSelected) {
                    next.remove(priority.id);
                  } else {
                    next.add(priority.id);
                  }
                  onChanged(next);
                },
              ),
            );
          }),
          const SizedBox(height: 6),
          Text(
            context.tr('onb_priorities_hint'),
            style: const TextStyle(fontSize: 12.5, color: PaperColors.faint),
          ),
        ],
      ),
    );
  }
}

class _PriorityRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _PriorityRow({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: selected ? PaperColors.ink : PaperColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? PaperColors.ink : PaperColors.hairline,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 20,
              color: selected ? PaperColors.paper : PaperColors.creamInk,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                  color: selected ? PaperColors.paper : PaperColors.ink,
                ),
              ),
            ),
            if (selected)
              const Icon(Icons.check_rounded,
                  size: 18, color: PaperColors.paper),
          ],
        ),
      ),
    );
  }
}
