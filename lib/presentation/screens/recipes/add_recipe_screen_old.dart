import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shoply/core/constants/app_colors.dart';
import 'package:shoply/core/constants/app_dimensions.dart';
import 'package:shoply/core/constants/app_text_styles.dart';
import 'package:shoply/data/models/recipe.dart';
import 'package:shoply/data/models/recipe_draft.dart';
import 'package:shoply/data/services/recipe_service.dart';
import 'package:shoply/data/services/recipe_draft_service.dart';
import 'package:shoply/core/localization/localization_helper.dart';
import 'package:shoply/presentation/screens/recipes/recipe_drafts_screen.dart';

class AddRecipeScreen extends StatefulWidget {
  final String? draftId;
  
  const AddRecipeScreen({super.key, this.draftId});

  @override
  State<AddRecipeScreen> createState() => _AddRecipeScreenState();
}

class _AddRecipeScreenState extends State<AddRecipeScreen> {
  final _formKey = GlobalKey<FormState>();
  final _recipeService = RecipeService();
  final _draftService = RecipeDraftService();
  final _imagePicker = ImagePicker();

  // Form controllers
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _prepTimeController = TextEditingController();
  final _cookTimeController = TextEditingController();
  final _servingsController = TextEditingController(text: '4');

  File? _selectedImage;
  bool _isLoading = false;
  bool _isLoadingDraft = false;
  String? _currentDraftId;

  final List<_IngredientInput> _ingredients = [_IngredientInput()];
  final List<TextEditingController> _instructionControllers = [TextEditingController()];

  @override
  void initState() {
    super.initState();
    if (widget.draftId != null) {
      _loadDraft(widget.draftId!);
    }
  }

