import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shoply/core/constants/categories.dart';
import 'package:shoply/core/design/design.dart';
import 'package:shoply/core/localization/localization_helper.dart';
import 'package:shoply/core/utils/diet_checker.dart';
import 'package:shoply/core/utils/item_input_parser.dart';
import 'package:shoply/data/models/custom_category.dart';
import 'package:shoply/data/models/shopping_item_model.dart';
import 'package:shoply/data/services/category_order_service.dart';
import 'package:shoply/data/services/connectivity_service.dart';
import 'package:shoply/data/services/supabase_service.dart';
import 'package:shoply/presentation/screens/lists/widgets/item_editor_parts.dart';
import 'package:shoply/presentation/state/auth_provider.dart';
import 'package:shoply/presentation/state/items_provider.dart';
import 'package:shoply/presentation/state/lists_provider.dart';
import 'package:shoply/presentation/widgets/design/app_button.dart';
import 'package:shoply/presentation/widgets/design/avo_icons.dart';
import 'package:shoply/presentation/widgets/design/avo_menu.dart';
import 'package:shoply/presentation/widgets/design/full_screen_editor.dart';
import 'package:shoply/presentation/widgets/design/inset_section.dart';
import 'package:shoply/presentation/widgets/design/item_row.dart'
    show AdaptiveTrailing;
import 'package:shoply/presentation/widgets/design/settings_rows.dart';
import 'package:shoply/presentation/widgets/design/status_row.dart';
import 'package:shoply/presentation/widgets/design/undo_toast.dart';
import 'package:shoply/presentation/widgets/slots/b_slots.dart';

/// Opens one item full screen to edit it (D2-Artikel), or to add one with
/// [prefill] when [item] is null. The one entry point for every screen.
///
/// Editing pushes from the right with a back chevron (D2); adding slides up
/// as a cover with an X. [prefill] is read like the add field ("2 Milch"
/// becomes Milch, quantity 2). The future completes when the screen closes.
Future<void> openItemEditor(
  BuildContext context, {
  required String listId,
  ShoppingItemModel? item,
  String prefill = '',
}) {
  // The composer keyboard closes before the editor slides in.
  FocusManager.instance.primaryFocus?.unfocus();
  return pushFullScreenEditor<void>(
    context,
    (_) => ItemEditorScreen(listId: listId, item: item, prefill: prefill),
    cover: item == null,
  );
}

/// An item that is not on a list yet (a row of the import review).
@immutable
class ItemDraft {
  /// Creates a draft.
  const ItemDraft({
    required this.name,
    this.quantity = 1,
    this.unit,
    this.categoryId,
  });

  /// The name as typed.
  final String name;

  /// Quantity, > 0.
  final double quantity;

  /// Unit id; null means pieces.
  final String? unit;

  /// Language-agnostic category id; null lets the app categorise.
  final String? categoryId;
}

/// Edits [draft] in the item full screen without saving anything; resolves
/// with the changed draft on "Fertig", or null when closed.
Future<ItemDraft?> openItemDraftEditor(
  BuildContext context, {
  required String listId,
  required ItemDraft draft,
}) {
  FocusManager.instance.primaryFocus?.unfocus();
  return pushFullScreenEditor<ItemDraft>(
    context,
    (_) => ItemEditorScreen(listId: listId, draft: draft),
    cover: false,
  );
}

/// Display name of the person who added an item (`users.display_name`),
/// null when unknown. Overridden in tests.
final itemAuthorNameProvider = FutureProvider.autoDispose
    .family<String?, String>((ref, userId) async {
      try {
        final row = await SupabaseService.instance.client
            .from('users')
            .select('display_name')
            .eq('id', userId)
            .maybeSingle();
        final name = row?['display_name'];
        return name is String && name.trim().isNotEmpty ? name.trim() : null;
      } catch (e) {
        debugPrint('⚠️ [ITEM_EDITOR] Author not loaded: $e');
        return null;
      }
    });

/// Name of the list [listId] from the loaded lists, null while unknown.
final itemEditorListNameProvider = Provider.autoDispose.family<String?, String>(
  (ref, listId) {
    final lists = ref.watch(listsNotifierProvider).valueOrNull;
    if (lists == null) return null;
    for (final list in lists) {
      if (list.id == listId) return list.name;
    }
    return null;
  },
);

