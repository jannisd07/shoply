import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';

import 'package:shoply/core/localization/localization_helper.dart';
import 'package:shoply/data/services/avo_assistant_service.dart';
import 'package:shoply/presentation/screens/avo/avo_chat.dart';
import 'package:shoply/presentation/screens/avo/avo_suggestions.dart';

/// Item names listed per change in the note, at most.
const int _maxNames = 8;

/// What is already done for a question, for the hidden note a retry sends
/// to Avo ("Schon erledigt, bitte nicht noch einmal: …"), or an empty text.
///
/// [done] are all done changes of the question so far (earlier failed rounds
/// included). Undone ones are left out. List, item and setting values come
/// in only when [avoSafeName] allows them (other members of a shared list
/// write those names); otherwise the change is described without them.
String avoDoneNote(
  BuildContext context,
  AvoChat chat,
  List<AvoWidgetPayload> done,
) {
  final parts = <String>[];
  for (final p in done) {
    if (chat.undoPhaseOf(p) == AvoUndoPhase.undone) continue;
    final change = chat.changeOf(p);
    if (change != null) {
      parts.add(_listChange(context, change));
      continue;
    }
    final setting = p.settingChange;
    if (setting != null && setting.success) {
      final value = avoSafeName(setting.newValue);
      parts.add(
        value == null ? setting.displayName : '${setting.displayName}: $value',
      );
      continue;
    }
    final tool = p.wroteTool;
    if (tool != null) {
      final list = avoSafeName(p.wroteListName);
      parts.add(list == null ? tool : '$tool ($list)');
    }
  }
  if (parts.isEmpty) return '';
  return context.tr(
    'avo_retry_done_note',
    params: {'changes': parts.join('; ')},
  );
}

String _listChange(BuildContext context, AvoListChange c) {
  final list = avoSafeName(c.listName) ?? context.tr('avo_note_a_list');
  final n = {'n': '${c.count}'};
  final lang = Localizations.maybeLocaleOf(context)?.languageCode ?? 'de';
  String qty(double v) => NumberFormat('0.##', lang).format(v);
  final item = avoSafeName(c.itemName);
  final before = c.previousQuantity;
  final after = c.newQuantity;

  final String what;
  switch (c.kind) {
    case AvoListChangeKind.added when before != null && after != null:
    case AvoListChangeKind.updated when before != null && after != null:
      what = item == null
          ? context.tr('avo_note_updated')
          : context.tr(
              'avo_card_quantity',
              params: {'item': item, 'new': qty(after), 'old': qty(before)},
            );
    case AvoListChangeKind.added:
      what = context.tr('avo_card_added', params: n);
    case AvoListChangeKind.checked:
      what = context.tr('avo_card_checked', params: n);
    case AvoListChangeKind.unchecked:
      what = context.tr('avo_card_unchecked', params: n);
    case AvoListChangeKind.updated:
      what = context.tr('avo_note_updated');
    case AvoListChangeKind.moved:
      what = context.tr('avo_note_moved', params: n);
    case AvoListChangeKind.created:
      what = context.tr('avo_card_new_list');
    case AvoListChangeKind.renamed:
      what = context.tr('avo_card_renamed_plain');
  }
  final names = [
    for (final i in c.items.take(_maxNames))
      if (avoSafeName(i.name) case final safe?) safe,
  ];
  final listed =
      c.kind == AvoListChangeKind.updated ||
          (c.kind == AvoListChangeKind.added && before != null) ||
          names.isEmpty
      ? ''
      : ' (${names.join(', ')})';
  return '$list: $what$listed';
}
