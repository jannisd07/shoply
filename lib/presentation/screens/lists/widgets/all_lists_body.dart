import 'package:flutter/semantics.dart';
import 'package:flutter/widgets.dart';

import 'package:cached_network_image/cached_network_image.dart';

import 'package:shoply/core/design/design.dart';
import 'package:shoply/core/localization/localization_helper.dart';
import 'package:shoply/data/models/shopping_list_model.dart';
import 'package:shoply/presentation/screens/lists/widgets/all_lists_data.dart';
import 'package:shoply/presentation/screens/lists/widgets/all_lists_quick_add.dart';
import 'package:shoply/presentation/screens/lists/widgets/list_info_colors.dart';
import 'package:shoply/presentation/screens/lists/widgets/share_members.dart';
import 'package:shoply/presentation/widgets/design/app_button.dart';
import 'package:shoply/presentation/widgets/design/avatar.dart';
import 'package:shoply/presentation/widgets/design/avo_icons.dart';
import 'package:shoply/presentation/widgets/design/empty_state.dart';
import 'package:shoply/presentation/widgets/design/inset_section.dart';
import 'package:shoply/presentation/widgets/design/item_row.dart';
import 'package:shoply/presentation/widgets/design/list_card.dart';
import 'package:shoply/presentation/widgets/design/search_field.dart';
import 'package:shoply/presentation/widgets/design/skeleton.dart';
import 'package:shoply/presentation/widgets/design/status_row.dart';
import 'package:shoply/presentation/widgets/slots/b_slots.dart';

// D2-Home vertical rhythm.
const double _kTitleToFirst = 13; // D2: section margin-top 13
const double _kSectionGap = AvoSpacing.m; // D2: margin-top 12, gap 12

/// What the overview has to show.
enum AllListsPhase {
  /// First load without any local data: placeholders.
  loading,

  /// Loading failed and nothing is known locally.
  error,

  /// Lists (maybe none) are known.
  ready,
}

/// The menu and VoiceOver actions of one list (Konzept 11 §7).
typedef ListMenuOpener = void Function(BuildContext anchor, ShoppingListModel list);

/// The scrolling content of the Listen tab (D2-Home), without the toolbar:
/// large title with the summary line, "Schnell wieder hinzufügen" for the
/// big card's list, the big [ListCard], "Andere Listen" and "Geteilt mit
/// mir" as [ListRow] groups. Pure: data in, callbacks out.
class AllListsContent extends StatelessWidget {
  const AllListsContent({
    super.key,
    required this.phase,
    required this.lists,
    required this.hero,
    required this.mine,
    required this.sharedWithMe,
    required this.currentUserId,
    required this.now,
    this.members = const {},
    this.quickAdd = const [],
    this.offline = false,
    this.query = '',
    this.onQueryChanged,
    required this.onOpen,
    required this.onMenu,
    required this.onCreate,
    required this.onJoin,
    required this.onQuickAdd,
    this.onRetry,
  });

  final AllListsPhase phase;

  /// All lists (for the summary line and the search).
  final List<ShoppingListModel> lists;

  /// The big card; null without lists.
  final ShoppingListModel? hero;

  /// Own lists below the card, already sorted.
  final List<ShoppingListModel> mine;

  /// Lists of other people, already sorted.
  final List<ShoppingListModel> sharedWithMe;

  final String? currentUserId;

  /// "Now" for "vor 2 Std.".
  final DateTime now;

  /// Known members per list id (shared lists only).
  final Map<String, List<ListMember>> members;

  final List<QuickAddSuggestion> quickAdd;
  final bool offline;

  /// The search text (the field shows from [kAllListsSearchFrom] lists).
  final String query;
  final ValueChanged<String>? onQueryChanged;

  final ValueChanged<ShoppingListModel> onOpen;
  final ListMenuOpener onMenu;
  final VoidCallback onCreate;
  final VoidCallback onJoin;
  final ValueChanged<QuickAddSuggestion> onQuickAdd;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[_header(context)];
    if (offline) {
      children.add(
        Padding(
          padding: const EdgeInsets.only(top: AvoSpacing.s),
          child: StatusRow(
            kind: StatusKind.offline,
            text: context.tr('common_offline'),
          ),
        ),
      );
    }

