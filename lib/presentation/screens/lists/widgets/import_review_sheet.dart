import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:shoply/core/constants/app_colors.dart';
import 'package:shoply/core/localization/localization_helper.dart';
import 'package:shoply/core/widgets/design_system.dart';
import 'package:shoply/data/services/list_import_service.dart';

/// The post-extraction review sheet: a fitted (roughly half-height) glass
/// sheet listing the recognized items, each editable inline and deletable
/// (swipe AND a visible button), low-confidence rows visually de-emphasized.
///
/// Resolves with the items to import, or null (Abbrechen / dismissed).
Future<List<ExtractedListItem>?> showImportReviewSheet(
  BuildContext context, {
  required ListImportResult result,
}) {
  return showModalBottomSheet<List<ExtractedListItem>>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    constraints: BoxConstraints(
      maxHeight: MediaQuery.sizeOf(context).height * 0.6,
    ),
    builder: (_) => _ImportReviewSheet(result: result),
  );
}

class _ImportReviewSheet extends StatefulWidget {
  final ListImportResult result;

  const _ImportReviewSheet({required this.result});

  @override
  State<_ImportReviewSheet> createState() => _ImportReviewSheetState();
}

class _RowData {
  final ExtractedListItem item;
  final TextEditingController nameController;
  final TextEditingController quantityController;
  final TextEditingController unitController;

  _RowData(this.item)
      : nameController = TextEditingController(text: item.name),
        quantityController = TextEditingController(
          text: item.quantity == null
              ? ''
              : (item.quantity! % 1 == 0
                    ? item.quantity!.toInt().toString()
                    : item.quantity!.toString()),
        ),
        unitController = TextEditingController(text: item.unit ?? '');

  void dispose() {
    nameController.dispose();
    quantityController.dispose();
    unitController.dispose();
  }

  ExtractedListItem toItem() => ExtractedListItem(
        name: nameController.text.trim(),
        quantity: double.tryParse(
          quantityController.text.trim().replaceAll(',', '.'),
        ),
        unit: unitController.text.trim().isEmpty
            ? null
            : unitController.text.trim(),
        confidence: item.confidence,
      );
}

class _ImportReviewSheetState extends State<_ImportReviewSheet> {
  late final List<_RowData> _rows;

  @override
  void initState() {
    super.initState();
    _rows = widget.result.items.map(_RowData.new).toList();
  }

  @override
  void dispose() {
    for (final row in _rows) {
      row.dispose();
    }
    super.dispose();
  }

  void _removeRow(_RowData row) {
    HapticFeedback.lightImpact();
    setState(() => _rows.remove(row));
    // Dispose after the frame so a Dismissible mid-animation doesn't touch
    // a disposed controller.
    WidgetsBinding.instance.addPostFrameCallback((_) => row.dispose());
  }

  void _import() {
    final items = _rows
        .map((r) => r.toItem())
        .where((i) => i.name.isNotEmpty)
        .toList();
    Navigator.of(context).pop(items);
  }

