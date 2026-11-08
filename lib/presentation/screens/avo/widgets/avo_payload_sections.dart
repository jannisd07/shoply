import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:shoply/core/design/design.dart';
import 'package:shoply/core/localization/localization_helper.dart';
import 'package:shoply/data/models/recipe.dart';
import 'package:shoply/data/models/shopping_history.dart';
import 'package:shoply/data/models/shopping_item_model.dart';
import 'package:shoply/data/models/shopping_list_model.dart';
import 'package:shoply/data/repositories/item_repository.dart';
import 'package:shoply/data/services/avo_assistant_service.dart';
import 'package:shoply/data/services/avo_consents.dart';
import 'package:shoply/data/services/avo_conversation.dart';
import 'package:shoply/presentation/providers/store_for_list_provider.dart';
import 'package:shoply/presentation/screens/avo/avo_chat.dart';
import 'package:shoply/presentation/screens/avo/widgets/avo_choice_card.dart';
import 'package:shoply/presentation/screens/avo/widgets/avo_confirm_card.dart';
import 'package:shoply/presentation/screens/avo/widgets/avo_result_card.dart';
import 'package:shoply/presentation/screens/avo/widgets/avo_status_sections.dart';
import 'package:shoply/presentation/screens/lists/widgets/list_info_colors.dart';
import 'package:shoply/presentation/screens/lists/widgets/list_item_tile.dart';
import 'package:shoply/presentation/widgets/article_image.dart';
import 'package:shoply/presentation/widgets/design/app_button.dart';
import 'package:shoply/presentation/widgets/design/avo_icons.dart';
import 'package:shoply/presentation/widgets/design/item_row.dart';
import 'package:shoply/presentation/widgets/design/list_card.dart';
import 'package:shoply/presentation/widgets/design/undo_toast.dart';
import 'package:shoply/routes/app_destinations.dart';

/// Item rows in a card: at most 8, then "Alle {n} ansehen" (Kap. 2.5).
const int _maxRows = 8;

/// Read results older than this get "Stand {Uhrzeit}" (Kap. 2.5).
const Duration _staleAfter = Duration(minutes: 10);

/// Recipe rows of a card (Kap. 5.3): at most three.
const int _maxRecipes = 3;
const double _recipeImage = 56; // D2
const double _listGlyph = 20; // D2

/// What every card of the Avo tab needs from the conversation and the tab.
class AvoCardScope {
  const AvoCardScope({
    required this.chat,
    required this.ref,
    required this.turn,
    this.offline = false,
    this.isFree = true,
  });

  final AvoChat chat;
  final WidgetRef ref;
  final AvoTurn turn;
  final bool offline;
  final bool isFree;
}

/// "Wocheneinkauf / 9 offen · Lidl": the store comes from the list's
/// confirmed market, if any.
String _withStore(String text, String? store) =>
    store == null || store.isEmpty ? text : '$text · $store';

void _openList(BuildContext context, String listId) =>
    openAppDestination(context, AppDestinations.list(listId));

/// The sections of [turn]'s answer card, in the order the tools finished.
/// Choice cards ([AvoPayloadKind.pickList]) are not in it: they stand on
/// their own under Avo's question ([avoChoiceCards]).
List<Widget> avoSectionsFor(BuildContext context, AvoCardScope scope) {
  final out = <Widget>[];
  for (final p in scope.turn.payloads) {
    final section = _sectionFor(context, scope, p);
    if (section != null) out.add(section);
  }
  return out;
}

