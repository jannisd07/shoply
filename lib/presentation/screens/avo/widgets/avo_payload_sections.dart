import 'package:flutter/widgets.dart';

import 'package:shoply/data/models/recipe.dart';
import 'package:shoply/data/models/shopping_history.dart';
import 'package:shoply/data/services/avo_assistant_service.dart';
import 'package:shoply/presentation/screens/avo/avo_chat.dart';
import 'package:shoply/presentation/screens/avo/widgets/avo_card_scope.dart';
import 'package:shoply/presentation/screens/avo/widgets/avo_delete_sections.dart';
import 'package:shoply/presentation/screens/avo/widgets/avo_interim_sections.dart';
import 'package:shoply/presentation/screens/avo/widgets/avo_list_sections.dart';
import 'package:shoply/presentation/screens/avo/widgets/avo_status_sections.dart';

export 'package:shoply/presentation/screens/avo/widgets/avo_card_scope.dart';

/// The sections of a round's answer card, in the order the tools finished.
/// Choice cards ([AvoPayloadKind.pickList]) are not in it: they stand on
/// their own under Avo's question ([avoChoiceCards]).
List<Widget> avoSectionsFor(BuildContext context, AvoCardScope scope) => [
  for (final p in scope.turn.payloads) ?_sectionFor(context, scope, p),
];

Widget? _sectionFor(BuildContext context, AvoCardScope s, AvoWidgetPayload p) {
  switch (p.kind) {
    case AvoPayloadKind.lists:
      return AvoListsSection(lists: p.lists ?? const []);
    case AvoPayloadKind.listItems:
      return AvoListItemsSection(payload: p, scope: s);
    case AvoPayloadKind.listChange:
      return p.listChange == null
          ? null
          : AvoListChangeSection(payload: p, scope: s);
    case AvoPayloadKind.confirmDelete:
      return p.pendingDelete == null
          ? null
          : AvoConfirmSection(payload: p, scope: s);
    case AvoPayloadKind.consentRequest:
      return AvoConsentSection(payload: p, scope: s);
    case AvoPayloadKind.moduleOff:
      final module = p.module;
      if (module == null) return null;
      return AvoModuleOffRow(
        module: module,
        phase: s.chat.modulePhaseOf(p),
        onTurnOn: () => s.chat.turnOnModule(
          p,
          offline: s.offline,
          proHintAllowed: s.proHintAllowed,
        ),
        onUndo: () => s.chat.undoModule(p),
      );
    case AvoPayloadKind.recipes:
      final recipes = p.recipes ?? const <Recipe>[];
      return recipes.isEmpty ? null : AvoRecipesSection(recipes: recipes);
    case AvoPayloadKind.history:
      final history = p.history ?? const <ShoppingHistory>[];
      return history.isEmpty ? null : AvoHistorySection(history: history);
    case AvoPayloadKind.nutrition:
      final data = p.nutrition;
      return data == null ? null : AvoNutritionSection(data: data);
    case AvoPayloadKind.settingChange:
      final result = p.settingChange;
      return result == null ? null : avoSettingSection(context, result);
    case AvoPayloadKind.appInfo:
      final info = p.appInfo;
      return info == null ? null : avoAppInfoSection(context, info);
    case AvoPayloadKind.pickList:
      return null;
  }
}

/// The "Auf welche Liste?" cards of [scope]'s round, each with the result of
/// the choice under it.
List<Widget> avoChoiceCards(BuildContext context, AvoCardScope scope) => [
  for (final p in scope.turn.payloads)
    if (p.kind == AvoPayloadKind.pickList && p.pickListData != null)
      AvoPickListCard(payload: p, scope: scope),
];

/// What the done changes of a failed round were, for the retry note to Avo
/// ("Wocheneinkauf: 3 hinzugefügt; Drogerie: 2 verschoben aus …").
String avoDoneChanges(BuildContext context, AvoCardScope scope) => [
  for (final p in scope.turn.payloads)
    if (scope.chat.changeOf(p) case final c?)
      if (scope.chat.undoPhaseOf(p) != AvoUndoPhase.undone)
        '${c.listName}: ${avoChangeSummary(context, c)}',
].join('; ');