/// The custom categories of [listId] (this device only).
final itemEditorCustomCategoriesProvider = FutureProvider.autoDispose
    .family<List<CustomCategory>, String>((ref, listId) async {
      if (listId.isEmpty) return const [];
      try {
        return await CategoryOrderService().getCustomCategories(listId);
      } catch (e) {
        debugPrint('⚠️ [ITEM_EDITOR] Custom categories not loaded: $e');
        return const [];
      }
    });

enum _Mode { edit, add, draft }

/// The values the screen edits, to tell whether anything changed.
@immutable
class _Values {
  const _Values({
    required this.name,
    required this.note,
    required this.quantity,
    required this.unit,
    required this.category,
  });

  final String name;
  final String note;
  final double quantity;
  final String? unit;
  final String? category;

  @override
  bool operator ==(Object other) =>
      other is _Values &&
      other.name == name &&
      other.note == note &&
      other.quantity == quantity &&
      other.unit == unit &&
      other.category == category;

  @override
  int get hashCode => Object.hash(name, note, quantity, unit, category);
}

/// The item full screen (D2-Artikel): photo and editable name at the top,
/// quantity, unit and category, Teil B's offer card, note and "added by",
/// "Artikel löschen" at the end; "Fertig" saves and closes.
///
/// Three modes: edit [item], add a new item to [listId] (item null, from
/// [prefill]), or edit an import [draft] without saving.
class ItemEditorScreen extends ConsumerStatefulWidget {
  /// Creates the screen; see [openItemEditor].
  const ItemEditorScreen({
    super.key,
    required this.listId,
    this.item,
    this.prefill = '',
    this.draft,
  }) : assert(item == null || draft == null);

  /// The list the item is (or will be) on.
  final String listId;

  /// The item to edit; null to add one.
  final ShoppingItemModel? item;

  /// Text for a new item, parsed like the add field.
  final String prefill;

  /// An import row to edit; "Fertig" pops it instead of saving.
  final ItemDraft? draft;

  @override
  ConsumerState<ItemEditorScreen> createState() => _ItemEditorScreenState();
}

class _ItemEditorScreenState extends ConsumerState<ItemEditorScreen> {
  final TextEditingController _name = TextEditingController();
  final TextEditingController _note = TextEditingController();
  final GlobalKey _unitKey = GlobalKey();
  final GlobalKey _categoryKey = GlobalKey();

  late double _quantity;
  String? _unit;
  String? _category;
  _Values? _initial;

  bool _saving = false;
  bool _failed = false;

  _Mode get _mode => widget.draft != null
      ? _Mode.draft
      : widget.item != null
      ? _Mode.edit
      : _Mode.add;

