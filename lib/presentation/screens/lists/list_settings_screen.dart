
import 'package:flutter/cupertino.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:shoply/core/design/design.dart';
import 'package:shoply/core/localization/localization_helper.dart';
import 'package:shoply/data/models/shopping_list_model.dart';
import 'package:shoply/data/services/connectivity_service.dart';
import 'package:shoply/presentation/screens/lists/category_order_screen.dart';
import 'package:shoply/presentation/screens/lists/list_activities_screen.dart';
import 'package:shoply/presentation/screens/lists/widgets/all_lists_data.dart';
import 'package:shoply/presentation/screens/lists/widgets/list_info_actions.dart';
import 'package:shoply/presentation/screens/lists/widgets/list_info_changes.dart';
import 'package:shoply/presentation/screens/lists/widgets/list_info_colors.dart';
import 'package:shoply/presentation/screens/lists/widgets/list_info_header.dart';
import 'package:shoply/presentation/screens/lists/widgets/list_info_rows.dart';
import 'package:shoply/presentation/screens/lists/widgets/share_list_dialog.dart';
import 'package:shoply/presentation/screens/lists/widgets/share_members.dart';
import 'package:shoply/presentation/state/auth_provider.dart';
import 'package:shoply/presentation/widgets/design/app_button.dart';
import 'package:shoply/presentation/widgets/design/avo_icons.dart';
import 'package:shoply/presentation/widgets/design/avo_menu.dart';
import 'package:shoply/presentation/widgets/design/confirm_dialog.dart';
import 'package:shoply/presentation/widgets/design/full_screen_editor.dart';
import 'package:shoply/presentation/widgets/design/inset_section.dart';
import 'package:shoply/presentation/widgets/design/settings_rows.dart';
import 'package:shoply/presentation/widgets/design/status_row.dart';
import 'package:shoply/presentation/widgets/design/undo_toast.dart';
import 'package:shoply/presentation/widgets/slots/b_slots.dart';
import 'package:shoply/routes/route_paths.dart';

/// Konzept 00 §12.20: unavailable controls at 40 %.
const double _kDisabledOpacity = 0.4;

/// Listen-Info (Konzept 11 §10, full screen instead of a sheet): name,
/// colour, store order and offers, members with "Personen einladen",
/// pinning, recent changes, and "Liste löschen" (creator) or "Liste
/// verlassen". Changes apply at once, so there is no "Fertig".
///
/// Everything comes from the local state first (lists, cached members);
/// the leading button is an X when the screen was opened as a cover and a
/// back chevron when it was pushed.
class ListSettingsScreen extends ConsumerStatefulWidget {
  const ListSettingsScreen({
    super.key,
    required this.listId,
    required this.listName,
    this.ownerId,
    this.focusName = false,
  });

  final String listId;

  /// The name until the list is known locally.
  final String listName;

  /// Null when the caller doesn't know it yet; taken from the list or the
  /// members then.
  final String? ownerId;

  /// Focus the name field on open ("Umbenennen").
  final bool focusName;

  @override
  ConsumerState<ListSettingsScreen> createState() => _ListSettingsScreenState();
}

class _ListSettingsScreenState extends ConsumerState<ListSettingsScreen> {
  late final TextEditingController _name = TextEditingController(
    text: _list?.name ?? widget.listName,
  );
  final FocusNode _nameFocus = FocusNode();
  bool _leaving = false;

