import 'package:intl/intl.dart';

class DateFormatter {
  /// Formats a date in a user-friendly way (e.g., "Today", "Yesterday", "2 days ago")
  static String formatRelativeDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final dateOnly = DateTime(date.year, date.month, date.day);
    
    if (dateOnly == today) {
      return 'Today';
    } else if (dateOnly == yesterday) {
      return 'Yesterday';
    } else {
      final difference = today.difference(dateOnly).inDays;
      if (difference < 7) {
        return '$difference days ago';
      } else if (difference < 30) {
        final weeks = (difference / 7).floor();
        return weeks == 1 ? '1 week ago' : '$weeks weeks ago';
      } else if (difference < 365) {
        final months = (difference / 30).floor();
        return months == 1 ? '1 month ago' : '$months months ago';
      } else {
        final years = (difference / 365).floor();
        return years == 1 ? '1 year ago' : '$years years ago';
      }
    }
  }
  
  /// Formats time (e.g., "2:30 PM")
  static String formatTime(DateTime date) {
    return DateFormat('HH:mm').format(date);
  }
  
  /// Formats date (e.g., "Jan 15, 2024")
  static String formatDate(DateTime date) {
    return DateFormat('MMM d, y').format(date);
  }
  
  /// Formats date and time (e.g., "Jan 15, 2024 at 2:30 PM")
  static String formatDateTime(DateTime date) {
    return '${formatDate(date)} at ${formatTime(date)}';
  }
  
  /// Formats date range (e.g., "Jan 15 - Jan 22")
  static String formatDateRange(DateTime start, DateTime end) {
    if (start.year == end.year && start.month == end.month) {
      return '${DateFormat('MMM d').format(start)} - ${DateFormat('d, y').format(end)}';
    } else {
      return '${DateFormat('MMM d').format(start)} - ${DateFormat('MMM d, y').format(end)}';
    }
  }
  
  /// Gets notification grouping label
  static String getNotificationGroupLabel(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final dateOnly = DateTime(date.year, date.month, date.day);
    
    if (dateOnly == today) {
      return 'Today';
    } else if (dateOnly == yesterday) {
      return 'Yesterday';
    } else {
      return formatDate(date);
    }
  }
}
