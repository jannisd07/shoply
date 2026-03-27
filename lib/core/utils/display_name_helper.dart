/// Helper to get a proper display name for users
/// Returns "User" if the display name is null, empty, or looks like an email
class DisplayNameHelper {
  /// Check if a string looks like an email address
  static bool _isEmail(String? value) {
    if (value == null || value.isEmpty) return false;
    return value.contains('@') && value.contains('.');
  }

  /// Get the display name to show in the UI
  /// Returns "User" if displayName is null, empty, or looks like an email
  static String getDisplayName(String? displayName, {String fallback = 'User'}) {
    if (displayName == null || displayName.trim().isEmpty) {
      return fallback;
    }
    
    // If the display name looks like an email, return fallback
    if (_isEmail(displayName)) {
      return fallback;
    }
    
    return displayName.trim();
  }

  /// Check if user needs to set their name
  /// Returns true if displayName is null, empty, or looks like an email
  static bool needsNamePrompt(String? displayName) {
    if (displayName == null || displayName.trim().isEmpty) {
      return true;
    }
    return _isEmail(displayName);
  }
}