    switch (phase) {
      case AllListsPhase.loading:
        children
          ..add(const SizedBox(height: _kTitleToFirst))
          ..add(const SkeletonSection(rows: 3));
      case AllListsPhase.error:
        children.add(
          Padding(
            padding: const EdgeInsets.only(top: AvoSpacing.s),
            child: StatusRow(
              kind: StatusKind.sectionError,
              text: context.tr('common_section_error'),
              actionLabel: onRetry == null
                  ? null
                  : context.tr('common_try_again'),
              onAction: onRetry,
            ),
          ),
        );
      case AllListsPhase.ready:
        children.addAll(_ready(context));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: children,
    );
  }

  Widget _header(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AvoSpacing.screen),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Semantics(
            header: true,
            child: Text(
              context.tr('common_tab_lists'),
              style: context.text(AvoTextStyle.largeTitle),
            ),
          ),
          if (phase == AllListsPhase.ready && lists.isNotEmpty)
            Text(
              allListsSummary(context, lists),
              style: context.text(
                AvoTextStyle.subhead,
                color: colors.secondaryLabel,
              ),
            ),
        ],
      ),
    );
  }

  List<Widget> _ready(BuildContext context) {
    if (lists.isEmpty) {
      return [
        const SizedBox(height: AvoSpacing.xxxl),
        EmptyState(
          title: context.tr('list_ov_empty_title'),
          message: context.tr('list_ov_empty_message'),
          actionLabel: context.tr('list_ov_first_list'),
          onAction: onCreate,
          icon: const AvoIcon(AvoIcons.cart, size: 48),
        ),
        const SizedBox(height: AvoSpacing.s),
        Center(
          child: AppButton.plain(
            label: context.tr('list_ov_join_list'),
            onPressed: offline ? null : onJoin,
          ),
        ),
      ];
    }

    final out = <Widget>[];
    final searching = query.trim().isNotEmpty;
    if (lists.length >= kAllListsSearchFrom) {
      out
        ..add(const SizedBox(height: _kTitleToFirst))
        ..add(
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AvoSpacing.screen),
            child: AvoSearchField(
              hint: context.tr('list_ov_search'),
              onChanged: onQueryChanged,
            ),
          ),
        );
    }

    if (searching) {
      final found = filterLists(lists, query);
      if (found.isEmpty) {
        out.add(
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AvoSpacing.screen,
              AvoSpacing.xl,
              AvoSpacing.screen,
              0,
            ),
            child: Text(
              context.tr('list_ov_no_results', params: {'query': query.trim()}),
              style: context.text(
                AvoTextStyle.body,
                color: context.colors.secondaryLabel,
              ),
            ),
          ),
        );
      } else {
        out
          ..add(const SizedBox(height: _kSectionGap))
          ..add(_rows(context, found));
      }
      return out;
    }

    final heroList = hero;
    if (heroList != null && quickAdd.isNotEmpty) {
      out
        ..add(const SizedBox(height: _kTitleToFirst))
        ..add(
          AllListsQuickAdd(
            listId: heroList.id,
            suggestions: quickAdd,
            onAdd: onQuickAdd,
          ),
        );
    }
    if (heroList != null) {
      out
        ..add(SizedBox(height: out.isEmpty ? _kTitleToFirst : _kSectionGap))
        ..add(
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AvoSpacing.screen),
            child: _HeroCard(
              list: heroList,
              members: members[heroList.id],
              currentUserId: currentUserId,
              now: now,
              onOpen: onOpen,
              onMenu: onMenu,
            ),
          ),
        );
    }
    if (mine.isNotEmpty) {
      out.add(
        InsetSection(
          header: context.tr('list_ov_other_lists'),
          separatorIndent: ListRow.separatorIndent,
          children: [for (final l in mine) _row(context, l)],
        ),
      );
    }
    if (sharedWithMe.isNotEmpty) {
      out.add(
        InsetSection(
          header: context.tr('list_ov_shared_with_me'),
          separatorIndent: ListRow.separatorIndent,
          children: [for (final l in sharedWithMe) _row(context, l)],
        ),
      );
    }
    return out;
  }

  Widget _rows(BuildContext context, List<ShoppingListModel> found) =>
      InsetSection(
        separatorIndent: ListRow.separatorIndent,
        children: [for (final l in found) _row(context, l)],
      );

  Widget _row(BuildContext context, ShoppingListModel list) => _ListRowEntry(
    list: list,
    members: members[list.id],
    currentUserId: currentUserId,
    onOpen: onOpen,
    onMenu: onMenu,
  );
}

/// "4 offen", "Alles erledigt" or "Leer", plus "von Tom" on lists of
/// other people.
String listRowMeta(
  BuildContext context,
  ShoppingListModel list, {
  List<ListMember>? members,
  String? currentUserId,
}) {
  final total = list.itemCount ?? 0;
  final open = list.uncheckedCount ?? 0;
  final String state;
  if (total == 0) {
    state = context.tr('list_ov_empty_list');
  } else if (open == 0) {
    state = context.tr('home_all_done');
  } else {
    state = context.tr('home_open_items', params: {'n': '$open'});
  }
  if (currentUserId == null || list.ownerId == currentUserId) return state;
  ListMember? owner;
  for (final m in members ?? const <ListMember>[]) {
    if (m.isOwner) owner = m;
  }
  if (owner == null || owner.name.isEmpty) return state;
  return '$state · ${context.tr('list_ov_by', params: {'name': owner.name})}';
}