Widget? _sectionFor(BuildContext context, AvoCardScope s, AvoWidgetPayload p) {
  switch (p.kind) {
    case AvoPayloadKind.lists:
      return _ListsSection(lists: p.lists ?? const []);
    case AvoPayloadKind.listItems:
      return _ListItemsSection(payload: p, scope: s);
    case AvoPayloadKind.listChange:
      final change = p.listChange;
      return change == null
          ? null
          : AvoListChangeSection(payload: p, change: change, scope: s);
    case AvoPayloadKind.confirmDelete:
      return _ConfirmSection(payload: p, scope: s);
    case AvoPayloadKind.consentRequest:
      return _ConsentSection(payload: p, scope: s);
    case AvoPayloadKind.moduleOff:
      final module = p.module;
      if (module == null) return null;
      return AvoModuleOffRow(
        module: module,
        phase: s.chat.modulePhaseOf(p),
        onTurnOn: () =>
            s.chat.turnOnModule(p, s.ref, offline: s.offline, isFree: s.isFree),
        onUndo: () => s.chat.undoModule(p, s.ref),
      );
    case AvoPayloadKind.recipes:
      final recipes = p.recipes ?? const <Recipe>[];
      return recipes.isEmpty ? null : _RecipesSection(recipes: recipes);
    case AvoPayloadKind.history:
      final history = p.history ?? const <ShoppingHistory>[];
      return history.isEmpty ? null : _HistorySection(history: history);
    case AvoPayloadKind.nutrition:
      final data = p.nutrition;
      return data == null ? null : _NutritionSection(data: data);
    case AvoPayloadKind.settingChange:
      final result = p.settingChange;
      if (result == null) return null;
      final setting = {'setting': result.displayName};
      if (!result.success) {
        return AvoResultSection(
          title: context.tr('avo_setting_failed', params: setting),
          leading: AvoSymbolTile(
            neutral: true,
            icon: Icon(
              CupertinoIcons.exclamationmark_circle,
              color: context.colors.destructive,
            ),
          ),
        );
      }
      final old = result.oldValue;
      return AvoResultSection(
        title: result.displayName,
        subtitle: old == null
            ? result.newValue
            : context.tr(
                'avo_card_was',
                params: {'value': result.newValue, 'old': old},
              ),
        leading: const AvoSymbolTile(icon: Icon(CupertinoIcons.gear)),
      );
    case AvoPayloadKind.appInfo:
      final info = p.appInfo;
      if (info == null) return null;
      return AvoResultSection(
        title: info.topic,
        leading: const AvoSymbolTile(icon: Icon(CupertinoIcons.info)),
        details: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AvoSpacing.l),
            child: Text(info.answer, style: context.text(AvoTextStyle.body)),
          ),
        ],
      );
    case AvoPayloadKind.pickList:
      return null;
  }
}

/// The "Auf welche Liste?" cards of [scope]'s turn, each with the result
/// of the choice under it.
List<Widget> avoChoiceCards(BuildContext context, AvoCardScope scope) => [
  for (final p in scope.turn.payloads)
    if (p.kind == AvoPayloadKind.pickList && p.pickListData != null)
      _PickListCard(payload: p, scope: scope),
];

// -------------------------------------------------------------- list cards

/// Square of a list: its cover, or its colour with the cart glyph.
class _ListSquare extends StatelessWidget {
  const _ListSquare({required this.list});

  final ShoppingListModel list;

  @override
  Widget build(BuildContext context) {
    final cover = listCoverUrl(list);
    return ExcludeSemantics(
      child: ItemThumb(
        size: AvoSizes.thumbSmall,
        radius: AvoRadii.imageSmall,
        image: cover == null ? null : NetworkImage(cover),
        placeholder: cover == null
            ? SizedBox.expand(
                child: ColoredBox(
                  color: listDisplayColor(context, list),
                  child: Center(
                    child: AvoIcon(
                      AvoIcons.cart,
                      size: _listGlyph,
                      color: context.colors.onTint,
                    ),
                  ),
                ),
              )
            : null,
      ),
    );
  }
}

/// `get_lists`: "Deine Listen" with one row per list; a tap opens it.
class _ListsSection extends StatelessWidget {
  const _ListsSection({required this.lists});

  final List<ShoppingListModel> lists;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return AvoResultSection(
      title: context.tr('avo_card_your_lists'),
      leading: const AvoSymbolTile(icon: AvoIcon(AvoIcons.cart)),
      detailIndent: ListRow.separatorIndent,
      details: [
        for (final l in lists)
          ListRow(
            title: l.name,
            meta: context.tr(
              'avo_card_open_count',
              params: {'n': '${l.uncheckedCount ?? l.itemCount ?? 0}'},
            ),
            color: listDisplayColor(context, l),
            glyph: AvoIcon(
              AvoIcons.cart,
              size: _listGlyph,
              color: colors.onTint,
            ),
            showChevron: false,
            onTap: () => _openList(context, l.id),
          ),
      ],
    );
  }
}

