import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:go_router/go_router.dart';
import 'package:shoply/core/constants/app_colors.dart';
import 'package:shoply/core/constants/app_dimensions.dart';
import 'package:shoply/data/models/recipe_draft.dart';
import 'package:shoply/data/services/recipe_draft_service.dart';
import 'package:shoply/core/localization/localization_helper.dart';

class RecipeDraftsScreen extends StatefulWidget {
  const RecipeDraftsScreen({super.key});

  @override
  State<RecipeDraftsScreen> createState() => _RecipeDraftsScreenState();
}

class _RecipeDraftsScreenState extends State<RecipeDraftsScreen> {
  final _draftService = RecipeDraftService();
  List<RecipeDraft> _drafts = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDrafts();
  }

  Future<void> _loadDrafts() async {
    setState(() => _isLoading = true);
    final drafts = await _draftService.getDrafts();
    if (mounted) {
      setState(() {
        _drafts = drafts;
        _isLoading = false;
      });
    }
  }

  Future<void> _deleteDraft(RecipeDraft draft) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.tr('delete_draft')),
        content: Text(context.tr('delete_draft_confirm')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.tr('cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(context.tr('delete')),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _draftService.deleteDraft(draft.id);
      _loadDrafts();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.tr('draft_deleted'))),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final backgroundColor = AppColors.recipeBg(context);
    final textPrimary = AppColors.textPrimary(context);
    final textSecondary = AppColors.textSecondary(context);
    final cardColor = AppColors.recipeSurface(context);
    final borderColor = AppColors.recipeBorderColor(context);

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: backgroundColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          context.tr('my_drafts'),
          style: TextStyle(
            color: textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_rounded, color: textPrimary),
          onPressed: () => context.pop(),
        ),
      ),
      body: _isLoading
          ? const Center(child: CupertinoActivityIndicator())
          : _drafts.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.edit_note_rounded,
                        size: 64,
                        color: textSecondary.withOpacity(0.5),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        context.tr('no_drafts'),
                        style: TextStyle(
                          color: textSecondary,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        context.tr('no_drafts_hint'),
                        style: TextStyle(
                          color: textSecondary.withOpacity(0.7),
                          fontSize: 14,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(AppDimensions.paddingLarge),
                  itemCount: _drafts.length,
                  itemBuilder: (context, index) {
                    final draft = _drafts[index];
                    return _DraftCard(
                      draft: draft,
                      cardColor: cardColor,
                      borderColor: borderColor,
                      textPrimary: textPrimary,
                      textSecondary: textSecondary,
                      onTap: () async {
                        // Navigate to edit draft
                        await context.push('/recipes/add', extra: {'draftId': draft.id});
                        // Reload drafts when returning
                        _loadDrafts();
                      },
                      onDelete: () => _deleteDraft(draft),
                    );
                  },
                ),
    );
  }
}

class _DraftCard extends StatelessWidget {
  final RecipeDraft draft;
  final Color cardColor;
  final Color borderColor;
  final Color textPrimary;
  final Color textSecondary;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _DraftCard({
    required this.draft,
    required this.cardColor,
    required this.borderColor,
    required this.textPrimary,
    required this.textSecondary,
    required this.onTap,
    required this.onDelete,
  });

  String _formatDate(DateTime date, BuildContext context) {
    final now = DateTime.now();
    final diff = now.difference(date);
    
    if (diff.inMinutes < 60) {
      return context.tr('minutes_ago').replaceAll('{count}', '${diff.inMinutes}');
    } else if (diff.inHours < 24) {
      return context.tr('hours_ago').replaceAll('{count}', '${diff.inHours}');
    } else if (diff.inDays < 7) {
      return context.tr('days_ago').replaceAll('{count}', '${diff.inDays}');
    } else {
      return '${date.day}.${date.month}.${date.year}';
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasImage = draft.localImagePath != null && 
                     File(draft.localImagePath!).existsSync();
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: borderColor),
          ),
          child: Row(
            children: [
              // Image or placeholder
              ClipRRect(
                borderRadius: const BorderRadius.horizontal(left: Radius.circular(12)),
                child: SizedBox(
                  width: 100,
                  height: 100,
                  child: hasImage
                      ? Image.file(
                          File(draft.localImagePath!),
                          fit: BoxFit.cover,
                        )
                      : Container(
                          color: borderColor,
                          child: Icon(
                            Icons.image_outlined,
                            size: 32,
                            color: textSecondary.withOpacity(0.5),
                          ),
                        ),
                ),
              ),
              // Content
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        draft.name.isEmpty 
                            ? context.tr('untitled_draft')
                            : draft.name,
                        style: TextStyle(
                          color: draft.name.isEmpty 
                              ? textSecondary 
                              : textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          fontStyle: draft.name.isEmpty 
                              ? FontStyle.italic 
                              : FontStyle.normal,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        draft.description.isEmpty
                            ? context.tr('no_description')
                            : draft.description,
                        style: TextStyle(
                          color: textSecondary,
                          fontSize: 13,
                          fontStyle: draft.description.isEmpty 
                              ? FontStyle.italic 
                              : FontStyle.normal,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(
                            Icons.access_time_rounded,
                            size: 14,
                            color: textSecondary.withOpacity(0.7),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _formatDate(draft.updatedAt, context),
                            style: TextStyle(
                              color: textSecondary.withOpacity(0.7),
                              fontSize: 12,
                            ),
                          ),
                          const Spacer(),
                          // Completion indicator
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: draft.isComplete
                                  ? AppColors.recipeGreenColor(context).withOpacity(0.15)
                                  : AppColors.recipeAccentColor(context).withOpacity(0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              draft.isComplete
                                  ? context.tr('ready_to_publish')
                                  : context.tr('incomplete'),
                              style: TextStyle(
                                color: draft.isComplete
                                    ? AppColors.recipeGreenColor(context)
                                    : AppColors.recipeAccentColor(context),
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              // Delete button
              IconButton(
                icon: Icon(
                  Icons.delete_outline_rounded,
                  color: textSecondary,
                ),
                onPressed: onDelete,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
