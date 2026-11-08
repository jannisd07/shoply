import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/semantics.dart' show CustomSemanticsAction;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shoply/core/constants/categories.dart';
import 'package:shoply/core/design/design.dart';
import 'package:shoply/core/localization/localization_helper.dart';
import 'package:shoply/data/models/shopping_item_model.dart';
import 'package:shoply/data/models/shopping_list_model.dart';
import 'package:shoply/data/repositories/item_repository.dart';
import 'package:shoply/data/services/connectivity_service.dart';
import 'package:shoply/data/services/list_import_service.dart';
import 'package:shoply/presentation/screens/lists/item_editor_screen.dart';
import 'package:shoply/presentation/screens/lists/widgets/item_editor_parts.dart';
import 'package:shoply/presentation/state/items_provider.dart';
import 'package:shoply/presentation/state/lists_provider.dart';
import 'package:shoply/presentation/widgets/design/app_button.dart';
import 'package:shoply/presentation/widgets/design/avo_menu.dart';
import 'package:shoply/presentation/widgets/design/check_circle.dart';
import 'package:shoply/presentation/widgets/design/full_screen_editor.dart';
import 'package:shoply/presentation/widgets/design/inset_section.dart';
import 'package:shoply/presentation/widgets/design/item_row.dart'
    show AdaptiveTrailing;
import 'package:shoply/presentation/widgets/design/settings_rows.dart';
import 'package:shoply/presentation/widgets/design/status_row.dart';
import 'package:shoply/presentation/widgets/design/undo_toast.dart';

// D2 list rows: at least 52 high, text 16 from the edge after the circle.
const double _rowMinHeight = 52; // D2
const double _rowVertical = AvoSpacing.s;
const double _textGap = AvoSpacing.m;

/// Results that came from pasted text, not from a photo (no photo note).
final Expando<bool> _pasted = Expando<bool>('pastedListImport');

/// Marks [result] as read from pasted text.
void markPastedImport(ListImportResult result) => _pasted[result] = true;

/// Checks the recognized items full screen ("14 Artikel erkannt", Konzept
/// 11 §3.3; a cover instead of the sheet).
///
/// Without [listId] it resolves with the items the person kept and the
/// caller adds them (the contract of the old sheet). With [listId] the
/// screen adds them itself in one batch (`ItemRepository.addItems`), shows
/// "13 Artikel hinzugefügt · Widerrufen" and resolves with the same items
/// for information only. Null when closed.
Future<List<ExtractedListItem>?> showImportReviewSheet(
  BuildContext context, {
  required ListImportResult result,
  String? listId,
}) {
  FocusManager.instance.primaryFocus?.unfocus();
  return pushFullScreenEditor<List<ExtractedListItem>>(
    context,
    (_) => ImportReviewScreen(result: result, listId: listId),
  );
}

/// The lists an import can go to; overridden in tests.
final importTargetListsProvider = Provider.autoDispose<List<ShoppingListModel>>(
  (ref) => ref.watch(listsNotifierProvider).valueOrNull ?? const [],
);

class _Row {
  _Row({required this.name}) : confidence = null;

  _Row.from(ExtractedListItem item)
    : name = item.name,
      quantity = item.quantity,
      unit = ItemUnits.normalize(item.unit),
      categoryId = item.categoryId,
      confidence = item.confidence;

  String name;
  double? quantity;
  String? unit;
  String? categoryId;
  final double? confidence;
  bool selected = true;

  /// Avo was unsure (below 0.75); the person should look at it.
  bool get unsure => confidence != null && confidence! < 0.75;

  ExtractedListItem toItem() => ExtractedListItem(
    name: name.trim(),
    quantity: quantity,
    unit: unit,
    confidence: confidence,
    categoryId: categoryId,
  );

  NewItem toNewItem() => NewItem(
    name: name.trim(),
    quantity: quantity ?? 1,
    unit: unit,
    category: categoryId,
  );
}

