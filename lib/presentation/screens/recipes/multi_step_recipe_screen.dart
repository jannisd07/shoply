import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/cupertino.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shoply/core/localization/app_translations.dart';
import 'package:shoply/data/models/recipe.dart';
import 'package:shoply/data/models/recipe_draft.dart';
import 'package:shoply/data/services/recipe_service.dart';
import 'package:shoply/data/services/recipe_draft_service.dart';
import 'package:shoply/core/constants/app_colors.dart';

/// Multi-step recipe creation screen - 4 steps matching the design
class MultiStepRecipeScreen extends StatefulWidget {
  final String? draftId;
  final String? recipeId;
  
  const MultiStepRecipeScreen({super.key, this.draftId, this.recipeId});

  @override
  State<MultiStepRecipeScreen> createState() => _MultiStepRecipeScreenState();
}

class _MultiStepRecipeScreenState extends State<MultiStepRecipeScreen> {
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

  String _languageCode = 'de';
  bool _isDark = false;
  
  // Colors based on theme — "Cookbook Evening" warm palette
  Color get _bgColor => _isDark ? AppColors.recipeDarkBg : AppColors.recipeLightBg;
  Color get _cardColor => _isDark ? AppColors.recipeDarkSurface : AppColors.recipeLightSurface;
  Color get _textPrimary => _isDark ? AppColors.recipeDarkTextPrimary : AppColors.lightTextPrimary;
  Color get _textSecondary => _isDark ? AppColors.recipeDarkTextSecondary : AppColors.lightTextSecondary;
  Color get _borderColor => _isDark ? AppColors.recipeDarkBorder : AppColors.recipeLightBorder;
  Color get _accentBlue => _isDark ? AppColors.recipeAccentDark : AppColors.recipeAccent;
  Color get _accentGreen => _isDark ? AppColors.recipeGreenDark : AppColors.recipeGreen;
  Color get _accentOrange => _isDark ? AppColors.recipeStepDark : AppColors.recipeStep;
  
  String _tr(String key) => AppTranslations.get(key, _languageCode);

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

  Future<void> _loadExistingRecipe(String recipeId) async {
    setState(() => _isLoadingData = true);
    
    try {
      final recipe = await _recipeService.getRecipeById(recipeId);
      if (mounted) {
        _editingRecipeId = recipe.id;
        _nameController.text = recipe.name;
        _existingImageUrl = recipe.imageUrl;
        _prepTimeController.text = recipe.prepTimeMinutes.toString();
        _cookTimeController.text = recipe.cookTimeMinutes.toString();
        _servingsController.text = recipe.defaultServings.toString();
        
        // Store original values
        _originalName = recipe.name;
        _originalPrepTime = recipe.prepTimeMinutes.toString();
        _originalCookTime = recipe.cookTimeMinutes.toString();
        _originalServings = recipe.defaultServings.toString();
        _originalIngredientNames = recipe.ingredients.map((i) => i.name).toList();
        _originalInstructions = recipe.instructions.toList();
        
        for (var ing in _ingredients) {
          ing.dispose();
        }
        _ingredients.clear();
        for (final ing in recipe.ingredients) {
          final input = _IngredientInput();
          input.nameController.text = ing.name;
          input.amountController.text = ing.amount.toString();
          input.unitController.text = ing.unit;
          _ingredients.add(input);
        }
        if (_ingredients.isEmpty) _ingredients.add(_IngredientInput());

        for (var controller in _instructionControllers) {
          controller.dispose();
        }
        _instructionControllers.clear();
        for (final instruction in recipe.instructions) {
          _instructionControllers.add(TextEditingController(text: instruction));
        }
        if (_instructionControllers.isEmpty) _instructionControllers.add(TextEditingController());
        
        setState(() => _isLoadingData = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingData = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${_tr('error')}: $e')),
        );
      }
    }
  }

