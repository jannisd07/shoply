import 'package:flutter/foundation.dart';
import 'package:shoply/data/services/supabase_service.dart';
import 'package:shoply/data/services/fcm_service.dart';

/// Service for diagnosing push notification issues
class NotificationDiagnosticService {
  static NotificationDiagnosticService? _instance;
  static NotificationDiagnosticService get instance {
    _instance ??= NotificationDiagnosticService._();
    return _instance!;
  }

  NotificationDiagnosticService._();

  final _supabase = SupabaseService.instance.client;

  /// Run full notification diagnostic
  Future<Map<String, dynamic>> runDiagnostic() async {
    final results = <String, dynamic>{};
    
    debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    debugPrint('🔍 NOTIFICATION DIAGNOSTIC STARTED');
    debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

    // 1. Check current user
    final currentUser = _supabase.auth.currentUser;
    results['currentUserId'] = currentUser?.id;
    results['userLoggedIn'] = currentUser != null;
    debugPrint('1️⃣ Current User: ${currentUser?.id ?? "NOT LOGGED IN"}');

    if (currentUser == null) {
      debugPrint('❌ User not logged in - cannot proceed');
      return results;
    }

    // 2. Check FCM token in memory
    final fcmToken = FCMService.instance.token;
    results['fcmTokenInMemory'] = fcmToken != null;
    results['fcmTokenLength'] = fcmToken?.length ?? 0;
    debugPrint('2️⃣ FCM Token in Memory: ${fcmToken != null ? "YES (${fcmToken.length} chars)" : "NO"}');

    // 3. Check FCM token in database
    try {
      final userResponse = await _supabase
          .from('users')
          .select('fcm_token, display_name')
          .eq('id', currentUser.id)
          .single();
      
      final dbToken = userResponse['fcm_token'] as String?;
      final displayName = userResponse['display_name'] as String?;
      results['fcmTokenInDb'] = dbToken != null && dbToken.isNotEmpty;
      results['fcmTokenDbLength'] = dbToken?.length ?? 0;
      results['displayName'] = displayName;
      debugPrint('3️⃣ FCM Token in Database: ${dbToken != null && dbToken.isNotEmpty ? "YES (${dbToken.length} chars)" : "NO"}');
      debugPrint('   Display Name: $displayName');
      
      // Check if tokens match
      if (fcmToken != null && dbToken != null) {
        final tokensMatch = fcmToken == dbToken;
        results['tokensMatch'] = tokensMatch;
        debugPrint('   Tokens Match: ${tokensMatch ? "✅ YES" : "❌ NO"}');
      }
    } catch (e) {
      debugPrint('❌ Failed to fetch user data: $e');
      results['dbError'] = e.toString();
    }

    // 4. Check if user is member of any shared lists
    try {
      final memberships = await _supabase
          .from('list_members')
          .select('list_id, shopping_lists(name)')
          .eq('user_id', currentUser.id);
      
      results['listMemberships'] = (memberships as List).length;
      debugPrint('4️⃣ List Memberships: ${(memberships).length}');
      for (final m in memberships) {
        final listName = m['shopping_lists']?['name'] ?? 'Unknown';
        debugPrint('   - $listName');
      }
    } catch (e) {
      debugPrint('❌ Failed to fetch memberships: $e');
    }

    // 5. Test Edge Function connectivity
    debugPrint('5️⃣ Testing Edge Function...');
    try {
      final testResult = await testEdgeFunctionConnectivity();
      results['edgeFunctionConnected'] = testResult['success'];
      results['edgeFunctionError'] = testResult['error'];
      debugPrint('   Edge Function: ${testResult['success'] ? "✅ Connected" : "❌ Error: ${testResult['error']}"}');
    } catch (e) {
      results['edgeFunctionError'] = e.toString();
      debugPrint('   Edge Function: ❌ $e');
    }

    debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    debugPrint('🔍 DIAGNOSTIC COMPLETE');
    debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

    return results;
  }

