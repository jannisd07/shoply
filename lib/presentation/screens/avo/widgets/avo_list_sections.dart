import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:shoply/core/design/design.dart';
import 'package:shoply/core/localization/localization_helper.dart';
import 'package:shoply/data/models/shopping_item_model.dart';
import 'package:shoply/data/models/shopping_list_model.dart';
import 'package:shoply/data/services/avo_assistant_service.dart';
import 'package:shoply/presentation/providers/store_for_list_provider.dart';
import 'package:shoply/presentation/screens/avo/avo_chat.dart';
import 'package:shoply/presentation/screens/avo/avo_l10n.dart';
import 'package:shoply/presentation/screens/avo/widgets/avo_card_scope.dart';
import 'package:shoply/presentation/screens/avo/widgets/avo_choice_card.dart';
import 'package:shoply/presentation/screens/avo/widgets/avo_result_card.dart';
import 'package:shoply/presentation/screens/lists/widgets/list_info_colors.dart';
import 'package:shoply/presentation/screens/lists/widgets/list_item_tile.dart';
import 'package:shoply/presentation/widgets/article_image.dart';
import 'package:shoply/presentation/widgets/design/avo_icons.dart';
import 'package:shoply/presentation/widgets/design/item_row.dart';
import 'package:shoply/presentation/widgets/design/list_card.dart';
import 'package:shoply/routes/app_destinations.dart';

/// Read results older than this get "Stand {Uhrzeit}" (Kap. 2.5).
const Duration _staleAfter = Duration(minutes: 10);
const double _listGlyph = 20; // D2

/// "Wocheneinkauf / 9 offen · Lidl": the store comes from the list's
/// confirmed market, if any.
String _withStore(String text, String? store) =>
    store == null || store.isEmpty ? text : '$text · $store';

void _openList(BuildContext context, String listId) =>
    openAppDestination(context, AppDestinations.list(listId));

/// What a change did, as the card's second line ("3 hinzugefügt", "Milch:
/// Menge 3, vorher 2"); also the text of its toast and of a retry note.
String avoChangeSummary(BuildContext context, AvoListChange c) {
  final n = {'n': '${c.count}'};
  final lang = Localizations.maybeLocaleOf(context)?.languageCode ?? 'de';
  String qty(double v) => NumberFormat('0.##', lang).format(v);
  switch (c.kind) {
    // An add that merged into an item already on the list raised its
    // quantity: say so instead of "1 hinzugefügt".
    case AvoListChangeKind.added
        when c.previousQuantity != null && c.newQuantity != null:
      return context.tr(
        'avo_card_quantity',
        params: {
          'item': c.itemName ?? '',
          'new': qty(c.newQuantity!),
          'old': qty(c.previousQuantity!),
        },
      );
    case AvoListChangeKind.added:
      return context.tr('avo_card_added', params: n);
    case AvoListChangeKind.checked:
      return context.tr('avo_card_checked', params: n);
    case AvoListChangeKind.unchecked:
      return context.tr('avo_card_unchecked', params: n);
    case AvoListChangeKind.updated:
      final before = c.previousQuantity;
      final after = c.newQuantity;
      return before != null && after != null
          ? context.tr(
              'avo_card_quantity',
              params: {
                'item': c.itemName ?? '',
                'new': qty(after),
                'old': qty(before),
              },
            )
          : context.tr('avo_card_updated', params: {'item': c.itemName ?? ''});
    case AvoListChangeKind.moved:
      return context.tr(
        'avo_card_moved',
        params: {...n, 'list': c.fromListName ?? ''},
      );
    case AvoListChangeKind.created:
      return context.tr('avo_card_new_list');
    case AvoListChangeKind.renamed:
      return c.previousName == null
          ? context.tr('avo_card_renamed_plain')
          : context.tr('avo_card_renamed', params: {'name': c.previousName!});
  }
}

/// The toast for a change made while the tab is not visible (Kap. 3.2),
/// without Avo's name: "3 Artikel zu Wocheneinkauf hinzugefügt".
String avoChangeToast(BuildContext context, AvoListChange c) {
  if (c.kind == AvoListChangeKind.added && c.previousQuantity == null) {
    return c.count == 1 && c.items.isNotEmpty
        ? context.tr(
            'avo_toast_added_one',
            params: {'item': c.items.first.name, 'list': c.listName},
          )
        : avoTrCount(context, 'avo_toast_added', c.count, {'list': c.listName});
  }
  return '${c.listName}: ${avoChangeSummary(context, c)}';
}

/// Square of a list: its cover, or its colour with the cart glyph.
class AvoListSquare extends StatelessWidget {
  const AvoListSquare({super.key, required this.list});

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

/// "9 offen · Lidl" for a list; the market only when it is confirmed.
String _openMeta(BuildContext context, WidgetRef ref, ShoppingListModel l) =>
    _withStore(
      context.tr(
        'avo_card_open_count',
        params: {'n': '${l.uncheckedCount ?? l.itemCount ?? 0}'},
      ),
      ref.watch(storeForListProvider(l.id))?.name,
    );

/// `get_lists`: "Deine Listen" with one row per list; a tap opens it.
class AvoListsSection extends ConsumerWidget {
  const AvoListsSection({super.key, required this.lists});