  Future<void> _loadDraft(String draftId) async {
    setState(() => _isLoadingDraft = true);
    
    final draft = await _draftService.getDraft(draftId);
    if (draft != null && mounted) {
      _currentDraftId = draft.id;
      _nameController.text = draft.name;
      _descriptionController.text = draft.description;
      
      if (draft.prepTimeMinutes != null) {
        _prepTimeController.text = draft.prepTimeMinutes.toString();
      }
      if (draft.cookTimeMinutes != null) {
        _cookTimeController.text = draft.cookTimeMinutes.toString();
      }
      if (draft.defaultServings != null) {
        _servingsController.text = draft.defaultServings.toString();
      }
      
      if (draft.localImagePath != null && File(draft.localImagePath!).existsSync()) {
        _selectedImage = File(draft.localImagePath!);
      }
      
      // Load ingredients
      for (var ing in _ingredients) {
        ing.dispose();
      }
      _ingredients.clear();
      if (draft.ingredients.isEmpty) {
        _ingredients.add(_IngredientInput());
      } else {
        for (final ing in draft.ingredients) {
          final input = _IngredientInput();
          input.nameController.text = ing.name;
          input.amountController.text = ing.amount;
          input.unitController.text = ing.unit;
          _ingredients.add(input);
        }
      }
      
      // Load instructions
      for (var c in _instructionControllers) {
        c.dispose();
      }
      _instructionControllers.clear();
      if (draft.instructions.isEmpty) {
        _instructionControllers.add(TextEditingController());
      } else {
        for (final instruction in draft.instructions) {
          _instructionControllers.add(TextEditingController(text: instruction));
        }
      }
      
      setState(() => _isLoadingDraft = false);
    } else {
      setState(() => _isLoadingDraft = false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _prepTimeController.dispose();
    _cookTimeController.dispose();
    _servingsController.dispose();
    for (var ing in _ingredients) {
      ing.dispose();
    }
    for (var controller in _instructionControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  /// Check if form is complete enough to publish
  bool get _canPublish {
    return _nameController.text.trim().isNotEmpty &&
           _descriptionController.text.trim().isNotEmpty &&
           _selectedImage != null &&
           _prepTimeController.text.trim().isNotEmpty &&
           _cookTimeController.text.trim().isNotEmpty &&
           _servingsController.text.trim().isNotEmpty &&
           _ingredients.any((i) => i.nameController.text.isNotEmpty) &&
           _instructionControllers.any((c) => c.text.isNotEmpty);
  }

  /// Check if there's any data to save as draft
  bool get _hasDraftData {
    return _nameController.text.trim().isNotEmpty ||
           _descriptionController.text.trim().isNotEmpty ||
           _selectedImage != null ||
           _ingredients.any((i) => i.nameController.text.isNotEmpty) ||
           _instructionControllers.any((c) => c.text.isNotEmpty);
  }

  @override
  Widget build(BuildContext context) {
    final backgroundColor = AppColors.recipeBg(context);
    final textPrimary = AppColors.textPrimary(context);
    final textSecondary = AppColors.textSecondary(context);
    final inputFill = AppColors.recipeInput(context);
    
    if (_isLoadingDraft) {
      return Scaffold(
        backgroundColor: backgroundColor,
        appBar: AppBar(
          backgroundColor: backgroundColor,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back_ios_rounded, color: textPrimary),
            onPressed: () => context.pop(),
          ),
        ),
        body: const Center(child: CupertinoActivityIndicator()),
      );
    }
    
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: backgroundColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          widget.draftId != null 
              ? context.tr('edit_draft') 
              : context.tr('add_recipe_title'),
          style: TextStyle(
            color: textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_rounded, color: textPrimary),
          onPressed: () => _handleBack(),
        ),
        actions: [
          // Save as draft button (show when there's data to save)
          if (_hasDraftData)
            TextButton.icon(
              onPressed: _isLoading ? null : _saveDraft,
              icon: Icon(
                Icons.save_outlined,
                size: 18,
                color: _isLoading ? textSecondary : AppColors.info,
              ),
              label: Text(
                context.tr('save_draft'),
                style: TextStyle(
                  color: _isLoading ? textSecondary : AppColors.info,
                ),
              ),
            ),
          // Publish button
          TextButton(
            onPressed: _isLoading ? null : _publishRecipe,
            child: _isLoading
                ? CupertinoActivityIndicator(radius: 10)
                : Text(
                    context.tr('publish'),
                    style: TextStyle(
                      color: _canPublish ? AppColors.success : textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
        ],
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: EdgeInsets.only(
              left: AppDimensions.paddingLarge,
              right: AppDimensions.paddingLarge,
              top: AppDimensions.paddingLarge,
              bottom: AppDimensions.paddingLarge + MediaQuery.of(context).padding.bottom + 80,
            ),
            children: [
            // Image Picker
            GestureDetector(
              onTap: _pickImage,
              child: Container(
                height: 200,
                decoration: BoxDecoration(
                  color: inputFill,
                  borderRadius: BorderRadius.circular(12),
                  image: _selectedImage != null
                      ? DecorationImage(
                          image: FileImage(_selectedImage!),
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                child: _selectedImage == null
                    ? Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_photo_alternate, size: 50, color: textSecondary),
                          const SizedBox(height: 8),
                          Text(context.tr('add_photo'), style: TextStyle(color: textSecondary)),
                          const SizedBox(height: 4),
                          Text(
                            context.tr('photo_required'),
                            style: TextStyle(
                              color: AppColors.recipeAccentColor(context).withOpacity(0.8),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      )
                    : null,
              ),
            ),

            const SizedBox(height: AppDimensions.spacingLarge),

            // Recipe Name
            TextFormField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: context.tr('recipe_name'),
                hintText: context.tr('recipe_name_hint'),
              ),
              onChanged: (_) => setState(() {}),
            ),

            const SizedBox(height: AppDimensions.spacingMedium),

            // Description
            TextFormField(
              controller: _descriptionController,
              decoration: InputDecoration(
                labelText: context.tr('description'),
                hintText: context.tr('description_hint'),
              ),
              maxLines: 3,
              onChanged: (_) => setState(() {}),
            ),

            const SizedBox(height: AppDimensions.spacingMedium),

            // Time & Servings - Two rows for better label visibility
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _prepTimeController,
                    decoration: InputDecoration(
                      labelText: context.tr('prep_time'),
                      hintText: context.tr('in_minutes'),
                    ),
                    keyboardType: const TextInputType.numberWithOptions(decimal: false),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _cookTimeController,
                    decoration: InputDecoration(
                      labelText: context.tr('cook_time'),
                      hintText: context.tr('in_minutes'),
                    ),
                    keyboardType: const TextInputType.numberWithOptions(decimal: false),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppDimensions.spacingSmall),
            TextFormField(
              controller: _servingsController,
              decoration: InputDecoration(
                labelText: context.tr('servings'),
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: false),
              onChanged: (_) => setState(() {}),
            ),

            const SizedBox(height: AppDimensions.spacingLarge),

            // Ingredients Section
            Row(
              children: [
                Text(context.tr('ingredients'), style: AppTextStyles.h3),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.add_circle_outline),
                  onPressed: () => setState(() => _ingredients.add(_IngredientInput())),
                ),
              ],
            ),
            const SizedBox(height: AppDimensions.spacingSmall),
            ..._ingredients.asMap().entries.map((entry) {
              final index = entry.key;
              final ingredient = entry.value;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: TextFormField(
                        controller: ingredient.nameController,
                        decoration: InputDecoration(
                          hintText: context.tr('ingredient'),
                          isDense: true,
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextFormField(
                        controller: ingredient.amountController,
                        decoration: InputDecoration(
                          hintText: context.tr('amount'),
                          isDense: true,
                        ),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextFormField(
                        controller: ingredient.unitController,
                        decoration: InputDecoration(
                          hintText: context.tr('unit'),
                          isDense: true,
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                    if (_ingredients.length > 1)
                      IconButton(
                        icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
                        onPressed: () => setState(() {
                          _ingredients[index].dispose();
                          _ingredients.removeAt(index);
                        }),
                      ),
                  ],
                ),
              );
            }),

            const SizedBox(height: AppDimensions.spacingLarge),

            // Instructions Section
            Row(
              children: [
                Text(context.tr('instructions'), style: AppTextStyles.h3),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.add_circle_outline),
                  onPressed: () => setState(() => _instructionControllers.add(TextEditingController())),
                ),
              ],
            ),
            const SizedBox(height: AppDimensions.spacingSmall),
            ..._instructionControllers.asMap().entries.map((entry) {
              final index = entry.key;
              final controller = entry.value;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      margin: const EdgeInsets.only(top: 8),
                      decoration: BoxDecoration(
                        color: AppColors.recipeAccentColor(context),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          '${index + 1}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextFormField(
                        controller: controller,
                        decoration: InputDecoration(
                          hintText: context.tr('instruction_step'),
                        ),
                        maxLines: 2,
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                    if (_instructionControllers.length > 1)
                      IconButton(
                        icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
                        onPressed: () => setState(() {
                          _instructionControllers[index].dispose();
                          _instructionControllers.removeAt(index);
                        }),
                      ),
                  ],
                ),
              );
            }),

            const SizedBox(height: AppDimensions.spacingLarge),
          ],
        ),
          ),
        ),
    );
  }

  void _handleBack() {
    if (_hasDraftData && _currentDraftId == null) {
      // Show dialog asking to save as draft
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(context.tr('save_draft_question')),
          content: Text(context.tr('save_draft_question_desc')),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                context.pop();
              },
              child: Text(context.tr('discard')),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(ctx);
                await _saveDraft();
              },
              child: Text(context.tr('save_draft')),
            ),
          ],
        ),
      );
    } else {
      context.pop();
    }
  }

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (image != null) {
        setState(() => _selectedImage = File(image.path));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${context.tr('error')}: $e')),
        );
      }
    }
  }

  Future<void> _saveDraft() async {
    setState(() => _isLoading = true);
    
    try {
      final ingredients = _ingredients
          .map((i) => DraftIngredient(
                name: i.nameController.text.trim(),
                amount: i.amountController.text.trim(),
                unit: i.unitController.text.trim(),
              ))
          .toList();
      
      final instructions = _instructionControllers
          .map((c) => c.text.trim())
          .toList();
      
      final now = DateTime.now();
      final draftId = _currentDraftId ?? 'draft_${now.millisecondsSinceEpoch}';
      
      final draft = RecipeDraft(
        id: draftId,
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim(),
        localImagePath: _selectedImage?.path,
        prepTimeMinutes: int.tryParse(_prepTimeController.text.trim()),
        cookTimeMinutes: int.tryParse(_cookTimeController.text.trim()),
        defaultServings: int.tryParse(_servingsController.text.trim()),
        ingredients: ingredients,
        instructions: instructions,
        createdAt: now,
        updatedAt: now,
      );
      
      await _draftService.saveDraft(draft);
      
      if (!mounted) return;
      
      // Navigate directly to drafts - use go() to replace current route
      context.go('/recipes/drafts');
      
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${context.tr('error')}: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _publishRecipe() async {
    // Validate image
    if (_selectedImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.tr('image_required_error')),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    
    // Validate form
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.tr('name_required_error')),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    
    if (_descriptionController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.tr('description_required_error')),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final prepTime = int.tryParse(_prepTimeController.text.trim());
      final cookTime = int.tryParse(_cookTimeController.text.trim());
      final servings = int.tryParse(_servingsController.text.trim());

      if (prepTime == null || cookTime == null || servings == null) {
        throw Exception(context.tr('invalid_numbers_error'));
      }

      // Validate ingredients
      final ingredients = <Ingredient>[];
      for (var ing in _ingredients) {
        final name = ing.nameController.text.trim();
        final amountStr = ing.amountController.text.trim();
        final unit = ing.unitController.text.trim();
        
        if (name.isEmpty || amountStr.isEmpty || unit.isEmpty) {
          throw Exception(context.tr('incomplete_ingredients_error'));
        }
        
        final amount = _parseAmount(amountStr);
        if (amount == null) {
          throw Exception('${context.tr('invalid_amount_error')}: $name');
        }
        
        ingredients.add(Ingredient(
          name: name,
          amount: amount,
          unit: unit,
        ));
      }

      // Validate instructions
      final instructions = _instructionControllers
          .map((c) => c.text.trim())
          .where((text) => text.isNotEmpty)
          .toList();
      
      if (instructions.isEmpty) {
        throw Exception(context.tr('no_instructions_error'));
      }

      // Upload image
      final imageUrl = await _recipeService.uploadRecipeImage(
        _selectedImage!.path,
        'recipe_${DateTime.now().millisecondsSinceEpoch}.jpg',
      );

      // Create recipe
      final recipe = Recipe(
        id: '',
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim(),
        imageUrl: imageUrl,
        prepTimeMinutes: prepTime,
        cookTimeMinutes: cookTime,
        defaultServings: servings,
        ingredients: ingredients,
        instructions: instructions,
        authorId: '',
        authorName: '',
        createdAt: DateTime.now(),
      );
      
      final createdRecipe = await _recipeService.createRecipe(recipe);
      
      // Delete draft if editing one
      if (_currentDraftId != null) {
        await _draftService.deleteDraft(_currentDraftId!);
      }

      if (mounted) {
        await Future.delayed(const Duration(milliseconds: 500));
        
        if (mounted) {
          Navigator.of(context).pop();
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${context.tr('recipe_published')}: "${createdRecipe.name}"'),
              backgroundColor: Colors.green,
            ),
          );
          
          Future.delayed(const Duration(milliseconds: 100), () {
            if (mounted) {
              context.push('/recipes/${createdRecipe.id}');
            }
          });
        }
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${context.tr('error')}: $e'),
            backgroundColor: AppColors.error,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  double? _parseAmount(String input) {
    final cleaned = input.trim().replaceAll(',', '.');
    
    final simple = double.tryParse(cleaned);
    if (simple != null) return simple;
    
    if (cleaned.contains('/')) {
      final parts = cleaned.split('/');
      if (parts.length == 2) {
        final numerator = double.tryParse(parts[0].trim());
        final denominator = double.tryParse(parts[1].trim());
        if (numerator != null && denominator != null && denominator != 0) {
          return numerator / denominator;
        }
      }
    }
    
    if (cleaned.contains('-')) {
      final parts = cleaned.split('-');
      if (parts.isNotEmpty) {
        final first = double.tryParse(parts[0].trim());
        if (first != null) return first;
      }
    }
    
    return null;
  }
}

class _IngredientInput {
  final nameController = TextEditingController();
  final amountController = TextEditingController();
  final unitController = TextEditingController();

  void dispose() {
    nameController.dispose();
    amountController.dispose();
    unitController.dispose();
  }
}
