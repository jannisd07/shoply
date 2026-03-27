import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shoply/core/constants/app_colors.dart';
import 'package:shoply/core/localization/localization_helper.dart';
import 'package:shoply/data/services/recipe_service.dart';
import 'package:cached_network_image/cached_network_image.dart';

/// Provider for top authors/creators
final creatorsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  return RecipeService().getTopAuthors(limit: 50);
});

/// Provider for author search
final authorSearchProvider = FutureProvider.family<List<Map<String, dynamic>>, String>((ref, query) async {
  if (query.isEmpty) return [];
  return RecipeService().searchAuthors(query);
});

/// Screen for browsing recipe creators/authors
class CreatorsScreen extends ConsumerStatefulWidget {
  const CreatorsScreen({super.key});

  @override
  ConsumerState<CreatorsScreen> createState() => _CreatorsScreenState();
}

class _CreatorsScreenState extends ConsumerState<CreatorsScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  bool _isSearching = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final backgroundColor = AppColors.recipeBg(context);
    final textPrimary = AppColors.textPrimary(context);
    final textSecondary = AppColors.textSecondary(context);
    
    final creatorsAsync = _searchQuery.isEmpty
        ? ref.watch(creatorsProvider)
        : ref.watch(authorSearchProvider(_searchQuery));

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
                onChanged: (value) {
                  setState(() => _searchQuery = value);
                },
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
                _searchQuery = '';
                _searchController.clear();
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
              onPressed: () {
                setState(() {
                  _searchQuery = '';
                  _searchController.clear();
                });
              },
            ),
        ],
      ),
      body: creatorsAsync.when(
        loading: () => const Center(child: CupertinoActivityIndicator()),
        error: (error, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              Text('${context.tr('error_loading_recipes')}: $error'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => ref.invalidate(creatorsProvider),
                child: Text(context.tr('retry')),
              ),
            ],
          ),
        ),
        data: (creators) => creators.isEmpty
            ? _buildEmptyState(context, _searchQuery.isNotEmpty)
            : CustomScrollView(
                physics: const BouncingScrollPhysics(
                  parent: AlwaysScrollableScrollPhysics(),
                ),
                slivers: [
                  CupertinoSliverRefreshControl(
                    onRefresh: () async {
                      ref.invalidate(creatorsProvider);
                    },
                  ),
                  SliverPadding(
                    padding: EdgeInsets.only(
                      left: 16,
                      right: 16,
                      top: 16,
                      bottom: 100 + MediaQuery.of(context).padding.bottom,
                    ),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final creator = creators[index];
                          return _CreatorCard(
                            name: creator['authorName'] as String,
                            avatarUrl: creator['authorAvatarUrl'] as String?,
                            recipeCount: creator['recipeCount'] as int,
                            averageRating: creator['averageRating'] as double? ?? 0.0,
                            onTap: () => context.push(
                              '/author/${creator['authorId']}',
                              extra: {'authorName': creator['authorName']},
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
    final textSecondary = AppColors.textSecondary(context);
    
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isSearch ? Icons.search_off_rounded : Icons.people_outline_rounded,
              size: 80,
              color: textSecondary.withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            Text(
              isSearch ? context.tr('no_creators_found') : context.tr('no_creators_yet'),
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              isSearch
                  ? context.tr('try_different_search')
                  : context.tr('be_first_to_share'),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                color: textSecondary.withOpacity(0.7),
              ),
            ),
          ],
        ),
      ),
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
    final cardColor = AppColors.recipeSurface(context);
    final textPrimary = AppColors.textPrimary(context);
    final textSecondary = AppColors.textSecondary(context);
    final borderColor = AppColors.recipeBorderColor(context);
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
                    child: avatarUrl != null
                        ? ClipOval(
                            child: CachedNetworkImage(
                              imageUrl: avatarUrl!,
                              fit: BoxFit.cover,
                              placeholder: (_, __) => _buildInitial(textSecondary),
                              errorWidget: (_, __, ___) => _buildInitial(textSecondary),
                            ),
                          )
                        : _buildInitial(textSecondary),
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

  Widget _buildInitial(Color textColor) {
    return Container(
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white,
      ),
      child: Center(
        child: Text(
          name.isNotEmpty ? name[0].toUpperCase() : '?',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: AppColors.recipeAccent,
          ),
        ),
      ),
    );
  }
}
