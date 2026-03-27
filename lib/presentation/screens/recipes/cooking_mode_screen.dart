import 'dart:async';
import 'dart:io' show Platform;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/cupertino.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:shoply/data/models/recipe.dart';
import 'package:shoply/core/localization/app_translations.dart';
import 'package:shoply/core/constants/app_colors.dart';

/// Full-screen cooking mode that guides users step-by-step through a recipe
class CookingModeScreen extends StatefulWidget {
  final Recipe recipe;
  final int servings;

  const CookingModeScreen({
    super.key,
    required this.recipe,
    required this.servings,
  });

  @override
  State<CookingModeScreen> createState() => _CookingModeScreenState();
}

class _CookingModeScreenState extends State<CookingModeScreen> with TickerProviderStateMixin {
  int _currentStep = 0;
  final Set<int> _checkedIngredients = {};
  late int _currentServings;
  
  Timer? _timer;
  int _timerSeconds = 0;
  bool _timerRunning = false;
  int? _activeTimerStep;

  late PageController _pageController;
  String _languageCode = 'de';
  bool _isDark = false;

  int get _totalSteps => widget.recipe.instructions.length + 1;

  List<Ingredient> get _adjustedIngredients {
    return widget.recipe.ingredients
        .map((ing) => ing.adjustForServings(widget.recipe.defaultServings, _currentServings))
        .toList();
  }
  
  bool get _allIngredientsChecked => 
      _checkedIngredients.length == _adjustedIngredients.length;
      
  String _tr(String key) => AppTranslations.get(key, _languageCode);
  String _trParams(String key, Map<String, String> params) => AppTranslations.get(key, _languageCode, params: params);

  // Colors based on theme — "Cookbook Evening" warm palette
  Color get _bgColor => _isDark ? AppColors.recipeDarkBg : AppColors.recipeLightBg;
  Color get _cardColor => _isDark ? AppColors.recipeDarkSurface : AppColors.recipeLightSurface;
  Color get _textPrimary => _isDark ? AppColors.recipeDarkTextPrimary : AppColors.lightTextPrimary;
  Color get _textSecondary => _isDark ? AppColors.recipeDarkTextSecondary : AppColors.lightTextSecondary;
  Color get _borderColor => _isDark ? AppColors.recipeDarkBorder : AppColors.recipeLightBorder;
  Color get _accentColor => _isDark ? AppColors.recipeAccentDark : AppColors.recipeAccent;
  Color get _greenColor => _isDark ? AppColors.recipeGreenDark : AppColors.recipeGreen;
  
  List<BoxShadow> get _cardShadow => _isDark ? [] : [
    BoxShadow(
      color: Colors.black.withOpacity(0.05),
      blurRadius: 10,
      offset: const Offset(0, 2),
    ),
  ];

  @override
  void initState() {
    super.initState();
    _currentServings = widget.servings;
    _pageController = PageController();
    WakelockPlus.enable();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageController.dispose();
    WakelockPlus.disable();
    super.dispose();
  }

  void _closeCookingMode() {
    Navigator.of(context).pop();
  }

