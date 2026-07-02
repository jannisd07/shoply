import 'dart:convert';
import 'dart:ui';
import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/cupertino.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shoply/core/constants/app_colors.dart';
import 'package:shoply/core/constants/categories.dart';
import 'package:shoply/core/localization/localization_helper.dart';
import 'package:shoply/data/models/list_activity.dart';
import 'package:shoply/data/services/list_activity_service.dart';
import 'package:shoply/presentation/widgets/common/liquid_glass_button.dart';
import 'package:shoply/presentation/widgets/common/paper_settings.dart';

/// Per-list custom category management and category ordering.

/// Service for managing category order and custom categories per shopping list.
class CategoryOrderService {
  static final CategoryOrderService _instance = CategoryOrderService._internal();
  factory CategoryOrderService() => _instance;
  CategoryOrderService._internal();

  /// Get the category order for a specific list
  Future<List<String>> getCategoryOrder(String listId) async {
    final prefs = await SharedPreferences.getInstance();
    final order = prefs.getStringList('category_order_$listId');
    if (order != null && order.isNotEmpty) {
      return order;
    }
    // Return default order: custom categories first, then built-in
    final customCategories = await getCustomCategories(listId);
    final customIds = customCategories.map((c) => c.id).toList();
    return [...customIds, ...Categories.allIds];
  }

  /// Save the category order for a specific list
  Future<void> saveCategoryOrder(String listId, List<String> order) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('category_order_$listId', order);
  }

  /// Get custom categories for a specific list
  Future<List<CustomCategory>> getCustomCategories(String listId) async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString('custom_categories_$listId');
    if (json == null) return [];
    
    final List<dynamic> list = jsonDecode(json);
    return list.map((e) => CustomCategory.fromJson(e)).toList();
  }

  /// Save custom categories for a specific list
  Future<void> saveCustomCategories(String listId, List<CustomCategory> categories) async {
    final prefs = await SharedPreferences.getInstance();
    final json = jsonEncode(categories.map((e) => e.toJson()).toList());
    await prefs.setString('custom_categories_$listId', json);
  }

  /// Add a custom category to a specific list (inserted at top)
  Future<CustomCategory> addCustomCategory(String listId, String name, Color color) async {
    final categories = await getCustomCategories(listId);
    final id = 'custom_${DateTime.now().millisecondsSinceEpoch}';
    final category = CustomCategory(
      id: id,
      name: name,
      color: color,
    );
    categories.insert(0, category);
    await saveCustomCategories(listId, categories);
    
    // Also update the category order to include this new category at the top
    final order = await getCategoryOrder(listId);
    if (!order.contains(id)) {
      order.insert(0, id);
      await saveCategoryOrder(listId, order);
    }
    
    return category;
  }

  /// Delete a custom category from a specific list
  Future<void> deleteCustomCategory(String listId, String categoryId) async {
    final categories = await getCustomCategories(listId);
    categories.removeWhere((c) => c.id == categoryId);
    await saveCustomCategories(listId, categories);
    
    // Also remove from category order
    final order = await getCategoryOrder(listId);
    order.remove(categoryId);
    await saveCategoryOrder(listId, order);
  }

  /// Update a custom category
  Future<void> updateCustomCategory(String listId, CustomCategory category) async {
    final categories = await getCustomCategories(listId);
    final index = categories.indexWhere((c) => c.id == category.id);
    if (index != -1) {
      categories[index] = category;
      await saveCustomCategories(listId, categories);
    }
  }
}

/// A custom category created by the user for a specific list.
class CustomCategory {
  final String id;
  final String name;
  final Color color;

  CustomCategory({
    required this.id,
    required this.name,
    required this.color,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'color': color.value,
  };

  factory CustomCategory.fromJson(Map<String, dynamic> json) => CustomCategory(
    id: json['id'],
    name: json['name'],
    color: Color(json['color']),
  );
}

/// Screen for managing category order and custom categories for a specific list.
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
  final _activityService = ListActivityService();
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
    
    final customMap = {for (var c in customCategories) c.id: c};
    final builtInIds = Categories.allIds;
    
