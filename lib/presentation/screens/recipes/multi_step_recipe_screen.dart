import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shoply/core/localization/localization_helper.dart';
import 'package:shoply/data/models/recipe.dart';
import 'package:shoply/data/models/recipe_draft.dart';
import 'package:shoply/data/services/recipe_draft_service.dart';
import 'package:shoply/data/services/recipe_service.dart';
import 'package:shoply/presentation/screens/recipes/recipe_draft_images.dart';
import 'package:shoply/presentation/screens/recipes/widgets/recipe_editor_palette.dart';
import 'package:shoply/presentation/screens/recipes/widgets/step_progress_ring.dart';
import 'package:shoply/presentation/state/recipes_provider.dart';

/// Multi-step recipe editor (photo & name, times, ingredients, steps) for
/// new recipes, drafts and editing an existing recipe.
///
/// In edit mode the screen pops with `true` after a successful save so the
/// caller can reload the recipe.
class MultiStepRecipeScreen extends ConsumerStatefulWidget {
  final String? draftId;
  final String? recipeId;

  const MultiStepRecipeScreen({super.key, this.draftId, this.recipeId});

  @override
  ConsumerState<MultiStepRecipeScreen> createState() => _MultiStepRecipeScreenState();
}

class _MultiStepRecipeScreenState extends ConsumerState<MultiStepRecipeScreen> {
  final _recipeService = RecipeService();
  final _draftService = RecipeDraftService();
  final _imagePicker = ImagePicker();
  late PageController _pageController;

  int _currentStep = 0;
  static const int _totalSteps = 4;

  // Form controllers
  final _nameController = TextEditingController();
  final _prepTimeController = TextEditingController();
  final _cookTimeController = TextEditingController();
  final _servingsController = TextEditingController(text: '4');

  File? _selectedImage;
  String? _existingImageUrl;
  bool _isLoading = false;
  bool _isLoadingData = false;
  String? _currentDraftId;
  String? _currentDraftImagePath;
  String? _editingRecipeId;

  // Original values for edit mode (to detect changes)
  String? _originalName;
  String? _originalPrepTime;
  String? _originalCookTime;
  String? _originalServings;
  List<String>? _originalIngredientNames;
  List<String>? _originalInstructions;

  final List<_IngredientInput> _ingredients = [_IngredientInput()];
  final List<TextEditingController> _instructionControllers = [TextEditingController()];

  RecipeEditorPalette _p = const RecipeEditorPalette(false);

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    if (widget.recipeId != null) {
      _loadExistingRecipe(widget.recipeId!);
    } else if (widget.draftId != null) {
      _loadDraft(widget.draftId!);
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _nameController.dispose();
    _prepTimeController.dispose();
    _servingsController.dispose();
    _cookTimeController.dispose();
    for (final ing in _ingredients) {
      ing.dispose();
    }
    for (final controller in _instructionControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  /// Replaces the ingredient and instruction rows (disposing the old
  /// controllers); always leaves at least one empty row of each.
  void _populateRows({
    required List<({String name, String amount, String unit})> ingredients,
    required List<String> instructions,
  }) {
    for (final ing in _ingredients) {
      ing.dispose();
    }
    _ingredients
      ..clear()
      ..addAll(ingredients.map((i) => _IngredientInput()
        ..nameController.text = i.name
        ..amountController.text = i.amount
        ..unitController.text = i.unit));
    if (_ingredients.isEmpty) _ingredients.add(_IngredientInput());

    for (final controller in _instructionControllers) {
      controller.dispose();
    }
    _instructionControllers
      ..clear()
      ..addAll(instructions.map((text) => TextEditingController(text: text)));
    if (_instructionControllers.isEmpty) {
      _instructionControllers.add(TextEditingController());
    }
  }

  Future<void> _loadExistingRecipe(String recipeId) async {
    setState(() => _isLoadingData = true);

    try {
      final recipe = await _recipeService.getRecipeById(recipeId);
      if (!mounted) return;
      _editingRecipeId = recipe.id;
      _nameController.text = recipe.name;
      _existingImageUrl = recipe.imageUrl;
      _prepTimeController.text = recipe.prepTimeMinutes.toString();
      _cookTimeController.text = recipe.cookTimeMinutes.toString();
      _servingsController.text = recipe.defaultServings.toString();

      _originalName = recipe.name;
      _originalPrepTime = recipe.prepTimeMinutes.toString();
      _originalCookTime = recipe.cookTimeMinutes.toString();
      _originalServings = recipe.defaultServings.toString();
      _originalIngredientNames = recipe.ingredients.map((i) => i.name).toList();
      _originalInstructions = recipe.instructions.toList();

      _populateRows(
        ingredients: [
          for (final ing in recipe.ingredients)
            (name: ing.name, amount: ing.amount.toString(), unit: ing.unit),
        ],
        instructions: recipe.instructions,
      );
      setState(() => _isLoadingData = false);
    } catch (e) {
      debugPrint('❌ [RECIPE_EDITOR] Failed to load recipe $recipeId: $e');
      if (!mounted) return;
      setState(() => _isLoadingData = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('recipe_load_failed'))),
      );
    }
  }