  Future<void> _loadDraft(String draftId) async {
    setState(() => _isLoadingData = true);

    try {
      final draft = await _draftService.getDraft(draftId);
      if (draft != null && mounted) {
        _currentDraftId = draft.id;
        _nameController.text = draft.name;

        if (draft.prepTimeMinutes != null) _prepTimeController.text = draft.prepTimeMinutes.toString();
        if (draft.cookTimeMinutes != null) _cookTimeController.text = draft.cookTimeMinutes.toString();
        if (draft.defaultServings != null) _servingsController.text = draft.defaultServings.toString();

        if (draft.localImagePath != null && File(draft.localImagePath!).existsSync()) {
          _selectedImage = File(draft.localImagePath!);
        }

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

        for (var controller in _instructionControllers) {
          controller.dispose();
        }
        _instructionControllers.clear();
        if (draft.instructions.isEmpty) {
          _instructionControllers.add(TextEditingController());
        } else {
          for (final instruction in draft.instructions) {
            _instructionControllers.add(TextEditingController(text: instruction));
          }
        }
      }

      if (mounted) setState(() => _isLoadingData = false);
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingData = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${_tr('error')}: $e')),
        );
      }
    }
  }

  void _dismissKeyboard() {
    FocusScope.of(context).unfocus();
  }

  void _goToStep(int step) {
    if (step >= 0 && step < _totalSteps) {
      _dismissKeyboard();
      setState(() => _currentStep = step);
      _pageController.animateToPage(
        step,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _nextStep() {
    if (_currentStep < _totalSteps - 1) {
      _goToStep(_currentStep + 1);
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      _goToStep(_currentStep - 1);
    }
  }

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
    
    // Check if any field changed from original
    if (_nameController.text.trim() != _originalName) return true;
    if (_prepTimeController.text.trim() != _originalPrepTime) return true;
    if (_cookTimeController.text.trim() != _originalCookTime) return true;
    if (_servingsController.text.trim() != _originalServings) return true;
    if (_selectedImage != null) return true; // New image selected
    
    // Check ingredients
    final currentIngredients = _ingredients.map((i) => i.nameController.text.trim()).where((n) => n.isNotEmpty).toList();
    if (currentIngredients.length != (_originalIngredientNames?.length ?? 0)) return true;
    for (int i = 0; i < currentIngredients.length; i++) {
      if (i >= (_originalIngredientNames?.length ?? 0) || currentIngredients[i] != _originalIngredientNames![i]) return true;
    }
    
    // Check instructions
    final currentInstructions = _instructionControllers.map((c) => c.text.trim()).where((t) => t.isNotEmpty).toList();
    if (currentInstructions.length != (_originalInstructions?.length ?? 0)) return true;
    for (int i = 0; i < currentInstructions.length; i++) {
      if (i >= (_originalInstructions?.length ?? 0) || currentInstructions[i] != _originalInstructions![i]) return true;
    }
    
    return false;
  }

  @override
  Widget build(BuildContext context) {
    _languageCode = Localizations.localeOf(context).languageCode;
    _isDark = Theme.of(context).brightness == Brightness.dark;
    
    if (_isLoadingData) {
      return Scaffold(
        backgroundColor: _bgColor,
        body: const Center(child: CupertinoActivityIndicator()),
      );
    }
    
    return Scaffold(
      backgroundColor: _bgColor,
      body: Stack(
        children: [
          // Main content with SafeArea
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
            bottom: MediaQuery.of(context).padding.bottom + 60, // Above tab bar
            child: _buildNavigationBar(),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    final stepTitles = [
      'Foto & Name',
      'Zeiten & Portionen',
      _tr('ingredients'),
      _tr('instructions'),
    ];
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: _bgColor,
      child: Row(
        children: [
          // Close button
          GestureDetector(
            onTap: _showExitConfirmation,
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: _cardColor,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Icon(Icons.close, color: _textPrimary, size: 22),
            ),
          ),
          const SizedBox(width: 16),
          
          // Title and step
          Expanded(
            child: Column(
              children: [
                Text(
                  _editingRecipeId != null ? _tr('edit_recipe') : 'Neues Rezept',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: _textPrimary),
                ),
                const SizedBox(height: 2),
                Text(
                  stepTitles[_currentStep],
                  style: TextStyle(fontSize: 13, color: _textSecondary),
                ),
              ],
            ),
          ),
          
          // Progress ring
          SizedBox(
            width: 44,
            height: 44,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CupertinoActivityIndicator(color: _accentBlue),
                Text(
                  '${_currentStep + 1}/$_totalSteps',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: _textPrimary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhotoNameStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      child: Column(
        children: [
          // Hero icon - blue camera
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: _accentBlue.withValues(alpha: 0.08),
              shape: BoxShape.circle,
              border: Border.all(color: _accentBlue.withValues(alpha: 0.2), width: 2),
            ),
            child: Icon(Icons.camera_alt_rounded, color: _accentBlue, size: 36),
          ),
          const SizedBox(height: 16),
          
          // Title
          Text(
            'Foto hinzufügen',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: _textPrimary),
          ),
          const SizedBox(height: 6),
          Text(
            'Ein tolles Foto macht dein Rezept besonders',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, color: _textSecondary),
          ),
          const SizedBox(height: 24),
          
          // Image picker card
          GestureDetector(
            onTap: _pickImage,
            child: Container(
              height: 180,
              width: double.infinity,
              decoration: BoxDecoration(
                color: _cardColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _borderColor),
                image: _selectedImage != null
                    ? DecorationImage(image: FileImage(_selectedImage!), fit: BoxFit.cover)
                    : _existingImageUrl != null
                        ? DecorationImage(image: NetworkImage(_existingImageUrl!), fit: BoxFit.cover)
                        : null,
              ),
              child: (_selectedImage == null && _existingImageUrl == null)
                  ? Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            color: _accentBlue.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.add_photo_alternate, size: 28, color: _accentBlue),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Tippen um Foto hinzuzufügen',
                          style: TextStyle(fontSize: 15, color: _textSecondary),
                        ),
                      ],
                    )
                  : null,
            ),
          ),
          const SizedBox(height: 16),
          
          // Name field card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _cardColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _borderColor),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Rezeptname',
                  style: TextStyle(fontSize: 13, color: _textSecondary),
                ),
                TextField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    hintText: 'z.B. Omas Apfelkuchen',
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: const EdgeInsets.only(top: 8),
                    hintStyle: TextStyle(color: _textSecondary, fontSize: 17),
                  ),
                  style: TextStyle(fontSize: 17, color: _textPrimary),
                  onChanged: (_) => setState(() {}),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimesStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      child: Column(
        children: [
          // Hero icon - blue clock
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: _accentBlue.withValues(alpha: 0.08),
              shape: BoxShape.circle,
              border: Border.all(color: _accentBlue.withValues(alpha: 0.2), width: 2),
            ),
            child: Icon(Icons.schedule_rounded, color: _accentBlue, size: 36),
          ),
          const SizedBox(height: 16),
          
          // Title
          Text(
            'Kochzeiten',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: _textPrimary),
          ),
          const SizedBox(height: 6),
          Text(
            'Wie lange dauert die Zubereitung?',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, color: _textSecondary),
          ),
          const SizedBox(height: 24),
          
          // Times card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _cardColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _borderColor),
            ),
            child: Column(
              children: [
                // Prep time
                _buildTimeRow(
                  icon: Icons.timer_outlined,
                  iconColor: _accentBlue,
                  iconBgColor: _accentBlue.withValues(alpha: 0.1),
                  label: 'Vorbereitungszeit',
                  controller: _prepTimeController,
                  suffix: 'Min',
                ),
                Divider(height: 16, color: _borderColor),
                // Cook time
                _buildTimeRow(
                  icon: Icons.local_fire_department,
                  iconColor: _accentOrange,
                  iconBgColor: _accentOrange.withValues(alpha: 0.1),
                  label: 'Kochzeit',
                  controller: _cookTimeController,
                  suffix: 'Min',
                ),
                Divider(height: 16, color: _borderColor),
                // Servings
                _buildTimeRow(
                  icon: Icons.people,
                  iconColor: _accentGreen,
                  iconBgColor: _accentGreen.withValues(alpha: 0.1),
                  label: 'Portionen',
                  controller: _servingsController,
                  suffix: 'Portionen',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeRow({
    required IconData icon,
    required Color iconColor,
    required Color iconBgColor,
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
            color: iconBgColor,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: iconColor, size: 22),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(fontSize: 13, color: _textSecondary)),
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
                        hintStyle: TextStyle(color: _textSecondary, fontSize: 20, fontWeight: FontWeight.w600),
                      ),
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: _textPrimary),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  Text(suffix, style: TextStyle(fontSize: 15, color: _textSecondary)),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildIngredientsStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      child: Column(
        children: [
          // Hero icon - green utensils
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: _accentGreen.withValues(alpha: 0.08),
              shape: BoxShape.circle,
              border: Border.all(color: _accentGreen.withValues(alpha: 0.2), width: 2),
            ),
            child: Icon(Icons.restaurant_rounded, color: _accentGreen, size: 36),
          ),
          const SizedBox(height: 16),
          
          // Title
          Text(
            _tr('ingredients'),
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: _textPrimary),
          ),
          const SizedBox(height: 6),
          Text(
            'Was brauchst du für dieses Rezept?',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, color: _textSecondary),
          ),
          const SizedBox(height: 24),
          
          // Ingredients card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _cardColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _borderColor),
            ),
            child: Column(
              children: [
                // Ingredient rows
                ..._ingredients.asMap().entries.map((entry) {
                  final index = entry.key;
                  final ingredient = entry.value;
                  return Column(
                    children: [
                      if (index > 0) const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: TextField(
                              controller: ingredient.nameController,
                              decoration: InputDecoration(
                                hintText: _tr('ingredient'),
                                border: InputBorder.none,
                                isDense: true,
                                hintStyle: TextStyle(color: _textSecondary),
                              ),
                              style: TextStyle(fontSize: 16, color: _textPrimary),
                              onChanged: (_) => setState(() {}),
                            ),
                          ),
                          SizedBox(
                            width: 50,
                            child: TextField(
                              controller: ingredient.amountController,
                              keyboardType: TextInputType.number,
                              textAlign: TextAlign.center,
                              decoration: InputDecoration(
                                hintText: '0',
                                border: InputBorder.none,
                                isDense: true,
                                hintStyle: TextStyle(color: _textSecondary),
                              ),
                              style: TextStyle(fontSize: 16, color: _textPrimary),
                              onChanged: (_) => setState(() {}),
                            ),
                          ),
                          SizedBox(
                            width: 70,
                            child: TextField(
                              controller: ingredient.unitController,
                              decoration: InputDecoration(
                                hintText: _tr('unit'),
                                border: InputBorder.none,
                                isDense: true,
                                hintStyle: TextStyle(color: _textSecondary),
                              ),
                              style: TextStyle(fontSize: 16, color: _textPrimary),
                              onChanged: (_) => setState(() {}),
                            ),
                          ),
                          if (_ingredients.length > 1)
                            GestureDetector(
                              onTap: () {
                                HapticFeedback.lightImpact();
                                setState(() {
                                  _ingredients[index].dispose();
                                  _ingredients.removeAt(index);
                                });
                              },
                              child: Icon(Icons.close, color: _textSecondary, size: 20),
                            ),
                        ],
                      ),
                      if (index < _ingredients.length - 1)
                        Divider(height: 12, color: _borderColor),
                    ],
                  );
                }),
                const SizedBox(height: 16),
                // Add button
                GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    setState(() => _ingredients.add(_IngredientInput()));
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: _accentGreen.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Zutat hinzufügen',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: _accentGreen),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInstructionsStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      child: Column(
        children: [
          // Hero icon - blue list
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: _accentBlue.withValues(alpha: 0.08),
              shape: BoxShape.circle,
              border: Border.all(color: _accentBlue.withValues(alpha: 0.2), width: 2),
            ),
            child: Icon(Icons.format_list_numbered_rounded, color: _accentBlue, size: 36),
          ),
          const SizedBox(height: 16),
          
          // Title
          Text(
            _tr('instructions'),
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: _textPrimary),
          ),
          const SizedBox(height: 6),
          Text(
            'Beschreibe die Kochschritte',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, color: _textSecondary),
          ),
          const SizedBox(height: 24),
          
          // Instructions card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _cardColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _borderColor),
            ),
            child: Column(
              children: [
                // Instruction rows
                ..._instructionControllers.asMap().entries.map((entry) {
                  final index = entry.key;
                  final controller = entry.value;
                  return Column(
                    children: [
                      if (index > 0) const SizedBox(height: 12),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: _accentBlue,
                              shape: BoxShape.circle,
                            ),
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
                              controller: controller,
                              maxLines: 2,
                              decoration: InputDecoration(
                                hintText: 'Beschreibe diesen Schritt...',
                                border: InputBorder.none,
                                isDense: true,
                                hintStyle: TextStyle(color: _textSecondary),
                              ),
                              style: TextStyle(fontSize: 16, color: _textPrimary, height: 1.4),
                              onChanged: (_) => setState(() {}),
                            ),
                          ),
                          if (_instructionControllers.length > 1)
                            GestureDetector(
                              onTap: () {
                                HapticFeedback.lightImpact();
                                setState(() {
                                  _instructionControllers[index].dispose();
                                  _instructionControllers.removeAt(index);
                                });
                              },
                              child: Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Icon(Icons.close, color: _textSecondary, size: 20),
                              ),
                            ),
                        ],
                      ),
                      if (index < _instructionControllers.length - 1)
                        Divider(height: 16, color: _borderColor),
                    ],
                  );
                }),
                const SizedBox(height: 16),
                // Add button
                GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    setState(() => _instructionControllers.add(TextEditingController()));
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: _accentBlue.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Schritt hinzufügen',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: _accentBlue),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavigationBar() {
    final isFirstStep = _currentStep == 0;
    final isLastStep = _currentStep == _totalSteps - 1;

    // iOS 26 has very tall bottom safe area - put buttons ABOVE the navbar
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
      decoration: BoxDecoration(
        color: _cardColor,
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
          // Back button
          Expanded(
            child: SizedBox(
              height: 52,
              child: OutlinedButton.icon(
                onPressed: isFirstStep ? null : _previousStep,
                icon: Icon(
                  Icons.arrow_back,
                  size: 18,
                  color: isFirstStep ? _textSecondary.withValues(alpha: 0.4) : _textSecondary,
                ),
                label: Text(
                  _tr('back'),
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    color: isFirstStep ? _textSecondary.withValues(alpha: 0.4) : _textSecondary,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  backgroundColor: _cardColor,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  side: BorderSide(color: isFirstStep ? _borderColor.withValues(alpha: 0.5) : _borderColor),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Next/Publish button
          Expanded(
            flex: 2,
            child: SizedBox(
              height: 52,
              child: ElevatedButton.icon(
                onPressed: isLastStep
                    ? (_isLoading ? null : _publishRecipe)
                    : (_canProceed ? _nextStep : null),
                icon: _isLoading
                    ? CupertinoActivityIndicator(radius: 10, color: Colors.white)
                    : Icon(isLastStep ? Icons.publish : Icons.arrow_forward, size: 18),
                label: Text(
                  isLastStep ? _tr('publish') : _tr('continue_text'),
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isLastStep ? _accentGreen : _accentBlue,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: _borderColor,
                  disabledForegroundColor: _textSecondary,
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
    // If editing and nothing changed, just close
    if (_editingRecipeId != null && !_hasChanges) {
      context.pop();
      return;
    }
    
    // If creating new and no data entered, just close
    if (_editingRecipeId == null && !_hasDraftData) {
      context.pop();
      return;
    }
    
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(_tr('save_draft_question'), textAlign: TextAlign.center, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: _textPrimary)),
        content: Text(_tr('save_draft_question_desc'), textAlign: TextAlign.center, style: TextStyle(fontSize: 15, color: _textSecondary)),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.pop();
            },
            child: Text(_tr('discard'), style: const TextStyle(color: Colors.red)),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await _saveDraft();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _accentBlue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text(_tr('save_draft'), style: const TextStyle(fontWeight: FontWeight.w600)),
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
      if (image != null) {
        setState(() => _selectedImage = File(image.path));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${_tr('error')}: $e')),
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
      
      final instructions = _instructionControllers.map((c) => c.text.trim()).toList();
      
      final now = DateTime.now();
      final draftId = _currentDraftId ?? 'draft_${now.millisecondsSinceEpoch}';
      
      final draft = RecipeDraft(
        id: draftId,
        name: _nameController.text.trim(),
        description: '',
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
      
      if (mounted) {
        context.go('/recipes/drafts');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${_tr('error')}: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _publishRecipe() async {
    setState(() => _isLoading = true);

    try {
      final prepTime = int.tryParse(_prepTimeController.text.trim());
      final cookTime = int.tryParse(_cookTimeController.text.trim());
      final servings = int.tryParse(_servingsController.text.trim());

      if (prepTime == null || cookTime == null || servings == null) {
        throw Exception(_tr('invalid_numbers_error'));
      }

      final ingredients = <Ingredient>[];
      for (var ing in _ingredients) {
        final name = ing.nameController.text.trim();
        final amountStr = ing.amountController.text.trim();
        final unit = ing.unitController.text.trim();
        
        if (name.isEmpty) continue;
        
        final amount = _parseAmount(amountStr);
        if (amount == null) {
          throw Exception('${_tr('invalid_amount_error')}: $name');
        }
        
        ingredients.add(Ingredient(name: name, amount: amount, unit: unit));
      }

      final instructions = _instructionControllers
          .map((c) => c.text.trim())
          .where((text) => text.isNotEmpty)
          .toList();
      
      if (instructions.isEmpty) {
        throw Exception(_tr('no_instructions_error'));
      }

      String imageUrl;
      if (_selectedImage != null) {
        imageUrl = await _recipeService.uploadRecipeImage(
          _selectedImage!.path,
          'recipe_${DateTime.now().millisecondsSinceEpoch}.jpg',
        );
      } else if (_existingImageUrl != null) {
        imageUrl = _existingImageUrl!;
      } else {
        throw Exception(_tr('image_required_error'));
      }

      final recipe = Recipe(
        id: _editingRecipeId ?? '',
        name: _nameController.text.trim(),
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
      );
      
      String resultRecipeId;
      String resultRecipeName = recipe.name;
      
      if (_editingRecipeId != null) {
        await _recipeService.updateRecipe(
          _editingRecipeId!,
          name: recipe.name,
          description: '',
          imageUrl: imageUrl,
          prepTimeMinutes: prepTime,
          cookTimeMinutes: cookTime,
          defaultServings: servings,
          ingredients: ingredients,
          instructions: instructions,
        );
        resultRecipeId = _editingRecipeId!;
      } else {
        final createdRecipe = await _recipeService.createRecipe(recipe);
        resultRecipeId = createdRecipe.id;
        resultRecipeName = createdRecipe.name;
      }
      
      if (_currentDraftId != null) {
        await _draftService.deleteDraft(_currentDraftId!);
      }

      if (mounted) {
        HapticFeedback.heavyImpact();
        Navigator.of(context).pop();
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${_tr('recipe_published')}: "$resultRecipeName"'),
            backgroundColor: _accentGreen,
          ),
        );
        
        Future.delayed(const Duration(milliseconds: 100), () {
          if (mounted) {
            context.push('/recipes/$resultRecipeId');
          }
        });
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${_tr('error')}: $e'),
            backgroundColor: Colors.red,
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
