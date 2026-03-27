import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shoply/core/mascot/avo_mascot.dart';

/// Gamification service for tracking user engagement and generating playful content
class GamificationService {
  static final GamificationService _instance = GamificationService._internal();
  factory GamificationService() => _instance;
  GamificationService._internal();

  static const String _streakKey = 'daily_streak';
  static const String _lastOpenKey = 'last_open_date';
  static const String _totalListsKey = 'total_lists_completed';
  static const String _totalItemsKey = 'total_items_checked';
  static const String _firstOpenKey = 'first_open_date';
  static const String _openCountKey = 'app_open_count';

  final Random _random = Random();

  // ============================================
  // STREAK TRACKING
  // ============================================

  /// Get current streak count
  Future<int> getCurrentStreak() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_streakKey) ?? 0;
  }

  /// Update streak on app open
  Future<int> updateStreak() async {
    final prefs = await SharedPreferences.getInstance();
    final lastOpen = prefs.getString(_lastOpenKey);
    final today = _dateToString(DateTime.now());
    
    if (lastOpen == null) {
      // First time user
      await prefs.setInt(_streakKey, 1);
      await prefs.setString(_lastOpenKey, today);
      await prefs.setString(_firstOpenKey, today);
      return 1;
    }
    
    if (lastOpen == today) {
      // Already opened today
      return prefs.getInt(_streakKey) ?? 1;
    }
    
    final lastDate = _stringToDate(lastOpen);
    final todayDate = DateTime.now();
    final difference = todayDate.difference(lastDate).inDays;
    
    int newStreak;
    if (difference == 1) {
      // Consecutive day - increase streak
      newStreak = (prefs.getInt(_streakKey) ?? 0) + 1;
    } else {
      // Streak broken
      newStreak = 1;
    }
    
    await prefs.setInt(_streakKey, newStreak);
    await prefs.setString(_lastOpenKey, today);
    
    // Update open count
    final openCount = prefs.getInt(_openCountKey) ?? 0;
    await prefs.setInt(_openCountKey, openCount + 1);
    
    return newStreak;
  }

  /// Check if today is a streak milestone
  bool isStreakMilestone(int streak) {
    return streak == 3 || streak == 7 || streak == 14 || 
           streak == 30 || streak == 50 || streak == 100 ||
           (streak > 0 && streak % 25 == 0);
  }

  // ============================================
  // PLAYFUL GREETINGS
  // ============================================

  /// Get time-based greeting with mascot mood
  (String greeting, AvoExpression mood) getTimeBasedGreeting(String? userName) {
    final hour = DateTime.now().hour;
    final name = userName ?? 'there';
    
    if (hour >= 5 && hour < 12) {
      return _getMorningGreeting(name);
    } else if (hour >= 12 && hour < 17) {
      return _getAfternoonGreeting(name);
    } else if (hour >= 17 && hour < 21) {
      return _getEveningGreeting(name);
    } else {
      return _getNightGreeting(name);
    }
  }

  (String, AvoExpression) _getMorningGreeting(String name) {
    final greetings = [
      ('Good morning, $name! ☀️ Ready to conquer today\'s shopping?', AvoExpression.happy),
      ('Rise and shine! 🌅 What\'s on the list today?', AvoExpression.happy),
      ('Hey $name! Early bird gets the freshest groceries! 🐦', AvoExpression.happy),
      ('Morning! ☕ Let\'s make today\'s shopping a breeze!', AvoExpression.happy),
    ];
    return greetings[_random.nextInt(greetings.length)];
  }

  (String, AvoExpression) _getAfternoonGreeting(String name) {
    final greetings = [
      ('Hey $name! 👋 Lunch run or afternoon shopping?', AvoExpression.happy),
      ('Good afternoon! 🌤️ Need help with your list?', AvoExpression.happy),
      ('Hi there! Perfect time for a quick shop! 🛒', AvoExpression.happy),
      ('Afternoon, $name! What goodies are we getting?', AvoExpression.thinking),
    ];
    return greetings[_random.nextInt(greetings.length)];
  }

  (String, AvoExpression) _getEveningGreeting(String name) {
    final greetings = [
      ('Evening, $name! 🌙 Last-minute shopping?', AvoExpression.happy),
      ('Hey! Planning tomorrow\'s meals? 🍳', AvoExpression.thinking),
      ('Good evening! 🌆 Let\'s check what you need!', AvoExpression.happy),
      ('Hi $name! Dinner prep time? I\'m here to help!', AvoExpression.happy),
    ];
    return greetings[_random.nextInt(greetings.length)];
  }

  (String, AvoExpression) _getNightGreeting(String name) {
    final greetings = [
      ('Still up, $name? 🌙 Quick list check?', AvoExpression.neutral),
      ('Night owl shopping! 🦉 I like your style!', AvoExpression.happy),
      ('Late night cravings? 🍪 Let\'s add them!', AvoExpression.happy),
      ('Burning the midnight oil! ✨ I\'m here for you!', AvoExpression.neutral),
    ];
    return greetings[_random.nextInt(greetings.length)];
  }

  /// Get streak-based greeting
  (String greeting, AvoExpression mood) getStreakGreeting(int streak, String? userName) {
    final name = userName ?? 'superstar';
    
    if (streak == 1) {
      return ('Welcome back, $name! Let\'s start a streak! 🔥', AvoExpression.happy);
    } else if (streak == 3) {
      return ('3 days in a row! You\'re on fire! 🔥🔥', AvoExpression.happy);
    } else if (streak == 7) {
      return ('ONE WEEK STREAK! 🎉 You\'re amazing, $name!', AvoExpression.happy);
    } else if (streak == 14) {
      return ('Two weeks! 💪 You\'re a shopping champion!', AvoExpression.success);
    } else if (streak == 30) {
      return ('30 DAYS! 🏆 You\'re a legend, $name!', AvoExpression.happy);
    } else if (streak >= 50) {
      return ('$streak days! 👑 You\'re unstoppable!', AvoExpression.happy);
    } else if (streak >= 7) {
      return ('$streak day streak! 🌟 Keep it going!', AvoExpression.success);
    } else {
      return ('$streak days strong! 💚 Nice work!', AvoExpression.happy);
    }
  }

  // ============================================
  // COMPLETION CELEBRATIONS
  // ============================================

  /// Get celebration message when all items are checked
  (String message, AvoExpression mood) getCompletionCelebration() {
    final celebrations = [
      ('All done! 🎉 You crushed it!', AvoExpression.happy),
      ('List complete! 💪 Shopping champion!', AvoExpression.success),
      ('Woohoo! ✨ Everything checked off!', AvoExpression.happy),
      ('Done and done! 🌟 Time to relax!', AvoExpression.happy),
      ('Perfect score! 🏆 All items found!', AvoExpression.happy),
    ];
    return celebrations[_random.nextInt(celebrations.length)];
  }

  /// Get encouragement message during shopping
  String getEncouragementMessage(int checkedCount, int totalCount) {
    final progress = checkedCount / totalCount;
    
    if (progress == 0) {
      return 'Let\'s get started! 💪';
    } else if (progress < 0.25) {
      return 'Great start! Keep going! 🚀';
    } else if (progress < 0.5) {
      return 'You\'re doing amazing! 🌟';
    } else if (progress < 0.75) {
      return 'More than halfway there! 🎯';
    } else if (progress < 1) {
      return 'Almost done! Final stretch! 🏃';
    } else {
      return 'All done! 🎉';
    }
  }

  // ============================================
  // PLAYFUL NOTIFICATIONS
  // ============================================

  /// Get playful reminder notification based on context
  String getPlayfulReminder({
    required int hoursSinceLastOpen,
    required int pendingItems,
    String? listName,
  }) {
    if (hoursSinceLastOpen > 48 && pendingItems > 0) {
      return [
        'Miss me? 🥺 Your $pendingItems items are waiting!',
        'Hey! Your shopping list is getting lonely... 📝',
        'Knock knock! 🚪 Your groceries miss you!',
        'Your list has been napping. Time to wake it up! 😴',
      ][_random.nextInt(4)];
    } else if (hoursSinceLastOpen > 24) {
      return [
        'New day, new shopping adventures! 🌅',
        'Your list misses you! Come say hi! 👋',
        'Ready for today\'s shopping quest? 🗡️',
        'The fridge might be feeling empty... 🧊',
      ][_random.nextInt(4)];
    } else {
      return [
        'Quick check: anything running low? 🤔',
        'Pro tip: A quick list check saves the day! ✨',
        'Family shopping time? I\'m ready! 👨‍👩‍👧‍👦',
        'Need anything from the store? 🛒',
      ][_random.nextInt(4)];
    }
  }

  // ============================================
  // TIPS & SUGGESTIONS
  // ============================================

  /// Get a random shopping tip
  (String tip, AvoExpression mood) getRandomTip() {
    final tips = [
      ('💡 Tip: Shop the perimeter first for fresh items!', AvoExpression.thinking),
      ('💡 Pro tip: Check your fridge before shopping!', AvoExpression.thinking),
      ('💡 Family hack: Let everyone add to the list!', AvoExpression.excited),
      ('💡 Save time: Group items by store section!', AvoExpression.thinking),
      ('💡 Budget tip: Make a list and stick to it!', AvoExpression.celebrating),
      ('💡 Eco tip: Bring your reusable bags! 🌱', AvoExpression.happy),
    ];
    return tips[_random.nextInt(tips.length)];
  }

  // ============================================
  // STATS TRACKING
  // ============================================

  Future<void> incrementListsCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    final current = prefs.getInt(_totalListsKey) ?? 0;
    await prefs.setInt(_totalListsKey, current + 1);
  }

  Future<void> incrementItemsChecked(int count) async {
    final prefs = await SharedPreferences.getInstance();
    final current = prefs.getInt(_totalItemsKey) ?? 0;
    await prefs.setInt(_totalItemsKey, current + count);
  }

  Future<Map<String, int>> getStats() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'streak': prefs.getInt(_streakKey) ?? 0,
      'listsCompleted': prefs.getInt(_totalListsKey) ?? 0,
      'itemsChecked': prefs.getInt(_totalItemsKey) ?? 0,
      'appOpens': prefs.getInt(_openCountKey) ?? 0,
    };
  }

  // ============================================
  // HELPER METHODS
  // ============================================

  String _dateToString(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  DateTime _stringToDate(String dateStr) {
    final parts = dateStr.split('-');
    return DateTime(
      int.parse(parts[0]),
      int.parse(parts[1]),
      int.parse(parts[2]),
    );
  }
}