  @override
  Widget build(BuildContext context) {
    final reduceTransparency = MediaQuery.highContrastOf(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final tint = reduceTransparency
        ? AppColors.surface(context)
        : (isDark
              ? const Color(0xFF1C1C1E).withValues(alpha: 0.78)
              : Colors.white.withValues(alpha: 0.8));

    final validCount =
        _rows.where((r) => r.nameController.text.trim().isNotEmpty).length;

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      child: BackdropFilter(
        filter: reduceTransparency
            ? ImageFilter.blur(sigmaX: 0, sigmaY: 0)
            : ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          color: tint,
          child: SafeArea(
            top: false,
            child: Padding(
              // Ride the keyboard while a row is being edited.
              padding: EdgeInsets.only(
                bottom: MediaQuery.viewInsetsOf(context).bottom,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 10, bottom: 6),
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.border(context),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 2),
                    child: Text(
                      context.tr(
                        'import_review_title',
                        params: {'count': '${_rows.length}'},
                      ),
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary(context),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Text(
                      context.tr('import_review_subtitle'),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12.5,
                        color: AppColors.textSecondary(context),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Flexible(
                    child: _rows.isEmpty
                        ? Padding(
                            padding: const EdgeInsets.all(24),
                            child: Text(
                              context.tr('import_review_empty'),
                              style: TextStyle(
                                fontSize: 13.5,
                                color: AppColors.textSecondary(context),
                              ),
                            ),
                          )
                        : ListView.builder(
                            shrinkWrap: true,
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            itemCount: _rows.length,
                            itemBuilder: (context, index) {
                              final row = _rows[index];
                              return Dismissible(
                                key: ObjectKey(row),
                                direction: DismissDirection.endToStart,
                                background: Container(
                                  alignment: Alignment.centerRight,
                                  padding: const EdgeInsets.only(right: 20),
                                  color: Colors.red.withValues(alpha: 0.85),
                                  child: const Icon(
                                    CupertinoIcons.trash,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                ),
                                onDismissed: (_) => _removeRow(row),
                                child: _ReviewRow(
                                  row: row,
                                  onDelete: () => _removeRow(row),
                                  onNameChanged: () => setState(() {}),
                                ),
                              );
                            },
                          ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
                    child: Row(
                      children: [
                        Expanded(
                          child: AppOutlineButton(
                            text: context.tr('cancel'),
                            onPressed: () => Navigator.of(context).pop(),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: AppButton(
                            text: context.tr(
                              'import_action',
                              params: {'count': '$validCount'},
                            ),
                            onPressed: validCount == 0 ? null : _import,
                          ),
                        ),
                      ],
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

class _ReviewRow extends StatelessWidget {
  final _RowData row;
  final VoidCallback onDelete;
  final VoidCallback onNameChanged;

  const _ReviewRow({
    required this.row,
    required this.onDelete,
    required this.onNameChanged,
  });

  @override
  Widget build(BuildContext context) {
    final lowConfidence = row.item.isLowConfidence;
    final textPrimary = AppColors.textPrimary(context);
    final textSecondary = AppColors.textSecondary(context);

    return Opacity(
      // De-emphasize low-confidence rows instead of hiding them.
      opacity: lowConfidence ? 0.55 : 1,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: row.nameController,
                onChanged: (_) => onNameChanged(),
                textCapitalization: TextCapitalization.sentences,
                style: TextStyle(fontSize: 15, color: textPrimary),
                decoration: InputDecoration(
                  isDense: true,
                  border: InputBorder.none,
                  hintText: context.tr('import_row_name_hint'),
                  hintStyle: TextStyle(fontSize: 15, color: textSecondary),
                ),
              ),
            ),
            SizedBox(
              width: 42,
              child: TextField(
                controller: row.quantityController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                textAlign: TextAlign.end,
                style: TextStyle(fontSize: 14, color: textSecondary),
                decoration: const InputDecoration(
                  isDense: true,
                  border: InputBorder.none,
                  hintText: '1',
                ),
              ),
            ),
            SizedBox(
              width: 44,
              child: TextField(
                controller: row.unitController,
                style: TextStyle(fontSize: 14, color: textSecondary),
                decoration: InputDecoration(
                  isDense: true,
                  border: InputBorder.none,
                  hintText: context.tr('import_row_unit_hint'),
                  hintStyle: TextStyle(fontSize: 14, color: textSecondary),
                ),
              ),
            ),
            if (lowConfidence)
              Padding(
                padding: const EdgeInsets.only(left: 2),
                child: Icon(
                  CupertinoIcons.question_circle,
                  size: 15,
                  color: textSecondary,
                ),
              ),
            IconButton(
              visualDensity: VisualDensity.compact,
              icon: Icon(
                CupertinoIcons.minus_circle,
                size: 20,
                color: textSecondary,
              ),
              onPressed: onDelete,
            ),
          ],
        ),
      ),
    );
  }
}
