import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';

class UnreadService {
  static const String _prefix = 'last_seen_list_';

  /// Markiert eine Liste als gelesen (speichert aktuellen Zeitstempel in UTC)
  Future<void> markAsRead(String listId) async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now().toUtc();
    await prefs.setString('$_prefix$listId', now.toIso8601String());
    
    if (kDebugMode) {
      print('🔵 [UnreadService] Mark as read: $listId at $now');
    }
  }

  /// Prüft, ob eine Liste ungelesene Änderungen hat
  /// Vergleicht lastUpdated (aus DB) mit lokalem lastSeen
  Future<bool> isUnread(String listId, DateTime? lastUpdated) async {
    if (lastUpdated == null) return false;

    final prefs = await SharedPreferences.getInstance();
    final lastSeenStr = prefs.getString('$_prefix$listId');

    // Normalize lastUpdated to UTC for comparison
    final lastUpdatedUtc = lastUpdated.toUtc();

    if (lastSeenStr == null) {
      // Wenn noch nie gesehen, ist sie "ungelesen" (oder neu)
      if (kDebugMode) {
        print('🔵 [UnreadService] List $listId is NEW/UNREAD (never seen)');
      }
      return true;
    }

    final lastSeen = DateTime.parse(lastSeenStr).toUtc();
    
    // Vergleich
    final isUnread = lastUpdatedUtc.isAfter(lastSeen);

    // Debugging (nur wenn sich Status ändern könnte oder relevant ist)
    // Wir loggen nicht alles, um die Konsole nicht zu fluten, aber bei "true" ist es interessant.
    if (kDebugMode && isUnread) {
       print('🔵 [UnreadService] List $listId is UNREAD!');
       print('   Updated (UTC): $lastUpdatedUtc');
       print('   Seen    (UTC): $lastSeen');
    }

    return isUnread;
  }
}
