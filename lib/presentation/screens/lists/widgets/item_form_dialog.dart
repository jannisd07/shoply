import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shoply/core/constants/app_colors.dart';
import 'package:shoply/core/constants/categories.dart';
import 'package:shoply/core/constants/paper_colors.dart';
import 'package:shoply/core/localization/app_localizations.dart';
import 'package:shoply/core/localization/localization_helper.dart';
import 'package:shoply/core/utils/diet_checker.dart';
import 'package:shoply/data/models/shopping_item_model.dart';
import 'package:shoply/data/services/supabase_service.dart';
import 'package:shoply/presentation/state/auth_provider.dart';
import 'package:shoply/presentation/state/items_provider.dart';

const _addUnits = ['pcs', 'kg', 'g', 'l', 'ml', 'pack'];

/// Shows the add-item dialog, or the edit dialog when [item] is given.
Future<void> showItemFormDialog(
  BuildContext context, {
  required String listId,
  ShoppingItemModel? item,
  String prefill = '',
}) {
  // Dismiss the composer keyboard before the dialog opens.
  FocusManager.instance.primaryFocus?.unfocus();
  return showDialog<void>(
    context: context,
    barrierColor: Colors.black54,
    builder: (_) => ItemFormDialog(listId: listId, item: item, prefill: prefill),
  );
}

/// Paper dialog to add a new item or edit / delete an existing one.
class ItemFormDialog extends ConsumerStatefulWidget {
  final String listId;
  final ShoppingItemModel? item;
  final String prefill;

  const ItemFormDialog({
    super.key,
    required this.listId,
    this.item,
    this.prefill = '',
  });

  @override
  ConsumerState<ItemFormDialog> createState() => _ItemFormDialogState();
}

