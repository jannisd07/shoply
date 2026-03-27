import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shoply/core/constants/app_colors.dart';
import 'package:shoply/core/constants/app_dimensions.dart';
import 'package:shoply/core/constants/app_text_styles.dart';
import 'package:shoply/core/localization/localization_helper.dart';
import 'package:shoply/presentation/state/lists_provider.dart';
import 'package:shoply/presentation/widgets/common/empty_state.dart';
import 'package:shoply/presentation/widgets/common/loading_indicator.dart';

class ListsScreen extends ConsumerStatefulWidget {
  const ListsScreen({super.key});

  @override
  ConsumerState<ListsScreen> createState() => _ListsScreenState();
}

enum SortOption {
  custom('Custom'),
  itemsDesc('Most Items'),
  itemsAsc('Least Items'),
  nameAsc('A-Z'),
  nameDesc('Z-A');

  final String label;
  const SortOption(this.label);
}

class _ListsScreenState extends ConsumerState<ListsScreen> {
  SortOption _currentSort = SortOption.itemsDesc;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(listsNotifierProvider.notifier).loadLists();
      
      final uri = GoRouterState.of(context).uri;
      if (uri.queryParameters['create'] == 'true') {
        _showCreateListDialog(context, ref);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final listsAsync = ref.watch(listsNotifierProvider);

    return Scaffold(
      body: Stack(
        children: [
          // Background Image
          Positioned.fill(
            child: Image.asset(
              'assets/images/app_background.jpg',
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                // Fallback if image doesn't exist
                return Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
                        Theme.of(context).scaffoldBackgroundColor,
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          
          // Main Content Card Overlay
          SafeArea(
            child: Column(
              children: [
                // Spacer to show background image at top
                const SizedBox(height: 180),
                
                // Main Content Container with rounded top corners
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? const Color(0xFF1C1C1E)
                          : const Color(0xFFF5F5F5), // Leicht grau
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(AppDimensions.bottomSheetBorderRadius),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 24,
                          offset: const Offset(0, -8),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        // Header Section
                        Padding(
                          padding: const EdgeInsets.all(AppDimensions.screenHorizontalPadding),
                          child: Row(
                            children: [
                              // Title
                              Expanded(
                                child: Text(
                                  context.tr('my_lists'),
                                  style: AppTextStyles.h2.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              
                              // Join List Icon
                              IconButton(
                                icon: const Icon(Icons.group_add),
                                onPressed: () => _showJoinListDialog(context, ref),
                                tooltip: context.tr('join_list'),
                                style: IconButton.styleFrom(
                                  backgroundColor: Theme.of(context).cardColor,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                              
                              const SizedBox(width: 8),
                              
                              // Sort Icon
                              IconButton(
                                icon: const Icon(Icons.sort),
                                onPressed: () => _showSortMenu(context),
                                tooltip: 'Sort',
                                style: IconButton.styleFrom(
                                  backgroundColor: Theme.of(context).cardColor,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        
                        // Lists Content
                        Expanded(
                          child: listsAsync.when(
                            data: (lists) {
                              if (lists.isEmpty) {
                                return EmptyState(
                                  icon: Icons.list_alt,
                                  title: context.tr('no_lists_yet'),
                                  subtitle: context.tr('create_first_list'),
                                  actionText: context.tr('create_list'),
                                  onActionPressed: () => _showCreateListDialog(context, ref),
                                );
                              }

                              // Sort lists
                              final sortedLists = [...lists];
                              switch (_currentSort) {
                                case SortOption.custom:
                                  // Use order_index from database
                                  break;
                                case SortOption.itemsDesc:
                                  sortedLists.sort((a, b) => (b.itemCount ?? 0).compareTo(a.itemCount ?? 0));
                                  break;
                                case SortOption.itemsAsc:
                                  sortedLists.sort((a, b) => (a.itemCount ?? 0).compareTo(b.itemCount ?? 0));
                                  break;
                                case SortOption.nameAsc:
                                  sortedLists.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
                                  break;
                                case SortOption.nameDesc:
                                  sortedLists.sort((a, b) => b.name.toLowerCase().compareTo(a.name.toLowerCase()));
                                  break;
                              }

                              return NotificationListener<ScrollNotification>(
                                onNotification: (notification) {
                                  if (notification is ScrollStartNotification) {
                                    FocusScope.of(context).unfocus();
                                  }
                                  return false;
                                },
                                child: RefreshIndicator(
                                onRefresh: () async {
                                  ref.invalidate(listsNotifierProvider);
                                },
                                child: _currentSort == SortOption.custom
                                    ? ReorderableListView.builder(
                                        padding: const EdgeInsets.only(
                                          left: AppDimensions.screenHorizontalPadding,
                                          right: AppDimensions.screenHorizontalPadding,
                                          bottom: 100,
                                        ),
                                        itemCount: sortedLists.length,
                                        autoScrollerVelocityScalar: 25.0, // Faster auto-scroll when dragging near edges
                                        onReorder: (oldIndex, newIndex) async {
                                          await ref.read(listsNotifierProvider.notifier).reorderLists(oldIndex, newIndex);
                                        },
                                        itemBuilder: (context, index) {
                                          final list = sortedLists[index];
                                          return _buildListCard(context, list);
                                        },
                                      )
                                    : ListView.builder(
                                        padding: const EdgeInsets.only(
                                          left: AppDimensions.screenHorizontalPadding,
                                          right: AppDimensions.screenHorizontalPadding,
                                          bottom: 100,
                                        ),
                                        itemCount: sortedLists.length,
                                  itemBuilder: (context, index) {
                                    final list = sortedLists[index];
                                    return _buildListCard(context, list);
                                  },
                                ),
                              ),
                              );
                            },
                            loading: () => const LoadingIndicator(message: 'Loading lists...'),
                            error: (error, stack) => Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.error_outline, size: 48, color: Colors.red),
                                  const SizedBox(height: 16),
                                  Text('Error: $error'),
                                  const SizedBox(height: 16),
                                  ElevatedButton(
                                    onPressed: () => ref.invalidate(listsNotifierProvider),
                                    child: Text(context.tr('retry')),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // Floating Action Button - Top Right (iOS 26 glass style)
          Positioned(
            top: 50,
            right: AppDimensions.screenHorizontalPadding,
            child: ClipOval(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withOpacity(0.3),
                      width: 1.5,
                    ),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => _showCreateListDialog(context, ref),
                      customBorder: const CircleBorder(),
                      splashColor: Colors.white.withOpacity(0.3),
                      highlightColor: Colors.white.withOpacity(0.1),
                      child: Icon(
                        Icons.add,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildListCard(BuildContext context, dynamic list) {
    const baseHeight = 98.0; // Aktuelle Höhe als Basis
    final cardHeight = baseHeight * 1.75; // 1.75x höher
    
    return Container(
      key: Key(list.id), // Key für ReorderableListView
      margin: const EdgeInsets.only(bottom: AppDimensions.spacingMedium),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppDimensions.cardBorderRadius),
        child: Container(
          decoration: BoxDecoration(
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.white // Dark Mode: Weiß
                : Colors.black, // Light Mode: Schwarz
            borderRadius: BorderRadius.circular(AppDimensions.cardBorderRadius),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                context.push('/lists/${list.id}?name=${Uri.encodeComponent(list.name)}');
              },
              borderRadius: BorderRadius.circular(AppDimensions.cardBorderRadius),
          child: SizedBox(
            height: cardHeight,
            child: Padding(
              padding: const EdgeInsets.all(AppDimensions.cardPadding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // List Name oben links
                  Text(
                    list.name,
                    style: AppTextStyles.h4.copyWith(
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.black // Dark Mode: Schwarz
                          : Colors.white, // Light Mode: Weiß
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  // Item count unten links
                  Text(
                    '${list.itemCount ?? 0} Items',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.black54 // Dark Mode: Schwarz (transparent)
                          : Colors.white70, // Light Mode: Weiß (transparent)
                    ),
                  ),
                ],
              ),
            ),
          ),
            ),
          ),
        ),
      ),
    );
  }

  void _showSortMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(AppDimensions.screenHorizontalPadding),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(context.tr('sort_by'), style: AppTextStyles.h3),
            const SizedBox(height: AppDimensions.spacingMedium),
            for (final option in SortOption.values)
              ListTile(
                leading: _currentSort == option
                    ? const Icon(Icons.check_circle, color: AppColors.lightAccent)
                    : const Icon(Icons.circle_outlined),
                title: Text(_getSortOptionLabel(context, option)),
                onTap: () {
                  setState(() {
                    _currentSort = option;
                  });
                  Navigator.pop(context);
                },
              ),
          ],
        ),
      ),
    );
  }

  String _getSortOptionLabel(BuildContext context, SortOption option) {
    switch (option) {
      case SortOption.custom:
        return context.tr('sort_custom');
      case SortOption.itemsDesc:
        return context.tr('sort_items_desc');
      case SortOption.itemsAsc:
        return context.tr('sort_items_asc');
      case SortOption.nameAsc:
        return context.tr('sort_name_asc');
      case SortOption.nameDesc:
        return context.tr('sort_name_desc');
    }
  }

  void _showCreateListDialog(BuildContext context, WidgetRef ref) {
    final controller = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.tr('create_list')),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            labelText: context.tr('list_name_label'),
            hintText: context.tr('list_name_hint'),
          ),
          autofocus: true,
          textCapitalization: TextCapitalization.words,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(context.tr('cancel')),
          ),
          ElevatedButton(
            onPressed: () async {
              if (controller.text.trim().isEmpty) return;

              try {
                await ref
                    .read(listsNotifierProvider.notifier)
                    .createList(controller.text.trim());

                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(context.tr('list_created'))),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e')),
                  );
                }
              }
            },
            child: Text(context.tr('create')),
          ),
        ],
      ),
    );
  }

  void _showJoinListDialog(BuildContext context, WidgetRef ref) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.tr('join_list')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(context.tr('enter_share_code_desc')),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                hintText: 'ABC123 or https://...',
                border: OutlineInputBorder(),
              ),
              textCapitalization: TextCapitalization.characters,
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(context.tr('cancel')),
          ),
          ElevatedButton(
            onPressed: () async {
              final input = controller.text.trim();
              if (input.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(context.tr('enter_code_or_link'))),
                );
                return;
              }

              try {
                final list = input.startsWith('http')
                    ? await ref.read(listsNotifierProvider.notifier).joinListWithLink(input)
                    : await ref.read(listsNotifierProvider.notifier).joinListWithCode(input.toUpperCase());

                if (context.mounted) {
                  Navigator.pop(context);
                  if (list != null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('${context.tr('joined_list')}: ${list.name}')),
                    );
                  }
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e')),
                  );
                }
              }
            },
            child: Text(context.tr('join')),
          ),
        ],
      ),
    );
  }
}