/// One item of a card: Teil A's item row; the circle checks the real item.
Widget _itemRow(
  BuildContext context,
  AvoCardScope s,
  ShoppingItemModel item, {
  VoidCallback? onOpen,
}) {
  final canCheck = item.id.isNotEmpty;
  return ItemRow(
    title: item.name,
    subtitle: itemSubtitle(context, item),
    thumb: ArticleImage(item: item),
    checked: s.chat.isChecked(item),
    onToggle: canCheck ? (v) => s.chat.setChecked(item, v, s.ref) : null,
    onTap: onOpen,
    openLabel: onOpen == null ? null : context.tr('avo_open_list'),
  );
}

String? _asOf(BuildContext context, AvoTurn turn) {
  if (DateTime.now().difference(turn.askedAt) < _staleAfter) return null;
  final locale = Localizations.maybeLocaleOf(context)?.toLanguageTag();
  return context.tr(
    'avo_row_as_of',
    params: {'time': DateFormat.Hm(locale).format(turn.askedAt)},
  );
}

/// `get_list_contents`: the list with its open items (Kap. 5.1).
class _ListItemsSection extends ConsumerWidget {
  const _ListItemsSection({required this.payload, required this.scope});

  final AvoWidgetPayload payload;
  final AvoCardScope scope;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final listId = payload.listId ?? '';
    final name = payload.listName ?? '';
    final store = listId.isEmpty
        ? null
        : ref.watch(storeForListProvider(listId))?.name;
    // The rows are the items open when Avo read the list; a tap in the card
    // checks them without removing them.
    final open = [
      for (final i in payload.items ?? const <ShoppingItemModel>[])
        if (!i.isChecked) i,
    ];
    final openNow = open.where((i) => !scope.chat.isChecked(i)).length;
    void openList() => _openList(context, listId);

    if (open.isEmpty) {
      return AvoResultSection(
        title: context.tr('avo_card_list_empty', params: {'list': name}),
        leading: const AvoSymbolTile(icon: AvoIcon(AvoIcons.cart)),
        footnote: _asOf(context, scope.turn),
        actions: [
          if (listId.isNotEmpty)
            AvoCardAction(
              label: context.tr('avo_open_list'),
              onPressed: openList,
            ),
        ],
      );
    }
    return AvoResultSection(
      title: name,
      subtitle: _withStore(
        context.tr('avo_card_open_count', params: {'n': '$openNow'}),
        store,
      ),
      leading: const AvoSymbolTile(icon: AvoIcon(AvoIcons.cart)),
      detailIndent: ItemRow.separatorIndentOf(context),
      details: [
        for (final item in open.take(_maxRows))
          _itemRow(context, scope, item, onOpen: openList),
      ],
      footnote: _asOf(context, scope.turn),
      actions: [
        AvoCardAction(label: context.tr('avo_open_list'), onPressed: openList),
        if (open.length > _maxRows)
          AvoCardAction(
            label: context.tr('avo_see_all', params: {'n': '${open.length}'}),
            onPressed: openList,
          ),
      ],
    );
  }
}

/// A change Avo made on a list (Kap. 5.1): the list, what happened, the
/// changed items, "Liste öffnen" and "Widerrufen".
class AvoListChangeSection extends ConsumerWidget {
  const AvoListChangeSection({
    super.key,
    required this.payload,
    required this.change,
    required this.scope,
  });

  /// Keys the undo state (the choice card's payload for its result).
  final AvoWidgetPayload payload;
  final AvoListChange change;
  final AvoCardScope scope;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = change;
    final store = c.listId.isEmpty
        ? null
        : ref.watch(storeForListProvider(c.listId))?.name;
    final n = {'n': '${c.count}'};
    final lang = Localizations.maybeLocaleOf(context)?.languageCode ?? 'de';
    String qty(double v) => NumberFormat('0.##', lang).format(v);

    final String subtitle;
    var openList = true;
    switch (c.kind) {
      case AvoListChangeKind.added:
        subtitle = _withStore(context.tr('avo_card_added', params: n), store);
      case AvoListChangeKind.checked:
        subtitle = context.tr('avo_card_checked', params: n);
        openList = false;
      case AvoListChangeKind.unchecked:
        subtitle = context.tr('avo_card_unchecked', params: n);
        openList = false;
      case AvoListChangeKind.updated:
        final before = c.previousQuantity;
        final after = c.newQuantity;
        subtitle = before != null && after != null
            ? context.tr(
                'avo_card_quantity',
                params: {
                  'item': c.itemName ?? '',
                  'new': qty(after),
                  'old': qty(before),
                },
              )
            : context.tr(
                'avo_card_updated',
                params: {'item': c.itemName ?? ''},
              );
        openList = false;
      case AvoListChangeKind.moved:
        subtitle = context.tr(
          'avo_card_moved',
          params: {...n, 'list': c.fromListName ?? ''},
        );
      case AvoListChangeKind.created:
        subtitle = _withStore(context.tr('avo_card_new_list'), store);
      case AvoListChangeKind.renamed:
        subtitle = c.previousName == null
            ? context.tr('avo_card_renamed_plain')
            : context.tr('avo_card_renamed', params: {'name': c.previousName!});
        openList = false;
    }

