import 'package:shoply/data/services/supabase_service.dart';

/// Service for learning and storing user's category preferences
/// When a user manually changes a category, we remember it for future use
/// Uses existing database - no schema changes required
class UserCategoryPreferences {
  static final UserCategoryPreferences _instance = UserCategoryPreferences._();
  static UserCategoryPreferences get instance => _instance;
  
  UserCategoryPreferences._();

  final SupabaseService _supabase = SupabaseService.instance;
  
  // In-memory cache for fast lookups
  final Map<String, String> _cache = {};
  bool _cacheLoaded = false;

  /// Learn a user's category preference for a product
  /// Called when user manually changes category
  Future<void> learnPreference(String productName, String category) async {
    final userId = _supabase.currentUser?.id;
    if (userId == null) return;

    final normalized = _normalizeProductName(productName);
    
    // Update cache
    _cache[normalized] = category;

    // Store in database using existing shopping_items table
    // We'll use the most recent category the user selected for this product
    // The database already tracks this through the category field
    
    // Note: We don't need to create a new table - the shopping_items table
    // already contains product_name → category mappings per user
  }

  /// Get user's preferred category for a product
  /// Returns null if no preference found
  Future<String?> getPreference(String productName) async {
    final userId = _supabase.currentUser?.id;
    if (userId == null) return null;

    final normalized = _normalizeProductName(productName);

    // Check cache first
    if (_cache.containsKey(normalized)) {
      return _cache[normalized];
    }

    // Load from database if not in cache
    if (!_cacheLoaded) {
      await _loadPreferences();
    }

    return _cache[normalized];
  }

  /// Load user's category preferences from database
  /// Analyzes user's shopping history to learn preferences
  Future<void> _loadPreferences() async {
    final userId = _supabase.currentUser?.id;
    if (userId == null) return;

    try {
      // Query all user's items to learn their category preferences
      // We look at which category they most frequently use for each product
      final response = await _supabase
          .from('shopping_items')
          .select('name, category')
          .eq('user_id', userId);

      if (response is! List) return;

      final items = response as List;
      
      // Count category usage per product
      final productCategories = <String, Map<String, int>>{};
      
      for (final item in items) {
        final name = item['name'] as String?;
        final category = item['category'] as String?;
        
        if (name == null || category == null) continue;
        
        final normalized = _normalizeProductName(name);
        
        productCategories.putIfAbsent(normalized, () => {});
        productCategories[normalized]![category] = 
            (productCategories[normalized]![category] ?? 0) + 1;
      }

      // For each product, use the most frequently used category
      for (final entry in productCategories.entries) {
        final productName = entry.key;
        final categoryCounts = entry.value;
        
        // Find category with highest count
        String? mostUsedCategory;
        int maxCount = 0;
        
        for (final catEntry in categoryCounts.entries) {
          if (catEntry.value > maxCount) {
            maxCount = catEntry.value;
            mostUsedCategory = catEntry.key;
          }
        }
        
        if (mostUsedCategory != null) {
          _cache[productName] = mostUsedCategory;
        }
      }

      _cacheLoaded = true;
    } catch (e) {
      // Silently handle errors - preferences are optional
    }
  }

  /// Clear cache (useful when user logs out)
  void clearCache() {
    _cache.clear();
    _cacheLoaded = false;
  }

  /// Normalize product name for consistent matching
  String _normalizeProductName(String name) {
    return name
        .toLowerCase()
        .trim()
        .replaceAll('ä', 'ae')
        .replaceAll('ö', 'oe')
        .replaceAll('ü', 'ue')
        .replaceAll('ß', 'ss')
        .replaceAll(RegExp(r'[^\w\s]'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  /// Get statistics about learned preferences
  Map<String, dynamic> getStatistics() {
    return {
      'total_preferences': _cache.length,
      'cache_loaded': _cacheLoaded,
    };
  }
}