  void _goToStep(int step) {
    if (step >= 0 && step < _totalSteps) {
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

  void _toggleIngredient(int index) {
    HapticFeedback.selectionClick();
    setState(() {
      if (_checkedIngredients.contains(index)) {
        _checkedIngredients.remove(index);
      } else {
        _checkedIngredients.add(index);
      }
    });
  }
  
  void _toggleSelectAll() {
    HapticFeedback.mediumImpact();
    setState(() {
      if (_allIngredientsChecked) {
        _checkedIngredients.clear();
      } else {
        _checkedIngredients.clear();
        for (int i = 0; i < _adjustedIngredients.length; i++) {
          _checkedIngredients.add(i);
        }
      }
    });
  }

  void _showServingsSelector() {
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: _cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _ServingsSelectorSheet(
        currentServings: _currentServings,
        isDark: _isDark,
        textPrimary: _textPrimary,
        textSecondary: _textSecondary,
        borderColor: _borderColor,
        cardColor: _cardColor,
        languageCode: _languageCode,
        onServingsChanged: (newServings) {
          setState(() {
            _currentServings = newServings;
            _checkedIngredients.clear();
          });
          Navigator.pop(context);
        },
      ),
    );
  }

  void _startTimer(int minutes) {
    HapticFeedback.mediumImpact();
    setState(() {
      _timerSeconds = minutes * 60;
      _timerRunning = true;
      _activeTimerStep = _currentStep;
    });
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_timerSeconds > 0) {
        setState(() => _timerSeconds--);
      } else {
        _timer?.cancel();
        setState(() => _timerRunning = false);
        HapticFeedback.heavyImpact();
        _showTimerCompleteDialog();
      }
    });
  }

  void _pauseTimer() {
    HapticFeedback.lightImpact();
    _timer?.cancel();
    setState(() => _timerRunning = false);
  }

  void _resumeTimer() {
    HapticFeedback.lightImpact();
    setState(() => _timerRunning = true);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_timerSeconds > 0) {
        setState(() => _timerSeconds--);
      } else {
        _timer?.cancel();
        setState(() => _timerRunning = false);
        HapticFeedback.heavyImpact();
        _showTimerCompleteDialog();
      }
    });
  }

  void _cancelTimer() {
    HapticFeedback.lightImpact();
    _timer?.cancel();
    setState(() {
      _timerSeconds = 0;
      _timerRunning = false;
      _activeTimerStep = null;
    });
  }

  void _showTimerCompleteDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: _cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _greenColor.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.timer_off, color: _greenColor, size: 24),
            ),
            const SizedBox(width: 12),
            Text(
              _tr('cooking_mode_timer_done'),
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: _textPrimary),
            ),
          ],
        ),
        content: Text(
          _tr('cooking_mode_time_up'),
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 15, color: _textSecondary),
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              setState(() => _activeTimerStep = null);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _accentColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text(_tr('ok'), style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  String _formatTime(int seconds) {
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  void _showExitConfirmation() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          _tr('cooking_mode_exit_title'),
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: _textPrimary),
        ),
        content: Text(
          _tr('cooking_mode_exit_message'),
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 15, color: _textSecondary),
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(_tr('cancel'), style: TextStyle(color: _textSecondary)),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _closeCookingMode();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text(_tr('cooking_mode_exit_button'), style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    _isDark = Theme.of(context).brightness == Brightness.dark;
    _languageCode = Localizations.localeOf(context).languageCode;
    
    // Get bottom padding - handle different iOS versions
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    double extraPadding = 0.0;
    
    if (Platform.isIOS) {
      if (bottomPadding > 50) {
        // iOS 26 liquid glass navbar - needs extra 160px
        extraPadding = 160.0;
      } else if (bottomPadding > 0 && bottomPadding <= 50) {
        // iOS 18 and earlier with home indicator (around 34px)
        // Buttons are too high, add 20px extra padding
        extraPadding = 20.0;
      }
    }
    
    final totalBottomPadding = bottomPadding + extraPadding;
    
    return Scaffold(
      backgroundColor: _bgColor,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _buildHeader(),
            
            if (_timerSeconds > 0 || _timerRunning)
              _buildTimerBar(),
            
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (index) => setState(() => _currentStep = index),
                itemCount: _totalSteps,
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return _buildIngredientsStep();
                  } else {
                    return _buildCookingStep(index - 1);
                  }
                },
              ),
            ),
            
            _buildNavigationBar(totalBottomPadding),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: _bgColor,
        border: Border(bottom: BorderSide(color: _borderColor, width: 0.5)),
      ),
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
                border: Border.all(color: _borderColor),
                boxShadow: _cardShadow,
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
                  widget.recipe.name,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: _textPrimary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  _currentStep == 0
                      ? _tr('cooking_mode_ingredients')
                      : _trParams('cooking_mode_step_of', {
                          'current': '$_currentStep',
                          'total': '${widget.recipe.instructions.length}'
                        }),
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
                CupertinoActivityIndicator(color: _accentColor),
                Text(
                  '${_currentStep + 1}/$_totalSteps',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: _textPrimary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimerBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            _accentColor.withOpacity(0.1),
            _accentColor.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _accentColor.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _accentColor.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(
              _timerRunning ? Icons.timer : Icons.pause_circle_outline,
              color: _accentColor,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Text(
            _formatTime(_timerSeconds),
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: _accentColor,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          const Spacer(),
          GestureDetector(
            onTap: _timerRunning ? _pauseTimer : _resumeTimer,
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: _accentColor.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(
                _timerRunning ? Icons.pause : Icons.play_arrow,
                color: _accentColor,
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _cancelTimer,
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.close, color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIngredientsStep() {
    final ingredients = _adjustedIngredients;
    final servingsText = _currentServings == 1 
        ? '1 ${_tr('cooking_mode_portion')}'
        : '$_currentServings ${_tr('cooking_mode_portions')}';

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Hero icon
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    _greenColor.withOpacity(0.2),
                    _greenColor.withOpacity(0.1),
                  ],
                ),
                shape: BoxShape.circle,
                border: Border.all(color: _greenColor.withOpacity(0.3), width: 2),
              ),
              child: Icon(Icons.restaurant_menu, color: _greenColor, size: 36),
            ),
            const SizedBox(height: 20),
            
            // Title
            Text(
              _tr('cooking_mode_gather_ingredients'),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: _textPrimary,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 8),
            
            // Subtitle
            Text(
              _tr('cooking_mode_gather_subtitle'),
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 15, color: _textSecondary),
            ),
            const SizedBox(height: 12),
            
            // Servings badge - TAPPABLE
            GestureDetector(
              onTap: _showServingsSelector,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: _accentColor.withOpacity(_isDark ? 0.2 : 0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: _accentColor.withOpacity(0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.people, size: 18, color: _accentColor),
                    const SizedBox(width: 8),
                    Text(
                      servingsText,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: _accentColor,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Icon(Icons.edit, size: 14, color: _accentColor),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            
            // Ingredients card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _cardColor,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _borderColor),
                boxShadow: _cardShadow,
              ),
              child: Column(
                children: [
                  // Select all button
                  GestureDetector(
                    onTap: _toggleSelectAll,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: _isDark ? AppColors.recipeDarkInput : AppColors.lightInputFill,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: _borderColor),
                      ),
                      child: Text(
                        _allIngredientsChecked ? _tr('deselect_all') : _tr('select_all'),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: _textSecondary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Ingredients list
                  ...ingredients.asMap().entries.map((entry) {
                    final index = entry.key;
                    final ingredient = entry.value;
                    final isChecked = _checkedIngredients.contains(index);

                    return GestureDetector(
                      onTap: () => _toggleIngredient(index),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: isChecked 
                              ? _greenColor.withOpacity(_isDark ? 0.15 : 0.08)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isChecked 
                                ? _greenColor.withOpacity(0.4)
                                : _borderColor,
                          ),
                        ),
                        child: Row(
                          children: [
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              width: 22,
                              height: 22,
                              decoration: BoxDecoration(
                                color: isChecked ? _greenColor : Colors.transparent,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: isChecked ? _greenColor : _textSecondary.withOpacity(0.4),
                                  width: 2,
                                ),
                              ),
                              child: isChecked
                                  ? const Icon(Icons.check, color: Colors.white, size: 14)
                                  : null,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                ingredient.displayText,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: isChecked ? _textSecondary : _textPrimary,
                                  decoration: isChecked ? TextDecoration.lineThrough : null,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),
            

          ],
        ),
      ),
    );
  }

  Widget _buildCookingStep(int stepIndex) {
    final instruction = widget.recipe.instructions[stepIndex];
    final hasActiveTimer = _activeTimerStep == _currentStep;
    final timerMinutes = _extractTimerMinutes(instruction);

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Step number with gradient circle
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    _accentColor,
                    _accentColor.withOpacity(0.7),
                  ],
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: _accentColor.withOpacity(0.3),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  '${stepIndex + 1}',
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 32),
            
            // Instruction card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: _cardColor,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _borderColor),
                boxShadow: _cardShadow,
              ),
              child: Text(
                instruction,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                  color: _textPrimary,
                  height: 1.6,
                ),
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Timer button
            if (timerMinutes != null && !hasActiveTimer)
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _startTimer(timerMinutes),
                  icon: Icon(Icons.timer, color: _accentColor),
                  label: Text(
                    _trParams('cooking_mode_start_timer', {'minutes': '$timerMinutes'}),
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: _accentColor,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    side: BorderSide(color: _accentColor, width: 2),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavigationBar(double totalBottomPadding) {
    final isFirstStep = _currentStep == 0;
    final isLastStep = _currentStep == _totalSteps - 1;

    return Container(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: totalBottomPadding + 16,
      ),
      decoration: BoxDecoration(
        color: _cardColor,
        border: Border(top: BorderSide(color: _borderColor)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Previous button
          Expanded(
            child: SizedBox(
              height: 52,
              child: OutlinedButton.icon(
                onPressed: isFirstStep ? null : _previousStep,
                icon: Icon(
                  Icons.arrow_back,
                  size: 18,
                  color: isFirstStep ? _textSecondary.withOpacity(0.4) : _textSecondary,
                ),
                label: Text(
                  _tr('back'),
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    color: isFirstStep ? _textSecondary.withOpacity(0.4) : _textSecondary,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  side: BorderSide(
                    color: isFirstStep ? _borderColor.withOpacity(0.5) : _borderColor,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Next button
          Expanded(
            child: SizedBox(
              height: 52,
              child: ElevatedButton.icon(
                onPressed: isLastStep ? _closeCookingMode : _nextStep,
                icon: Icon(
                  isLastStep ? Icons.check : Icons.arrow_forward,
                  size: 18,
                ),
                label: Text(
                  isLastStep ? _tr('done') : _tr('continue_text'),
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isLastStep ? _greenColor : _accentColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  int? _extractTimerMinutes(String text) {
    final patterns = [
      RegExp(r'(\d+)\s*(?:Minuten|minuten|Min\.|min\.?|minutes?)', caseSensitive: false),
      RegExp(r'(\d+)-(\d+)\s*(?:Minuten|minuten|Min\.|min\.?|minutes?)', caseSensitive: false),
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(text);
      if (match != null) {
        return int.tryParse(match.group(1)!);
      }
    }
    return null;
  }
}

/// Bottom sheet for selecting servings
class _ServingsSelectorSheet extends StatelessWidget {
  final int currentServings;
  final bool isDark;
  final Color textPrimary;
  final Color textSecondary;
  final Color borderColor;
  final Color cardColor;
  final String languageCode;
  final Function(int) onServingsChanged;

  const _ServingsSelectorSheet({
    required this.currentServings,
    required this.isDark,
    required this.textPrimary,
    required this.textSecondary,
    required this.borderColor,
    required this.cardColor,
    required this.languageCode,
    required this.onServingsChanged,
  });

  String _tr(String key) => AppTranslations.get(key, languageCode);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: borderColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),
          
          // Title
          Text(
            _tr('servings'),
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: textPrimary,
            ),
          ),
          const SizedBox(height: 24),
          
          // Servings grid
          Wrap(
            spacing: 12,
            runSpacing: 12,
            alignment: WrapAlignment.center,
            children: [1, 2, 3, 4, 5, 6, 8, 10, 12].map((servings) {
              final isSelected = servings == currentServings;
              final accentColor = AppColors.recipeAccentColor(context);
              return GestureDetector(
                onTap: () => onServingsChanged(servings),
                child: Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: isSelected 
                        ? accentColor 
                        : (isDark ? AppColors.recipeDarkInput : AppColors.lightInputFill),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isSelected ? accentColor : borderColor,
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      '$servings',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: isSelected ? Colors.white : textPrimary,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          
          SizedBox(height: MediaQuery.of(context).padding.bottom + 16),
        ],
      ),
    );
  }
}