  Future<void> _loadDraft(String draftId) async {
    setState(() => _isLoadingData = true);

    try {
      final draft = await _draftService.getDraft(draftId);
      final image = await RecipeDraftImages.resolve(draft?.localImagePath);
      if (draft != null && mounted) {
        _currentDraftId = draft.id;
        _currentDraftImagePath = image?.path;
        _selectedImage = image;
        _nameController.text = draft.name;
        if (draft.prepTimeMinutes != null) _prepTimeController.text = draft.prepTimeMinutes.toString();
        if (draft.cookTimeMinutes != null) _cookTimeController.text = draft.cookTimeMinutes.toString();
        if (draft.defaultServings != null) _servingsController.text = draft.defaultServings.toString();

        _populateRows(
          ingredients: [
            for (final ing in draft.ingredients)
              (name: ing.name, amount: ing.amount, unit: ing.unit),
          ],
          instructions: draft.instructions,
        );
      }

      if (mounted) setState(() => _isLoadingData = false);
    } catch (e) {
      debugPrint('❌ [RECIPE_EDITOR] Failed to load draft $draftId: $e');
      if (!mounted) return;
      setState(() => _isLoadingData = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('error_generic', params: {'error': '$e'}))),
      );
    }
  }

  void _goToStep(int step) {
    if (step >= 0 && step < _totalSteps) {
      FocusScope.of(context).unfocus();
      setState(() => _currentStep = step);
      _pageController.animateToPage(
        step,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _nextStep() => _goToStep(_currentStep + 1);

  void _previousStep() => _goToStep(_currentStep - 1);

  bool get _canProceed {
    switch (_currentStep) {
      case 0:
        return _nameController.text.trim().isNotEmpty &&
            (_selectedImage != null || _existingImageUrl != null);
      case 1:
        return _prepTimeController.text.trim().isNotEmpty &&
            _cookTimeController.text.trim().isNotEmpty &&
            _servingsController.text.trim().isNotEmpty;
      case 2:
        return _ingredients.any((i) => i.nameController.text.isNotEmpty);
      case 3:
        return _instructionControllers.any((c) => c.text.isNotEmpty);
      default:
        return false;
    }
  }

  bool get _hasDraftData {
    return _nameController.text.trim().isNotEmpty ||
        _selectedImage != null ||
        _ingredients.any((i) => i.nameController.text.isNotEmpty) ||
        _instructionControllers.any((c) => c.text.isNotEmpty);
  }

  bool get _hasChanges {
    if (_originalName == null) return _hasDraftData;

    if (_nameController.text.trim() != _originalName) return true;
    if (_prepTimeController.text.trim() != _originalPrepTime) return true;
    if (_cookTimeController.text.trim() != _originalCookTime) return true;
    if (_servingsController.text.trim() != _originalServings) return true;
    if (_selectedImage != null) return true; // New image selected

    bool differs(List<String> current, List<String>? original) {
      if (current.length != (original?.length ?? 0)) return true;
      for (int i = 0; i < current.length; i++) {
        if (current[i] != original![i]) return true;
      }
      return false;
    }

    final currentIngredients = _ingredients
        .map((i) => i.nameController.text.trim())
        .where((n) => n.isNotEmpty)
        .toList();
    final currentInstructions = _instructionControllers
        .map((c) => c.text.trim())
        .where((t) => t.isNotEmpty)
        .toList();
    return differs(currentIngredients, _originalIngredientNames) ||
        differs(currentInstructions, _originalInstructions);
  }

  @override
  Widget build(BuildContext context) {
    _p = RecipeEditorPalette.of(context);

    if (_isLoadingData) {
      return Scaffold(
        backgroundColor: _p.bg,
        body: const Center(child: CupertinoActivityIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: _p.bg,
      body: Stack(
        children: [
          SafeArea(
            child: Column(
              children: [
                _buildHeader(),
                Expanded(
                  child: PageView(
                    controller: _pageController,
                    physics: const NeverScrollableScrollPhysics(),
                    onPageChanged: (index) => setState(() => _currentStep = index),
                    children: [
                      _buildPhotoNameStep(),
                      _buildTimesStep(),
                      _buildIngredientsStep(),
                      _buildInstructionsStep(),
                    ],
                  ),
                ),
                // Space for the fixed bottom navigation
                const SizedBox(height: 100),
              ],
            ),
          ),
          // Fixed bottom navigation - positioned above the tab bar
          Positioned(
            left: 0,
            right: 0,
            bottom: MediaQuery.paddingOf(context).bottom + 60,
            child: _buildNavigationBar(),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    final stepTitles = [
      context.tr('recipe_step_photo'),
      context.tr('recipe_step_times'),
      context.tr('ingredients'),
      context.tr('instructions'),
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: _p.bg,
      child: Row(
        children: [
          GestureDetector(
            onTap: _showExitConfirmation,
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: _p.card,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Icon(Icons.close, color: _p.textPrimary, size: 22),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              children: [
                Text(
                  context.tr(_editingRecipeId != null ? 'edit_recipe' : 'add_recipe_title'),
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: _p.textPrimary),
                ),
                const SizedBox(height: 2),
                Text(
                  stepTitles[_currentStep],
                  style: TextStyle(fontSize: 13, color: _p.textSecondary),
                ),
              ],
            ),
          ),
          StepProgressRing(
            currentStep: _currentStep,
            totalSteps: _totalSteps,
            color: _p.accent,
            trackColor: _p.border,
            textColor: _p.textPrimary,
          ),
        ],
      ),
    );
  }

  /// Shared layout of every step: hero icon, title, subtitle and a card.
  Widget _buildStepPage({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required Widget card,
    Widget? beforeCard,
  }) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      child: Column(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.08),
              shape: BoxShape.circle,
              border: Border.all(color: color.withValues(alpha: 0.2), width: 2),
            ),
            child: Icon(icon, color: color, size: 36),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: _p.textPrimary),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, color: _p.textSecondary),
          ),
          const SizedBox(height: 24),
          if (beforeCard != null) ...[
            beforeCard,
            const SizedBox(height: 16),
          ],
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _p.card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _p.border),
            ),
            child: card,
          ),
        ],
      ),
    );
  }

  Widget _buildAddRowButton({required String label, required Color color, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: color),
        ),
      ),
    );
  }

  Widget _buildPhotoNameStep() {
    final hasImage = _selectedImage != null || _existingImageUrl != null;
    return _buildStepPage(
      icon: Icons.camera_alt_rounded,
      color: _p.accent,
      title: context.tr('recipe_add_photo_title'),
      subtitle: context.tr('recipe_add_photo_subtitle'),
      beforeCard: GestureDetector(
        onTap: _pickImage,
        child: Container(
          height: 180,
          width: double.infinity,
          decoration: BoxDecoration(
            color: _p.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _p.border),
            image: _selectedImage != null
                ? DecorationImage(image: FileImage(_selectedImage!), fit: BoxFit.cover)
                : _existingImageUrl != null
                    ? DecorationImage(
                        image: CachedNetworkImageProvider(_existingImageUrl!),
                        fit: BoxFit.cover,
                      )
                    : null,
          ),
          child: hasImage
              ? null
              : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: _p.accent.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.add_photo_alternate, size: 28, color: _p.accent),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      context.tr('tap_to_add_photo'),
                      style: TextStyle(fontSize: 15, color: _p.textSecondary),
                    ),
                  ],
                ),
        ),
      ),
      card: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.tr('recipe_name'),
            style: TextStyle(fontSize: 13, color: _p.textSecondary),
          ),
          TextField(
            controller: _nameController,
            decoration: InputDecoration(
              hintText: context.tr('recipe_name_hint'),
              border: InputBorder.none,
              isDense: true,
              contentPadding: const EdgeInsets.only(top: 8),
              hintStyle: TextStyle(color: _p.textSecondary, fontSize: 17),
            ),
            style: TextStyle(fontSize: 17, color: _p.textPrimary),
            onChanged: (_) => setState(() {}),
          ),
        ],
      ),
    );
  }

  Widget _buildTimesStep() {
    return _buildStepPage(
      icon: Icons.schedule_rounded,
      color: _p.accent,
      title: context.tr('recipe_times_title'),
      subtitle: context.tr('recipe_times_subtitle'),
      card: Column(
        children: [
          _buildTimeRow(
            icon: Icons.timer_outlined,
            color: _p.accent,
            label: context.tr('prep_time'),
            controller: _prepTimeController,
            suffix: context.tr('minutes_short'),
          ),
          Divider(height: 16, color: _p.border),
          _buildTimeRow(
            icon: Icons.local_fire_department,
            color: _p.orange,
            label: context.tr('cook_time'),
            controller: _cookTimeController,
            suffix: context.tr('minutes_short'),
          ),
          Divider(height: 16, color: _p.border),
          _buildTimeRow(
            icon: Icons.people,
            color: _p.green,
            label: context.tr('servings'),
            controller: _servingsController,
            suffix: context.tr('portions'),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeRow({
    required IconData icon,
    required Color color,
    required String label,
    required TextEditingController controller,
    required String suffix,
  }) {
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 22),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(fontSize: 13, color: _p.textSecondary)),
              Row(
                children: [
                  SizedBox(
                    width: 50,
                    child: TextField(
                      controller: controller,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        hintText: '0',
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                        hintStyle: TextStyle(color: _p.textSecondary, fontSize: 20, fontWeight: FontWeight.w600),
                      ),
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: _p.textPrimary),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  Text(suffix, style: TextStyle(fontSize: 15, color: _p.textSecondary)),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildIngredientsStep() {
    InputDecoration fieldDecoration(String hint) => InputDecoration(
          hintText: hint,
          border: InputBorder.none,
          isDense: true,
          hintStyle: TextStyle(color: _p.textSecondary),
        );
    final fieldStyle = TextStyle(fontSize: 16, color: _p.textPrimary);

    return _buildStepPage(
      icon: Icons.restaurant_rounded,
      color: _p.green,
      title: context.tr('ingredients'),
      subtitle: context.tr('recipe_ingredients_subtitle'),
      card: Column(
        children: [
          for (int index = 0; index < _ingredients.length; index++) ...[
            if (index > 0) const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: TextField(
                    controller: _ingredients[index].nameController,
                    decoration: fieldDecoration(context.tr('ingredient')),
                    style: fieldStyle,
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                SizedBox(
                  width: 50,
                  child: TextField(
                    controller: _ingredients[index].amountController,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    decoration: fieldDecoration('0'),
                    style: fieldStyle,
                  ),
                ),
                SizedBox(
                  width: 70,
                  child: TextField(
                    controller: _ingredients[index].unitController,
                    decoration: fieldDecoration(context.tr('unit')),
                    style: fieldStyle,
                  ),
                ),
                if (_ingredients.length > 1)
                  GestureDetector(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      final removed = _ingredients.removeAt(index);
                      setState(() {});
                      // Dispose after the row's TextFields left the tree.
                      WidgetsBinding.instance.addPostFrameCallback((_) => removed.dispose());
                    },
                    child: Icon(Icons.close, color: _p.textSecondary, size: 20),
                  ),
              ],
            ),
            if (index < _ingredients.length - 1) Divider(height: 12, color: _p.border),
          ],
          const SizedBox(height: 16),
          _buildAddRowButton(
            label: context.tr('add_ingredient'),
            color: _p.green,
            onTap: () => setState(() => _ingredients.add(_IngredientInput())),
          ),
        ],
      ),
    );
  }

  Widget _buildInstructionsStep() {
    return _buildStepPage(
      icon: Icons.format_list_numbered_rounded,
      color: _p.accent,
      title: context.tr('instructions'),
      subtitle: context.tr('recipe_instructions_subtitle'),
      card: Column(
        children: [
          for (int index = 0; index < _instructionControllers.length; index++) ...[
            if (index > 0) const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(color: _p.accent, shape: BoxShape.circle),
                  child: Center(
                    child: Text(
                      '${index + 1}',
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _instructionControllers[index],
                    maxLines: 2,
                    decoration: InputDecoration(
                      hintText: context.tr('instruction_step'),
                      border: InputBorder.none,
                      isDense: true,
                      hintStyle: TextStyle(color: _p.textSecondary),
                    ),
                    style: TextStyle(fontSize: 16, color: _p.textPrimary, height: 1.4),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                if (_instructionControllers.length > 1)
                  GestureDetector(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      final removed = _instructionControllers.removeAt(index);
                      setState(() {});
                      WidgetsBinding.instance.addPostFrameCallback((_) => removed.dispose());
                    },
                    child: Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Icon(Icons.close, color: _p.textSecondary, size: 20),
                    ),
                  ),
              ],
            ),
            if (index < _instructionControllers.length - 1) Divider(height: 16, color: _p.border),
          ],
          const SizedBox(height: 16),
          _buildAddRowButton(
            label: context.tr('add_step'),
            color: _p.accent,
            onTap: () => setState(() => _instructionControllers.add(TextEditingController())),
          ),
        ],
      ),
    );
  }

  Widget _buildNavigationBar() {
    final isFirstStep = _currentStep == 0;
    final isLastStep = _currentStep == _totalSteps - 1;
    final backColor = isFirstStep ? _p.textSecondary.withValues(alpha: 0.4) : _p.textSecondary;

    // iOS 26 has very tall bottom safe area - put buttons ABOVE the navbar
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
      decoration: BoxDecoration(
        color: _p.card,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: SizedBox(
              height: 52,
              child: OutlinedButton.icon(
                onPressed: isFirstStep ? null : _previousStep,
                icon: Icon(Icons.arrow_back, size: 18, color: backColor),
                label: Text(
                  context.tr('back'),
                  style: TextStyle(fontWeight: FontWeight.w500, color: backColor),
                ),
                style: OutlinedButton.styleFrom(
                  backgroundColor: _p.card,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  side: BorderSide(color: isFirstStep ? _p.border.withValues(alpha: 0.5) : _p.border),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: SizedBox(
              height: 52,
              child: ElevatedButton.icon(
                onPressed: isLastStep
                    ? (_isLoading ? null : _publishRecipe)
                    : (_canProceed ? _nextStep : null),
                icon: _isLoading
                    ? const CupertinoActivityIndicator(radius: 10, color: Colors.white)
                    : Icon(isLastStep ? Icons.publish : Icons.arrow_forward, size: 18),
                label: Text(
                  context.tr(isLastStep ? 'publish' : 'continue_text'),
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isLastStep ? _p.green : _p.accent,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: _p.border,
                  disabledForegroundColor: _p.textSecondary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showExitConfirmation() {
    // Nothing to keep: editing without changes, or a new recipe without data.
    if ((_editingRecipeId != null && !_hasChanges) ||
        (_editingRecipeId == null && !_hasDraftData)) {
      context.pop();
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _p.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(context.tr('save_draft_question'), textAlign: TextAlign.center, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: _p.textPrimary)),
        content: Text(context.tr('save_draft_question_desc'), textAlign: TextAlign.center, style: TextStyle(fontSize: 15, color: _p.textSecondary)),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.pop();
            },
            child: Text(context.tr('discard'), style: const TextStyle(color: Colors.red)),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await _saveDraft();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _p.accent,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text(context.tr('save_draft'), style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );
      if (image != null && mounted) {
        setState(() => _selectedImage = File(image.path));
      }
    } catch (e) {
      debugPrint('❌ [RECIPE_EDITOR] Image picker failed: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('error_generic', params: {'error': '$e'}))),
      );
    }
  }

  Future<void> _saveDraft() async {
    setState(() => _isLoading = true);

    try {
      final now = DateTime.now();
      final draftId = _currentDraftId ?? 'draft_${now.millisecondsSinceEpoch}';

      // Keep a durable copy of the photo; the picker's file lives in tmp.
      final imagePath = _selectedImage == null
          ? null
          : await RecipeDraftImages.persist(draftId, _selectedImage!);

      final draft = RecipeDraft(
        id: draftId,
        name: _nameController.text.trim(),
        description: '',
        localImagePath: imagePath,
        prepTimeMinutes: int.tryParse(_prepTimeController.text.trim()),
        cookTimeMinutes: int.tryParse(_cookTimeController.text.trim()),
        defaultServings: int.tryParse(_servingsController.text.trim()),
        ingredients: _ingredients
            .map((i) => DraftIngredient(
                  name: i.nameController.text.trim(),
                  amount: i.amountController.text.trim(),
                  unit: i.unitController.text.trim(),
                ))
            .toList(),
        instructions: _instructionControllers.map((c) => c.text.trim()).toList(),
        createdAt: now,
        updatedAt: now,
      );

      await _draftService.saveDraft(draft);

      if (mounted) context.go('/recipes/drafts');
    } catch (e) {
      debugPrint('❌ [RECIPE_EDITOR] Failed to save draft: $e');
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.tr('error_generic', params: {'error': '$e'})),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _publishRecipe() async {
    setState(() => _isLoading = true);

    try {
      final prepTime = int.tryParse(_prepTimeController.text.trim());
      final cookTime = int.tryParse(_cookTimeController.text.trim());
      final servings = int.tryParse(_servingsController.text.trim());

      if (prepTime == null || cookTime == null || servings == null) {
        throw _EditorException(context.tr('invalid_numbers_error'));
      }

      final ingredients = <Ingredient>[];
      for (final ing in _ingredients) {
        final name = ing.nameController.text.trim();
        if (name.isEmpty) continue;
        final amount = _parseAmount(ing.amountController.text);
        if (amount == null) {
          throw _EditorException('${context.tr('invalid_amount_error')}: $name');
        }
        ingredients.add(Ingredient(name: name, amount: amount, unit: ing.unitController.text.trim()));
      }

      final instructions = _instructionControllers
          .map((c) => c.text.trim())
          .where((text) => text.isNotEmpty)
          .toList();
      if (instructions.isEmpty) {
        throw _EditorException(context.tr('no_instructions_error'));
      }

      final String imageUrl;
      if (_selectedImage != null) {
        imageUrl = await _recipeService.uploadRecipeImage(
          _selectedImage!.path,
          'recipe_${DateTime.now().millisecondsSinceEpoch}.jpg',
        );
      } else if (_existingImageUrl != null) {
        imageUrl = _existingImageUrl!;
      } else {
        throw _EditorException(context.tr('image_required_error'));
      }

      final name = _nameController.text.trim();
      final String resultRecipeId;
      var resultRecipeName = name;

      if (_editingRecipeId != null) {
        await _recipeService.updateRecipe(
          _editingRecipeId!,
          name: name,
          // The editor has no description field: null keeps the stored
          // description ('' used to erase it on every edit).
          description: null,
          imageUrl: imageUrl,
          prepTimeMinutes: prepTime,
          cookTimeMinutes: cookTime,
          defaultServings: servings,
          ingredients: ingredients,
          instructions: instructions,
        );
        resultRecipeId = _editingRecipeId!;
      } else {
        final createdRecipe = await _recipeService.createRecipe(Recipe(
          id: '',
          name: name,
          description: '',
          imageUrl: imageUrl,
          prepTimeMinutes: prepTime,
          cookTimeMinutes: cookTime,
          defaultServings: servings,
          ingredients: ingredients,
          instructions: instructions,
          authorId: '',
          authorName: '',
          createdAt: DateTime.now(),
        ));
        resultRecipeId = createdRecipe.id;
        resultRecipeName = createdRecipe.name;
      }

      if (_currentDraftId != null) {
        await _draftService.deleteDraft(_currentDraftId!);
        await RecipeDraftImages.delete(_currentDraftImagePath);
      }

      if (!mounted) return;
      // New/changed recipe must show up in every recipe list.
      refreshRecipeData(ref);
      HapticFeedback.heavyImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${context.tr('recipe_published')}: "$resultRecipeName"'),
          backgroundColor: _p.green,
        ),
      );

      if (_editingRecipeId != null) {
        // Back to the (still open) detail page, which reloads on `true`.
        context.pop(true);
      } else {
        context.pushReplacement('/recipes/$resultRecipeId');
      }
    } catch (e) {
      debugPrint('❌ [RECIPE_EDITOR] Failed to publish recipe: $e');
      if (!mounted) return;
      setState(() => _isLoading = false);
      final message = e is _EditorException
          ? e.message
          : context.tr('error_generic', params: {'error': '$e'});
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  /// Parses "1", "1,5", "0.5" or "1/2".
  double? _parseAmount(String input) {
    final cleaned = input.trim().replaceAll(',', '.');
    final simple = double.tryParse(cleaned);
    if (simple != null) return simple;

    final parts = cleaned.split('/');
    if (parts.length == 2) {
      final numerator = double.tryParse(parts[0].trim());
      final denominator = double.tryParse(parts[1].trim());
      if (numerator != null && denominator != null && denominator != 0) {
        return numerator / denominator;
      }
    }
    return null;
  }
}

/// A validation message that is already localized for the user.
class _EditorException implements Exception {
  final String message;
  const _EditorException(this.message);
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
