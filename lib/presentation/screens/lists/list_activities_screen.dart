import 'package:flutter/cupertino.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:shoply/core/design/design.dart';
import 'package:shoply/core/localization/localization_helper.dart';
import 'package:shoply/data/models/list_activity.dart';
import 'package:shoply/presentation/screens/lists/widgets/list_info_changes.dart';
import 'package:shoply/presentation/state/auth_provider.dart';
import 'package:shoply/presentation/widgets/design/full_screen_editor.dart';
import 'package:shoply/presentation/widgets/design/inset_section.dart';

/// "Alle Änderungen" of a list (Konzept 11 §10.3): one section per day
/// ("Heute", "Gestern", "Mo., 2. Nov."), 30 days back, equal events of one
/// person bundled. Opened from Listen-Info and from notifications
/// (`/lists/:listId/activities`). No "Verlauf löschen".
class ListActivitiesScreen extends ConsumerWidget {
  const ListActivitiesScreen({
    super.key,
    required this.listId,
    required this.listName,
  });

  final String listId;
  final String listName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userId = ref.watch(authUserIdProvider);
    final now = ref.watch(listChangesClockProvider)();
    final cutoff = now.subtract(const Duration(days: kListChangesDays));
    final all = ref.watch(listChangesProvider(listId)).valueOrNull ?? const [];
    final recent = [
      for (final a in all)
        if (a.timestamp.isAfter(cutoff)) a,
    ];

    final days = <DateTime, List<ListActivity>>{};
    for (final a in recent) {
      final t = a.timestamp.toLocal();
      days.putIfAbsent(DateTime(t.year, t.month, t.day), () => []).add(a);
    }

    final route = ModalRoute.of(context);
    final cover = route is PageRoute && route.fullscreenDialog;

    return FullScreenEditor(
      title: context.tr('list_ov_changes_title'),
      leading: cover ? EditorLeading.close : EditorLeading.back,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (days.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AvoSpacing.screen,
                vertical: AvoSpacing.l,
              ),
              child: Text(
                context.tr('list_ov_no_changes'),
                style: context.text(
                  AvoTextStyle.body,
                  color: context.colors.secondaryLabel,
                ),
              ),
            ),
          for (final entry in days.entries)
            InsetSection(
              header: listChangeDay(context, entry.key, now),
              children: [
                for (final c in bundleChanges(entry.value))
                  ListChangeRow(change: c, currentUserId: userId, now: now),
              ],
            ),
        ],
      ),
    );
  }
}