  /// Test Edge Function connectivity
  Future<Map<String, dynamic>> testEdgeFunctionConnectivity() async {
    try {
      // Send a test notification to ourselves with a dummy token
      // This will fail but tells us if the function is reachable
      final response = await _supabase.functions.invoke(
        'send-push-notification',
        body: {
          'token': 'test_connectivity_check',
          'notification': {
            'title': 'Test',
            'body': 'Connectivity test',
          },
          'data': {},
        },
      );

      // Even if it fails (token invalid), we know the function is reachable
      final data = response.data as Map<String, dynamic>?;
      debugPrint('   Edge Function Response: ${response.status}');
      if (data?['debug'] != null) {
        debugPrint('   Debug logs from Edge Function:');
        for (final line in (data!['debug'] as List)) {
          debugPrint('      $line');
        }
      }
      
      // If we get any response, the function is connected
      return {'success': true, 'status': response.status, 'data': data};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Send a test notification to the current user
  Future<bool> sendTestNotificationToSelf() async {
    debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    debugPrint('📤 SENDING TEST NOTIFICATION TO SELF');
    debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

    final currentUser = _supabase.auth.currentUser;
    if (currentUser == null) {
      debugPrint('❌ No user logged in');
      return false;
    }

    try {
      // Get current user's FCM token from database
      final userResponse = await _supabase
          .from('users')
          .select('fcm_token, display_name')
          .eq('id', currentUser.id)
          .single();

      final fcmToken = userResponse['fcm_token'] as String?;
      final displayName = userResponse['display_name'] as String? ?? 'User';

      if (fcmToken == null || fcmToken.isEmpty) {
        debugPrint('❌ No FCM token found in database');
        debugPrint('   Please ensure push notifications are enabled');
        return false;
      }

      debugPrint('📱 FCM Token: ${fcmToken.substring(0, 40)}...');
      debugPrint('👤 Sending to: $displayName');

      // Send test notification via Edge Function
      final response = await _supabase.functions.invoke(
        'send-push-notification',
        body: {
          'token': fcmToken,
          'notification': {
            'title': '🧪 Test Notification',
            'body': 'If you see this, push notifications are working!',
          },
          'data': {
            'type': 'test',
            'timestamp': DateTime.now().toIso8601String(),
          },
        },
      );

      final data = response.data as Map<String, dynamic>?;
      debugPrint('📨 Response Status: ${response.status}');
      
      if (data?['debug'] != null) {
        debugPrint('📋 Debug logs:');
        for (final line in (data!['debug'] as List)) {
          debugPrint('   $line');
        }
      }

      if (response.status == 200) {
        debugPrint('✅ Test notification sent successfully!');
        debugPrint('   Check your device for the notification');
        return true;
      } else {
        debugPrint('❌ Failed: ${data?['error'] ?? 'Unknown error'}');
        return false;
      }
    } catch (e) {
      debugPrint('❌ Error sending test notification: $e');
      return false;
    }
  }

  /// Force save FCM token to database
  Future<bool> forceSaveFcmToken() async {
    debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    debugPrint('💾 FORCE SAVING FCM TOKEN');
    debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

    try {
      await FCMService.instance.saveTokenForCurrentUser();
      
      // Verify it was saved
      final currentUser = _supabase.auth.currentUser;
      if (currentUser != null) {
        final userResponse = await _supabase
            .from('users')
            .select('fcm_token')
            .eq('id', currentUser.id)
            .single();
        
        final savedToken = userResponse['fcm_token'] as String?;
        if (savedToken != null && savedToken.isNotEmpty) {
          debugPrint('✅ Token saved successfully (${savedToken.length} chars)');
          return true;
        }
      }
      
      debugPrint('❌ Token not saved');
      return false;
    } catch (e) {
      debugPrint('❌ Error: $e');
      return false;
    }
  }
}