    final phase = scope.chat.undoPhaseOf(payload);
    final state = switch (phase) {
      AvoUndoPhase.undone => AvoSectionState.undone,
      AvoUndoPhase.changedSince => AvoSectionState.changedSince,
      _ => AvoSectionState.done,
    };
    final goTo =
        c.kind == AvoListChangeKind.renamed ||
            c.kind == AvoListChangeKind.checked ||
            c.kind == AvoListChangeKind.unchecked ||
            c.kind == AvoListChangeKind.updated
        ? context.tr('avo_view')
        : context.tr('avo_open_list');
    final undoable = c.undo != null;
    final items = c.items.take(_maxRows).toList();
    final sentence = [
      '${c.listName}: $subtitle',
      if (items.isNotEmpty) items.map((i) => i.name).join(', '),
      if (undoable && state == AvoSectionState.done)
        context.tr('avo_a11y_undo_available'),
    ].join('. ');

    return AvoResultSection(
      title: c.listName,
      subtitle: subtitle,
      state: state,
      semanticLabel: sentence,
      leading: AvoSymbolTile(
        icon: AvoIcon(
          c.kind == AvoListChangeKind.checked ? AvoIcons.check : AvoIcons.cart,
        ),
      ),
      detailIndent: ItemRow.separatorIndentOf(context),
      details: state == AvoSectionState.undone
          ? const []
          : [
              for (final i in items)
                _itemRow(
                  context,
                  scope,
                  i,
                  onOpen: () => _openList(context, c.listId),
                ),
            ],
      actions: [
        if (openList || state == AvoSectionState.undone)
          AvoCardAction(
            label: goTo,
            onPressed: () => _openList(context, c.listId),
          ),
        if (undoable)
          AvoCardAction(
            label: context.tr('avo_undo'),
            isUndo: true,
            working: phase == AvoUndoPhase.working,
            onPressed: phase == AvoUndoPhase.idle
                ? () => scope.chat.undo(payload)
                : null,
          ),
      ],
    );
  }
}

/// `ask_pick_list`: "Auf welche Liste?" with the person's lists, then the
/// result of the choice.
class _PickListCard extends ConsumerWidget {
  const _PickListCard({required this.payload, required this.scope});

  final AvoWidgetPayload payload;
  final AvoCardScope scope;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lists = ref.watch(avoListsProvider);
    final result = scope.chat.pickResultOf(payload);
    final choice = AvoChoiceCard(
      options: [
        for (final l in lists)
          AvoChoiceOption(
            id: l.id,
            title: l.name,
            subtitle: context.tr(
              'avo_card_open_count',
              params: {'n': '${l.uncheckedCount ?? l.itemCount ?? 0}'},
            ),
            leading: _ListSquare(list: l),
          ),
      ],
      selectedId: scope.chat.pickedListOf(payload),
      stale: scope.chat.isChoiceStale(payload),
      enabled: !scope.offline,
      onSelect: (id) => scope.chat.pick(payload, id, scope.ref),
    );
    if (result == null) return choice;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        choice,
        const SizedBox(height: AvoSpacing.s),
        AvoResultCard(
          sections: [
            AvoListChangeSection(
              payload: payload,
              change: result,
              scope: scope,
            ),
          ],
        ),
      ],
    );
  }
}

// ------------------------------------------------------------ confirmation

class _ConfirmSection extends ConsumerWidget {
  const _ConfirmSection({required this.payload, required this.scope});