class _ItemFormDialogState extends ConsumerState<ItemFormDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _quantityController;
  late final TextEditingController _notesController;
  String? _selectedUnit;
  bool _isSaving = false;

  /// Started once, so unit taps don't refetch who added the item.
  Future<Map<String, dynamic>?>? _addedByFuture;

  ShoppingItemModel? get _item => widget.item;
  bool get _isEdit => _item != null;

  @override
  void initState() {
    super.initState();
    final item = _item;
    _nameController = TextEditingController(text: item?.name ?? widget.prefill);
    _quantityController = TextEditingController(
      text: item == null
          ? '1'
          : item.quantity % 1 == 0
              ? item.quantity.toInt().toString()
              : item.quantity.toString(),
    );
    _notesController = TextEditingController(text: item?.notes ?? '');
    _selectedUnit = item == null ? null : (item.unit ?? 'pcs');

    final addedBy = item?.addedBy;
    if (addedBy != null && addedBy.isNotEmpty) {
      _addedByFuture = _fetchUserInfo(addedBy);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _quantityController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<Map<String, dynamic>?> _fetchUserInfo(String userId) async {
    try {
      return await SupabaseService.instance.client
          .from('users')
          .select('display_name, avatar_url')
          .eq('id', userId)
          .maybeSingle();
    } catch (e) {
      debugPrint('❌ [LIST_DETAIL] Failed to fetch user info: $e');
      return null;
    }
  }

  String? get _notes {
    final notes = _notesController.text.trim();
    return notes.isEmpty ? null : notes;
  }

  double get _quantity => double.tryParse(_quantityController.text) ?? 1.0;

  void _showError(Object e) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          context.tr('error_adding', params: {'error': e.toString()}),
        ),
        backgroundColor: AppColors.error,
      ),
    );
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty || _isSaving) return;
    setState(() => _isSaving = true);

    final notifier = ref.read(itemsNotifierProvider(widget.listId).notifier);
    try {
      final item = _item;
      if (item == null) {
        final user = ref.read(currentUserProvider).value;
        await notifier.addItem(
          name: name,
          quantity: _quantity,
          unit: _selectedUnit,
          category: null, // Let Gemini categorize automatically
          notes: _notes,
          isDietWarning: user != null &&
              DietChecker.checkDietWarning(name, user.dietPreferences),
        );
      } else {
        await notifier.updateItem(item.id, {
          'name': name,
          'quantity': _quantity,
          'unit': _selectedUnit,
          'notes': _notes,
        });
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      debugPrint('❌ [LIST_DETAIL] Failed to save item: $e');
      if (mounted) setState(() => _isSaving = false);
      _showError(e);
    }
  }

  Future<void> _delete() async {
    final item = _item;
    if (item == null || _isSaving) return;
    setState(() => _isSaving = true);
    try {
      await ref
          .read(itemsNotifierProvider(widget.listId).notifier)
          .deleteItem(item.id);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      debugPrint('❌ [LIST_DETAIL] Failed to delete item: $e');
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('action_failed'))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF1C1C1E) : PaperColors.surface;
    final fillColor =
        isDark ? Colors.white.withValues(alpha: 0.06) : PaperColors.paper;
    final fg = AppColors.textPrimary(context);
    final muted = AppColors.textSecondary(context);
    final l10n = AppLocalizations.of(context);

    InputDecoration fieldDecoration(String hint) => InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: muted.withValues(alpha: 0.5)),
          filled: true,
          fillColor: fillColor,
          border: _noBorder,
          enabledBorder: _noBorder,
          focusedBorder: _noBorder,
          contentPadding: const EdgeInsets.all(16),
        );

    final units = _isEdit ? Categories.units : _addUnits;

    return Center(
      child: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 24,
            right: 24,
          ),
          child: Material(
            color: bgColor,
            borderRadius: BorderRadius.circular(20),
            clipBehavior: Clip.antiAlias,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Header row with title and X button
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _isEdit ? l10n.editItem : l10n.addItem,
                        style: PaperTextStyles.serif(22, color: fg),
                      ),
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: muted.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.close_rounded,
                            size: 16,
                            color: muted,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  if (_addedByFuture != null)
                    _AddedByRow(
                      future: _addedByFuture!,
                      userId: _item!.addedBy!,
                      fillColor: fillColor,
                    ),

                  TextField(
                    controller: _nameController,
                    style: TextStyle(color: fg, fontSize: 16),
                    decoration: fieldDecoration(l10n.itemName),
                    autofocus: !_isEdit && widget.prefill.isEmpty,
                    textCapitalization: TextCapitalization.sentences,
                  ),
                  const SizedBox(height: 12),

                  TextField(
                    controller: _quantityController,
                    style: TextStyle(color: fg, fontSize: 16),
                    decoration: fieldDecoration(l10n.quantity),
                    keyboardType: _isEdit
                        ? const TextInputType.numberWithOptions(decimal: true)
                        : TextInputType.number,
                  ),
                  const SizedBox(height: 12),

                  // Unit pill selector
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final unit in units)
                        _UnitPill(
                          unit: unit,
                          selected: _selectedUnit == unit,
                          fillColor: fillColor,
                          onTap: () {
                            setState(() {
                              final deselected = _isEdit ? 'pcs' : null;
                              _selectedUnit =
                                  _selectedUnit == unit ? deselected : unit;
                            });
                            HapticFeedback.selectionClick();
                          },
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  TextField(
                    controller: _notesController,
                    style: TextStyle(color: fg, fontSize: 16),
                    decoration: fieldDecoration(l10n.notes),
                    maxLines: 2,
                    textCapitalization: TextCapitalization.sentences,
                  ),
                  const SizedBox(height: 24),

                  if (_isEdit)
                    Row(
                      children: [
                        GestureDetector(
                          onTap: _delete,
                          child: Container(
                            height: 52,
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            decoration: BoxDecoration(
                              color: Colors.red.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Center(
                              child: Icon(
                                Icons.delete_outline_rounded,
                                color: Colors.red.shade400,
                                size: 22,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: PaperPrimaryButton(
                            label: l10n.save,
                            onTap: _save,
                          ),
                        ),
                      ],
                    )
                  else
                    PaperPrimaryButton(label: l10n.addItem, onTap: _save),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

const _noBorder = OutlineInputBorder(
  borderRadius: BorderRadius.all(Radius.circular(14)),
  borderSide: BorderSide.none,
);

/// The 52pt black/white (inverted in dark mode) call-to-action used by the
/// list dialogs.
class PaperPrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final IconData? icon;

  const PaperPrimaryButton({
    super.key,
    required this.label,
    required this.onTap,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fg = isDark ? Colors.black : Colors.white;
    final text = Text(
      label,
      style: TextStyle(
        fontSize: icon == null ? 17 : 16,
        fontWeight: FontWeight.w600,
        color: fg,
        letterSpacing: -0.3,
      ),
    );
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        height: 52,
        decoration: BoxDecoration(
          color: isDark ? Colors.white : Colors.black,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Center(
          child: icon == null
              ? text
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, size: 18, color: fg),
                    const SizedBox(width: 8),
                    text,
                  ],
                ),
        ),
      ),
    );
  }
}

class _UnitPill extends StatelessWidget {
  final String unit;
  final bool selected;
  final Color fillColor;
  final VoidCallback onTap;

  const _UnitPill({
    required this.unit,
    required this.selected,
    required this.fillColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? (isDark ? Colors.white : Colors.black)
              : fillColor,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          unit,
          style: TextStyle(
            color: selected
                ? (isDark ? Colors.black : Colors.white)
                : AppColors.textSecondary(context),
            fontSize: 14,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }
}

/// "Added by NAME" row; tapping it opens that user's profile.
class _AddedByRow extends StatelessWidget {
  final Future<Map<String, dynamic>?> future;
  final String userId;
  final Color fillColor;

  const _AddedByRow({
    required this.future,
    required this.userId,
    required this.fillColor,
  });

  @override
  Widget build(BuildContext context) {
    final fg = AppColors.textPrimary(context);
    final muted = AppColors.textSecondary(context);

    return FutureBuilder<Map<String, dynamic>?>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Center(
              child: CupertinoActivityIndicator(radius: 10, color: muted),
            ),
          );
        }

        final userInfo = snapshot.data;
        final displayName = userInfo?['display_name'] as String? ??
            context.tr('unknown_user');
        final avatarUrl = userInfo?['avatar_url'] as String?;
        final hasAvatar = avatarUrl != null && avatarUrl.isNotEmpty;

        return GestureDetector(
          onTap: () {
            Navigator.pop(context);
            context.push(
              '/author/$userId',
              extra: {'authorName': displayName},
            );
          },
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: fillColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: muted.withValues(alpha: 0.15),
                  backgroundImage: hasAvatar ? NetworkImage(avatarUrl) : null,
                  child: hasAvatar
                      ? null
                      : Text(
                          displayName.isNotEmpty
                              ? displayName[0].toUpperCase()
                              : '?',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: fg,
                          ),
                        ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.tr('added_by'),
                        style: TextStyle(fontSize: 11, color: muted),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        displayName,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: fg,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: muted, size: 20),
              ],
            ),
          ),
        );
      },
    );
  }
}
