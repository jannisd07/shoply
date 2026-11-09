import 'package:flutter/foundation.dart';

import 'package:shoply/data/models/shopping_list_model.dart';
import 'package:shoply/data/services/avo_assistant_service.dart';
import 'package:shoply/presentation/providers/avo_screen_context_provider.dart';

/// The symbol in front of a suggestion (SF Symbol names from Kap. 4.2).
enum AvoSuggestionSymbol {
  plus,
  tag,
  clockArrow,
  forkKnife,
  checklist,
  checkmark,
  leaf,
  bookmark,
  list,
  halfCircle,
  toggles,
}

/// One thing to ask Avo: a translation key with its parameters.
@immutable
class AvoSuggestion {
  const AvoSuggestion(this.key, this.symbol, [this.params = const {}]);

  final String key;
  final AvoSuggestionSymbol symbol;
  final Map<String, String> params;

  @override
  bool operator ==(Object other) =>
      other is AvoSuggestion &&
      other.key == key &&
      mapEquals(other.params, params);

  @override
  int get hashCode => Object.hash(key, Object.hashAll(params.values));

  @override
  String toString() => 'AvoSuggestion($key, $params)';
}

const _whatsOnList = AvoSuggestion(
  'avo_sugg_whats_on_list',
  AvoSuggestionSymbol.list,
);
const _buyRegularly = AvoSuggestion(
  'avo_sugg_buy_regularly',
  AvoSuggestionSymbol.clockArrow,
);
const _lastShopAgain = AvoSuggestion(
  'avo_sugg_last_shop_again',
  AvoSuggestionSymbol.clockArrow,
);
const _cookWeek = AvoSuggestion(
  'avo_sugg_cook_week',
  AvoSuggestionSymbol.forkKnife,
);
const _whatsMissing = AvoSuggestion(
  'avo_sugg_whats_missing',
  AvoSuggestionSymbol.checklist,
);
const _bakingPaper = AvoSuggestion(
  'avo_sugg_add_baking_paper',
  AvoSuggestionSymbol.plus,
);
const _lastSaturday = AvoSuggestion(
  'avo_sugg_last_saturday',
  AvoSuggestionSymbol.clockArrow,
);
const _partyList = AvoSuggestion(
  'avo_sugg_party_list',
  AvoSuggestionSymbol.plus,
);
const _cookToday = AvoSuggestion(
  'avo_sugg_cook_today',
  AvoSuggestionSymbol.forkKnife,
);
const _vegetarianQuick = AvoSuggestion(
  'avo_sugg_vegetarian_quick',
  AvoSuggestionSymbol.leaf,
);
const _savedRecipes = AvoSuggestion(
  'avo_sugg_saved_recipes',
  AvoSuggestionSymbol.bookmark,
);
const _darkMode = AvoSuggestion(
  'avo_sugg_dark_mode',
  AvoSuggestionSymbol.halfCircle,
);
const _peanutAllergy = AvoSuggestion(
  'avo_sugg_peanut_allergy',
  AvoSuggestionSymbol.leaf,
);
const _modules = AvoSuggestion('avo_sugg_modules', AvoSuggestionSymbol.toggles);

/// Names from shared lists (other members write them) go into text that is
/// sent to Avo without the person typing it (suggestions, the retry note)
/// only when short and on one line (W1 review).
const int _maxNameLength = 40;

/// Line breaks, line and paragraph separators and other control characters
/// (incl. U+0085, VT, FF, U+2028, U+2029), and double quotes (straight and
/// typographic): the retry note puts names in quotes, so a name must never
/// be able to close them and read as sentence text (W1 re-review 3).
final RegExp _unsafeChars = RegExp(
  r'[\u0000-\u001F\u007F-\u009F\u2028\u2029"\u201c\u201d\u201e\u201f\u2033]',
);

/// [name] trimmed, or null when it is empty, longer than 40 characters,
/// spans lines, holds control characters or a double quote.
String? avoSafeName(String? name) {
  if (name == null) return null;
  final n = name.trim();
  if (n.isEmpty || n.length > _maxNameLength || _unsafeChars.hasMatch(n)) {
    return null;
  }
  return n;
}

/// Fills up when a context row drops suggestions (Kap. 4.2: "rückt der
/// nächste Kern-Vorschlag nach").
const _reserve = [_whatsOnList, _cookToday, _lastSaturday];

/// The three suggestions of the empty chat for the screen the person came
/// from (Kap. 4.2).
///
/// [list] is the list of a list or shopping context, or the person's most
/// recent list for Home and contexts without one ("wie Liste von heute").
/// [openItemNames] are its open items (shopping mode: "Hak Milch und Butter
/// ab"). Suggestions that need data the app does not have yet (meal plan for
/// today, a real region for offers, photos) are left out, never shown
/// half-filled.
List<AvoSuggestion> avoEmptySuggestions({
  AvoScreenContext? context,
  ShoppingListModel? list,
  List<String> openItemNames = const [],
}) {
  final screen = context?.screen;
  final rows = <AvoSuggestion>[];

  void listRows(ShoppingListModel? l) {
    if (l == null) {
      rows.addAll([_lastSaturday, _partyList]);
    } else if ((l.uncheckedCount ?? l.itemCount ?? 0) > 0) {
      rows.add(_buyRegularly);
    } else {
      rows.addAll([_lastShopAgain, _cookWeek]);
    }
  }

  switch (screen) {
    case 'shopping':
      rows.add(_whatsMissing);
      final names = [
        for (final n in openItemNames)
          if (avoSafeName(n) case final safe?) safe,
      ];
      if (names.length >= 2) {
        rows.add(
          AvoSuggestion('avo_sugg_check_two', AvoSuggestionSymbol.checkmark, {
            'a': names[0],
            'b': names[1],
          }),
        );
      }
      rows.add(_bakingPaper);
    case 'lists':
    case 'history':
      rows.addAll([_lastSaturday, _partyList]);
    case 'recipes':
      rows.addAll([_cookToday, _vegetarianQuick, _savedRecipes]);
    case 'profile':
    case 'settings':
      rows.addAll([_darkMode, _peanutAllergy, _modules]);
    default:
      listRows(list);
  }

  for (final r in _reserve) {
    if (rows.length >= 3) break;
    if (!rows.contains(r)) rows.add(r);
  }
  return rows.take(3).toList();
}

/// At most two follow-up questions under the newest answer (Kap. 2.10),
/// worked out from its result alone. [targetList] is the list Avo would put
/// things on (context list, else the newest list). No offers, no store
/// comparison, nothing Pro.
List<AvoSuggestion> avoFollowUps(
  List<AvoWidgetPayload> payloads, {
  String? targetList,
}) {
  final out = <AvoSuggestion>[];
  final hasRecipes = payloads.any(
    (p) => p.card is AvoRecipesCard && (p.card! as AvoRecipesCard).recipes.isNotEmpty,
  );
  final target = targetList == null ? null : avoSafeName(targetList);
  if (hasRecipes && target != null) {
    out.add(
      AvoSuggestion('avo_chip_ingredients_to', AvoSuggestionSymbol.plus, {
        'list': target,
      }),
    );
  }
  final added = payloads.any((p) {
    final kind = p.listChange?.kind;
    return kind == AvoListChangeKind.added || kind == AvoListChangeKind.moved;
  });
  if (added) out.add(_buyRegularly);
  return out.take(2).toList();
}
