import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:shoply/core/constants/categories.dart';
import 'package:shoply/data/models/custom_category.dart';
import 'package:shoply/data/services/supabase_service.dart';

/// Per-list category order and custom categories.
///
/// Both live in this device's SharedPreferences only, so they are not
/// shared with other list members.
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
    // Default order: custom categories first, then built-in
    final customCategories = await getCustomCategories(listId);
    return [...customCategories.map((c) => c.id), ...Categories.allIds];
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
    return list
        .map((e) => CustomCategory.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Save custom categories for a specific list
  Future<void> saveCustomCategories(
    String listId,
    List<CustomCategory> categories,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final json = jsonEncode(categories.map((e) => e.toJson()).toList());
    await prefs.setString('custom_categories_$listId', json);
  }

  /// Add a custom category to a specific list (inserted at top)
  Future<CustomCategory> addCustomCategory(
    String listId,
    String name,
    Color color,
  ) async {
    final categories = await getCustomCategories(listId);
    final category = CustomCategory(
      id: 'custom_${DateTime.now().millisecondsSinceEpoch}',
      name: name,
      color: color,
    );
    categories.insert(0, category);
    await saveCustomCategories(listId, categories);

    final order = await getCategoryOrder(listId);
    if (!order.contains(category.id)) {
      order.insert(0, category.id);
      await saveCategoryOrder(listId, order);
    }

    return category;
  }

  /// Delete a custom category from a specific list. Items that were filed
  /// under it move back to 'other' so they don't point at a missing id.
  Future<void> deleteCustomCategory(String listId, String categoryId) async {
    final categories = await getCustomCategories(listId);
    categories.removeWhere((c) => c.id == categoryId);
    await saveCustomCategories(listId, categories);

    final order = await getCategoryOrder(listId);
    order.remove(categoryId);
    await saveCategoryOrder(listId, order);

    try {
      await SupabaseService.instance
          .from('shopping_items')
          .update({'category_id': 'other'})
          .eq('list_id', listId)
          .eq('category_id', categoryId);
    } catch (e) {
      debugPrint('❌ [CATEGORY_ORDER] Failed to reassign items: $e');
    }
  }

  /// Update a custom category
  Future<void> updateCustomCategory(
    String listId,
    CustomCategory category,
  ) async {
    final categories = await getCustomCategories(listId);
    final index = categories.indexWhere((c) => c.id == category.id);
    if (index != -1) {
      categories[index] = category;
      await saveCustomCategories(listId, categories);
    }
  }
}
