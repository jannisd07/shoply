import 'package:flutter/widgets.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:shoply/core/design/design.dart';
import 'package:shoply/core/localization/localization_helper.dart';
import 'package:shoply/data/models/shopping_list_model.dart';
import 'package:shoply/presentation/providers/store_for_list_provider.dart'
    show listStoreRepositoryProvider, storeInfoForChain;
import 'package:shoply/presentation/screens/lists/widgets/all_lists_data.dart';
import 'package:shoply/presentation/screens/lists/widgets/list_info_actions.dart';
import 'package:shoply/presentation/screens/lists/widgets/list_info_colors.dart';
import 'package:shoply/presentation/screens/lists/widgets/list_info_header.dart';
import 'package:shoply/presentation/widgets/design/full_screen_editor.dart';
import 'package:shoply/presentation/widgets/design/inset_section.dart';
import 'package:shoply/presentation/widgets/design/settings_rows.dart';
import 'package:shoply/presentation/widgets/design/status_row.dart';
import 'package:shoply/presentation/widgets/slots/b_slots.dart';

/// Opens "Neue Liste" full screen (Konzept 11 §8, as a cover instead of a
/// sheet). Completes with the created list (its `id` is the new list's
/// id), or null when closed.
///
/// [initialName] prefills the name; [storeChainId] preselects the market
/// (A-L3, "Neue Liste …" in Teil B's "Auf welche Liste?"), which the person
/// can change or remove before "Anlegen". The market is saved with the
/// list; a failure there keeps the new list.
Future<ShoppingListModel?> openNewListEditor(
  BuildContext context, {
  String initialName = '',
  String? storeChainId,
}) => pushFullScreenEditor<ShoppingListModel>(
  context,
  (_) => NewListEditor(initialName: initialName, storeChainId: storeChainId),
);

/// [openNewListEditor] for callers that only need the new list's id.
Future<String?> openNewListEditorForId(
  BuildContext context, {
  String initialName = '',
  String? storeChainId,
}) async => (await openNewListEditor(
  context,
  initialName: initialName,
  storeChainId: storeChainId,
))?.id;

/// Name, colour, market and "Anlegen" for a new list. The glyph shows the
/// chosen colour live; the first unused palette colour is preselected.
class NewListEditor extends ConsumerStatefulWidget {
  const NewListEditor({super.key, this.initialName = '', this.storeChainId});

  /// Prefilled name (Avo, `shoply://create-list?name=`).
  final String initialName;

  /// Preselected market (a chain id such as `lidl`); null: none.
  final String? storeChainId;

  @override
  ConsumerState<NewListEditor> createState() => _NewListEditorState();
}

class _NewListEditorState extends ConsumerState<NewListEditor> {
  late final TextEditingController _name = TextEditingController(
    text: widget.initialName,
  );
  ListPaletteColor? _color;
  late String? _chain = widget.storeChainId;
  bool _working = false;
  bool _failed = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  bool get _canCreate => _name.text.trim().isNotEmpty && !_working;

  Future<void> _create() async {
    if (!_canCreate) return;
    final color = _color ?? _defaultColor();
    setState(() {
      _working = true;
      _failed = false;
    });
    try {
      final list = await ref
          .read(listActionsProvider)
          .createList(_name.text.trim(), colorHex: color.hex);
      final chain = _chain;
      if (chain != null) {
        try {
          await ref
              .read(listStoreRepositoryProvider)
              .setExplicit(list.id, chain);
        } catch (e) {
          debugPrint('⚠️ [NEW_LIST] Market of the new list not saved: $e');
        }
      }
      if (!mounted) return;
      Navigator.of(context).pop(list);
    } catch (e) {
      debugPrint('❌ [NEW_LIST] Failed to create list: $e');
      if (!mounted) return;
      AvoHaptics.error();
      setState(() {
        _working = false;
        _failed = true;
      });
    }
  }

  /// "Markt wählen" (S2) without a list: it only returns the choice.
  Future<void> _pickStore() async {
    final choice = await openStorePicker(
      context,
      from: StorePickerOrigin.newList,
    );
    if (!mounted || choice == null) return;
    setState(() {
      _chain = switch (choice) {
        ChainStoreChoice(:final chainId) => chainId,
        _ => null,
      };
    });
  }

  ListPaletteColor _defaultColor() {
    final lists = ref.read(allListsSourceProvider).valueOrNull ?? const [];
    return nextFreePaletteColor(lists);
  }

  @override
  Widget build(BuildContext context) {
    final color = _color ?? _defaultColor();
    return FullScreenEditor(
      title: context.tr('list_ov_new_list'),
      onDone: _create,
      doneLabel: context.tr('list_ov_create'),
      doneEnabled: _canCreate,
      working: _working,
      workingLabel: context.tr('list_ov_creating'),
      dirty: _name.text.trim().isNotEmpty,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          ListInfoHeader(
            color: color.resolve(context),
            field: ListNameField(
              controller: _name,
              autofocus: true,
              onChanged: (_) => setState(() => _failed = false),
              onSubmitted: (_) => _create(),
            ),
          ),
          if (_failed)
            Padding(
              padding: const EdgeInsets.only(top: AvoSpacing.m),
              child: StatusRow(
                kind: StatusKind.failed,
                text: context.tr('list_ov_create_failed'),
              ),
            ),
          InsetSection(
            children: [
              NavRow(
                title: context.tr('list_ov_section_store'),
                value: _chain == null
                    ? context.tr('offer_store_none')
                    : storeInfoForChain(_chain!)?.name ??
                          context.tr('offer_store_none'),
                onTap: _working ? null : _pickStore,
              ),
            ],
          ),
          InsetSection(
            header: context.tr('list_ov_color'),
            children: [
              ListColorPicker(
                selectedId: color.id,
                onSelected: (p) => setState(() => _color = p),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
