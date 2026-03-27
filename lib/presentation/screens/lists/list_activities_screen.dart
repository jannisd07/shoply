import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:shoply/core/constants/app_colors.dart';
import 'package:shoply/core/localization/localization_helper.dart';
import 'package:shoply/data/models/list_activity.dart';
import 'package:shoply/data/services/list_activity_service.dart';
import 'package:shoply/presentation/widgets/common/liquid_glass_button.dart';

/// Screen displaying all activities/changes for a shopping list.
/// 
/// This screen is accessed from notifications to show users what
/// has happened on a shared list.
class ListActivitiesScreen extends ConsumerStatefulWidget {
  final String listId;
  final String listName;

  const ListActivitiesScreen({
    super.key,
    required this.listId,
    required this.listName,
  });

  @override
  ConsumerState<ListActivitiesScreen> createState() => _ListActivitiesScreenState();
}

class _ListActivitiesScreenState extends ConsumerState<ListActivitiesScreen> {
  final _activityService = ListActivityService();
  List<ListActivity> _activities = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadActivities();
  }

  Future<void> _loadActivities() async {
    final activities = await _activityService.getActivities(widget.listId);
    if (mounted) {
      setState(() {
        _activities = activities;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final languageCode = Localizations.localeOf(context).languageCode;

    return Scaffold(
      backgroundColor: isDark ? Colors.black : Colors.grey[100],
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Padding(
          padding: const EdgeInsets.only(left: 8),
          child: Center(
            child: LiquidGlassButton(
              icon: Icons.close,
              onPressed: () => Navigator.pop(context),
            ),
          ),
        ),
        title: Text(
          context.tr('list_activities'),
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : Colors.black,
          ),
        ),
        centerTitle: true,
        actions: [
          if (_activities.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: LiquidGlassButton(
                icon: Icons.delete_outline,
                onPressed: _showClearConfirmation,
              ),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CupertinoActivityIndicator())
          : _activities.isEmpty
              ? _buildEmptyState(isDark)
              : _buildActivityList(isDark, languageCode),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.history,
              size: 64,
              color: isDark ? Colors.grey[600] : Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              context.tr('no_activities'),
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.grey[400] : Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              context.tr('no_activities_desc'),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: isDark ? Colors.grey[500] : Colors.grey[500],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActivityList(bool isDark, String languageCode) {
    // Group activities by date
    final Map<String, List<ListActivity>> groupedActivities = {};
    
    for (final activity in _activities) {
      final dateKey = _getDateKey(activity.timestamp, languageCode);
      groupedActivities.putIfAbsent(dateKey, () => []);
      groupedActivities[dateKey]!.add(activity);
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: groupedActivities.length,
      itemBuilder: (context, index) {
        final dateKey = groupedActivities.keys.elementAt(index);
        final activities = groupedActivities[dateKey]!;
        
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Date header
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                dateKey,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                  letterSpacing: 0.5,
                ),
              ),
            ),
            // Activities for this date
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withOpacity(0.08)
                        : Colors.white.withOpacity(0.8),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isDark
                          ? Colors.white.withOpacity(0.1)
                          : Colors.black.withOpacity(0.05),
                    ),
                  ),
                  child: Column(
                    children: activities.asMap().entries.map((entry) {
                      final idx = entry.key;
                      final activity = entry.value;
                      final isLast = idx == activities.length - 1;
                      
                      return _buildActivityTile(
                        activity,
                        languageCode,
                        isDark,
                        isLast,
                      );
                    }).toList(),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
        );
      },
    );
  }

  Widget _buildActivityTile(
    ListActivity activity,
    String languageCode,
    bool isDark,
    bool isLast,
  ) {
    final timeFormat = DateFormat.Hm();
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: !isLast
          ? BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: isDark
                      ? Colors.white.withOpacity(0.08)
                      : Colors.black.withOpacity(0.05),
                ),
              ),
            )
          : null,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Icon
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: _getActivityColor(activity.type).withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: Text(
                activity.getIcon(),
                style: const TextStyle(fontSize: 18),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  activity.getDescription(languageCode: languageCode),
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: isDark ? Colors.white : Colors.black87,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  timeFormat.format(activity.timestamp),
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.grey[500] : Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _getActivityColor(ListActivityType type) {
    switch (type) {
      case ListActivityType.itemAdded:
        return Colors.green;
      case ListActivityType.itemRemoved:
        return Colors.red;
      case ListActivityType.itemChecked:
        return AppColors.lightAccent;
      case ListActivityType.itemUnchecked:
        return Colors.orange;
      case ListActivityType.categoryAdded:
        return Colors.blue;
      case ListActivityType.categoryRemoved:
        return Colors.red;
      case ListActivityType.categoryReordered:
        return Colors.purple;
      case ListActivityType.listShared:
        return Colors.teal;
      case ListActivityType.memberJoined:
        return Colors.green;
      case ListActivityType.memberLeft:
        return Colors.grey;
      case ListActivityType.listRenamed:
        return Colors.indigo;
      case ListActivityType.shoppingCompleted:
        return AppColors.lightAccent;
      case ListActivityType.backgroundChanged:
        return Colors.pink;
    }
  }

  String _getDateKey(DateTime timestamp, String languageCode) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final activityDate = DateTime(timestamp.year, timestamp.month, timestamp.day);
    
    final isGerman = languageCode == 'de';
    
    if (activityDate == today) {
      return isGerman ? 'Heute' : 'Today';
    } else if (activityDate == yesterday) {
      return isGerman ? 'Gestern' : 'Yesterday';
    } else if (now.difference(activityDate).inDays < 7) {
      // Show weekday name
      return DateFormat.EEEE(languageCode).format(timestamp);
    } else {
      // Show full date
      return DateFormat.yMMMd(languageCode).format(timestamp);
    }
  }

  void _showClearConfirmation() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? Colors.grey[900] : Colors.white,
        title: Text(context.tr('clear_activities')),
        content: Text(context.tr('clear_activities_confirm')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(context.tr('cancel')),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _activityService.clearActivities(widget.listId);
              setState(() {
                _activities = [];
              });
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(context.tr('clear')),
          ),
        ],
      ),
    );
  }
}
