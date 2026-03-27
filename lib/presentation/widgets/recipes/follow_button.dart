import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shoply/core/constants/app_colors.dart';
import 'package:shoply/core/localization/localization_helper.dart';
import 'package:shoply/data/services/recipe_features_service.dart';

/// Provider to track followed creator IDs
final followedCreatorsProvider = StateNotifierProvider<FollowedCreatorsNotifier, Set<String>>((ref) {
  return FollowedCreatorsNotifier();
});

class FollowedCreatorsNotifier extends StateNotifier<Set<String>> {
  FollowedCreatorsNotifier() : super({}) {
    _loadFollowedCreators();
  }

  final _service = RecipeFeaturesService.instance;

  Future<void> _loadFollowedCreators() async {
    final ids = await _service.getFollowedCreatorIds();
    state = ids;
  }

  Future<void> toggleFollow(String creatorId) async {
    final isFollowing = state.contains(creatorId);
    
    // Optimistic update
    if (isFollowing) {
      state = Set.from(state)..remove(creatorId);
    } else {
      state = Set.from(state)..add(creatorId);
    }

    // Sync with server
    final success = isFollowing
        ? await _service.unfollowCreator(creatorId)
        : await _service.followCreator(creatorId);

    if (!success) {
      // Revert on failure
      if (isFollowing) {
        state = Set.from(state)..add(creatorId);
      } else {
        state = Set.from(state)..remove(creatorId);
      }
    }
  }

  bool isFollowing(String creatorId) => state.contains(creatorId);
}

/// Button to follow/unfollow a recipe creator
class FollowButton extends ConsumerWidget {
  final String creatorId;
  final bool compact;

  const FollowButton({
    super.key,
    required this.creatorId,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final followedIds = ref.watch(followedCreatorsProvider);
    final isFollowing = followedIds.contains(creatorId);

    if (compact) {
      return IconButton(
        onPressed: () {
          ref.read(followedCreatorsProvider.notifier).toggleFollow(creatorId);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(isFollowing 
                  ? context.tr('unfollowed') 
                  : context.tr('following_now')),
              duration: const Duration(seconds: 2),
            ),
          );
        },
        icon: Icon(
          isFollowing ? Icons.person_remove_rounded : Icons.person_add_rounded,
          color: isFollowing ? AppColors.textSecondary(context) : AppColors.recipeAccentColor(context),
        ),
      );
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      child: ElevatedButton.icon(
        onPressed: () {
          ref.read(followedCreatorsProvider.notifier).toggleFollow(creatorId);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(isFollowing 
                  ? context.tr('unfollowed') 
                  : context.tr('following_now')),
              duration: const Duration(seconds: 2),
            ),
          );
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: isFollowing 
              ? AppColors.recipeSurface(context) 
              : AppColors.recipeAccentColor(context),
          foregroundColor: isFollowing 
              ? AppColors.textPrimary(context) 
              : Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: isFollowing 
                ? BorderSide(color: AppColors.recipeBorderColor(context)) 
                : BorderSide.none,
          ),
        ),
        icon: Icon(
          isFollowing ? Icons.check_rounded : Icons.add_rounded,
          size: 18,
        ),
        label: Text(
          isFollowing ? context.tr('following') : context.tr('follow'),
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}
