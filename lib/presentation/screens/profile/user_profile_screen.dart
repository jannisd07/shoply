import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shoply/core/constants/app_dimensions.dart';
import 'package:shoply/core/constants/app_text_styles.dart';
import 'package:shoply/data/models/recipe.dart';
import 'package:shoply/data/services/supabase_service.dart';
import 'package:cached_network_image/cached_network_image.dart';

class UserProfileScreen extends ConsumerStatefulWidget {
  final String userId;
  final String userName;
  
  const UserProfileScreen({
    super.key,
    required this.userId,
    required this.userName,
  });
  
  @override
  ConsumerState<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends ConsumerState<UserProfileScreen> {
  List<Recipe> _userRecipes = [];
  bool _isLoading = true;
  String? _avatarUrl;
  
  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }
  
  Future<void> _loadUserProfile() async {
    try {
      // Get user info
      final userResponse = await SupabaseService.instance.client
          .from('users')
          .select('avatar_url')
          .eq('id', widget.userId)
          .maybeSingle();
      
      // Get user's recipes
      final recipesResponse = await SupabaseService.instance.client
          .from('recipes')
          .select('*')
          .eq('author_id', widget.userId)
          .order('created_at', ascending: false);
      
      if (mounted) {
        setState(() {
          _avatarUrl = userResponse?['avatar_url'];
          _userRecipes = (recipesResponse as List)
              .map((json) => Recipe.fromJson(json))
              .toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading profile: $e')),
        );
      }
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.userName),
      ),
      body: _isLoading
          ? const Center(child: CupertinoActivityIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(AppDimensions.screenHorizontalPadding),
              child: Column(
                children: [
                  // Profile header
                  CircleAvatar(
                    radius: 50,
                    backgroundImage: _avatarUrl != null
                        ? NetworkImage(_avatarUrl!)
                        : null,
                    child: _avatarUrl == null
                        ? Text(
                            widget.userName[0].toUpperCase(),
                            style: const TextStyle(fontSize: 32),
                          )
                        : null,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    widget.userName,
                    style: AppTextStyles.h2,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${_userRecipes.length} ${_userRecipes.length == 1 ? "recipe" : "recipes"}',
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 32),
                  
                  // Recipes grid
                  if (_userRecipes.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(32),
                      child: Text(
                        'No recipes yet',
                        style: AppTextStyles.bodyMedium.copyWith(color: Colors.grey),
                      ),
                    )
                  else
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: 0.75,
                      ),
                      itemCount: _userRecipes.length,
                      itemBuilder: (context, index) {
                        final recipe = _userRecipes[index];
                        return _buildRecipeCard(recipe);
                      },
                    ),
                ],
              ),
            ),
    );
  }
  
  Widget _buildRecipeCard(Recipe recipe) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('/recipes/${recipe.id}'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image
            CachedNetworkImage(
              imageUrl: recipe.imageUrl,
              height: 120,
              width: double.infinity,
              fit: BoxFit.cover,
              placeholder: (context, url) => Container(
                height: 120,
                color: Colors.grey.shade200,
                child: const Center(child: CupertinoActivityIndicator()),
              ),
              errorWidget: (context, url, error) => Container(
                height: 120,
                color: Colors.grey.shade200,
                child: const Icon(Icons.restaurant, size: 40),
              ),
            ),
            // Content
            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    recipe.name,
                    style: AppTextStyles.h4,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.star, size: 14, color: Colors.amber),
                      const SizedBox(width: 4),
                      Text(
                        recipe.averageRating > 0
                            ? recipe.averageRating.toStringAsFixed(1)
                            : 'New',
                        style: AppTextStyles.bodySmall,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
