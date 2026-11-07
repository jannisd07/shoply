import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shoply/core/constants/app_colors.dart';
import 'package:shoply/core/localization/localization_helper.dart';
import 'package:shoply/presentation/screens/recipes/recipes_home_data.dart';
import 'package:shoply/presentation/screens/recipes/widgets/author_avatar.dart';
import 'package:shoply/presentation/screens/recipes/widgets/recipe_state_views.dart';
import 'package:shoply/presentation/state/recipes_provider.dart';

/// All recipe authors, ranked, derived from the app-wide recipe list (no
/// extra download). The page shows the top 50 and searches all of them.
final creatorsProvider =
    FutureProvider.autoDispose<List<RecipeAuthorSummary>>((ref) async {
  return topAuthorsFrom(await ref.watch(recipesProvider.future));
});

const _maxListedCreators = 50;

/// Screen for browsing recipe creators/authors
class CreatorsScreen extends ConsumerStatefulWidget {
  const CreatorsScreen({super.key});

  @override
  ConsumerState<CreatorsScreen> createState() => _CreatorsScreenState();
}

class _CreatorsScreenState extends ConsumerState<CreatorsScreen> {
  final _searchController = TextEditingController();
  Timer? _searchDebounce;
  String _searchQuery = '';
  bool _isSearching = false;

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _setQuery(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 300), () {
      if (mounted) setState(() => _searchQuery = value.trim());
    });
  }

  void _clearQuery() {
    _searchDebounce?.cancel();
    _searchController.clear();
    _searchQuery = '';
  }

  @override
  Widget build(BuildContext context) {
    final backgroundColor = AppColors.recipeBg(context);
    final textPrimary = AppColors.textPrimary(context);
    final textSecondary = AppColors.textSecondary(context);
    
    final query = _searchQuery.toLowerCase();
    final creatorsAsync = ref.watch(creatorsProvider).whenData(
          (all) => query.isEmpty
              ? all.take(_maxListedCreators).toList()
              : all.where((a) => a.name.toLowerCase().contains(query)).toList(),
        );

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: backgroundColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: context.tr('search_creators'),
                  hintStyle: TextStyle(color: textSecondary),
                  border: InputBorder.none,
                ),
                style: TextStyle(color: textPrimary),
                onChanged: _setQuery,
              )
            : Text(
                context.tr('creators'),
                style: TextStyle(
                  color: textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_rounded, color: textPrimary),
          onPressed: () {
            if (_isSearching) {
              setState(() {
                _isSearching = false;
                _clearQuery();
              });
            } else {
              context.pop();
            }
          },
        ),
        actions: [
          if (!_isSearching)
            IconButton(
              icon: Icon(Icons.search_rounded, color: textPrimary),
              onPressed: () {
                setState(() => _isSearching = true);
              },
            ),
          if (_isSearching && _searchQuery.isNotEmpty)
            IconButton(
              icon: Icon(Icons.close_rounded, color: textPrimary),
              onPressed: () => setState(_clearQuery),
            ),
        ],
      ),
      body: creatorsAsync.when(
        loading: () => const Center(child: CupertinoActivityIndicator()),
        error: (_, __) => RecipeErrorView(
          onRetry: () => ref.invalidate(recipesProvider),
        ),
        data: (creators) => creators.isEmpty
            ? _buildEmptyState(context, _searchQuery.isNotEmpty)
            : CustomScrollView(
                physics: const BouncingScrollPhysics(
                  parent: AlwaysScrollableScrollPhysics(),
                ),
                slivers: [
                  CupertinoSliverRefreshControl(
                    onRefresh: () async => ref.invalidate(recipesProvider),
                  ),
                  SliverPadding(
                    padding: EdgeInsets.only(
                      left: 16,
                      right: 16,
                      top: 16,
                      bottom: 100 + MediaQuery.paddingOf(context).bottom,
                    ),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final creator = creators[index];
                          return _CreatorCard(
                            name: creator.name,
                            avatarUrl: creator.avatarUrl,
                            recipeCount: creator.recipeCount,
                            averageRating: creator.averageRating,
                            onTap: () => context.push(
                              '/author/${creator.id}',
                              extra: {'authorName': creator.name},
                            ),
                          );
                        },
                        childCount: creators.length,
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, bool isSearch) {
    return RecipeEmptyView(
      icon: isSearch ? Icons.search_off_rounded : Icons.people_outline_rounded,
      title: context.tr(isSearch ? 'no_creators_found' : 'no_creators_yet'),
      subtitle: context.tr(isSearch ? 'try_different_search' : 'be_first_to_share'),
    );
  }
}

class _CreatorCard extends StatelessWidget {
  final String name;
  final String? avatarUrl;
  final int recipeCount;
  final double averageRating;
  final VoidCallback onTap;

  const _CreatorCard({
    required this.name,
    this.avatarUrl,
    required this.recipeCount,
    required this.averageRating,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final textPrimary = AppColors.textPrimary(context);
    final textSecondary = AppColors.textSecondary(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBgColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: cardBgColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: isDark ? null : [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Avatar with gradient border
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [AppColors.recipeAccentColor(context), AppColors.recipeAccentDark],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  padding: const EdgeInsets.all(2),
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: cardBgColor,
                    ),
                    padding: const EdgeInsets.all(2),
                    child: AuthorAvatar(
                      name: name,
                      avatarUrl: avatarUrl,
                      size: 52,
                      backgroundColor: Colors.white,
                      initialStyle: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: AppColors.recipeAccent,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                // Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: TextStyle(
                          color: textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              border: Border.all(color: textSecondary.withOpacity(0.2)),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.restaurant_rounded, size: 12, color: textSecondary),
                                const SizedBox(width: 4),
                                Text(
                                  recipeCount == 1 
                                    ? '1 ${context.tr('recipe_singular')}'
                                    : '$recipeCount ${context.tr('recipes_plural')}',
                                  style: TextStyle(
                                    color: textSecondary,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (averageRating > 0) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                border: Border.all(color: textSecondary.withOpacity(0.2)),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.star_rounded, size: 12, color: textSecondary),
                                  const SizedBox(width: 3),
                                  Text(
                                    averageRating.toStringAsFixed(1),
                                    style: TextStyle(
                                      color: textSecondary,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                // Arrow
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 14,
                    color: textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