/// Names for the avatar stack: you first (neutral), then the others.
List<String> _stackNames(
  BuildContext context,
  List<ListMember> members,
  String? currentUserId,
) {
  final you = [for (final m in members) if (m.userId == currentUserId) m];
  final others = otherMembers(members, currentUserId);
  return [for (final m in [...you, ...others]) memberName(context, m)];
}

class _ListRowEntry extends StatelessWidget {
  const _ListRowEntry({
    required this.list,
    required this.members,
    required this.currentUserId,
    required this.onOpen,
    required this.onMenu,
  });

  final ShoppingListModel list;
  final List<ListMember>? members;
  final String? currentUserId;
  final ValueChanged<ShoppingListModel> onOpen;
  final ListMenuOpener onMenu;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final total = list.itemCount ?? 0;
    final open = list.uncheckedCount ?? 0;
    final complete = total > 0 && open == 0;
    final known = members ?? const <ListMember>[];
    final shared = known.length > 1;
    final names = shared
        ? _stackNames(context, known, currentUserId)
        : const <String>[];
    final cover = listCoverUrl(list);
    final youFirst = known.any((m) => m.userId == currentUserId);

    return Builder(
      builder: (anchor) => GestureDetector(
        onLongPress: () => onMenu(anchor, list),
        child: ListRow(
          title: list.name,
          meta: listRowMeta(
            context,
            list,
            members: members,
            currentUserId: currentUserId,
          ),
          complete: complete,
          cover: cover == null
              ? null
              : ItemThumb(image: CachedNetworkImageProvider(cover)),
          color: listDisplayColor(context, list),
          glyph: AvoIcon(AvoIcons.cart, color: colors.onTint),
          done: complete ? total : null,
          total: complete ? total : null,
          accessory: names.isEmpty
              ? null
              : AvatarStack(
                  names: names,
                  neutralFirst: youFirst,
                  semanticLabel: context.tr(
                    'common_shared_with',
                    params: {'names': names.join(', ')},
                  ),
                ),
          onTap: () => onOpen(list),
          semanticActions: {
            context.tr('common_more'): () => onMenu(anchor, list),
          },
        ),
      ),
    );
  }
}

/// The big card of the pinned or last used list (D2 "Listenkarte · Cover +
/// Fortschritt"): photo or colour band, "mit Lena", Teil B's offer badge,
/// "12 Artikel · 4 offen · vor 2 Std." and the progress line.
class _HeroCard extends StatelessWidget {
  const _HeroCard({
    required this.list,
    required this.members,
    required this.currentUserId,
    required this.now,
    required this.onOpen,
    required this.onMenu,
  });

  final ShoppingListModel list;
  final List<ListMember>? members;
  final String? currentUserId;
  final DateTime now;
  final ValueChanged<ShoppingListModel> onOpen;
  final ListMenuOpener onMenu;

  @override
  Widget build(BuildContext context) {
    final total = list.itemCount ?? 0;
    final open = list.uncheckedCount ?? 0;
    final color = listDisplayColor(context, list);
    final url = listCoverUrl(list);
    final others = otherMembers(members ?? const [], currentUserId);
    final meta = [
      if (total == 0)
        context.tr('list_ov_empty_list')
      else
        itemCountLabel(context, total),
      if (open > 0) context.tr('home_open_items', params: {'n': '$open'}),
      relativeListTime(context, list.updatedAt, now),
    ].join(' · ');

    return Builder(
      builder: (anchor) => MergeSemantics(
        child: Semantics(
          customSemanticsActions: {
            CustomSemanticsAction(label: context.tr('common_more')): () =>
                onMenu(anchor, list),
          },
          child: GestureDetector(
            onLongPress: () => onMenu(anchor, list),
            child: ListCard(
              title: list.name,
              done: total - open,
              total: total,
              meta: meta,
              color: color,
              cover: url == null
                  ? null
                  : Image(
                      image: CachedNetworkImageProvider(url),
                      fit: BoxFit.cover,
                      excludeFromSemantics: true,
                      errorBuilder: (context, error, stack) =>
                          ColoredBox(color: color),
                    ),
              sharedLabel: withMembersLabel(context, others),
              sharedName: others.isEmpty
                  ? null
                  : memberName(context, others.first),
              badge: ListOfferCountBadge(listId: list.id),
              onTap: () => onOpen(list),
            ),
          ),
        ),
      ),
    );
  }
}
