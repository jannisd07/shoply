class AppConfig {
  // Share link configuration
  // TODO: Replace with your actual domain
  static const String shareDomain = 'https://shoplyai.app';
  static const String sharePathPrefix = '/join';
  
  /// Generate a share link for a list
  static String generateShareLink(String shareCode) {
    return '$shareDomain$sharePathPrefix/$shareCode';
  }
  
  /// Extract share code from a share link
  static String? extractShareCodeFromLink(String link) {
    final uri = Uri.tryParse(link);
    if (uri == null) return null;
    
    // Check if it's a valid share link
    if (uri.host != Uri.parse(shareDomain).host) return null;
    
    // Extract code from path
    final segments = uri.pathSegments;
    if (segments.length >= 2 && segments[0] == 'join') {
      return segments[1].toUpperCase();
    }
    
    return null;
  }
}
