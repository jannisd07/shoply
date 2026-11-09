import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:shoply/core/design/design.dart';
import 'package:shoply/core/localization/localization_helper.dart';
import 'package:shoply/core/modules/app_modules.dart';
import 'package:shoply/data/services/avo_assistant_service.dart';
import 'package:shoply/presentation/screens/avo/avo_card_format.dart';
import 'package:shoply/presentation/screens/avo/avo_l10n.dart';
import 'package:shoply/presentation/screens/avo/widgets/avo_card_scope.dart';
import 'package:shoply/presentation/screens/avo/widgets/avo_choice_card.dart';
import 'package:shoply/presentation/screens/avo/widgets/avo_record_sections.dart';
import 'package:shoply/presentation/screens/avo/widgets/avo_recipe_sections.dart';
import 'package:shoply/presentation/screens/avo/widgets/avo_result_card.dart';
import 'package:shoply/presentation/widgets/design/avo_icons.dart';
import 'package:shoply/routes/app_destinations.dart';

// Kap. 5.4: the meal plan (module Wochenplan, only once it is released).
const double _recipeImage = 56; // D2

/// `get_plan`: "Heute: Ofengemüse mit Feta", or the days with their
/// recipes; empty: "Heute ist nichts geplant.". kcal only with the calories
/// module.
class AvoPlanSection extends ConsumerWidget {
  const AvoPlanSection({super.key, required this.card});

  final AvoPlanCard card;

  @override
  Widget build(BuildContext context, WidgetRef ref) => _planSection(
    context,
    card,
    kcal: ref.watch(moduleEnabledProvider(AppModule.calories)),
  );
}

AvoResultSection _planSection(
  BuildContext context,
  AvoPlanCard card, {
  required bool kcal,
}) {
  final now = DateTime.now();
  final oneDay = card.days == 1;
  void open() => openAppDestination(context, AppDestinations.plan);
  if (card.lines.isEmpty) {
    return AvoResultSection(
      title: context.tr(
        oneDay && avoIsToday(card.from, now)
            ? 'avo_plan_nothing_today'
            : 'avo_plan_nothing',
      ),
      leading: const AvoSymbolTile(icon: AvoIcon(AvoIcons.calendar)),
      onOpen: open,
      actions: [AvoCardAction(label: context.tr('avo_view'), onPressed: open)],
    );
  }
  final today = oneDay && avoIsToday(card.from, now) && card.lines.length == 1;
  return AvoResultSection(
    title: today
        ? context.tr('avo_plan_today', params: {'recipe': card.lines.first.name})
        : context.tr('avo_plan_title'),
    leading: const AvoSymbolTile(icon: AvoIcon(AvoIcons.calendar)),
    detailIndent: context.isAccessibilityText
        ? AvoSpacing.l
        : AvoSpacing.l + _recipeImage + AvoSpacing.m,
    details: [
      for (final l in card.lines)
        AvoRecipeRow(
          title: l.name,
          meta: [
            avoDay(context, l.day),
            avoTrCount(context, 'avo_card_servings', l.servings),
            if (kcal && l.kcal != null) '${avoInt(context, l.kcal!)} kcal',
          ].join(' · '),
          imageUrl: l.imageUrl,
          onTap: l.recipeId == null
              ? open
              : () => openAppDestination(
                  context,
                  AppDestinations.recipe(l.recipeId!),
                ),
        ),
    ],
    onOpen: open,
    actions: [AvoCardAction(label: context.tr('avo_view'), onPressed: open)],
  );
}

/// `add_to_plan` on a day that has a recipe: Avo's question, the two
/// answers, then the result of the choice (Kap. 5.4).
class AvoPlanChoice extends StatelessWidget {
  const AvoPlanChoice({
    super.key,
    required this.payload,
    required this.scope,
    required this.card,
  });

  final AvoWidgetPayload payload;
  final AvoCardScope scope;
  final AvoPlanTakenCard card;

  @override
  Widget build(BuildContext context) {
    final chat = scope.chat;
    final record = chat.recordOf(payload);
    final choice = AvoChoiceCard(
      options: [
        AvoChoiceOption(
          id: 'add',
          title: context.tr('avo_plan_add_alongside'),
          leading: const AvoSymbolTile(icon: AvoIcon(AvoIcons.plus)),
        ),
        AvoChoiceOption(
          id: 'replace',
          title: context.tr('avo_plan_replace'),
          leading: const AvoSymbolTile(icon: AvoIcon(AvoIcons.calendar)),
        ),
      ],
      selectedId: chat.pickedListOf(payload),
      stale: chat.isChoiceStale(payload),
      enabled: !scope.offline,
      onSelect: (id) => chat.choosePlan(payload, replace: id == 'replace'),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        AvoQuestionText(
          text: context.tr(
            card.plannedNames.length > 1 ? 'avo_plan_taken_many' : 'avo_plan_taken',
            params: {
              'day': avoWeekday(context, card.day),
              'recipe': avoAnd(context, card.plannedNames),
            },
          ),
        ),
        const SizedBox(height: AvoSpacing.s),
        choice,
        if (record != null) ...[
          const SizedBox(height: AvoSpacing.s),
          AvoResultCard(
            sections: [AvoRecordSection(payload: payload, scope: scope)],
          ),
        ],
      ],
    );
  }
}
