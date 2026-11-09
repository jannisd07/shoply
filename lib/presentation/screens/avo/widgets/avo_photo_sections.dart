import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:shoply/core/design/design.dart';
import 'package:shoply/core/localization/localization_helper.dart';
import 'package:shoply/data/services/avo_assistant_service.dart';
import 'package:shoply/presentation/screens/avo/avo_card_format.dart';
import 'package:shoply/presentation/screens/avo/avo_chat.dart';
import 'package:shoply/presentation/screens/avo/avo_l10n.dart';
import 'package:shoply/presentation/screens/avo/widgets/avo_card_scope.dart';
import 'package:shoply/presentation/screens/avo/widgets/avo_choice_card.dart';
import 'package:shoply/presentation/screens/avo/widgets/avo_list_sections.dart';
import 'package:shoply/presentation/screens/avo/widgets/avo_record_sections.dart';
import 'package:shoply/presentation/screens/avo/widgets/avo_result_card.dart';
import 'package:shoply/presentation/widgets/design/avo_icons.dart';
import 'package:shoply/presentation/widgets/design/check_circle.dart';
import 'package:shoply/routes/app_destinations.dart';

// Kap. 7: a photo for Avo, its choice, the shopping note, what went wrong.
const double _rowMinHeight = 52; // D2 selectable row

/// "Was soll ich mit dem Foto machen?" with "Als Essen eintragen" (only
/// with the calories module) and "Artikel auf eine Liste" (Kap. 7.1).
class AvoPhotoChoice extends StatelessWidget {
  const AvoPhotoChoice({
    super.key,
    required this.payload,
    required this.scope,
    required this.card,
  });

  final AvoWidgetPayload payload;
  final AvoCardScope scope;
  final AvoPhotoChoiceCard card;

  @override
  Widget build(BuildContext context) {
    final chat = scope.chat;
    final chosen = chat.photoChoiceOf(payload);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        AvoQuestionText(text: context.tr('avo_photo_question')),
        const SizedBox(height: AvoSpacing.s),
        AvoChoiceCard(
          options: [
            if (card.caloriesOn)
              AvoChoiceOption(
                id: AvoPhotoIntent.meal.name,
                title: context.tr('avo_photo_as_meal'),
                leading: const AvoSymbolTile(icon: AvoIcon(AvoIcons.flame)),
              ),
            AvoChoiceOption(
              id: AvoPhotoIntent.list.name,
              title: context.tr('avo_photo_to_list'),
              leading: const AvoSymbolTile(
                icon: Icon(CupertinoIcons.doc_text_viewfinder),
              ),
            ),
          ],
          selectedId: chosen?.name,
          stale: chosen == null && !identical(scope.turn, chat.latest),
          enabled: !scope.offline,
          onSelect: (id) => chat.choosePhoto(
            payload,
            AvoPhotoIntent.values.byName(id),
            offline: scope.offline,
          ),
        ),
      ],
    );
  }
}

/// A photographed shopping note (Kap. 7.3): "14 Artikel erkannt" with rows
/// to leave out, "Nicht erkannt", "{n} hinzufügen"; without a list from the
/// context first "Auf welche Liste?". Afterwards the result with
/// "Widerrufen".
class AvoListImport extends ConsumerWidget {
  const AvoListImport({
    super.key,
    required this.payload,
    required this.scope,
    required this.card,
  });

  final AvoWidgetPayload payload;
  final AvoCardScope scope;
  final AvoListImportCard card;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chat = scope.chat;
    if (chat.recordOf(payload) != null) {
      return AvoResultCard(
        sections: [AvoRecordSection(payload: payload, scope: scope)],
      );
    }
    final off = chat.deselectedOf(payload);
    final chosen = card.items.length - off.length;
    final listId = chat.importListOf(payload);
    final lists = [...ref.watch(avoListsProvider)]
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    final listName = lists.where((l) => l.id == listId).firstOrNull?.name;
    final working = chat.isCardWorking(payload);
    final colors = context.colors;