/// The review screen of [showImportReviewSheet].
class ImportReviewScreen extends ConsumerStatefulWidget {
  /// Creates the screen.
  const ImportReviewScreen({super.key, required this.result, this.listId});

  /// What was recognized.
  final ListImportResult result;

  /// Add to this list from the screen; null returns the items instead.
  final String? listId;

  @override
  ConsumerState<ImportReviewScreen> createState() => _ImportReviewScreenState();
}

class _ImportReviewScreenState extends ConsumerState<ImportReviewScreen> {
  late final List<_Row> _rows = [
    for (final item in widget.result.items)
      if (item.name.trim().isNotEmpty) _Row.from(item),
  ];
  late final List<String> _unparsed = [
    for (final line in widget.result.unparsedLines)
      if (line.trim().isNotEmpty) line.trim(),
  ];
  late String? _target = widget.listId;
  final GlobalKey _targetKey = GlobalKey();

  bool _dirty = false;
  bool _adding = false;
  bool _failed = false;

  int get _selectedCount =>
      _rows.where((r) => r.selected && r.name.trim().isNotEmpty).length;

  void _toggle(_Row row) => setState(() {
    row.selected = !row.selected;
    _dirty = true;
    _failed = false;
  });

  Future<void> _edit(_Row row) async {
    final draft = await openItemDraftEditor(
      context,
      listId: _target ?? '',
      draft: ItemDraft(
        name: row.name,
        quantity: row.quantity ?? 1,
        unit: row.unit,
        categoryId: row.categoryId,
      ),
    );
    if (draft == null || !mounted) return;
    setState(() {
      row
        ..name = draft.name
        ..quantity = draft.quantity
        ..unit = ItemUnits.normalize(draft.unit)
        ..categoryId = draft.categoryId
        ..selected = true;
      _dirty = true;
      _failed = false;
    });
  }

  Future<void> _takeOver(String line) async {
    final row = _Row(name: line);
    setState(() {
      _unparsed.remove(line);
      _rows.add(row);
      _dirty = true;
    });
    await _edit(row);
  }

  void _pickTarget(List<ShoppingListModel> lists) {
    unawaited(
      showAvoMenu(
        context,
        anchorKey: _targetKey,
        semanticLabel: context.tr('list_item_import_target'),
        items: [
          for (final list in lists)
            AvoMenuItem(
              label: list.name,
              checked: list.id == _target,
              onSelected: () => setState(() {
                if (list.id == _target) return;
                _target = list.id;
                _dirty = true;
                _failed = false;
              }),
            ),
        ],
      ),
    );
  }

  Future<void> _add() async {
    if (_adding) return;
    final kept = [
      for (final r in _rows)
        if (r.selected && r.name.trim().isNotEmpty) r,
    ];
    if (kept.isEmpty) return;
    final navigator = Navigator.of(context);
    final items = [for (final r in kept) r.toItem()];
    final target = _target;
    if (target == null) {
      navigator.pop(items);
      return;
    }

    setState(() {
      _adding = true;
      _failed = false;
    });
    final repository = ref.read(itemRepositoryProvider);
    final notifier = ref.read(itemsNotifierProvider(target).notifier);
    final added = context.tr(
      kept.length == 1
          ? 'list_item_import_added_one'
          : 'list_item_import_added',
      params: {'count': '${kept.length}'},
    );
    final undo = context.tr('common_undo');
    try {
      final result = await repository.addItems(target, [
        for (final r in kept) r.toNewItem(),
      ]);
      unawaited(notifier.loadItems());
      if (!mounted) return;
      // Routine, so no success moment; the rows grow in behind the cover.
      AvoToast.show(
        context,
        message: added,
        actionLabel: undo,
        onAction: () => unawaited(_undo(repository, notifier, result.token)),
      );
      navigator.pop(items);
    } catch (e) {
      debugPrint('❌ [LIST_IMPORT] Adding failed: $e');
      if (!mounted) return;
      unawaited(AvoHaptics.error());
      setState(() {
        _adding = false;
        _failed = true;
      });
    }
  }

