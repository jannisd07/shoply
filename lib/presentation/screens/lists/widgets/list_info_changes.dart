import 'package:flutter/widgets.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:shoply/core/design/design.dart';
import 'package:shoply/core/localization/localization_helper.dart';
import 'package:shoply/data/models/list_activity.dart';
import 'package:shoply/data/services/list_activity_service.dart';
import 'package:shoply/presentation/screens/lists/widgets/all_lists_data.dart';
import 'package:shoply/presentation/widgets/design/avatar.dart';

/// The changes of a list, newest first. Today's source is the local
/// [ListActivityService] (this device only); the server table `list_events`
/// (Konzept 11 §10.3, E-12) replaces it. Overridden in tests.
final listChangesProvider = FutureProvider.autoDispose
    .family<List<ListActivity>, String>(
      (ref, listId) => ListActivityService().getActivities(listId),
    );

/// How many changes Listen-Info shows (Konzept 11 §10.1).
const int kListInfoChangeCount = 5;

/// "Alle Änderungen" goes this many days back (Konzept 11 §10.3).
const int kListChangesDays = 30;

/// The clock of Listen-Info and "Alle Änderungen" ("Heute", "vor 12 Min.");
/// tests give it a fixed time.
final listChangesClockProvider = Provider<DateTime Function()>(
  (ref) => DateTime.now,
);

/// Consecutive equal events of one person within this window are one row
/// ("Lena hat 5 Artikel abgehakt").
const Duration kListChangeBundle = Duration(minutes: 10);

/// One row of "Zuletzt geändert": an event, or several of the same kind.
@immutable
class ListChange {
  const ListChange({required this.first, this.count = 1});

  /// The newest event of the bundle.
  final ListActivity first;

  /// How many events the row stands for.
  final int count;
}

bool _bundles(ListActivityType type) => switch (type) {
  ListActivityType.itemAdded ||
  ListActivityType.itemRemoved ||
  ListActivityType.itemChecked ||
  ListActivityType.itemUnchecked => true,
  _ => false,
};

/// Bundles [activities] (newest first) into rows.
List<ListChange> bundleChanges(List<ListActivity> activities) {
  final out = <ListChange>[];
  for (final a in activities) {
    if (out.isNotEmpty) {
      final last = out.last;
      final previous = last.first;
      if (_bundles(a.type) &&
          a.type == previous.type &&
          a.userId == previous.userId &&
          previous.timestamp.difference(a.timestamp).abs() <=
              kListChangeBundle) {
        out[out.length - 1] = ListChange(
          first: previous,
          count: last.count + 1,
        );
        continue;
      }
    }
    out.add(ListChange(first: a));
  }
  return out;
}

/// "Lena hat Butter hinzugefügt", "Du hast 5 Artikel abgehakt".
String listChangeText(
  BuildContext context,
  ListChange change, {
  required String? currentUserId,
}) {
  final a = change.first;
  final you = a.userId == currentUserId;
  final who = a.userName.trim().isEmpty
      ? context.tr('someone')
      : a.userName.trim();
  final item = '${a.metadata?['itemName'] ?? ''}'.trim();
  final many = change.count > 1;
  String key(String base) => you ? '${base}_you' : base;
  final params = <String, String>{
    'who': who,
    'item': item,
    'n': '${change.count}',
  };

  switch (a.type) {
    case ListActivityType.itemAdded:
      return context.tr(
        key(many ? 'list_ov_ev_added_many' : 'list_ov_ev_added'),
        params: params,
      );
    case ListActivityType.itemRemoved:
      return context.tr(
        key(many ? 'list_ov_ev_removed_many' : 'list_ov_ev_removed'),
        params: params,
      );
    case ListActivityType.itemChecked:
      return context.tr(
        key(many ? 'list_ov_ev_checked_many' : 'list_ov_ev_checked'),
        params: params,
      );
    case ListActivityType.itemUnchecked:
      return context.tr(
        key(many ? 'list_ov_ev_unchecked_many' : 'list_ov_ev_unchecked'),
        params: params,
      );
    case ListActivityType.memberJoined:
      final member = '${a.metadata?['memberName'] ?? ''}'.trim();
      return context.tr(
        key('list_ov_ev_joined'),
        params: {'who': member.isEmpty ? who : member},
      );
    case ListActivityType.memberLeft:
      final member = '${a.metadata?['memberName'] ?? ''}'.trim();
      return context.tr(
        key('list_ov_ev_left'),
        params: {'who': member.isEmpty ? who : member},
      );
    case ListActivityType.listRenamed:
      return context.tr(
        key('list_ov_ev_renamed'),
        params: {'who': who, 'name': '${a.metadata?['newName'] ?? ''}'},
      );
    case ListActivityType.shoppingCompleted:
      return context.tr(
        key('list_ov_ev_shopping'),
        params: {'who': who, 'n': '${a.metadata?['itemCount'] ?? 0}'},
      );
    case ListActivityType.categoryAdded:
    case ListActivityType.categoryRemoved:
    case ListActivityType.categoryReordered:
    case ListActivityType.listShared:
    case ListActivityType.backgroundChanged:
      return context.tr(key('list_ov_ev_changed'), params: {'who': who});
  }
}