  ShoppingListModel? get _list {
    final lists = ref.read(allListsSourceProvider).valueOrNull;
    if (lists == null) return null;
    for (final l in lists) {
      if (l.id == widget.listId) return l;
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    _nameFocus.addListener(() {
      if (!_nameFocus.hasFocus) _saveName();
    });
    if (widget.focusName) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _nameFocus.requestFocus();
        _name.selection = TextSelection(
          baseOffset: 0,
          extentOffset: _name.text.length,
        );
      });
    }
  }

  @override
  void dispose() {
    _nameFocus.dispose();
    _name.dispose();
    super.dispose();
  }

  String get _currentName => _list?.name ?? widget.listName;

  Future<void> _saveName() async {
    final name = _name.text.trim();
    final old = _currentName;
    if (name.isEmpty) {
      _name.text = old;
      return;
    }
    if (name == old || _leaving) return;
    try {
      await ref.read(listActionsProvider).rename(widget.listId, name);
    } catch (e) {
      debugPrint('❌ [LIST_INFO] Failed to rename list: $e');
      if (!mounted) return;
      _name.text = old;
      _failed();
    }
  }

  Future<void> _setColor(ListPaletteColor color) async {
    try {
      await ref.read(listActionsProvider).setColor(widget.listId, color.hex);
    } catch (e) {
      debugPrint('❌ [LIST_INFO] Failed to save colour: $e');
      _failed();
    }
  }

  void _failed() {
    AvoHaptics.error();
    if (!mounted) return;
    AvoToast.show(context, message: context.tr('action_failed'));
  }

  void _openOrder() {
    Navigator.of(context).push<bool>(
      CupertinoPageRoute(
        builder: (_) => CategoryOrderScreen(
          listId: widget.listId,
          listName: _currentName,
        ),
      ),
    );
  }

  void _openChanges() {
    Navigator.of(context).push<void>(
      CupertinoPageRoute(
        builder: (_) => ListActivitiesScreen(
          listId: widget.listId,
          listName: _currentName,
        ),
      ),
    );
  }

  void _invite() => showShareListDialog(
    context,
    ref,
    listId: widget.listId,
    listName: _currentName,
  );

  Future<void> _removeMember(ListMember member) async {
    final name = memberName(context, member);
    final confirmed = await showAvoConfirm(
      context,
      title: context.tr('list_ov_remove_title', params: {'name': name}),
      message: context.tr(
        'list_ov_remove_message',
        params: {'name': name, 'list': _currentName},
      ),
      confirmLabel: context.tr('list_ov_remove'),
    );
    if (!confirmed || !mounted) return;
    try {
      await ref
          .read(listActionsProvider)
          .removeMember(widget.listId, member.userId);
      ref.invalidate(listMembersProvider(widget.listId));
    } catch (e) {
      debugPrint('❌ [LIST_INFO] Failed to remove member: $e');
      _failed();
    }
  }

  void _memberMenu(BuildContext anchor, ListMember member) {
    final offline = ref.read(isOfflineProvider);
    showAvoMenu(
      anchor,
      semanticLabel: memberName(context, member),
      items: [
        AvoMenuItem(
          label: context.tr('list_ov_remove'),
          destructive: true,
          enabled: !offline,
          subtitle: offline ? context.tr('common_needs_connection') : null,
          onSelected: () => _removeMember(member),
        ),
      ],
    );
  }

  /// Leaves the screen after the list is gone and shows [message].
  void _closeAfterRemoval(String message) {
    final router = GoRouter.maybeOf(context);
    final navigator = Navigator.of(context);
    final toastContext = navigator.context;
    if (navigator.canPop()) navigator.pop();
    router?.go(RoutePaths.lists);
    if (toastContext.mounted) AvoToast.show(toastContext, message: message);
  }

  Future<void> _delete(ShoppingListModel? list) async {
    final total = list?.itemCount ?? 0;
    final name = _currentName;
    final confirmed = await showAvoConfirm(
      context,
      title: context.tr('list_ov_delete_title', params: {'name': name}),
      message: total > 0
          ? context.tr('list_ov_delete_message_items', params: {'n': '$total'})
          : context.tr('list_ov_delete_message'),
      confirmLabel: context.tr('list_ov_delete'),
    );
    if (!confirmed || !mounted) return;
    final message = context.tr('list_ov_deleted', params: {'name': name});
    _leaving = true;
    try {
      await ref.read(listActionsProvider).deleteList(widget.listId);
      await _unpinIfPinned();
      if (mounted) _closeAfterRemoval(message);
    } catch (e) {
      _leaving = false;
      debugPrint('❌ [LIST_INFO] Failed to delete list: $e');
      _failed();
    }
  }

  Future<void> _leave() async {
    final name = _currentName;
    final confirmed = await showAvoConfirm(
      context,
      title: context.tr('list_ov_leave_title', params: {'name': name}),
      message: context.tr('list_ov_leave_message'),
      confirmLabel: context.tr('list_ov_leave'),
    );
    if (!confirmed || !mounted) return;
    final message = context.tr('list_ov_left', params: {'name': name});
    _leaving = true;
    try {
      await ref.read(listActionsProvider).leaveList(widget.listId);
      await _unpinIfPinned();
      if (mounted) _closeAfterRemoval(message);
    } catch (e) {
      _leaving = false;
      debugPrint('❌ [LIST_INFO] Failed to leave list: $e');
      _failed();
    }
  }

  Future<void> _unpinIfPinned() async {
    if (ref.read(pinnedListProvider).listId == widget.listId) {
      await ref.read(pinnedListProvider.notifier).pin(null);
    }
  }

  String? _createdLine(
    BuildContext context,
    ShoppingListModel? list,
    List<ListMember> members,
  ) {
    if (list == null) return null;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final date = DateFormat.MMMd(locale).format(list.createdAt.toLocal());
    ListMember? owner;
    for (final m in members) {
      if (m.userId == list.ownerId) owner = m;
    }
    if (owner == null || owner.name.isEmpty) {
      return context.tr('list_ov_created_since', params: {'date': date});
    }
    return context.tr(
      'list_ov_created_by',
      params: {'name': owner.name, 'date': date},
    );
  }

  @override
  Widget build(BuildContext context) {
    final lists = ref.watch(allListsSourceProvider).valueOrNull;
    ShoppingListModel? list;
    for (final l in lists ?? const <ShoppingListModel>[]) {
      if (l.id == widget.listId) list = l;
    }
    final userId = ref.watch(authUserIdProvider);
    final membersValue = ref.watch(listMembersProvider(widget.listId));
    final members = membersValue.valueOrNull ?? const <ListMember>[];
    final offline = ref.watch(isOfflineProvider);
    final pinned = ref.watch(pinnedListProvider).listId == widget.listId;
    final offersOn = ref.watch(offersAvailableProvider);
    final offersHidden = ref.watch(offersHiddenForListProvider(widget.listId));
    final changes = bundleChanges(
      ref.watch(listChangesProvider(widget.listId)).valueOrNull ?? const [],
    );
    final now = DateTime.now();

    ListMember? ownerMember;
    for (final m in members) {
      if (m.isOwner) ownerMember = m;
    }
    final ownerId = widget.ownerId ?? list?.ownerId ?? ownerMember?.userId;
    final creator = userId != null && ownerId == userId;

    // Keep the field in step with renames from elsewhere while not editing.
    ref.listen<AsyncValue<List<ShoppingListModel>>>(allListsSourceProvider, (
      _,
      next,
    ) {
      for (final l in next.valueOrNull ?? const <ShoppingListModel>[]) {
        if (l.id != widget.listId) continue;
        if (!_nameFocus.hasFocus && _name.text != l.name) _name.text = l.name;
      }
    });

    final route = ModalRoute.of(context);
    final cover = route is PageRoute && route.fullscreenDialog;
    final color = list == null
        ? kListPalette.first.resolve(context)
        : listDisplayColor(context, list);
    final photo = list == null ? null : listCoverUrl(list);

    final memberRows = <Widget>[
      for (final m in members)
        Builder(
          builder: (anchor) {
            final removable = creator && m.userId != userId && !m.isOwner;
            return MemberRow(
              member: m,
              currentUserId: userId,
              onLongPress: removable ? () => _memberMenu(anchor, m) : null,
              semanticActions: removable && !offline
                  ? {context.tr('list_ov_remove'): () => _removeMember(m)}
                  : const {},
            );
          },
        ),
      ListInfoActionRow(
        label: context.tr('list_ov_invite'),
        icon: AvoIcons.people,
        onTap: _invite,
      ),
    ];

    final destructive = creator
        ? context.tr('list_ov_delete_list')
        : context.tr('list_ov_leave_list');
    Widget destructiveRow = DestructiveRow(
      title: destructive,
      onTap: creator ? () => _delete(list) : _leave,
    );
    if (offline) {
      destructiveRow = Semantics(
        container: true,
        button: true,
        enabled: false,
        label: destructive,
        child: ExcludeSemantics(
          child: IgnorePointer(
            child: Opacity(opacity: _kDisabledOpacity, child: destructiveRow),
          ),
        ),
      );
    }

    return FullScreenEditor(
      title: context.tr('list_ov_info_title'),
      leading: cover ? EditorLeading.close : EditorLeading.back,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          ListInfoHeader(
            color: color,
            coverUrl: photo,
            caption: _createdLine(context, list, members),
            field: ListNameField(
              controller: _name,
              focusNode: _nameFocus,
              onSubmitted: (_) => _nameFocus.unfocus(),
            ),
          ),
          InsetSection(
            header: context.tr('list_ov_color'),
            children: [
              ListColorPicker(
                selectedId: list == null ? null : paletteColorOf(list)?.id,
                photoUrl: photo,
                onPhotoSelected: () {},
                onSelected: _setColor,
              ),
            ],
          ),
          InsetSection(
            header: context.tr('list_ov_section_store'),
            headerTrailing: StoreChip(listId: widget.listId),
            children: [
              NavRow(title: context.tr('list_ov_order'), onTap: _openOrder),
              if (offersOn)
                ToggleRow(
                  title: context.tr('list_ov_offers_toggle'),
                  value: !offersHidden,
                  onChanged: (on) =>
                      setOffersHiddenForList(ref, widget.listId, !on),
                ),
            ],
          ),
          InsetSection(
            header: membersValue.hasValue
                ? context.tr(
                    'list_ov_members_count',
                    params: {'n': '${members.length}'},
                  )
                : context.tr('members'),
            children: memberRows,
          ),
          if (membersValue.hasError)
            Padding(
              padding: const EdgeInsets.only(top: AvoSpacing.s),
              child: StatusRow(
                kind: StatusKind.sectionError,
                text: context.tr('list_ov_members_error'),
                actionLabel: context.tr('common_try_again'),
                onAction: () =>
                    ref.invalidate(listMembersProvider(widget.listId)),
              ),
            ),
          const SizedBox(height: AvoSpacing.section),
          InsetSection(
            footer: context.tr('list_ov_pin_footer'),
            children: [
              ToggleRow(
                title: context.tr('list_ov_pin'),
                value: pinned,
                onChanged: (on) => ref
                    .read(pinnedListProvider.notifier)
                    .pin(on ? widget.listId : null),
              ),
            ],
          ),
          InsetSection(
            header: context.tr('list_ov_section_changes'),
            headerTrailing: changes.isEmpty
                ? null
                : AppButton.plain(
                    label: context.tr('list_ov_show_all'),
                    onPressed: _openChanges,
                  ),
            children: changes.isEmpty
                ? [
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AvoSpacing.l,
                        vertical: AvoSpacing.m,
                      ),
                      child: Text(
                        context.tr('list_ov_no_changes'),
                        style: context.text(
                          AvoTextStyle.body,
                          color: context.colors.secondaryLabel,
                        ),
                      ),
                    ),
                  ]
                : [
                    for (final c in changes.take(kListInfoChangeCount))
                      ListChangeRow(
                        change: c,
                        currentUserId: userId,
                        now: now,
                      ),
                  ],
          ),
          const SizedBox(height: AvoSpacing.section),
          InsetSection(
            footer: offline
                ? context.tr('common_needs_connection')
                : (creator ? context.tr('list_ov_delete_footer') : null),
            children: [destructiveRow],
          ),
        ],
      ),
    );
  }
}
