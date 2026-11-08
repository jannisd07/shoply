import 'package:flutter/widgets.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:shoply/core/design/design.dart';
import 'package:shoply/core/localization/localization_helper.dart';
import 'package:shoply/data/models/shopping_list_model.dart';
import 'package:shoply/presentation/screens/lists/widgets/all_lists_data.dart';
import 'package:shoply/presentation/screens/lists/widgets/list_info_actions.dart';
import 'package:shoply/presentation/screens/lists/widgets/list_info_colors.dart';
import 'package:shoply/presentation/screens/lists/widgets/list_info_header.dart';
import 'package:shoply/presentation/widgets/design/full_screen_editor.dart';
import 'package:shoply/presentation/widgets/design/inset_section.dart';
import 'package:shoply/presentation/widgets/design/status_row.dart';

/// Opens "Neue Liste" full screen (Konzept 11 §8, as a cover instead of a
/// sheet). Completes with the created list, or null when closed.
Future<ShoppingListModel?> openNewListEditor(BuildContext context) =>
    pushFullScreenEditor<ShoppingListModel>(
      context,
      (_) => const NewListEditor(),
    );

/// Name, colour and "Anlegen" for a new list. The glyph shows the chosen
/// colour live; the first unused palette colour is preselected.
class NewListEditor extends ConsumerStatefulWidget {
  const NewListEditor({super.key, this.initialName = ''});

  /// Prefilled name (Avo, `shoply://create-list?name=`).
  final String initialName;

  @override
  ConsumerState<NewListEditor> createState() => _NewListEditorState();
}

class _NewListEditorState extends ConsumerState<NewListEditor> {
  late final TextEditingController _name = TextEditingController(
    text: widget.initialName,
  );
  ListPaletteColor? _color;
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