/// The time at the end of a row: "vor 12 Min.", "9:15", "Gestern", "14. Okt."
String listChangeTime(BuildContext context, DateTime time, DateTime now) {
  final local = time.toLocal();
  final diff = now.difference(local);
  if (diff.inMinutes < 60) return relativeListTime(context, local, now);
  final locale = Localizations.localeOf(context).toLanguageTag();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(local.year, local.month, local.day);
  final days = today.difference(day).inDays;
  if (days == 0) return DateFormat.Hm(locale).format(local);
  if (days == 1) return context.tr('yesterday');
  return listDate(context, local, now);
}

/// The section title of a day in "Alle Änderungen": "Heute", "Gestern",
/// "Mo., 2. Nov."
String listChangeDay(BuildContext context, DateTime day, DateTime now) {
  final today = DateTime(now.year, now.month, now.day);
  final d = DateTime(day.year, day.month, day.day);
  final days = today.difference(d).inDays;
  if (days == 0) return context.tr('today');
  if (days == 1) return context.tr('yesterday');
  final locale = Localizations.localeOf(context).toLanguageTag();
  return DateFormat.MMMEd(locale).format(d);
}

/// A row of "Zuletzt geändert" (Konzept 11 §10.3): avatar 20 pt, the text,
/// the time at the end (below the text from AX1). No emoji, no colour.
class ListChangeRow extends StatelessWidget {
  const ListChangeRow({
    super.key,
    required this.change,
    required this.currentUserId,
    required this.now,
  });

  final ListChange change;
  final String? currentUserId;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final ax = context.isAccessibilityText;
    final text = listChangeText(context, change, currentUserId: currentUserId);
    final time = listChangeTime(context, change.first.timestamp, now);
    final name = change.first.userName;
    final textWidget = Text(text, style: context.text(AvoTextStyle.body));
    final timeWidget = Text(
      time,
      style: context.text(AvoTextStyle.caption1, color: colors.secondaryLabel),
    );
    return Semantics(
      container: true,
      label: '$text, $time',
      excludeSemantics: true,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: AvoSizes.hitTarget),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AvoSpacing.l,
            vertical: AvoSpacing.m,
          ),
          child: Row(
            crossAxisAlignment: ax
                ? CrossAxisAlignment.start
                : CrossAxisAlignment.center,
            children: [
              Avatar(
                name: name.trim().isEmpty ? '?' : name,
                size: ax ? AvatarSize.medium : AvatarSize.small,
                neutral: change.first.userId == currentUserId,
              ),
              const SizedBox(width: AvoSpacing.m),
              Expanded(
                child: ax
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [textWidget, timeWidget],
                      )
                    : textWidget,
              ),
              if (!ax) ...[const SizedBox(width: AvoSpacing.s), timeWidget],
            ],
          ),
        ),
      ),
    );
  }
}