    final found = AvoResultSection(
      title: avoTrCount(context, 'avo_import_found', card.items.length),
      subtitle: listName,
      leading: const AvoSymbolTile(
        icon: Icon(CupertinoIcons.doc_text_viewfinder),
      ),
      maxCollapsed: card.items.length,
      maxExpanded: card.items.length,
      detailIndent: AvoSpacing.l + AvoSizes.hitTarget + AvoSpacing.xs,
      details: [
        for (var i = 0; i < card.items.length; i++)
          _ImportRow(
            name: card.items[i].name,
            amount: _amount(
              context,
              card.items[i].quantity,
              card.items[i].unit,
            ),
            selected: !off.contains(i),
            onToggle: () => chat.toggleImportRow(payload, i),
          ),
      ],
      actions: [
        AvoCardAction(
          label: context.tr('avo_import_add', params: {'n': '$chosen'}),
          working: working,
          onPressed: listId == null || chosen == 0 || working || scope.offline
              ? null
              : () => chat.addImport(payload),
        ),
      ],
    );
    final unreadable = card.unreadable.isEmpty
        ? null
        : AvoResultSection(
            title: context.tr('avo_import_unreadable'),
            titleColor: colors.secondaryLabel,
            leading: AvoSymbolTile(
              neutral: true,
              icon: Icon(CupertinoIcons.question, color: colors.secondaryLabel),
            ),
            details: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AvoSpacing.l),
                child: Text(
                  card.unreadable.join(', '),
                  style: context.text(
                    AvoTextStyle.subhead,
                    color: colors.secondaryLabel,
                  ),
                ),
              ),
            ],
          );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        AvoResultCard(sections: [found, ?unreadable]),
        if (card.listId == null && lists.isNotEmpty) ...[
          const SizedBox(height: AvoSpacing.s),
          AvoQuestionText(text: context.tr('avo_import_which_list')),
          const SizedBox(height: AvoSpacing.s),
          AvoChoiceCard(
            options: [
              for (final l in lists)
                AvoChoiceOption(
                  id: l.id,
                  title: l.name,
                  leading: AvoListSquare(list: l),
                ),
            ],
            selectedId: listId,
            enabled: !scope.offline,
            onSelect: (id) => chat.pickImportList(payload, id),
          ),
        ],
      ],
    );
  }

  static String? _amount(BuildContext context, double? quantity, String? unit) {
    if (quantity == null) return unit;
    final n = avoDecimal(context, quantity, decimals: 2);
    return unit == null || unit.isEmpty ? n : '$n $unit';
  }
}

/// One recognised item; a tap leaves it out or takes it again.
class _ImportRow extends StatelessWidget {
  const _ImportRow({
    required this.name,
    required this.selected,
    required this.onToggle,
    this.amount,
  });

  final String name;
  final String? amount;
  final bool selected;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Semantics(
      container: true,
      checked: selected,
      label: amount == null ? name : '$name, $amount',
      onTap: onToggle,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onToggle,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: _rowMinHeight),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AvoSpacing.l),
            child: Row(
              children: [
                SizedBox.square(
                  dimension: AvoSizes.hitTarget,
                  child: Center(
                    child: IgnorePointer(
                      child: CheckCircle(
                        checked: selected,
                        itemName: name,
                        onChanged: (_) {},
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: AvoSpacing.xs),
                Expanded(
                  child: Text(
                    name,
                    style: context.text(
                      AvoTextStyle.body,
                      color: selected ? colors.label : colors.secondaryLabel,
                    ),
                  ),
                ),
                if (amount != null) ...[
                  const SizedBox(width: AvoSpacing.s),
                  Text(
                    amount!,
                    style: context.text(
                      AvoTextStyle.subhead,
                      color: colors.secondaryLabel,
                      tabular: true,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A photo Avo could not use (Kap. 7.4): what happened and the way on.
/// [onNewPhoto] opens the photo menu again ("Neues Foto").
AvoResultSection avoPhotoErrorSection(
  BuildContext context,
  AvoCardScope s,
  AvoPhotoErrorCard card, {
  VoidCallback? onNewPhoto,
}) {
  final colors = context.colors;
  void manual() => openAppDestination(context, AppDestinations.calories);
  final (
    String text,
    String? actionLabel,
    VoidCallback? action,
    bool error,
  ) = switch (card.code) {
    'no_food_detected' => (
      context.tr('avo_photo_no_food'),
      context.tr('avo_photo_manual'),
      manual,
      false,
    ),
    'no_items_found' => (
      context.tr('avo_photo_no_items'),
      context.tr('avo_photo_new'),
      onNewPhoto,
      false,
    ),
    'unreadable_image' => (
      context.tr('avo_photo_unreadable'),
      context.tr('avo_photo_new'),
      onNewPhoto,
      false,
    ),
    'quota_exceeded' || 'rate_limited' when card.meal => (
      context.tr('avo_photo_limit_meal'),
      context.tr('avo_photo_manual'),
      manual,
      false,
    ),
    'quota_exceeded' ||
    'rate_limited' => (context.tr('avo_photo_limit_list'), null, null, false),
    'network_error' || 'timeout' => (
      context.tr('avo_err_unreachable'),
      context.tr('avo_retry'),
      () => s.chat.retry(s.turn, offline: s.offline),
      true,
    ),
    _ => (
      context.tr('avo_err_title'),
      context.tr('avo_retry'),
      () => s.chat.retry(s.turn, offline: s.offline),
      true,
    ),
  };
  return AvoResultSection(
    title: text,
    leading: AvoSymbolTile(
      neutral: true,
      icon: AvoIcon(
        error ? AvoIcons.exclamationmarkCircle : AvoIcons.camera,
        color: error ? colors.destructive : colors.secondaryLabel,
      ),
    ),
    actions: [
      if (actionLabel != null && action != null)
        AvoCardAction(label: actionLabel, onPressed: action),
    ],
  );
}
