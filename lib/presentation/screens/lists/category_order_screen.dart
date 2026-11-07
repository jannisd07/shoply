import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shoply/core/constants/app_colors.dart';
import 'package:shoply/core/constants/categories.dart';
import 'package:shoply/core/localization/localization_helper.dart';
import 'package:shoply/data/models/custom_category.dart';
import 'package:shoply/data/services/category_order_service.dart';
import 'package:shoply/presentation/widgets/common/confirm_dialog.dart';
import 'package:shoply/presentation/widgets/common/liquid_glass_button.dart';
import 'package:shoply/presentation/widgets/common/paper_settings.dart';

/// Screen for managing category order and custom categories for a specific list.
///
/// Order and custom categories are stored on this device only, so changes
/// here are not announced to other list members.
class CategoryOrderScreen extends StatefulWidget {
  final String listId;
  final String listName;

  const CategoryOrderScreen({
    super.key,
    required this.listId,
    required this.listName,
  });

  @override
  State<CategoryOrderScreen> createState() => _CategoryOrderScreenState();
}

class _CategoryOrderScreenState extends State<CategoryOrderScreen> {
  final _service = CategoryOrderService();
  List<_CategoryItem> _categories = [];
  bool _isLoading = true;
  bool _hasChanges = false;

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    final order = await _service.getCategoryOrder(widget.listId);
    final customCategories = await _service.getCustomCategories(widget.listId);

    final customMap = {for (final c in customCategories) c.id: c};
    final builtInIds = Categories.allIds;

    _CategoryItem builtIn(String id) => _CategoryItem(
          id: id,
          name: id, // Store ID for translation lookup
          color: Categories.getById(id).color,
          isCustom: false,
        );

    final items = <_CategoryItem>[];

    // Add categories in order
    for (final id in order) {
      final custom = customMap[id];
      if (custom != null) {
        items.add(_CategoryItem.custom(custom));
      } else if (builtInIds.contains(id)) {
        items.add(builtIn(id));
      }
    }

    // Add any built-in categories not in order yet
    for (final id in builtInIds) {
      if (!order.contains(id)) items.add(builtIn(id));
    }

    // Add any custom categories not in order yet (at top)
    for (final custom in customCategories) {
      if (!order.contains(custom.id)) {
        items.insert(0, _CategoryItem.custom(custom));
      }
    }

    if (!mounted) return;
    setState(() {
      _categories = items;
      _isLoading = false;
    });
  }

  Future<void> _saveOrder() async {
    final order = _categories.map((c) => c.id).toList();
    await _service.saveCategoryOrder(widget.listId, order);
    if (mounted) setState(() => _hasChanges = true);
  }

  Future<void> _showAddCategorySheet() async {
    final result = await _showCategoryFormSheet(context);
    if (result == null || !mounted) return;

    final category = await _service.addCustomCategory(
      widget.listId,
      result.name,
      result.color,
    );
    if (!mounted) return;
    setState(() {
      _categories.insert(0, _CategoryItem.custom(category));
      _hasChanges = true;
    });
    await _saveOrder();
  }

  Future<void> _showEditCategorySheet(_CategoryItem category) async {
    final result = await _showCategoryFormSheet(context, existing: category);
    if (result == null || !mounted) return;

    if (result.delete) {
      await _showDeleteConfirmation(category);
      return;
    }

    final updated = CustomCategory(
      id: category.id,
      name: result.name,
      color: result.color,
    );
    await _service.updateCustomCategory(widget.listId, updated);
    if (!mounted) return;
    setState(() {
      final index = _categories.indexWhere((c) => c.id == category.id);
      if (index != -1) _categories[index] = _CategoryItem.custom(updated);
      _hasChanges = true;
    });
  }

  Future<void> _showDeleteConfirmation(_CategoryItem category) async {
    final confirmed = await confirmDestructive(
      context,
      title: context.tr('delete_category'),
      message: context.tr('delete_category_confirm'),
      confirmLabel: context.tr('delete'),
    );
    if (!confirmed) return;
    await _service.deleteCustomCategory(widget.listId, category.id);
    if (!mounted) return;
    setState(() {
      _categories.removeWhere((c) => c.id == category.id);
      _hasChanges = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = AppColors.background(context);
    final textSecondary = AppColors.textSecondary(context);

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: PaperSettingsAppBar(
        title: context.tr('category_order'),
        onBack: () => Navigator.pop(context, _hasChanges),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: PaperCircleIconButton(
                icon: Icons.add_rounded,
                onTap: _showAddCategorySheet,
              ),
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CupertinoActivityIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(26, 4, 26, 16),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      context.tr('drag_to_reorder'),
                      style: TextStyle(
                        color: textSecondary,
                        fontSize: 13,
                        height: 1.5,
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: ReorderableListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    itemCount: _categories.length,
                    autoScrollerVelocityScalar: 25.0,
                    onReorder: (oldIndex, newIndex) {
                      HapticFeedback.mediumImpact();
                      setState(() {
                        if (newIndex > oldIndex) newIndex--;
                        final item = _categories.removeAt(oldIndex);
                        _categories.insert(newIndex, item);
                      });
                      _saveOrder();
                    },
                    proxyDecorator: (child, index, animation) {
                      return AnimatedBuilder(
                        animation: animation,
                        builder: (context, child) {
                          final scale = Tween<double>(begin: 1.0, end: 1.03).animate(animation);
                          return Transform.scale(
                            scale: scale.value,
                            child: Material(
                              color: Colors.transparent,
                              child: child,
                            ),
                          );
                        },
                        child: child,
                      );
                    },
                    itemBuilder: (context, index) {
                      final category = _categories[index];
                      return _buildCategoryTile(category, isDark, index);
                    },
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildCategoryTile(_CategoryItem category, bool isDark, int index) {
    final textPrimary = AppColors.textPrimary(context);
    final textSecondary = AppColors.textSecondary(context);
    final dividerColor = AppColors.divider(context);

    return Column(
      key: ValueKey(category.id),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            children: [
              // Color dot
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: category.color,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 14),
              // Category name
              Expanded(
                child: Text(
                  category.isCustom
                      ? category.name
                      : Categories.getById(category.id).getName(Localizations.localeOf(context).languageCode),
                  style: TextStyle(
                    fontWeight: FontWeight.w400,
                    fontSize: 15,
                    color: textPrimary,
                  ),
                ),
              ),
              // Edit for custom
              if (category.isCustom)
                GestureDetector(
                  onTap: () => _showEditCategorySheet(category),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Icon(
                      Icons.edit_rounded,
                      color: textSecondary.withValues(alpha: 0.5),
                      size: 16,
                    ),
                  ),
                ),
              // Drag handle
              Icon(
                Icons.drag_handle_rounded,
                color: textSecondary.withValues(alpha: 0.4),
                size: 22,
              ),
            ],
          ),
        ),
        if (index < _categories.length - 1)
          Container(height: 0.5, color: dividerColor),
      ],
    );
  }
}

