import 'package:flutter/foundation.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shoply/data/models/recipe.dart';
import 'package:shoply/data/services/deep_link_service.dart';

/// Service for sharing content using native share dialogs
/// Supports recipes, shopping lists, and custom content
class SharingService {
  static final SharingService instance = SharingService._();
  SharingService._();

  /// Share a recipe using native share dialog
  Future<ShareResult> shareRecipe(Recipe recipe) async {
    final shareUrl = DeepLinkService.getRecipeShareUrl(recipe.id);
    final shareText = _buildRecipeShareText(recipe, shareUrl);
    
    debugPrint('📤 [SHARING] Sharing recipe: ${recipe.name}');
    debugPrint('   URL: $shareUrl');
    
    return Share.shareWithResult(
      shareText,
      subject: '🍳 ${recipe.name} - Shoply Recipe',
    );
  }

  /// Share a shopping list using native share dialog
  Future<ShareResult> shareList({
    required String listId,
    required String listName,
    int? itemCount,
  }) async {
    final shareUrl = DeepLinkService.getListShareUrl(listId);
    final shareText = _buildListShareText(listName, shareUrl, itemCount);
    
    debugPrint('📤 [SHARING] Sharing list: $listName');
    debugPrint('   URL: $shareUrl');
    
    return Share.shareWithResult(
      shareText,
      subject: '🛒 $listName - Shoply List',
    );
  }

  /// Share a list invite link
  Future<ShareResult> shareListInvite({
    required String listId,
    required String listName,
    String? inviteCode,
  }) async {
    final shareUrl = DeepLinkService.getListInviteUrl(listId, inviteCode: inviteCode);
    
    final shareText = '''
Join my shopping list "$listName" on Shoply! 🛒

$shareUrl

Open the link to collaborate on shopping lists together!
''';
    
    debugPrint('📤 [SHARING] Sharing list invite: $listName');
    debugPrint('   URL: $shareUrl');
    
    return Share.shareWithResult(
      shareText,
      subject: '🛒 Join $listName on Shoply',
    );
  }

  /// Share an author profile
  Future<ShareResult> shareAuthor({
    required String authorId,
    required String authorName,
    int? recipeCount,
  }) async {
    final shareUrl = DeepLinkService.getAuthorShareUrl(authorId);
    
    String shareText = 'Check out $authorName on Shoply! 👨‍🍳\n\n';
    if (recipeCount != null && recipeCount > 0) {
      shareText += '$recipeCount recipes to explore!\n\n';
    }
    shareText += shareUrl;
    
    debugPrint('📤 [SHARING] Sharing author: $authorName');
    debugPrint('   URL: $shareUrl');
    
    return Share.shareWithResult(
      shareText,
      subject: '👨‍🍳 $authorName on Shoply',
    );
  }

  /// Share custom content with a URL
  Future<ShareResult> shareCustom({
    required String title,
    required String body,
    required String url,
  }) async {
    final shareText = '$body\n\n$url';
    
    debugPrint('📤 [SHARING] Sharing custom content: $title');
    debugPrint('   URL: $url');
    
    return Share.shareWithResult(
      shareText,
      subject: title,
    );
  }

  /// Build share text for a recipe
  String _buildRecipeShareText(Recipe recipe, String shareUrl) {
    final buffer = StringBuffer();
    
    buffer.writeln('🍳 Check out this recipe: ${recipe.name}');
    buffer.writeln();
    
    // Add time info
    if (recipe.totalTimeMinutes > 0) {
      buffer.writeln('⏱ Ready in ${recipe.totalTimeMinutes} min');
    }
    
    // Add rating info
    if (recipe.ratingCount > 0) {
      buffer.writeln('⭐ ${recipe.averageRating.toStringAsFixed(1)} (${recipe.ratingCount} ratings)');
    }
    
    // Add servings info
    if (recipe.defaultServings > 0) {
      buffer.writeln('🍽 ${recipe.defaultServings} servings');
    }
    
    // Add description preview
    if (recipe.description.isNotEmpty) {
      final description = recipe.description.length > 100
          ? '${recipe.description.substring(0, 100)}...'
          : recipe.description;
      buffer.writeln();
      buffer.writeln(description);
    }
    
    buffer.writeln();
    buffer.writeln(shareUrl);
    
    return buffer.toString();
  }

  /// Build share text for a shopping list
  String _buildListShareText(String listName, String shareUrl, int? itemCount) {
    final buffer = StringBuffer();
    
    buffer.writeln('🛒 Check out this shopping list: $listName');
    buffer.writeln();
    
    if (itemCount != null && itemCount > 0) {
      buffer.writeln('📝 $itemCount items');
      buffer.writeln();
    }
    
    buffer.writeln(shareUrl);
    
    return buffer.toString();
  }

  /// Get share text for a recipe (without actually sharing)
  String getRecipeShareText(Recipe recipe) {
    final shareUrl = DeepLinkService.getRecipeShareUrl(recipe.id);
    return _buildRecipeShareText(recipe, shareUrl);
  }

  /// Get share URL for a recipe
  String getRecipeShareUrl(String recipeId) {
    return DeepLinkService.getRecipeShareUrl(recipeId);
  }

  /// Get share URL for a list
  String getListShareUrl(String listId) {
    return DeepLinkService.getListShareUrl(listId);
  }
}
