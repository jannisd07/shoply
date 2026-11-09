import 'package:flutter/cupertino.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:shoply/core/design/design.dart';
import 'package:shoply/core/localization/localization_helper.dart';
import 'package:shoply/data/models/shopping_list_model.dart';
import 'package:shoply/presentation/screens/lists/list_settings_screen.dart';
import 'package:shoply/presentation/screens/lists/widgets/all_lists_data.dart';
import 'package:shoply/presentation/screens/profile/settings/data/list_preferences.dart';
import 'package:shoply/presentation/screens/profile/settings/widgets/settings_page.dart';
import 'package:shoply/presentation/state/auth_provider.dart';
import 'package:shoply/presentation/state/last_list_provider.dart';
import 'package:shoply/presentation/widgets/design/avo_menu.dart';
import 'package:shoply/presentation/widgets/design/full_screen_editor.dart';
import 'package:shoply/presentation/widgets/design/inset_section.dart';
import 'package:shoply/presentation/widgets/design/picker_row.dart';
import 'package:shoply/presentation/widgets/design/row_highlight.dart';
import 'package:shoply/presentation/widgets/design/settings_rows.dart';

/// The list "Reihenfolge im Markt" opens: the pinned list, else the one
/// opened last, else the first one; null without lists.
ShoppingListModel? todaysList(
  List<ShoppingListModel> lists, {
  String? pinnedId,
  String? lastId,
}) {
  if (lists.isEmpty) return null;
  for (final id in [pinnedId, lastId]) {
    if (id == null) continue;
    for (final l in lists) {
      if (l.id == id) return l;
    }
  }
  return lists.first;
}

/// Listen (`/settings/lists`, Konzept 18 §5.4): Anzeige (item images,
/// "Vielleicht auch"), Beim Öffnen ("Liste beim Start" as a pull-down menu:
/// the last used list or one pinned list), Einkaufsmodus (screen on, "Anderen
/// zeigen, dass ich einkaufe", K18-07) and "Reihenfolge im Markt", which
/// opens the Listen-Info of today's list (no second place to edit it).
class ListsSettingsScreen extends ConsumerWidget {
  const ListsSettingsScreen({super.key, this.highlightRowId});

  /// Row to highlight once (`?row=`), see `RowHighlightScope`.
  final String? highlightRowId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(listPreferencesProvider);
    final notifier = ref.read(listPreferencesProvider.notifier);
    final lists =
        ref.watch(allListsSourceProvider).valueOrNull ??
        const <ShoppingListModel>[];
    final pinnedId = ref.watch(pinnedListProvider).listId;
    final lastId = ref.watch(lastAccessedListProvider).valueOrNull;
    final name = ref.watch(currentUserProvider).valueOrNull?.displayName;

    ShoppingListModel? pinned;
    for (final l in lists) {
      if (l.id == pinnedId) pinned = l;
    }
    final today = todaysList(lists, pinnedId: pinnedId, lastId: lastId);
    final firstName = name?.trim().split(RegExp(r'\s+')).first;

    void pin(String? id) => ref.read(pinnedListProvider.notifier).pin(id);

    return SettingsPage(
      title: context.tr('setp_lists_title'),
      highlightRowId: highlightRowId,
      children: [
        InsetSection(
          header: context.tr('setp_lists_display'),
          children: [
            HighlightableRow(
              id: 'lists.item_images',
              child: ToggleRow(
                title: context.tr('setp_lists_images'),
                subtitle: context.tr(
                  context.isAccessibilityText
                      ? 'setp_lists_images_ax'
                      : 'setp_lists_images_sub',
                ),
                value: prefs.showItemImages,
                onChanged: (v) =>
                    notifier.update(prefs.copyWith(showItemImages: v)),
              ),
            ),
            HighlightableRow(
              id: 'lists.suggestions',
              child: ToggleRow(
                title: context.tr('setp_lists_suggestions'),
                subtitle: context.tr('setp_lists_suggestions_sub'),
                value: prefs.suggestions,
                onChanged: (v) =>
                    notifier.update(prefs.copyWith(suggestions: v)),
              ),
            ),
          ],
        ),
        InsetSection(
          header: context.tr('setp_lists_on_open'),
          children: [
            HighlightableRow(
              id: 'lists.start_list',
              child: MenuValueRow(
                title: context.tr('setp_lists_start'),
                value: pinned?.name ?? context.tr('setp_lists_start_last'),
                items: [
                  AvoMenuItem(
                    label: context.tr('setp_lists_start_last'),
                    checked: pinned == null,
                    onSelected: () => pin(null),
                  ),
                  if (lists.isNotEmpty) const AvoMenuDivider(),
                  for (final l in lists)
                    AvoMenuItem(
                      label: l.name,
                      checked: l.id == pinned?.id,
                      onSelected: () => pin(l.id),
                    ),
                ],
              ),
            ),
          ],
        ),
        InsetSection(
          header: context.tr('setp_lists_shopping'),
          children: [
            HighlightableRow(
              id: 'lists.keep_screen_on',
              child: ToggleRow(
                title: context.tr('setp_lists_screen_on'),
                subtitle: context.tr('setp_lists_screen_on_sub'),
                value: prefs.keepScreenOn,
                onChanged: (v) =>
                    notifier.update(prefs.copyWith(keepScreenOn: v)),
              ),
            ),
            HighlightableRow(
              id: 'lists.share_presence',
              child: ToggleRow(
                title: context.tr('setp_lists_presence'),
                subtitle: firstName == null || firstName.isEmpty
                    ? context.tr('setp_lists_presence_sub')
                    : context.tr(
                        'setp_lists_presence_sub_named',
                        params: {'name': firstName},
                      ),
                value: prefs.sharePresence,
                onChanged: (v) =>
                    notifier.update(prefs.copyWith(sharePresence: v)),
              ),
            ),
          ],
        ),
        InsetSection(
          header: context.tr('setp_lists_categories'),
          children: [
            HighlightableRow(
              id: 'lists.store_order',
              child: NavRow(
                title: context.tr('setp_lists_order'),
                subtitle: context.tr(
                  today == null
                      ? 'setp_lists_order_none'
                      : 'setp_lists_order_sub',
                ),
                value: today?.name,
                onTap: today == null
                    ? null
                    : () => pushFullScreenEditor<void>(
                        context,
                        (_) => ListSettingsScreen(
                          listId: today.id,
                          listName: today.name,
                          ownerId: today.ownerId,
                        ),
                        cover: false,
                      ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