class _CategoryItem {
  final String id;
  final String name;
  final Color color;
  final bool isCustom;

  _CategoryItem({
    required this.id,
    required this.name,
    required this.color,
    required this.isCustom,
  });

  _CategoryItem.custom(CustomCategory category)
      : id = category.id,
        name = category.name,
        color = category.color,
        isCustom = true;
}

/// Result of the add/edit category sheet.
class _CategoryFormResult {
  final String name;
  final Color color;
  final bool delete;

  const _CategoryFormResult({
    required this.name,
    required this.color,
    this.delete = false,
  });
}

const _categoryColors = <Color>[
  Colors.red,
  Colors.pink,
  Colors.purple,
  Colors.deepPurple,
  Colors.indigo,
  Colors.blue,
  Colors.lightBlue,
  Colors.cyan,
  Colors.teal,
  Colors.green,
  Colors.lightGreen,
  Colors.lime,
  Colors.amber,
  Colors.orange,
  Colors.deepOrange,
  Colors.brown,
];

/// Shows the add (no [existing]) or edit category sheet.
Future<_CategoryFormResult?> _showCategoryFormSheet(
  BuildContext context, {
  _CategoryItem? existing,
}) {
  return showModalBottomSheet<_CategoryFormResult>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _CategoryFormSheet(existing: existing),
  );
}

class _CategoryFormSheet extends StatefulWidget {
  final _CategoryItem? existing;

  const _CategoryFormSheet({this.existing});

  @override
  State<_CategoryFormSheet> createState() => _CategoryFormSheetState();
}

class _CategoryFormSheetState extends State<_CategoryFormSheet> {
  late final TextEditingController _nameController;
  late Color _selectedColor;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.existing?.name ?? '');
    _selectedColor = widget.existing?.color ?? AppColors.lightAccent;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;
    Navigator.pop(
      context,
      _CategoryFormResult(name: name, color: _selectedColor),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AdaptiveBlurView(
      blurStyle: BlurStyle.systemMaterial,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      child: Container(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Glass handle bar
              Center(
                child: Container(
                  width: 40,
                  height: 5,
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.4)
                        : Colors.black.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                context.tr(_isEdit ? 'edit_category' : 'add_category'),
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.5,
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),
              const SizedBox(height: 24),
              AdaptiveTextField(
                controller: _nameController,
                placeholder: context.tr(
                  _isEdit ? 'category_name' : 'category_name_hint',
                ),
                autofocus: !_isEdit,
                textCapitalization: TextCapitalization.sentences,
                // Rebuild so the submit button enables as soon as a name
                // is typed.
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 20),
              Text(
                context.tr('select_color'),
                style: TextStyle(fontSize: 14, color: Colors.grey[600]),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final color in _categoryColors)
                    GestureDetector(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() => _selectedColor = color);
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: _selectedColor == color
                                ? (isDark ? Colors.white : Colors.black)
                                : Colors.transparent,
                            width: 3,
                          ),
                          boxShadow: _selectedColor == color
                              ? [
                                  BoxShadow(
                                    color: color.withValues(alpha: 0.5),
                                    blurRadius: 8,
                                    spreadRadius: 2,
                                  ),
                                ]
                              : null,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 28),
              if (_isEdit)
                Row(
                  children: [
                    Expanded(
                      child: LiquidGlassOutlinedButton(
                        label: context.tr('delete'),
                        isDestructive: true,
                        onPressed: () => Navigator.pop(
                          context,
                          _CategoryFormResult(
                            name: widget.existing!.name,
                            color: widget.existing!.color,
                            delete: true,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: LiquidGlassFilledButton(
                        label: context.tr('save'),
                        onPressed: _submit,
                      ),
                    ),
                  ],
                )
              else
                LiquidGlassFilledButton(
                  label: context.tr('add'),
                  onPressed:
                      _nameController.text.trim().isEmpty ? null : _submit,
                ),
              // Extra padding for iOS 26 home indicator/navbar
              SizedBox(height: 34 + MediaQuery.of(context).viewPadding.bottom),
            ],
          ),
        ),
      ),
    );
  }
}
