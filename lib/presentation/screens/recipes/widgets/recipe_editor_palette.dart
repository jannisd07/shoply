import 'package:flutter/material.dart';
import 'package:shoply/core/constants/app_colors.dart';

/// "Cookbook Evening" colours shared by the recipe editor and cooking mode
/// (both used to carry their own copy of these getters).
class RecipeEditorPalette {
  final bool isDark;

  const RecipeEditorPalette(this.isDark);

  RecipeEditorPalette.of(BuildContext context)
      : isDark = Theme.of(context).brightness == Brightness.dark;

  Color get bg => isDark ? AppColors.recipeDarkBg : AppColors.recipeLightBg;
  Color get card => isDark ? AppColors.recipeDarkSurface : AppColors.recipeLightSurface;
  Color get input => isDark ? AppColors.recipeDarkInput : AppColors.lightInputFill;
  Color get textPrimary =>
      isDark ? AppColors.recipeDarkTextPrimary : AppColors.lightTextPrimary;
  Color get textSecondary =>
      isDark ? AppColors.recipeDarkTextSecondary : AppColors.lightTextSecondary;
  Color get border => isDark ? AppColors.recipeDarkBorder : AppColors.recipeLightBorder;
  Color get accent => isDark ? AppColors.recipeAccentDark : AppColors.recipeAccent;
  Color get green => isDark ? AppColors.recipeGreenDark : AppColors.recipeGreen;
  Color get orange => isDark ? AppColors.recipeStepDark : AppColors.recipeStep;
}
