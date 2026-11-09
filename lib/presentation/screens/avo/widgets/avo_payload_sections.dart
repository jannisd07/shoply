import 'package:flutter/widgets.dart';

import 'package:shoply/data/services/avo_assistant_service.dart';
import 'package:shoply/presentation/screens/avo/widgets/avo_card_scope.dart';
import 'package:shoply/presentation/screens/avo/widgets/avo_delete_sections.dart';
import 'package:shoply/presentation/screens/avo/widgets/avo_health_sections.dart';
import 'package:shoply/presentation/screens/avo/widgets/avo_history_sections.dart';
import 'package:shoply/presentation/screens/avo/widgets/avo_list_sections.dart';
import 'package:shoply/presentation/screens/avo/widgets/avo_offer_sections.dart';
import 'package:shoply/presentation/screens/avo/widgets/avo_photo_sections.dart';
import 'package:shoply/presentation/screens/avo/widgets/avo_plan_sections.dart';
import 'package:shoply/presentation/screens/avo/widgets/avo_recipe_sections.dart';
import 'package:shoply/presentation/screens/avo/widgets/avo_record_sections.dart';
import 'package:shoply/presentation/screens/avo/widgets/avo_setting_sections.dart';
import 'package:shoply/presentation/screens/avo/widgets/avo_status_sections.dart';

export 'package:shoply/presentation/screens/avo/widgets/avo_card_scope.dart';

/// The sections of a round's answer card, in the order the tools finished.
/// Cards that ask the person something stand on their own instead
/// ([avoChoiceCards], [avoPhotoChoices]). [onNewPhoto] is "Neues Foto" of a
/// photo Avo could not read.
List<Widget> avoSectionsFor(
  BuildContext context,
  AvoCardScope scope, {
  VoidCallback? onNewPhoto,
}) => [
  for (final p in scope.turn.payloads)
    ..._sectionsFor(context, scope, p, onNewPhoto),
];

List<Widget> _sectionsFor(
  BuildContext context,
  AvoCardScope s,
  AvoWidgetPayload p,
  VoidCallback? onNewPhoto,
) {
  switch (p.kind) {
    case AvoPayloadKind.lists:
      return [AvoListsSection(lists: p.lists ?? const [])];
    case AvoPayloadKind.listItems:
      return [AvoListItemsSection(payload: p, scope: s)];
    case AvoPayloadKind.listChange:
      return [if (p.listChange != null) AvoListChangeSection(payload: p, scope: s)];
    case AvoPayloadKind.confirmDelete:
      return [
        if (p.pendingDelete != null) AvoConfirmSection(payload: p, scope: s),
      ];
    case AvoPayloadKind.consentRequest:
      return [AvoConsentSection(payload: p, scope: s)];
    case AvoPayloadKind.moduleOff:
      final module = p.module;
      if (module == null) return const [];
      return [
        AvoModuleOffRow(
          module: module,
          phase: s.chat.modulePhaseOf(p),
          onTurnOn: () => s.chat.turnOnModule(
            p,
            offline: s.offline,
            proHintAllowed: s.proHintAllowed,
          ),
          onUndo: () => s.chat.undoModule(p),
        ),
      ];
    case AvoPayloadKind.record:
      return [AvoRecordSection(payload: p, scope: s)];
    case AvoPayloadKind.card:
      final card = p.card;
      if (card == null) return const [];
      return _cardSections(context, s, p, card, onNewPhoto);
    case AvoPayloadKind.pickList:
    case AvoPayloadKind.wrote:
      return const [];
  }
}

List<Widget> _cardSections(
  BuildContext context,
  AvoCardScope s,
  AvoWidgetPayload p,
  AvoCardData card,
  VoidCallback? onNewPhoto,
) => switch (card) {
  AvoTripsCard() => avoTripsSections(context, s, p, card),
  AvoRestockCard() => [avoRestockSection(context, s, p, card)],
  AvoRecipesCard() => [AvoRecipesSection(card: card)],
  AvoRecipeNutritionCard() => [avoRecipeNutritionSection(context, card)],
  AvoPlanCard() => [avoPlanSection(context, card)],
  AvoOfferSearchCard() => [AvoOfferSearchSection(card: card)],
  AvoOfferSetupCard() => [AvoOfferSetupSection(card: card)],
  AvoDealsCard() => [AvoDealsSection(card: card)],
  AvoSavingsCard() => [AvoSavingsSection(card: card)],
  AvoNutritionStatusCard() => [avoNutritionStatusSection(context, card)],
  AvoWeekCard() => [avoWeekSection(context, card)],
  AvoChallengesCard() => avoChallengeSections(context, card),
  AvoEstimateCard() => [
    AvoEstimateSection(payload: p, scope: s, card: card),
  ],
  AvoGoalPreviewCard() => [
    AvoGoalPreviewSection(payload: p, scope: s, card: card),
  ],
  AvoAllergyCard() => [AvoAllergySection(payload: p, scope: s, card: card)],
  AvoSettingFailedCard() => [avoSettingFailedSection(context, card)],
  AvoAppInfoCard() => [avoAppInfoSection(context, card)],
  AvoPhotoErrorCard() => [
    avoPhotoErrorSection(context, s, card, onNewPhoto: onNewPhoto),
  ],
  // Standing on their own (choices).
  AvoPlanTakenCard() || AvoListImportCard() || AvoPhotoChoiceCard() =>
    const [],
};

/// The cards that ask the person to choose, each with the result of the
/// choice under it: "Auf welche Liste?", a planned day, a shopping note.
List<Widget> avoChoiceCards(BuildContext context, AvoCardScope scope) => [
  for (final p in scope.turn.payloads)
    if (p.kind == AvoPayloadKind.pickList && p.pickListData != null)
      AvoPickListCard(payload: p, scope: scope)
    else if (p.card case final AvoPlanTakenCard card)
      AvoPlanChoice(payload: p, scope: scope, card: card)
    else if (p.card case final AvoListImportCard card)
      AvoListImport(payload: p, scope: scope, card: card),
];

/// "Was soll ich mit dem Foto machen?": right under the photo, above the
/// status line of the reading that follows.
List<Widget> avoPhotoChoices(BuildContext context, AvoCardScope scope) => [
  for (final p in scope.turn.payloads)
    if (p.card case final AvoPhotoChoiceCard card)
      AvoPhotoChoice(payload: p, scope: scope, card: card),
];
