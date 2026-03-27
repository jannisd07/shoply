import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shoply/core/mascot/avo_mascot.dart';
import 'package:shoply/data/services/notification_service.dart';

/// Service for sending Avo mascot-based notifications with gamification
/// Manages when and what type of motivational notifications to send
class MascotNotificationService {
  static MascotNotificationService? _instance;
  static MascotNotificationService get instance {
    _instance ??= MascotNotificationService._();
    return _instance!;
  }

  MascotNotificationService._();

  static const String _lastNotificationKey = 'avo_last_notification';
  static const String _notificationCountKey = 'avo_notification_count';
  static const String _lastActiveKey = 'avo_last_active';
  static const String _streakKey = 'avo_streak_days';
  static const String _languageKey = 'app_language';

  final Random _random = Random();

  /// Get stored language preference (default to 'en')
  Future<String> _getLanguage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_languageKey) ?? 'en';
    } catch (e) {
      return 'en';
    }
  }

  /// Messages in both languages - consolidated for 4 expression states
  Map<AvoExpression, List<String>> _getMessages(String lang) {
    if (lang == 'de') {
      return {
        AvoExpression.neutral: [
          'Ich vermisse dich! Lange nicht gesehen...',
          'Deine Einkaufsliste wartet auf dich...',
          'Komm zurück! Ich hab tolle Rezepte! 💚',
          'Hey Freund, lass uns was planen!',
        ],
        AvoExpression.happy: [
          'Hey! Bereit für deine Einkaufsliste? 🛒',
          'Super gemacht! Weiter so! ✨',
          'Deine Listen sehen heute toll aus!',
          'Einkaufen leicht gemacht! 💚',
          'Juhu! Du warst super organisiert! 🎉',
          'Toll! Du hast deinen Einkauf erledigt! 🌟',
          'Hey! 👋 Bereit zum Einkaufen?',
          'Willkommen zurück! Lass uns loslegen!',
        ],
        AvoExpression.confused: [
          'Hmm... vielleicht was zur Liste hinzufügen? 🤔',
          'Ich überlege... was brauchst du heute?',
          'Hast du was auf deiner Liste vergessen?',
          'Lass mich dir beim Planen helfen!',
        ],
        AvoExpression.success: [
          'Ich helfe dir gerne beim Einkaufen! 💚',
          'Du bist mein Lieblingskunde!',
          'Danke, dass du mich nutzt! Du bist toll!',
          'Deine Listen sehen super organisiert aus!',
          'Du bist unschlagbar! Mach weiter so! 🔥',
          'Level up! Du wirst zum Einkaufsprofi! 🏆',
        ],
      };
    }
    return {
      AvoExpression.neutral: [
        'I miss you! Haven\'t seen you in a while...',
        'Your shopping list is waiting for you...',
        'Come back! I\'ve got some great recipes! 💚',
        'Hey friend, let\'s organize something together!',
      ],
      AvoExpression.happy: [
        'Hey! Ready to make your shopping list? 🛒',
        'Great job organizing! Keep it up! ✨',
        'Your lists are looking amazing today!',
        'Shopping made easy with a little help! 💚',
        'Woohoo! You\'ve been super organized lately! 🎉',
        'Amazing! You completed all your shopping! 🌟',
        'Hey there! 👋 Ready for some shopping?',
        'Welcome back! Let\'s get organized!',
      ],
      AvoExpression.confused: [
        'Hmm... maybe add some items to your list? 🤔',
        'I\'m thinking... what do you need today?',
        'Did you forget something on your list?',
        'Let me help you plan your shopping!',
      ],
      AvoExpression.success: [
        'I love helping you shop! 💚',
        'You\'re my favorite shopper!',
        'Thanks for using me! You\'re the best!',
        'Looking good with those organized lists!',
        'You\'re on fire! Keep that streak going! 🔥',
        'Level up! You\'re becoming a shopping pro! 🏆',
      ],
    };
  }

  /// Welcome messages in both languages
  List<String> _getWelcomeMessages(String lang) {
    if (lang == 'de') {
      return [
        'Hi! Ich bin $avoName, dein Einkaufshelfer! 🥑',
        'Freut mich! Ich helfe dir organisiert zu bleiben! 💚',
        'Lass uns Einkaufen zum Spaß machen!',
        'Bereit für deine erste Liste?',
      ];
    }
    return [
      'Hi! I\'m $avoName, your shopping buddy! 🥑',
      'Nice to meet you! I\'ll help you stay organized! 💚',
      'Let\'s make shopping fun together!',
      'Ready to create your first list?',
    ];
  }

  /// Context messages in both languages
  String _getContextMessageByLang(AvoContext context, String lang) {
    final messages = _getMessages(lang);
    final welcomeMessages = _getWelcomeMessages(lang);
    
    if (lang == 'de') {
      switch (context) {
        case AvoContext.welcome:
          return welcomeMessages[_random.nextInt(welcomeMessages.length)];
        case AvoContext.emptyList:
          return 'Deine Liste ist leer! Lass uns Artikel hinzufügen! 📝';
        case AvoContext.shoppingComplete:
          return 'Toll! Du hast deinen Einkauf erledigt! 🎉';
        case AvoContext.newRecipe:
          return 'Ooh, ein neues Rezept? Ich liebe es! 🍳';
        case AvoContext.comeBack:
          return messages[AvoExpression.neutral]![_random.nextInt(messages[AvoExpression.neutral]!.length)];
        case AvoContext.streak:
          return 'Wow! Du bist auf einer Einkaufsserie! Weiter so! 🔥';
        case AvoContext.morning:
          return 'Guten Morgen! Bereit für den heutigen Einkauf? ☀️';
        case AvoContext.evening:
          return 'Guten Abend! Vergiss deine Liste nicht! 🌙';
        case AvoContext.weekend:
          return 'Es ist Wochenende! Perfekt zum Mahlzeiten planen! 🎉';
      }
    }
    
    switch (context) {
      case AvoContext.welcome:
        return welcomeMessages[_random.nextInt(welcomeMessages.length)];
      case AvoContext.emptyList:
        return 'Your list looks empty! Let\'s add some items! 📝';
      case AvoContext.shoppingComplete:
        return 'Amazing! You completed your shopping! 🎉';
      case AvoContext.newRecipe:
        return 'Ooh, trying a new recipe? I love it! 🍳';
      case AvoContext.comeBack:
        return messages[AvoExpression.neutral]![_random.nextInt(messages[AvoExpression.neutral]!.length)];
      case AvoContext.streak:
        return 'Wow! You\'re on a shopping streak! Keep going! 🔥';
      case AvoContext.morning:
        return 'Good morning! Ready to plan today\'s shopping? ☀️';
      case AvoContext.evening:
        return 'Good evening! Don\'t forget to check your list! 🌙';
      case AvoContext.weekend:
        return 'It\'s the weekend! Perfect time for meal planning! 🎉';
    }
  }

  /// Messages based on context (uses stored language)
  Future<String> getContextMessageAsync(AvoContext context) async {
    final lang = await _getLanguage();
    return _getContextMessageByLang(context, lang);
  }
  
  /// Sync version for immediate use (defaults to English, use async when possible)
  String getContextMessage(AvoContext context) {
    return _getContextMessageByLang(context, 'en');
  }

  /// Get expression for context
  AvoExpression getExpressionForContext(AvoContext context) {
    switch (context) {
      case AvoContext.welcome:
        return AvoExpression.happy;
      case AvoContext.emptyList:
        return AvoExpression.confused;
      case AvoContext.shoppingComplete:
        return AvoExpression.happy;
      case AvoContext.newRecipe:
        return AvoExpression.happy;
      case AvoContext.comeBack:
        return AvoExpression.neutral;
      case AvoContext.streak:
        return AvoExpression.happy;
      case AvoContext.morning:
        return AvoExpression.happy;
      case AvoContext.evening:
        return AvoExpression.happy;
      case AvoContext.weekend:
        return AvoExpression.happy;
    }
  }

  /// Check if we should send a notification and what type
  Future<void> checkAndSendNotification() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastNotification = prefs.getInt(_lastNotificationKey) ?? 0;
      final lastActive = prefs.getInt(_lastActiveKey) ?? DateTime.now().millisecondsSinceEpoch;
      final notificationCount = prefs.getInt(_notificationCountKey) ?? 0;
      
      final now = DateTime.now();
      final lastNotifTime = DateTime.fromMillisecondsSinceEpoch(lastNotification);
      final lastActiveTime = DateTime.fromMillisecondsSinceEpoch(lastActive);
      
      // Don't send more than 2 notifications per day
      if (notificationCount >= 2 && 
          now.difference(lastNotifTime).inHours < 24) {
        debugPrint('🥑 [AVO] Max daily notifications reached');
        return;
      }
      
      // Minimum 4 hours between notifications
      if (now.difference(lastNotifTime).inHours < 4) {
        debugPrint('🥑 [AVO] Too soon for another notification');
        return;
      }
      
      // Determine notification type based on user behavior
      AvoContext context;
      
      // If user hasn't been active for 2+ days, send "miss you" notification
      if (now.difference(lastActiveTime).inDays >= 2) {
        context = AvoContext.comeBack;
      }
      // Morning notification (8-10 AM)
      else if (now.hour >= 8 && now.hour <= 10) {
        context = AvoContext.morning;
      }
      // Evening reminder (6-8 PM)
      else if (now.hour >= 18 && now.hour <= 20) {
        context = AvoContext.evening;
      }
      // Weekend special
      else if (now.weekday == DateTime.saturday || now.weekday == DateTime.sunday) {
        context = AvoContext.weekend;
      }
      // Random motivational
      else {
        final contexts = [AvoContext.morning, AvoContext.evening];
        context = contexts[_random.nextInt(contexts.length)];
      }
      
      await _sendAvoNotification(context);
      
      // Update tracking
      await prefs.setInt(_lastNotificationKey, now.millisecondsSinceEpoch);
      final newCount = now.difference(lastNotifTime).inHours >= 24 ? 1 : notificationCount + 1;
      await prefs.setInt(_notificationCountKey, newCount);
      
    } catch (e) {
      debugPrint('🥑 [AVO] Error checking notification: $e');
    }
  }

  /// Send an Avo notification
  Future<void> _sendAvoNotification(AvoContext context) async {
    final lang = await _getLanguage();
    final message = _getContextMessageByLang(context, lang);
    final expression = getExpressionForContext(context);
    
    // Create notification title based on expression and language
    String title;
    if (lang == 'de') {
      switch (expression) {
        case AvoExpression.neutral:
          title = '🥑 $avoName vermisst dich!';
        case AvoExpression.happy:
          title = '🥑 $avoName sagt hallo!';
        case AvoExpression.confused:
          title = '🥑 $avoName denkt nach...';
        case AvoExpression.success:
          title = '🥑 $avoName ist stolz!';
        case AvoExpression.waving:
          title = '🥑 $avoName winkt dir zu!';
        case AvoExpression.thinking:
          title = '🥑 $avoName grübelt...';
        case AvoExpression.excited:
          title = '🥑 $avoName ist begeistert!';
        case AvoExpression.celebrating:
          title = '🥑 $avoName feiert!';
      }
    } else {
      switch (expression) {
        case AvoExpression.neutral:
          title = '🥑 $avoName misses you!';
        case AvoExpression.happy:
          title = '🥑 $avoName says hi!';
        case AvoExpression.confused:
          title = '🥑 $avoName is thinking...';
        case AvoExpression.success:
          title = '🥑 $avoName is proud!';
        case AvoExpression.waving:
          title = '🥑 $avoName waves at you!';
        case AvoExpression.thinking:
          title = '🥑 $avoName is pondering...';
        case AvoExpression.excited:
          title = '🥑 $avoName is excited!';
        case AvoExpression.celebrating:
          title = '🥑 $avoName is celebrating!';
      }
    }

    await NotificationService.instance.showNotification(
      id: DateTime.now().millisecondsSinceEpoch % 100000,
      title: title,
      body: message,
      payload: '{"type": "avo_notification", "context": "${context.name}"}',
    );
    
    debugPrint('🥑 [AVO] Sent notification: $title - $message');
  }

  /// Update user's last active time
  Future<void> updateLastActive() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_lastActiveKey, DateTime.now().millisecondsSinceEpoch);
    } catch (e) {
      debugPrint('🥑 [AVO] Error updating last active: $e');
    }
  }

  /// Update streak when user completes shopping
  Future<int> updateStreak() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final streak = prefs.getInt(_streakKey) ?? 0;
      final newStreak = streak + 1;
      await prefs.setInt(_streakKey, newStreak);
      
      // Send streak notification at milestones
      if (newStreak == 3 || newStreak == 7 || newStreak == 14 || newStreak == 30) {
        await _sendAvoNotification(AvoContext.streak);
      }
      
      return newStreak;
    } catch (e) {
      debugPrint('🥑 [AVO] Error updating streak: $e');
      return 0;
    }
  }

  /// Get current streak
  Future<int> getStreak() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getInt(_streakKey) ?? 0;
    } catch (e) {
      return 0;
    }
  }

  /// Send a specific notification
  Future<void> sendNotification(AvoContext context) async {
    await _sendAvoNotification(context);
  }
}

/// Context for Avo's messages
enum AvoContext {
  welcome,
  emptyList,
  shoppingComplete,
  newRecipe,
  comeBack,
  streak,
  morning,
  evening,
  weekend,
}
