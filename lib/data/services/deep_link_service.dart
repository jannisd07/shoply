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
  static const String webDomain = 'shoplyai.app';
  static const String webScheme = 'https';
  
  // Custom URL scheme for fallback
  static const String customScheme = 'shoply';

  final _appLinks = AppLinks();
  GoRouter? _router;
  StreamSubscription<Uri>? _linkSubscription;
  bool _isInitialized = false;

  // Last handled link, used to drop a duplicate delivery of the same URI.
  String? _lastLink;
  DateTime? _lastLinkAt;
  static const _duplicateWindow = Duration(seconds: 2);

  /// Handles `shoply://add-item?name=...&list=...&quantity=...` — fired by
  /// the Siri/Shortcuts "add item" App Intent (see `AppIntents.swift`). Set
  /// once during app init (in `app.dart`, where a Riverpod `ref` is
  /// available) since this service itself has no provider access.
  Future<void> Function(String itemName, String listName, double? quantity)?
      onAddItemRequested;

  /// Handles `shoply://create-list?name=...` — fired by the Siri/Shortcuts
  /// "create list" App Intent.
  Future<void> Function(String listName)? onCreateListRequested;

  /// Initialize the deep link service with the app router.
  ///
  /// app_links (>= 6.0) delivers the initial link (app cold-started from a
  /// link) on [AppLinks.uriLinkStream] too, so subscribing is enough; reading
  /// `getInitialLink()` as well would handle that link twice.
  Future<void> initialize(GoRouter router) async {
    if (_isInitialized) return;

    _router = router;
    _isInitialized = true;

    _linkSubscription = _appLinks.uriLinkStream.listen(
      _handleDeepLink,
      onError: (error) {
        debugPrint('⚠️ [DEEP_LINK] Link stream error: $error');
      },
    );

    debugPrint('✅ [DEEP_LINK] DeepLinkService initialized');
  }

  /// Handle incoming deep link
  void _handleDeepLink(Uri uri) {
    final link = uri.toString();
    final now = DateTime.now();
    if (link == _lastLink &&
        _lastLinkAt != null &&
        now.difference(_lastLinkAt!) < _duplicateWindow) {
      debugPrint('⚠️ [DEEP_LINK] Ignoring duplicate link: $link');
      return;
    }
    _lastLink = link;
    _lastLinkAt = now;

    debugPrint('🔗 [DEEP_LINK] Received link: $uri');

    // Action-type links (Siri/Shortcuts) perform a data mutation instead of a
    // plain navigation — handle them before the path-based routing below.
    if (uri.scheme == customScheme && _handleActionLink(uri)) return;

    // Handle different link types
    final path = _extractPath(uri);
    if (path != null) {
      debugPrint('🔗 [DEEP_LINK] Navigating to: $path');
      _router!.go(path);
    }
  }

  /// Handles Siri/Shortcuts action links (`add-item`, `create-list`) that
  /// mutate app data rather than just navigate. Returns true if [uri] was an
  /// action link (handled or not — either way, normal navigation is skipped).
  bool _handleActionLink(Uri uri) {
    switch (uri.host) {
      case 'add-item':
        final name = uri.queryParameters['name'];
        final list = uri.queryParameters['list'];
        if (name == null || name.isEmpty || list == null || list.isEmpty) {
          debugPrint('⚠️ [DEEP_LINK] add-item missing name/list: $uri');
          return true;
        }
        final quantity = double.tryParse(uri.queryParameters['quantity'] ?? '');
        final handler = onAddItemRequested;
        if (handler == null) {
          debugPrint('⚠️ [DEEP_LINK] add-item received before app was ready');
          return true;
        }
        unawaited(handler(name, list, quantity));
        return true;

      case 'create-list':
        final name = uri.queryParameters['name'];
        if (name == null || name.isEmpty) {
          debugPrint('⚠️ [DEEP_LINK] create-list missing name: $uri');
          return true;
        }
        final handler = onCreateListRequested;
        if (handler == null) {
          debugPrint('⚠️ [DEEP_LINK] create-list received before app was ready');
          return true;
        }
        unawaited(handler(name));
        return true;

      default:
        return false;
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
          return '/list/${segments[1]}';
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
          return '/list/${segments[0]}';
        }
        return '/home';

      case 'lists':
        // No standalone "all lists" screen — Home is the lists overview.
        return '/home';

      case 'recipes':
        if (segments.isNotEmpty) {
          switch (segments[0]) {
            case 'saved':
              return '/recipes/saved';
            case 'search':
              final q = uri.queryParameters['q'] ?? '';
              return Uri(path: '/recipes', queryParameters: {'q': q}).toString();
          }
        }
        return '/recipes';

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

  /// Dispose of resources
  void dispose() {
    _linkSubscription?.cancel();
    _isInitialized = false;
  }
}
