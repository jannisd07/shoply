import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shoply/data/services/smart_recommendation_engine.dart';
import 'package:shoply/data/services/supabase_service.dart';
import 'package:shoply/core/constants/app_dimensions.dart';

class SmartRecommendationsWidget extends ConsumerStatefulWidget {
  final String listId;
  final Function(String itemName, double? quantity) onAddItem;

  const SmartRecommendationsWidget({
    super.key,
    required this.listId,
    required this.onAddItem,
  });

  @override
  ConsumerState<SmartRecommendationsWidget> createState() =>
      _SmartRecommendationsWidgetState();
}

class _SmartRecommendationsWidgetState
    extends ConsumerState<SmartRecommendationsWidget> {
  final _recommendationEngine = SmartRecommendationEngine();
  List<RecommendedItem> _recommendations = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadRecommendations();
  }

  Future<void> _loadRecommendations() async {
    setState(() => _isLoading = true);
    try {
      final userId = SupabaseService.instance.currentUser?.id;
      if (userId == null) {
        setState(() => _isLoading = false);
        return;
      }

      final recommendations =
          await _recommendationEngine.getRecommendations(userId: userId);
      setState(() {
        _recommendations = recommendations;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Consistent minimum height to prevent layout shifts
    const double minHeight = 100.0;
    
    if (_isLoading) {
      return SizedBox(
        height: minHeight,
        child: Center(
          child: CupertinoActivityIndicator(radius: 10),
        ),
      );
    }

    if (_recommendations.isEmpty) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: AppDimensions.spacingMedium),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDarkMode
              ? [
                  Colors.blue.withValues(alpha: 0.15),
                  Colors.blue.withValues(alpha: 0.1),
                ]
              : [
                  Colors.blue.withValues(alpha: 0.1),
                  Colors.blue.withValues(alpha: 0.05),
                ],
        ),
        border: Border.all(
          color: Colors.blue.withValues(alpha: 0.3),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.lightbulb_outline_rounded,
                color: Colors.blue.shade700,
                size: 22,
              ),
              const SizedBox(width: 8),
              Text(
                'Suggested Items',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: isDarkMode ? Colors.white : Colors.black,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _recommendations.map((item) {
              return _RecommendationChip(
                item: item,
                onTap: () {
                  widget.onAddItem(item.itemName, item.quantity);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Added ${item.itemName} to list'),
                      duration: const Duration(seconds: 2),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class _RecommendationChip extends StatelessWidget {
  final RecommendedItem item;
  final VoidCallback onTap;

  const _RecommendationChip({
    required this.item,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDarkMode
                ? [
                    Colors.white.withValues(alpha: 0.15),
                    Colors.white.withValues(alpha: 0.1),
                  ]
                : [
                    Colors.white,
                    Colors.white.withValues(alpha: 0.9),
                  ],
          ),
          border: Border.all(
            color: Colors.blue.withValues(alpha: 0.5),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.blue.withValues(alpha: 0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.add_circle_outline_rounded,
              size: 18,
              color: Colors.blue.shade700,
            ),
            const SizedBox(width: 6),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  item.itemName,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: isDarkMode ? Colors.white : Colors.black,
                  ),
                ),
                if (item.reason.isNotEmpty)
                  Text(
                    item.reason,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontSize: 10,
                      color: Colors.grey.shade600,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