  @override
  void initState() {
    super.initState();
    final item = widget.item;
    final draft = widget.draft;
    if (item != null) {
      _name.text = item.name;
      _note.text = item.notes ?? '';
      _quantity = item.quantity > 0 ? item.quantity : 1;
      _unit = ItemUnits.normalize(item.unit);
      _category = item.categoryId ?? item.category;
    } else if (draft != null) {
      _name.text = draft.name;
      _quantity = draft.quantity > 0 ? draft.quantity : 1;
      _unit = ItemUnits.normalize(draft.unit);
      _category = draft.categoryId;
    } else {
      _quantity = 1;
    }
    _name.addListener(_changed);
    _note.addListener(_changed);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initial != null) return;
    // A new item reads its text like the add field ("2 Milch").
    if (_mode == _Mode.add && widget.prefill.trim().isNotEmpty) {
      final lang = Localizations.localeOf(context).languageCode;
      final parsed = parseSingleItem(widget.prefill, lang: lang);
      if (parsed != null) {
        _name.text = parsed.name;
        _quantity = parsed.quantity;
        _unit = ItemUnits.normalize(parsed.unit);
        _note.text = parsed.note ?? '';
      } else {
        _name.text = widget.prefill.trim();
      }
    }
    _initial = _values;
  }

  @override
  void dispose() {
    _name.dispose();
    _note.dispose();
    super.dispose();
  }

  void _changed() => setState(() => _failed = false);

  _Values get _values => _Values(
    name: _name.text.trim(),
    note: _note.text.trim(),
    quantity: _quantity,
    unit: _unit,
    category: _category,
  );

  bool get _dirty => _initial != null && _values != _initial;

  /// The item as it is on the list now; null once someone else deleted it.
  ShoppingItemModel? _live(List<ShoppingItemModel>? items) {
    final item = widget.item!;
    if (items == null) return item;
    for (final i in items) {
      if (i.id == item.id) return i;
    }
    // A row that was just added has a placeholder id until the server
    // answers; it is not gone, only renamed.
    if (item.id.startsWith('pending')) {
      for (final i in items.reversed) {
        if (i.name == item.name) return i;
      }
      return item;
    }
    return null;
  }

  String _lang(BuildContext context) =>
      Localizations.localeOf(context).languageCode;

  String _categoryName(
    BuildContext context,
    String? id,
    List<CustomCategory> custom,
  ) {
    if (id == null || id.isEmpty) return context.tr('list_item_category_auto');
    for (final c in custom) {
      if (c.id == id) return c.name;
    }
    return Categories.getById(id).getName(_lang(context));
  }

  // ---------------------------------------------------------------- actions

  Future<void> _done({required bool gone}) async {
    final name = _name.text.trim();
    if (name.isEmpty || _saving) return;
    final navigator = Navigator.of(context);

    if (_mode == _Mode.draft) {
      navigator.pop(
        ItemDraft(
          name: name,
          quantity: _quantity,
          unit: _unit,
          categoryId: _category,
        ),
      );
      return;
    }
    if (_mode == _Mode.edit && !gone && !_dirty) {
      navigator.pop();
      return;
    }

    setState(() {
      _saving = true;
      _failed = false;
    });
    final notifier = ref.read(itemsNotifierProvider(widget.listId).notifier);
    final note = _note.text.trim();
    try {
      final item = widget.item;
      if (item != null && !gone) {
        await notifier.updateItem(item.id, _changes(item));
      } else {
        await notifier.addItem(
          name: name,
          quantity: _quantity,
          unit: _unit,
          category: _category,
          notes: note.isEmpty ? null : note,
          isDietWarning: _dietWarning(name),
          barcode: item?.barcode,
          price: item?.price,
          priceCurrency: item?.priceCurrency,
          priceRetailer: item?.priceRetailer,
          priceUnit: item?.priceUnit,
          priceOldValue: item?.priceOldValue,
          // Quantity and unit are set in the screen; no second parse.
          autoParse: false,
        );
      }
      if (!mounted) return;
      navigator.pop();
    } catch (e) {
      debugPrint('❌ [ITEM_EDITOR] Save failed: $e');
      if (!mounted) return;
      unawaited(AvoHaptics.error());
      setState(() {
        _saving = false;
        _failed = true;
      });
    }
  }

  /// The columns that changed against [item].
  Map<String, dynamic> _changes(ShoppingItemModel item) {
    final now = _values;
    final start = _initial!;
    return {
      if (now.name != start.name) 'name': now.name,
      if (now.quantity != start.quantity) 'quantity': now.quantity,
      if (now.unit != start.unit) 'unit': now.unit,
      if (now.note != start.note) 'notes': now.note.isEmpty ? null : now.note,
      if (now.category != start.category) 'category_id': now.category,
    };
  }

  bool _dietWarning(String name) {
    final user = ref.read(currentUserProvider).valueOrNull;
    return user != null &&
        DietChecker.checkDietWarning(name, user.dietPreferences);
  }

  void _delete() {
    final item = widget.item;
    if (item == null || _saving) return;
    final notifier = ref.read(itemsNotifierProvider(widget.listId).notifier);
    final root = Navigator.of(context, rootNavigator: true).context;
    final deleted = context.tr(
      'list_item_deleted',
      params: {'name': item.name},
    );
    final failed = context.tr(
      'list_item_delete_failed',
      params: {'name': item.name},
    );
    final undo = context.tr('common_undo');

    // Gone at once, with undo instead of a question (Konzept 11 §4).
    AvoToast.show(
      context,
      message: deleted,
      actionLabel: undo,
      onAction: () => unawaited(_restore(notifier, item)),
    );
    Navigator.of(context).pop();
    unawaited(
      notifier.deleteItem(item.id).catchError((Object e) {
        debugPrint('❌ [ITEM_EDITOR] Delete failed: $e');
        if (root.mounted) AvoToast.show(root, message: failed);
      }),
    );
  }

  static Future<void> _restore(
    ItemsNotifier notifier,
    ShoppingItemModel item,
  ) async {
    try {
      await notifier.addItem(
        name: item.name,
        quantity: item.quantity,
        unit: item.unit,
        category: item.categoryId ?? item.category,
        notes: item.notes,
        isDietWarning: item.isDietWarning,
        barcode: item.barcode,
        price: item.price,
        priceCurrency: item.priceCurrency,
        priceRetailer: item.priceRetailer,
        priceUnit: item.priceUnit,
        priceOldValue: item.priceOldValue,
        autoParse: false,
      );
    } catch (e) {
      debugPrint('❌ [ITEM_EDITOR] Undo delete failed: $e');
    }
  }

  void _pickUnit() {
    final current = _unit ?? ItemUnits.pieces;
    unawaited(
      showAvoMenu(
        context,
        anchorKey: _unitKey,
        semanticLabel: context.tr('list_item_unit_others'),
        items: [
          for (final unit in ItemUnits.others)
            AvoMenuItem(
              label: ItemUnits.longLabel(context, unit),
              checked: unit == current,
              onSelected: () => _setUnit(unit),
            ),
        ],
      ),
    );
  }

  void _setUnit(String? unit) {
    final next = ItemUnits.normalize(unit);
    if (next == _unit) return;
    setState(() {
      _unit = next;
      _failed = false;
    });
  }

  void _pickCategory(List<CustomCategory> custom) {
    final lang = _lang(context);
    final current = _category;
    unawaited(
      showAvoMenu(
        context,
        anchorKey: _categoryKey,
        semanticLabel: context.tr('category'),
        items: [
          if (_mode != _Mode.edit) ...[
            AvoMenuItem(
              label: context.tr('list_item_category_auto'),
              checked: current == null,
              onSelected: () => _setCategory(null),
            ),
            const AvoMenuDivider(),
          ],
          for (final c in custom)
            AvoMenuItem(
              label: c.name,
              checked: c.id == current,
              onSelected: () => _setCategory(c.id),
            ),
          if (custom.isNotEmpty) const AvoMenuDivider(),
          for (final c in Categories.all)
            AvoMenuItem(
              label: c.getName(lang),
              checked: c.id == current,
              onSelected: () => _setCategory(c.id),
            ),
        ],
      ),
    );
  }

  void _setCategory(String? id) {
    if (id == _category) return;
    setState(() {
      _category = id;
      _failed = false;
    });
  }

  // ------------------------------------------------------------------ build

  @override
  Widget build(BuildContext context) {
    final mode = _mode;
    final item = widget.item;
    final listId = widget.listId;

    final live = mode == _Mode.edit
        ? _live(ref.watch(itemsNotifierProvider(listId)).valueOrNull)
        : null;
    final gone = mode == _Mode.edit && live == null;
    final offline = mode != _Mode.draft && ref.watch(isOfflineProvider);
    final listName = listId.isEmpty
        ? null
        : ref.watch(itemEditorListNameProvider(listId));
    final custom =
        ref.watch(itemEditorCustomCategoriesProvider(listId)).valueOrNull ??
        const <CustomCategory>[];

    final name = _name.text.trim();
    final edit = mode == _Mode.edit;
    final String? doneLabel = switch (mode) {
      _Mode.add => context.tr('list_item_add'),
      _Mode.edit when gone => context.tr('list_item_readd'),
      _ => null,
    };

    final status = _failed
        ? StatusRow(
            kind: StatusKind.failed,
            text: context.tr('list_item_save_failed'),
            actionLabel: context.tr('common_try_again'),
            onAction: () => _done(gone: gone),
          )
        : gone
        ? StatusRow(
            kind: StatusKind.sectionError,
            text: context.tr('list_item_gone'),
          )
        : offline
        ? StatusRow(
            kind: StatusKind.offline,
            text: context.tr('list_item_offline'),
          )
        : null;

    final subtitle = [
      if (_category != null) _categoryName(context, _category, custom),
      if (listName != null)
        context.tr('list_item_in_list', params: {'list': listName}),
    ].join(' · ');

    final imageItem = _imageItem(live ?? item, name);

    return FullScreenEditor(
      title: context.tr(
        mode == _Mode.add ? 'list_item_new_title' : 'list_item_title',
      ),
      leading: mode == _Mode.add ? EditorLeading.close : EditorLeading.back,
      leadingLabel: mode != _Mode.add && listName != null
          ? context.tr('common_back_to', params: {'title': listName})
          : null,
      onDone: () => _done(gone: gone),
      doneLabel: doneLabel,
      doneEnabled: name.isNotEmpty,
      working: _saving,
      workingLabel: context.tr('list_item_saving'),
      dirty: _dirty,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (status != null)
            Padding(
              padding: const EdgeInsets.only(bottom: AvoSpacing.m),
              child: status,
            ),
          _Header(
            image: ArticleImage(
              item: imageItem,
              size: AvoSizes.thumbLarge,
              radius: AvoRadii.imageLarge,
            ),
            credit: ArticleImageCredit(
              item: imageItem,
              size: AvoSizes.thumbLarge,
            ),
            name: _name,
            subtitle: subtitle.isEmpty ? null : subtitle,
            autofocus: mode == _Mode.add && name.isEmpty,
            onSubmitted: () => _done(gone: gone),
          ),
          const SizedBox(height: AvoSpacing.xxl),
          InsetSection(
            children: [
              ItemControlRow(
                label: context.tr('quantity'),
                control: ItemQuantityControl(
                  quantity: _quantity,
                  unit: _unit,
                  semanticLabel: context.tr('quantity'),
                  onChanged: (q) => setState(() {
                    _quantity = q;
                    _failed = false;
                  }),
                ),
              ),
              KeyedSubtree(
                key: _unitKey,
                child: ItemControlRow(
                  label: context.tr('unit'),
                  controlWidth: compactSegmentsWidth(
                    context,
                    ItemUnitControl.labelsFor(context, _unit),
                  ),
                  stretchWhenStacked: true,
                  control: ItemUnitControl(
                    unit: _unit,
                    semanticLabel: context.tr('unit'),
                    onChanged: _setUnit,
                    onMore: _pickUnit,
                  ),
                ),
              ),
              KeyedSubtree(
                key: _categoryKey,
                child: NavRow(
                  title: context.tr('category'),
                  value: _categoryName(context, _category, custom),
                  onTap: () => _pickCategory(custom),
                ),
              ),
            ],
          ),
          if (edit && live != null)
            CollapsingPadding(
              padding: const EdgeInsetsDirectional.only(top: AvoSpacing.l),
              child: ItemOfferCard(listId: listId, item: live),
            ),
          if (mode != _Mode.draft) ...[
            const SizedBox(height: AvoSpacing.l),
            InsetSection(
              children: [
                _NoteRow(controller: _note),
                if (edit) _AddedByRow(item: item!),
              ],
            ),
          ],
          if (edit && !gone)
            Padding(
              padding: const EdgeInsets.only(top: AvoSpacing.m),
              child: Center(
                child: AppButton.destructive(
                  label: context.tr('list_item_delete'),
                  icon: const AvoIcon(AvoIcons.trash),
                  onPressed: _saving ? null : _delete,
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// The item [ArticleImage] shows: the saved one, or for a new item or a
  /// draft one built from what is typed.
  ShoppingItemModel _imageItem(ShoppingItemModel? item, String name) {
    if (item != null) return item;
    final now = DateTime.now();
    return ShoppingItemModel(
      id: 'draft',
      listId: widget.listId,
      name: name,
      quantity: _quantity,
      unit: _unit,
      category: _category,
      categoryId: _category,
      createdAt: now,
      updatedAt: now,
    );
  }
}

/// Photo 88 and the editable name 28/34 bold, with "Kategorie · in Liste"
/// under it (D2-Artikel header). The photo is left out from AX1 on.
class _Header extends StatelessWidget {
  const _Header({
    required this.image,
    required this.credit,
    required this.name,
    required this.subtitle,
    required this.autofocus,
    required this.onSubmitted,
  });

  final Widget image;

  /// "Foto: Open Food Facts, CC BY-SA" under the photo (Teil B); nothing
  /// for own illustrations.
  final Widget credit;
  final TextEditingController name;
  final String? subtitle;
  final bool autofocus;
  final VoidCallback onSubmitted;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final style = context.text(AvoTextStyle.title1);
    final sub = subtitle;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AvoSpacing.screen),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          _headerRow(context, colors, style, sub),
          CollapsingPadding(
            padding: const EdgeInsetsDirectional.only(top: AvoSpacing.xs),
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: credit,
            ),
          ),
        ],
      ),
    );
  }

  Widget _headerRow(
    BuildContext context,
    AvoColors colors,
    TextStyle style,
    String? sub,
  ) {
    return Row(
      children: [
        CollapsingPadding(
          padding: const EdgeInsetsDirectional.only(end: AvoSpacing.l),
          child: image,
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              ItemTextField(
                controller: name,
                autofocus: autofocus,
                style: style,
                placeholder: context.tr('list_item_name_placeholder'),
                semanticLabel: context.tr('list_item_name_label'),
                onSubmitted: onSubmitted,
              ),
              if (sub != null)
                Padding(
                  padding: const EdgeInsets.only(top: AvoSpacing.xxs),
                  child: Text(
                    sub,
                    style: context.text(
                      AvoTextStyle.subhead,
                      color: colors.secondaryLabel,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// "Notiz" with the field at the end (D2); below the label from AX1 on.
class _NoteRow extends StatelessWidget {
  const _NoteRow({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    final label = context.tr('list_item_note');
    final ax = context.isAccessibilityText;
    final field = ItemTextField(
      controller: controller,
      style: context.text(AvoTextStyle.body),
      placeholder: context.tr('list_item_note_placeholder'),
      semanticLabel: label,
      padding: const EdgeInsets.symmetric(vertical: AvoSpacing.m),
      textAlign: ax ? TextAlign.start : TextAlign.end,
    );
    final title = ExcludeSemantics(
      child: Text(label, style: context.text(AvoTextStyle.body)),
    );
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: ItemControlRow.minHeight),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AvoSpacing.l),
        child: ax
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: AvoSpacing.m),
                  title,
                  field,
                ],
              )
            : Row(
                children: [
                  title,
                  const SizedBox(width: AvoSpacing.m),
                  Expanded(child: field),
                ],
              ),
      ),
    );
  }
}

/// "Hinzugefügt von Lena · Dienstag" (D2); not tappable.
class _AddedByRow extends ConsumerWidget {
  const _AddedByRow({required this.item});

  final ShoppingItemModel item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final when = itemAddedWhen(context, item.createdAt);
    final addedBy = item.addedBy;
    String? who;
    if (addedBy != null && addedBy.isNotEmpty) {
      if (addedBy == ref.watch(authUserIdProvider)) {
        who = context.tr('you');
      } else {
        // Until the name arrives the row shows the day only, no spinner.
        who = ref.watch(itemAuthorNameProvider(addedBy)).valueOrNull;
      }
    }
    final title = context.tr('added_by');
    final value = who == null ? when : '$who · $when';
    final colors = context.colors;
    return Semantics(
      container: true,
      label: title,
      value: value,
      child: ExcludeSemantics(
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minHeight: ItemControlRow.minHeight,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AvoSpacing.l,
              vertical: AvoSpacing.m,
            ),
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              heightFactor: 1,
              child: AdaptiveTrailing(
                stacked: context.isAccessibilityText,
                runGap: AvoSpacing.xxs,
                trailing: Text(
                  value,
                  textAlign: context.isAccessibilityText
                      ? TextAlign.start
                      : TextAlign.end,
                  style: context.text(
                    AvoTextStyle.body,
                    color: colors.secondaryLabel,
                  ),
                ),
                child: Text(title, style: context.text(AvoTextStyle.body)),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