  final AvoWidgetPayload payload;
  final AvoCardScope scope;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pending = payload.pendingDelete!;
    final lists = ref.watch(avoListsProvider);
    final name = pending.name;
    final String title;
    String? body;
    String? hint;
    String done;
    switch (pending.target) {
      case AvoDeleteTarget.list:
        final list = lists.where((l) => l.id == pending.targetId).firstOrNull;
        final n = {'n': '${list?.itemCount ?? 0}'};
        title = context.tr('avo_confirm_list_title', params: {'name': name});
        body = context.tr(
          list?.isShared ?? false
              ? 'avo_confirm_list_shared_body'
              : 'avo_confirm_list_body',
          params: n,
        );
        hint = context.tr('avo_confirm_hint_list');
        done = context.tr('avo_deleted_list', params: {'name': name});
      case AvoDeleteTarget.item:
        final list = lists.where((l) => l.id == pending.parentId).firstOrNull;
        title = list == null
            ? context.tr('avo_confirm_list_title', params: {'name': name})
            : context.tr(
                'avo_confirm_item_title',
                params: {'name': name, 'list': list.name},
              );
        done = context.tr('avo_deleted_items', params: {'n': '1'});
      case AvoDeleteTarget.foodLog:
        title = context.tr('avo_confirm_food_title', params: {'food': name});
        done = context.tr('avo_deleted_named', params: {'name': name});
      case AvoDeleteTarget.planEntry:
      case AvoDeleteTarget.historyTrip:
      case AvoDeleteTarget.listMember:
        title = context.tr('avo_confirm_list_title', params: {'name': name});
        done = context.tr('avo_deleted_named', params: {'name': name});
    }
    return AvoConfirmCard(
      title: title,
      body: body,
      confirmLabel: context.tr('avo_delete'),
      confirmHint: hint,
      doneText: done,
      phase: scope.chat.confirmPhaseOf(payload),
      offline: scope.offline,
      expiresAt: pending.expiresAt,
      onExpired: scope.chat.refreshConfirm,
      onConfirm: () => scope.chat.confirmDelete(payload, scope.ref),
      onCancel: () => scope.chat.cancelDelete(payload),
    );
  }
}

/// Asks to share data with Avo before a tool may use it (Kap. 16): calories,
/// weight and goals, or diet and allergies.
class _ConsentSection extends StatelessWidget {
  const _ConsentSection({required this.payload, required this.scope});

