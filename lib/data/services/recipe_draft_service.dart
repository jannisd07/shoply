import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shoply/data/models/recipe_draft.dart';

/// Service for managing recipe drafts stored locally
class RecipeDraftService {
  static const String _draftsKey = 'recipe_drafts';
  
  /// Get all saved drafts
  Future<List<RecipeDraft>> getDrafts() async {
    final prefs = await SharedPreferences.getInstance();
    final draftsJson = prefs.getString(_draftsKey);
    
    if (draftsJson == null || draftsJson.isEmpty) {
      return [];
    }
    
    try {
      final List<dynamic> decoded = jsonDecode(draftsJson);
      return decoded
          .map((d) => RecipeDraft.fromJson(d as Map<String, dynamic>))
          .toList()
        ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt)); // Most recent first
    } catch (e) {
      print('❌ [DRAFT] Error loading drafts: $e');
      return [];
    }
  }
  
  /// Get a specific draft by ID
  Future<RecipeDraft?> getDraft(String id) async {
    final drafts = await getDrafts();
    try {
      return drafts.firstWhere((d) => d.id == id);
    } catch (_) {
      return null;
    }
  }
  
  /// Save or update a draft
  Future<RecipeDraft> saveDraft(RecipeDraft draft) async {
    final drafts = await getDrafts();
    final existingIndex = drafts.indexWhere((d) => d.id == draft.id);
    
    final updatedDraft = draft.copyWith(updatedAt: DateTime.now());
    
    if (existingIndex >= 0) {
      drafts[existingIndex] = updatedDraft;
    } else {
      drafts.add(updatedDraft);
    }
    
    await _saveDrafts(drafts);
    print('✅ [DRAFT] Saved draft: ${updatedDraft.name}');
    return updatedDraft;
  }
  
  /// Delete a draft
  Future<void> deleteDraft(String id) async {
    final drafts = await getDrafts();
    drafts.removeWhere((d) => d.id == id);
    await _saveDrafts(drafts);
    print('✅ [DRAFT] Deleted draft: $id');
  }
  
  /// Create a new empty draft
  RecipeDraft createNewDraft() {
    final now = DateTime.now();
    return RecipeDraft(
      id: 'draft_${now.millisecondsSinceEpoch}',
      name: '',
      description: '',
      ingredients: [],
      instructions: [],
      createdAt: now,
      updatedAt: now,
    );
  }
  
  /// Save all drafts to SharedPreferences
  Future<void> _saveDrafts(List<RecipeDraft> drafts) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(drafts.map((d) => d.toJson()).toList());
    await prefs.setString(_draftsKey, encoded);
  }
}