    final items = <_CategoryItem>[];
    
    // Add categories in order
    for (final id in order) {
      if (customMap.containsKey(id)) {
        final custom = customMap[id]!;
        items.add(_CategoryItem(
          id: id,
          name: custom.name,
          color: custom.color,
          isCustom: true,
        ));
      } else if (builtInIds.contains(id)) {
        final cat = Categories.getById(id);
        items.add(_CategoryItem(
          id: id,
          name: id, // Store ID for translation lookup
          color: cat.color,
          isCustom: false,
        ));
      }
    }
    
    // Add any built-in categories not in order yet
    for (final id in builtInIds) {
      if (!order.contains(id)) {
        final cat = Categories.getById(id);
        items.add(_CategoryItem(
          id: id,
          name: id, // Store ID for translation lookup
          color: cat.color,
          isCustom: false,
        ));
      }
    }
    
    // Add any custom categories not in order yet (at top)
    for (final custom in customCategories) {
      if (!order.contains(custom.id)) {
        items.insert(0, _CategoryItem(
          id: custom.id,
          name: custom.name,
          color: custom.color,
          isCustom: true,
        ));
      }
    }

    setState(() {
      _categories = items;
      _isLoading = false;
    });
  }

  Future<void> _saveOrder({bool logActivity = false}) async {
    final order = _categories.map((c) => c.id).toList();
    await _service.saveCategoryOrder(widget.listId, order);
    setState(() => _hasChanges = true);
    
    // Log activity and send notification for reorder
    if (logActivity) {
      await _activityService.logActivity(
        listId: widget.listId,
        type: ListActivityType.categoryReordered,
      );
      await _activityService.notifyCategoryChange(
        listId: widget.listId,
        listName: widget.listName,
        type: ListActivityType.categoryReordered,
      );
    }
  }

  void _showAddCategoryDialog() {
    final nameController = TextEditingController();
    Color selectedColor = AppColors.lightAccent;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
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
                        color: isDark ? Colors.white.withOpacity(0.4) : Colors.black.withOpacity(0.25),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    context.tr('add_category'),
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.5,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Glass text field
                  AdaptiveTextField(
                    controller: nameController,
                    placeholder: context.tr('category_name_hint'),
                    autofocus: true,
                    textCapitalization: TextCapitalization.sentences,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    context.tr('select_color'),
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
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
                    ].map((color) => GestureDetector(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setDialogState(() => selectedColor = color);
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          border: selectedColor == color
                              ? Border.all(color: isDark ? Colors.white : Colors.black, width: 3)
                              : Border.all(color: Colors.transparent, width: 3),
                          boxShadow: selectedColor == color
                              ? [BoxShadow(color: color.withOpacity(0.5), blurRadius: 8, spreadRadius: 2)]
                              : null,
                        ),
                      ),
                    )).toList(),
                  ),
                  const SizedBox(height: 28),
                  LiquidGlassFilledButton(
                    label: context.tr('add'),
                    onPressed: nameController.text.trim().isEmpty ? null : () async {
                      if (nameController.text.trim().isEmpty) return;
                      
                      final categoryName = nameController.text.trim();
                      final category = await _service.addCustomCategory(
                        widget.listId,
                        categoryName,
                        selectedColor,
                      );
                      
                      Navigator.pop(context);
                      
                      setState(() {
                        _categories.insert(0, _CategoryItem(
                          id: category.id,
                          name: category.name,
                          color: category.color,
                          isCustom: true,
                        ));
                        _hasChanges = true;
                      });
                      await _saveOrder();
                      
                      // Log activity and send notification
                      await _activityService.logActivity(
                        listId: widget.listId,
                        type: ListActivityType.categoryAdded,
                        metadata: {'categoryName': categoryName},
                      );
                      await _activityService.notifyCategoryChange(
                        listId: widget.listId,
                        listName: widget.listName,
                        type: ListActivityType.categoryAdded,
                        categoryName: categoryName,
                      );
                    },
                  ),
                  // Extra padding for iOS 26 home indicator/navbar
                  SizedBox(height: 34 + MediaQuery.of(context).viewPadding.bottom),
                ],
              ),
            ),
            ),
          );
        },
      ),
    );
  }

  void _showEditCategoryDialog(_CategoryItem category) {
    final nameController = TextEditingController(text: category.name);
    Color selectedColor = category.color;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
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
                        color: isDark ? Colors.white.withOpacity(0.4) : Colors.black.withOpacity(0.25),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    context.tr('edit_category'),
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.5,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Glass text field
                  AdaptiveTextField(
                    controller: nameController,
                    placeholder: context.tr('category_name'),
                    textCapitalization: TextCapitalization.sentences,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    context.tr('select_color'),
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
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
                    ].map((color) => GestureDetector(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setDialogState(() => selectedColor = color);
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          border: selectedColor == color
                              ? Border.all(color: isDark ? Colors.white : Colors.black, width: 3)
                              : Border.all(color: Colors.transparent, width: 3),
                          boxShadow: selectedColor == color
                              ? [BoxShadow(color: color.withOpacity(0.5), blurRadius: 8, spreadRadius: 2)]
                              : null,
                        ),
                      ),
                    )).toList(),
                  ),
                  const SizedBox(height: 28),
                  Row(
                    children: [
                      Expanded(
                        child: LiquidGlassOutlinedButton(
                          label: context.tr('delete'),
                          isDestructive: true,
                          onPressed: () => _showDeleteConfirmation(category),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: LiquidGlassFilledButton(
                          label: context.tr('save'),
                          onPressed: () async {
                            if (nameController.text.trim().isEmpty) return;
                            
                            final updated = CustomCategory(
                              id: category.id,
                              name: nameController.text.trim(),
                              color: selectedColor,
                            );
                            await _service.updateCustomCategory(widget.listId, updated);
                            
                            Navigator.pop(context);
                            
                            setState(() {
                              final index = _categories.indexWhere((c) => c.id == category.id);
                              if (index != -1) {
                                _categories[index] = _CategoryItem(
                                  id: category.id,
                                  name: nameController.text.trim(),
                                  color: selectedColor,
                                  isCustom: true,
                                );
                              }
                              _hasChanges = true;
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                  // Extra padding for iOS 26 home indicator/navbar
                  SizedBox(height: 34 + MediaQuery.of(context).viewPadding.bottom),
                ],
              ),
            ),
            ),
          );
        },
      ),
    );
  }

  void _showDeleteConfirmation(_CategoryItem category) {
    Navigator.pop(context); // Close edit sheet first
    final categoryName = category.name;
    
    AdaptiveAlertDialog.show(
      context: context,
      title: context.tr('delete_category'),
      message: context.tr('delete_category_confirm'),
      icon: PlatformInfo.isIOS26OrHigher() ? 'trash.fill' : Icons.delete,
      iconColor: Colors.red,
      actions: [
        AlertAction(
          title: context.tr('cancel'),
          style: AlertActionStyle.cancel,
          onPressed: () {},
        ),
        AlertAction(
          title: context.tr('delete'),
          style: AlertActionStyle.destructive,
          onPressed: () async {
            await _service.deleteCustomCategory(widget.listId, category.id);
            setState(() {
              _categories.removeWhere((c) => c.id == category.id);
              _hasChanges = true;
            });
            
            // Log activity and send notification
            await _activityService.logActivity(
              listId: widget.listId,
              type: ListActivityType.categoryRemoved,
              metadata: {'categoryName': categoryName},
            );
            await _activityService.notifyCategoryChange(
              listId: widget.listId,
              listName: widget.listName,
              type: ListActivityType.categoryRemoved,
              categoryName: categoryName,
            );
          },
        ),
      ],
    );
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
                onTap: _showAddCategoryDialog,
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
                      _saveOrder(logActivity: true);
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
                  onTap: () => _showEditCategoryDialog(category),
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

  IconData _getCategoryIcon(String categoryId) {
    try {
      return Categories.getById(categoryId).icon;
    } catch (e) {
      return Icons.category;
    }
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
}