  final AvoWidgetPayload payload;
  final AvoCardScope scope;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final prefix = payload.consentKind == AvoConsentKind.body
        ? 'avo_consent_body'
        : 'avo_consent_health';
    final answer = scope.chat.consentOf(payload);
    return Semantics(
      container: true,
      explicitChildNodes: true,
      child: Padding(
        padding: const EdgeInsets.all(AvoSpacing.l),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Semantics(
              header: true,
              child: Text(
                context.tr('${prefix}_title'),
                style: context.text(AvoTextStyle.headline),
              ),
            ),
            const SizedBox(height: AvoSpacing.xs),
            Semantics(
              liveRegion: answer != null,
              child: Text(
                context.tr(
                  answer == null
                      ? '${prefix}_body'
                      : answer
                      ? 'avo_consent_shared'
                      : 'avo_consent_not_now',
                ),
                style: context.text(
                  AvoTextStyle.subhead,
                  color: colors.secondaryLabel,
                ),
              ),
            ),
            if (answer == null) ...[
              const SizedBox(height: AvoSpacing.m),
              Wrap(
                spacing: AvoSpacing.s,
                runSpacing: AvoSpacing.s,
                children: [
                  AppButton.primary(
                    label: context.tr('avo_consent_share'),
                    onPressed: () =>
                        scope.chat.answerConsent(payload, share: true),
                  ),
                  AppButton.plain(
                    label: context.tr('avo_consent_not_now_action'),
                    onPressed: () =>
                        scope.chat.answerConsent(payload, share: false),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------- other tools (full cards later)

/// Recipes found or saved (interim until the recipe cards of Kap. 5.3).
class _RecipesSection extends StatelessWidget {
  const _RecipesSection({required this.recipes});

  final List<Recipe> recipes;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final ax = context.isAccessibilityText;
    return AvoResultSection(
      title: context.tr('avo_card_recipes'),
      leading: const AvoSymbolTile(icon: AvoIcon(AvoIcons.forkKnife)),
      detailIndent: ax
          ? AvoSpacing.l
          : AvoSpacing.l + _recipeImage + AvoSpacing.m,
      details: [
        for (final r in recipes.take(_maxRecipes))
          Semantics(
            container: true,
            button: true,
            label:
                '${r.name}, '
                '${context.tr('avo_card_minutes', params: {'n': '${r.totalTimeMinutes}'})}',
            excludeSemantics: true,
            onTap: () =>
                openAppDestination(context, AppDestinations.recipe(r.id)),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () =>
                  openAppDestination(context, AppDestinations.recipe(r.id)),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AvoSpacing.l,
                  vertical: AvoSpacing.s,
                ),
                child: Row(
                  children: [
                    if (!ax) ...[
                      ItemThumb(
                        size: _recipeImage,
                        radius: AvoRadii.imageSmall,
                        image: r.imageUrl.isEmpty
                            ? null
                            : NetworkImage(r.imageUrl),
                      ),
                      const SizedBox(width: AvoSpacing.m),
                    ],
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            r.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: context.text(AvoTextStyle.headline),
                          ),
                          Text(
                            context.tr(
                              'avo_card_minutes',
                              params: {'n': '${r.totalTimeMinutes}'},
                            ),
                            style: context.text(
                              AvoTextStyle.footnote,
                              color: colors.secondaryLabel,
                              tabular: true,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Shopping trips (interim until the history cards of Kap. 5.2), with "Alle
/// wieder auf {Liste}" for the newest trip.
class _HistorySection extends ConsumerWidget {
  const _HistorySection({required this.history});

  final List<ShoppingHistory> history;

  Future<void> _addAll(
    BuildContext context,
    ShoppingHistory trip,
    ShoppingListModel list,
  ) async {
    final message = context.tr(
      'avo_card_history_added',
      params: {'n': '${trip.items.length}', 'list': list.name},
    );
    final undo = context.tr('avo_undo');
    try {
      final result = await ItemRepository.instance.addItems(list.id, [
        for (final i in trip.items)
          NewItem(
            name: i.name,
            quantity: i.quantity,
            unit: i.unit,
            category: i.category,
          ),
      ]);
      if (!context.mounted) return;
      AvoToast.show(
        context,
        message: message,
        actionLabel: undo,
        onAction: () => ItemRepository.instance.undoAddItems(result.token),
      );
    } catch (e) {
      debugPrint('❌ [AVO_TAB] Trip not added: $e');
      unawaited(AvoHaptics.error());
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final lists = ref.watch(avoListsProvider);
    final target = lists.isEmpty ? null : lists.first;
    final newest = history.first;
    final locale = Localizations.maybeLocaleOf(context)?.toLanguageTag();
    return AvoResultSection(
      title: context.tr('avo_card_trips'),
      leading: const AvoSymbolTile(icon: AvoIcon(AvoIcons.clock)),
      details: [
        for (final h in history.take(_maxRows))
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AvoSpacing.l,
              vertical: AvoSpacing.s,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(h.listName, style: context.text(AvoTextStyle.body)),
                Text(
                  [
                    DateFormat.MMMEd(locale).format(h.completedAt),
                    context.tr(
                      'avo_card_items',
                      params: {'n': '${h.items.length}'},
                    ),
                  ].join(' · '),
                  style: context.text(
                    AvoTextStyle.subhead,
                    color: colors.secondaryLabel,
                    tabular: true,
                  ),
                ),
              ],
            ),
          ),
      ],
      actions: [
        if (target != null && newest.items.isNotEmpty)
          AvoCardAction(
            label: context.tr(
              'avo_card_history_add_all',
              params: {'list': target.name},
            ),
            onPressed: () => _addAll(context, newest, target),
          ),
      ],
    );
  }
}

/// Nutrition of a recipe (interim until the cards of Kap. 5.3).
class _NutritionSection extends StatelessWidget {
  const _NutritionSection({required this.data});

  final AvoNutritionData data;

  @override
  Widget build(BuildContext context) {
    String grams(double? g, String key) =>
        g == null ? '' : '${g.round()} g ${context.tr(key)}';
    final parts = [
      if (data.calories != null) '${data.calories} kcal',
      grams(data.proteinG, 'protein'),
      grams(data.carbsG, 'carbs'),
      grams(data.fatG, 'fat'),
    ].where((p) => p.isNotEmpty).join(' · ');
    return AvoResultSection(
      title: data.recipeName,
      subtitle: parts,
      leading: const AvoSymbolTile(icon: Icon(CupertinoIcons.flame)),
      footnote: [
        context.tr('avo_per_serving'),
        if (data.estimated) context.tr('avo_estimated_from_ingredients'),
      ].join(' · '),
    );
  }
}