  static Future<void> _undo(
    ItemRepository repository,
    ItemsNotifier notifier,
    String token,
  ) async {
    try {
      await repository.undoAddItems(token);
      await notifier.loadItems();
    } catch (e) {
      debugPrint('❌ [LIST_IMPORT] Undo failed: $e');
    }
  }

  /// Open items of the target list by name and unit, to say which rows
  /// add to an existing one.
  Set<String> _onList() {
    final target = _target;
    if (target == null) return const {};
    final items =
        ref.watch(itemsNotifierProvider(target)).valueOrNull ??
        const <ShoppingItemModel>[];
    return {
      for (final i in items)
        if (!i.isChecked) _key(i.name, i.unit),
    };
  }

  static String _key(String name, String? unit) =>
      '${name.trim().toLowerCase()}|${ItemUnits.normalize(unit) ?? ''}';

  @override
  Widget build(BuildContext context) {
    final target = _target;
    final lang = Localizations.localeOf(context).languageCode;
    final offline = target != null && ref.watch(isOfflineProvider);
    final lists = target == null
        ? const <ShoppingListModel>[]
        : ref.watch(importTargetListsProvider);
    final targetName = target == null
        ? null
        : ref.watch(itemEditorListNameProvider(target));
    final onList = _onList();
    final count = widget.result.items.length;
    final selected = _selectedCount;
    final photoNote = _pasted[widget.result] == true
        ? null
        : context.tr('list_item_import_photo_note');

    final status = _failed
        ? StatusRow(
            kind: StatusKind.failed,
            text: context.tr('list_item_import_add_failed'),
            actionLabel: context.tr('common_try_again'),
            onAction: _add,
          )
        : offline
        ? StatusRow(
            kind: StatusKind.offline,
            text: context.tr('list_item_import_offline'),
          )
        : null;

    return FullScreenEditor(
      title: count == 1
          ? context.tr('list_item_import_review_title_one')
          : context.tr(
              'list_item_import_review_title',
              params: {'count': '$count'},
            ),
      dirty: _dirty && !_adding,
      bottom: AppButton.primary(
        label: selected == 1
            ? context.tr('list_item_import_add_one')
            : context.tr(
                'list_item_import_add_count',
                params: {'count': '$selected'},
              ),
        size: AppButtonSize.large,
        expand: true,
        working: _adding,
        workingLabel: context.tr('list_item_import_adding'),
        onPressed: selected == 0 ? null : _add,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (status != null)
            Padding(
              padding: const EdgeInsets.only(bottom: AvoSpacing.m),
              child: status,
            ),
          if (target != null)
            Padding(
              padding: const EdgeInsets.only(bottom: AvoSpacing.xs),
              child: InsetSection(
                children: [
                  KeyedSubtree(
                    key: _targetKey,
                    child: NavRow(
                      title: context.tr('list_item_import_target'),
                      value: targetName ?? '',
                      onTap: lists.length < 2 ? null : () => _pickTarget(lists),
                    ),
                  ),
                ],
              ),
            ),
          InsetSection(
            header: context.tr('list_item_import_section_found'),
            footer: _unparsed.isEmpty ? photoNote : null,
            separatorIndent: _ReviewRow.textEdge,
            children: [
              for (final row in _rows)
                _ReviewRow(
                  key: ObjectKey(row),
                  name: row.name,
                  selected: row.selected,
                  quantity: itemQuantityLabel(
                    context,
                    quantity: row.quantity,
                    unit: row.unit,
                  ),
                  details: [
                    if (row.categoryId != null)
                      Categories.getById(row.categoryId!).getName(lang),
                    if (onList.contains(_key(row.name, row.unit)))
                      context.tr('list_item_import_already_on_list'),
                  ],
                  unsure: row.unsure,
                  onToggle: () => _toggle(row),
                  onEdit: () => _edit(row),
                ),
            ],
          ),
          if (_unparsed.isNotEmpty)
            InsetSection(
              header: context.tr(
                'list_item_import_section_unparsed',
                params: {'count': '${_unparsed.length}'},
              ),
              footer: photoNote,
              children: [
                for (final line in _unparsed)
                  _UnparsedRow(
                    key: ValueKey(line),
                    text: line,
                    onTap: () => _takeOver(line),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

/// A recognized item: selection circle, name with details, quantity at the
/// end (below the name from AX1 on). The circle selects, the rest opens the
/// item full screen.
class _ReviewRow extends StatelessWidget {
  const _ReviewRow({
    super.key,
    required this.name,
    required this.selected,
    required this.quantity,
    required this.details,
    required this.unsure,
    required this.onToggle,
    required this.onEdit,
  });

  /// The text edge: 16 + circle 26 + 12 (hairlines start there).
  static const double textEdge = AvoSpacing.l + AvoSizes.checkCircle + _textGap;

  final String name;
  final bool selected;
  final String? quantity;
  final List<String> details;
  final bool unsure;
  final VoidCallback onToggle;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    // The circle's 44 pt hit area reaches past the circle on both sides.
    const overhang = (AvoSizes.hitTarget - AvoSizes.checkCircle) / 2;
    final ax = context.isAccessibilityText;
    final firstLine = context.typography.lineHeightOf(AvoTextStyle.body);
    final sub = context.text(
      AvoTextStyle.subhead,
      color: colors.secondaryLabel,
    );
    final check = context.tr('list_item_import_check');
    final edit = context.tr('common_edit_item');

    final text = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          name,
          style: context.text(
            AvoTextStyle.body,
            color: selected ? colors.label : colors.secondaryLabel,
          ),
        ),
        if (details.isNotEmpty) Text(details.join(' · '), style: sub),
        if (unsure) Text(check, style: context.text(AvoTextStyle.subhead)),
      ],
    );
    final amount = quantity;

    return Semantics(
      container: true,
      checked: selected,
      label: [name, ?amount, ...details, if (unsure) check].join(', '),
      onTap: onToggle,
      customSemanticsActions: {CustomSemanticsAction(label: edit): onEdit},
      child: ExcludeSemantics(
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: _rowMinHeight),
          child: Row(
            crossAxisAlignment: ax
                ? CrossAxisAlignment.start
                : CrossAxisAlignment.center,
            children: [
              const SizedBox(width: AvoSpacing.l - overhang),
              Padding(
                // From AX1 the circle stays with the first line of the name.
                padding: EdgeInsets.only(
                  top: ax
                      ? math.max(
                          0,
                          _rowVertical + (firstLine - AvoSizes.hitTarget) / 2,
                        )
                      : 0,
                ),
                child: CheckCircle(
                  checked: selected,
                  itemName: name,
                  onChanged: (_) => onToggle(),
                ),
              ),
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: onEdit,
                  child: Padding(
                    padding: const EdgeInsetsDirectional.fromSTEB(
                      _textGap - overhang,
                      _rowVertical,
                      AvoSpacing.l,
                      _rowVertical,
                    ),
                    child: AdaptiveTrailing(
                      stacked: ax,
                      trailing: amount == null
                          ? null
                          : Text(
                              amount,
                              style: context.text(
                                AvoTextStyle.body,
                                color: colors.secondaryLabel,
                                tabular: true,
                              ),
                            ),
                      child: text,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A line Avo could not read as an item; tapping takes it over.
class _UnparsedRow extends StatelessWidget {
  const _UnparsedRow({super.key, required this.text, required this.onTap});

  final String text;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final hint = context.tr('list_item_import_take_over');
    return Semantics(
      container: true,
      button: true,
      label: text,
      hint: hint,
      onTap: onTap,
      child: ExcludeSemantics(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: _rowMinHeight),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AvoSpacing.l,
                vertical: _rowVertical,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(text, style: context.text(AvoTextStyle.body)),
                  Text(
                    hint,
                    style: context.text(
                      AvoTextStyle.subhead,
                      color: context.colors.secondaryLabel,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