  final List<ShoppingListModel> lists;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    return AvoResultSection(
      title: context.tr('avo_card_your_lists'),
      leading: const AvoSymbolTile(icon: AvoIcon(AvoIcons.cart)),
      detailIndent: ListRow.separatorIndent,
      details: [
        for (final l in lists)
          ListRow(
            title: l.name,
            meta: _openMeta(context, ref, l),
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
  final canCheck = item.id.isNotEmpty && !item.id.startsWith('pending-');
  return ItemRow(
    title: item.name,
    subtitle: itemSubtitle(context, item),
    thumb: ArticleImage(item: item),
    checked: s.chat.isChecked(item),
    onToggle: canCheck ? (v) => s.chat.setChecked(item, v) : null,
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
class AvoListItemsSection extends ConsumerWidget {
  const AvoListItemsSection({
    super.key,
    required this.payload,
    required this.scope,
  });

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
        onOpen: listId.isEmpty ? null : openList,
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
        for (final item in open)
          _itemRow(context, scope, item, onOpen: openList),
      ],
      onOpen: openList,
      seeAllLabel: context.tr('avo_see_all_in', params: {'list': name}),
      onSeeAll: openList,
      footnote: _asOf(context, scope.turn),
      actions: [
        AvoCardAction(label: context.tr('avo_open_list'), onPressed: openList),
        if (open.length > 8)
          AvoCardAction(
            label: context.tr('avo_see_all', params: {'n': '${open.length}'}),
            onPressed: openList,
          ),
      ],
    );
  }
}

/// A change Avo made on a list (Kap. 5.1): the list, what happened, the
/// changed items, "Liste öffnen" and "Widerrufen"; a failed part with
/// "Erneut versuchen", a queued change with the sync mark.
class AvoListChangeSection extends ConsumerWidget {
  const AvoListChangeSection({
    super.key,
    required this.payload,
    required this.scope,
  });

  /// Keys the card's state (undo, retried part) in the conversation.
  final AvoWidgetPayload payload;
  final AvoCardScope scope;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = scope.chat.changeOf(payload);
    if (c == null) return const SizedBox.shrink();
    final store = c.listId.isEmpty
        ? null
        : ref.watch(storeForListProvider(c.listId))?.name;
    final summary = avoChangeSummary(context, c);
    final subtitle = switch (c.kind) {
      AvoListChangeKind.added ||
      AvoListChangeKind.created => _withStore(summary, store),
      _ => summary,
    };
    final opensList = switch (c.kind) {
      AvoListChangeKind.added ||
      AvoListChangeKind.moved ||
      AvoListChangeKind.created => true,
      _ => false,
    };

    final phase = scope.chat.undoPhaseOf(payload);
    final state = switch (phase) {
      AvoUndoPhase.undone => AvoSectionState.undone,
      AvoUndoPhase.changedSince => AvoSectionState.changedSince,
      _ => AvoSectionState.done,
    };
    final undoable = c.undo != null && !c.pendingOffline;
    final sentence = [
      '${c.listName}: $subtitle',
      if (c.items.isNotEmpty) c.items.take(8).map((i) => i.name).join(', '),
      if (undoable && state == AvoSectionState.done)
        context.tr('avo_a11y_undo_available'),
    ].join('. ');
    void openList() => _openList(context, c.listId);

    return AvoResultSection(
      title: c.listName,
      subtitle: subtitle,
      state: state,
      semanticLabel: sentence,
      pendingOffline: c.pendingOffline,
      partialText: c.failedCount > 0
          ? avoTrCount(context, 'avo_row_partial_moved', c.failedCount)
          : null,
      onRetryPartial: c.retryFailed == null
          ? null
          : () => scope.chat.retryPartial(payload),
      partialWorking: scope.chat.isPartialWorking(payload),
      leading: AvoSymbolTile(
        icon: AvoIcon(
          c.kind == AvoListChangeKind.checked ? AvoIcons.check : AvoIcons.cart,
        ),
      ),
      detailIndent: ItemRow.separatorIndentOf(context),
      details: state == AvoSectionState.undone
          ? const []
          : [
              for (final i in c.items)
                _itemRow(context, scope, i, onOpen: openList),
            ],
      onOpen: openList,
      seeAllLabel: context.tr('avo_see_all_in', params: {'list': c.listName}),
      onSeeAll: openList,
      actions: [
        if (opensList || state == AvoSectionState.undone)
          AvoCardAction(
            label: context.tr(opensList ? 'avo_open_list' : 'avo_view'),
            onPressed: openList,
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

/// `ask_pick_list`: "Auf welche Liste?" with the person's lists, the most
/// recently changed first, then the result of the choice.
class AvoPickListCard extends ConsumerWidget {
  const AvoPickListCard({
    super.key,
    required this.payload,
    required this.scope,
  });

  final AvoWidgetPayload payload;
  final AvoCardScope scope;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lists = [...ref.watch(avoListsProvider)]
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    final result = scope.chat.pickResultOf(payload);
    final choice = AvoChoiceCard(
      options: [
        for (final l in lists)
          AvoChoiceOption(
            id: l.id,
            title: l.name,
            subtitle: _openMeta(context, ref, l),
            leading: AvoListSquare(list: l),
          ),
      ],
      selectedId: scope.chat.pickedListOf(payload),
      stale: scope.chat.isChoiceStale(payload),
      enabled: !scope.offline,
      onSelect: (id) => scope.chat.pick(payload, id),
    );
    if (result == null) return choice;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        choice,
        const SizedBox(height: AvoSpacing.s),
        AvoResultCard(
          sections: [AvoListChangeSection(payload: payload, scope: scope)],
        ),
      ],
    );
  }
}
