import 'package:flutter/cupertino.dart';

import 'package:shoply/core/design/design.dart';
import 'package:shoply/core/localization/localization_helper.dart';
import 'package:shoply/presentation/widgets/design/avo_icons.dart';
import 'package:shoply/presentation/widgets/design/full_screen_editor.dart';
import 'package:shoply/presentation/widgets/design/inset_section.dart';
import 'package:shoply/presentation/widgets/design/settings_rows.dart';
import 'package:shoply/presentation/widgets/design/status_row.dart';

/// What the category editor returns: a new name, or "delete".
@immutable
class CategoryEditResult {
  const CategoryEditResult.name(String this.name) : delete = false;
  const CategoryEditResult.delete() : name = null, delete = true;

  final String? name;
  final bool delete;
}

/// Opens "Neue Kategorie" (no [initialName]) or "Kategorie bearbeiten"
/// full screen (Konzept 11 §12.2, as a cover instead of a sheet).
/// [takenNames] are the names in use (any case), except [initialName].
Future<CategoryEditResult?> openCategoryEditor(
  BuildContext context, {
  String? initialName,
  required Set<String> takenNames,
}) => pushFullScreenEditor<CategoryEditResult>(
  context,
  (_) => CategoryEditor(initialName: initialName, takenNames: takenNames),
);

/// One name field with the tag symbol (no colour, Konzept 00 §12.19), the
/// footnote, "Diese Kategorie gibt es schon." and, when editing,
/// "Kategorie löschen".
class CategoryEditor extends StatefulWidget {
  const CategoryEditor({
    super.key,
    this.initialName,
    this.takenNames = const {},
  });

  final String? initialName;
  final Set<String> takenNames;

  @override
  State<CategoryEditor> createState() => _CategoryEditorState();
}

class _CategoryEditorState extends State<CategoryEditor> {
  late final TextEditingController _name = TextEditingController(
    text: widget.initialName ?? '',
  );

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  String get _value => _name.text.trim();

  bool get _exists {
    final value = _value.toLowerCase();
    if (value.isEmpty) return false;
    if (value == widget.initialName?.trim().toLowerCase()) return false;
    return widget.takenNames.any((n) => n.trim().toLowerCase() == value);
  }

  bool get _canSave => _value.isNotEmpty && !_exists;

  void _save() {
    if (!_canSave) return;
    Navigator.of(context).pop(CategoryEditResult.name(_value));
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final editing = widget.initialName != null;
    return FullScreenEditor(
      title: context.tr(
        editing ? 'list_ov_category_edit' : 'list_ov_category_new',
      ),
      onDone: _save,
      doneEnabled: _canSave,
      dirty: _value != (widget.initialName ?? '').trim(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          InsetSection(
            footer: context.tr('list_ov_category_footer'),
            children: [
              ConstrainedBox(
                constraints: const BoxConstraints(
                  minHeight: AvoSizes.hitTarget,
                ),
                child: Padding(
                  padding: const EdgeInsetsDirectional.only(
                    start: AvoSpacing.l,
                  ),
                  child: Row(
                    children: [
                      AvoIcon(
                        AvoIcons.tag,
                        size: 20,
                        color: colors.secondaryLabel,
                      ),
                      const SizedBox(width: AvoSpacing.m),
                      Expanded(
                        child: Semantics(
                          textField: true,
                          label: context.tr('list_ov_category_name'),
                          child: CupertinoTextField.borderless(
                            controller: _name,
                            autofocus: true,
                            placeholder: context.tr(
                              'list_ov_category_placeholder',
                            ),
                            placeholderStyle: context.text(
                              AvoTextStyle.body,
                              color: colors.placeholder,
                            ),
                            style: context.text(AvoTextStyle.body),
                            textCapitalization: TextCapitalization.sentences,
                            textInputAction: TextInputAction.done,
                            minLines: 1,
                            maxLines: null,
                            padding: const EdgeInsets.fromLTRB(
                              0,
                              AvoSpacing.m - 1,
                              AvoSpacing.l,
                              AvoSpacing.m - 1,
                            ),
                            onChanged: (_) => setState(() {}),
                            onSubmitted: (_) => _save(),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          if (_exists)
            Padding(
              padding: const EdgeInsets.only(top: AvoSpacing.m),
              child: StatusRow(
                kind: StatusKind.failed,
                text: context.tr('list_ov_category_exists'),
              ),
            ),
          if (editing) ...[
            const SizedBox(height: AvoSpacing.section),
            InsetSection(
              children: [
                DestructiveRow(
                  title: context.tr('list_ov_category_delete'),
                  onTap: () => Navigator.of(
                    context,
                  ).pop(const CategoryEditResult.delete()),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
