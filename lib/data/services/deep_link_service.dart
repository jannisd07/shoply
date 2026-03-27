import 'dart:async';
import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';

/// Service for handling deep links and universal/app links
/// Supports both custom scheme (shoply://) and HTTPS universal links
class DeepLinkService {
  static final DeepLinkService instance = DeepLinkService._();
  DeepLinkService._();

  // Domain for universal links
  static const String webDomain = 'www.shoplyai.app';
  static const String webScheme = 'https';
  
  // Custom URL scheme for fallback
  static const String customScheme = 'shoply';

  final _appLinks = AppLinks();
  GoRouter? _router;
  StreamSubscription<Uri>? _linkSubscription;
  String? _pendingDeepLink;
  bool _isInitialized = false;

  /// Initialize the deep link service with the app router
  Future<void> initialize(GoRouter router) async {
    if (_isInitialized) return;
    
    _router = router;
    _isInitialized = true;
    
    debugPrint('🔗 [DEEP_LINK] Initializing DeepLinkService...');

    // Handle initial link (app opened from link while closed)
    try {
      final initialUri = await _appLinks.getInitialLink();
      if (initialUri != null) {
        debugPrint('🔗 [DEEP_LINK] Initial link: $initialUri');
        _pendingDeepLink = initialUri.toString();
      }
    } catch (e) {
      debugPrint('⚠️ [DEEP_LINK] Error getting initial link: $e');
    }

    // Listen for incoming links while app is running
    _setupLinkStream();

    debugPrint('✅ [DEEP_LINK] DeepLinkService initialized');
  }

  /// Setup stream listener for incoming links
  void _setupLinkStream() {
    _linkSubscription = _appLinks.uriLinkStream.listen(
      (Uri uri) {
        debugPrint('🔗 [DEEP_LINK] Received link: $uri');
        _handleDeepLink(uri.toString());
      },
      onError: (error) {
        debugPrint('⚠️ [DEEP_LINK] Link stream error: $error');
      },
    );
  }

  /// Process any pending deep link (call after app is fully loaded)
  void processPendingDeepLink() {
    if (_pendingDeepLink != null) {
      debugPrint('🔗 [DEEP_LINK] Processing pending link: $_pendingDeepLink');
      _handleDeepLink(_pendingDeepLink!);
      _pendingDeepLink = null;
    }
  }

  /// Handle incoming deep link
  void _handleDeepLink(String link) {
    if (_router == null) {
      debugPrint('⚠️ [DEEP_LINK] Router not initialized, storing link');
      _pendingDeepLink = link;
      return;
    }

    final uri = Uri.tryParse(link);
    if (uri == null) {
      debugPrint('❌ [DEEP_LINK] Invalid URI: $link');
      return;
    }

    debugPrint('🔗 [DEEP_LINK] Parsing URI: $uri');
    debugPrint('   - Scheme: ${uri.scheme}');
    debugPrint('   - Host: ${uri.host}');
    debugPrint('   - Path: ${uri.path}');
    debugPrint('   - Segments: ${uri.pathSegments}');

    // Handle different link types
    final path = _extractPath(uri);
    if (path != null) {
      debugPrint('🔗 [DEEP_LINK] Navigating to: $path');
      _router!.go(path);
    }
  }

  /// Extract the navigation path from a URI
  String? _extractPath(Uri uri) {
    // Handle HTTPS universal links
    if (uri.scheme == 'https' || uri.scheme == 'http') {
      return _parseWebPath(uri);
    }
    
    // Handle custom scheme (shoply://)
    if (uri.scheme == customScheme) {
      return _parseCustomSchemePath(uri);
    }

    return null;
  }

  /// Parse path from web URL (universal/app links)
  String? _parseWebPath(Uri uri) {
    final segments = uri.pathSegments;
    if (segments.isEmpty) return '/home';

    switch (segments[0]) {
      case 'recipe':
        if (segments.length >= 2) {
          return '/recipe/${segments[1]}';
        }
        return '/recipes';
        
      case 'list':
        if (segments.length >= 2) {
          return '/lists/${segments[1]}';
        }
        return '/home';
        
      case 'author':
        if (segments.length >= 2) {
          return '/author/${segments[1]}';
        }
        return '/recipes';
        
      case 'invite':
        // Handle list invite links
        if (segments.length >= 2) {
          return '/invite/${segments[1]}';
        }
        return '/home';
        
      default:
        return '/home';
    }
  }

  /// Parse path from custom scheme URL (shoply://)
  String? _parseCustomSchemePath(Uri uri) {
    final host = uri.host;
    final segments = uri.pathSegments;

    switch (host) {
      case 'recipe':
        if (segments.isNotEmpty) {
          return '/recipe/${segments[0]}';
        }
        return '/recipes';
        
      case 'list':
        if (segments.isNotEmpty) {
          return '/lists/${segments[0]}';
        }
        return '/home';
        
      case 'author':
        if (segments.isNotEmpty) {
          return '/author/${segments[0]}';
        }
        return '/recipes';
        
      case 'addItem':
        // Google Assistant action
        return '/home';
        
      default:
        // Handle path-based format (shoply:///recipe/123)
        if (uri.path.isNotEmpty) {
          return uri.path;
        }
        return '/home';
    }
  }

  /// Generate a shareable web URL for a recipe
  static String getRecipeShareUrl(String recipeId) {
    return '$webScheme://$webDomain/recipe/$recipeId';
  }

  /// Generate a shareable web URL for a list
  static String getListShareUrl(String listId) {
    return '$webScheme://$webDomain/list/$listId';
  }

  /// Generate a shareable web URL for a list invite
  static String getListInviteUrl(String listId, {String? inviteCode}) {
    final baseUrl = '$webScheme://$webDomain/invite/$listId';
    if (inviteCode != null) {
      return '$baseUrl?code=$inviteCode';
    }
    return baseUrl;
  }

  /// Generate a shareable web URL for an author profile
  static String getAuthorShareUrl(String authorId) {
    return '$webScheme://$webDomain/author/$authorId';
  }

  /// Generate a deep link (custom scheme) for a recipe
  static String getRecipeDeepLink(String recipeId) {
    return '$customScheme://recipe/$recipeId';
  }

  /// Generate a deep link (custom scheme) for a list
  static String getListDeepLink(String listId) {
    return '$customScheme://list/$listId';
  }

  /// Dispose of resources
  void dispose() {
    _linkSubscription?.cancel();
    _isInitialized = false;
  }
}
