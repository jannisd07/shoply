import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Tutorial step definition
enum TutorialStepType {
  tapRecipesTab,
  selectRecipe,
  navigateBackFromRecipe,
  tapShoppingListsTab,
  openShoppingList,
  checkOffItem,
}

/// A single tutorial step configuration
class TutorialStep {
  final TutorialStepType type;
  final String avoMessage;
  final String targetDescription;
  final GlobalKey? targetKey;
  final Alignment avoPosition;
  final bool requiresNavigation;

  const TutorialStep({
    required this.type,
    required this.avoMessage,
    required this.targetDescription,
    this.targetKey,
    this.avoPosition = Alignment.bottomCenter,
    this.requiresNavigation = false,
  });
}

/// Interactive tutorial controller - singleton
class InteractiveTutorialService extends ChangeNotifier {
  static InteractiveTutorialService? _instance;
  static InteractiveTutorialService get instance =>
      _instance ??= InteractiveTutorialService._();

  InteractiveTutorialService._();

  static const String _tutorialCompletedKey = 'interactive_tutorial_completed';
  static const String _tutorialSkippedKey = 'interactive_tutorial_skipped';

  bool _isActive = false;
  int _currentStepIndex = 0;
  bool _isInitialized = false;

  // Global keys for target elements
  final GlobalKey recipesTabKey = GlobalKey(debugLabel: 'recipesTab');
  final GlobalKey shoppingListsTabKey = GlobalKey(debugLabel: 'shoppingListsTab');
  final GlobalKey firstRecipeKey = GlobalKey(debugLabel: 'firstRecipe');
  final GlobalKey firstListKey = GlobalKey(debugLabel: 'firstList');
  final GlobalKey firstListItemKey = GlobalKey(debugLabel: 'firstListItem');
  final GlobalKey backButtonKey = GlobalKey(debugLabel: 'backButton');

  List<TutorialStep> get _steps => [
        TutorialStep(
          type: TutorialStepType.tapRecipesTab,
          avoMessage: 'Hey! 👋 Let me show you around!\nTap on "Recipes" to discover delicious meals!',
          targetDescription: 'Recipes Tab',
          targetKey: recipesTabKey,
          avoPosition: Alignment.topCenter,
        ),
        TutorialStep(
          type: TutorialStepType.selectRecipe,
          avoMessage: 'Great! 🍳 Now tap on any recipe to see the details!',
          targetDescription: 'Recipe Card',
          targetKey: firstRecipeKey,
          avoPosition: Alignment.bottomCenter,
          requiresNavigation: true,
        ),
        TutorialStep(
          type: TutorialStepType.navigateBackFromRecipe,
          avoMessage: 'Yummy! 😋 Now go back to explore more features.',
          targetDescription: 'Back Button',
          targetKey: backButtonKey,
          avoPosition: Alignment.bottomCenter,
          requiresNavigation: true,
        ),
        TutorialStep(
          type: TutorialStepType.tapShoppingListsTab,
          avoMessage: 'Now let\'s check your shopping lists! 🛒\nTap on "Home" to see your lists.',
          targetDescription: 'Home Tab',
          targetKey: shoppingListsTabKey,
          avoPosition: Alignment.topCenter,
        ),
        TutorialStep(
          type: TutorialStepType.openShoppingList,
          avoMessage: 'Tap on a shopping list to open it!\nYou can share lists with family & friends! 👨‍👩‍👧‍👦',
          targetDescription: 'Shopping List',
          targetKey: firstListKey,
          avoPosition: Alignment.bottomCenter,
          requiresNavigation: true,
        ),
      ];

  bool get isActive => _isActive;
  int get currentStepIndex => _currentStepIndex;
  int get totalSteps => _steps.length;
  TutorialStep? get currentStep =>
      _isActive && _currentStepIndex < _steps.length
          ? _steps[_currentStepIndex]
          : null;

  GlobalKey? get currentTargetKey => currentStep?.targetKey;

  /// Initialize and check if tutorial should be shown
  Future<void> initialize() async {
    if (_isInitialized) return;
    _isInitialized = true;

    final shouldShow = await shouldShowTutorial();
    if (shouldShow) {
      debugPrint('🎓 [TUTORIAL] Starting interactive tutorial');
      _isActive = true;
      _currentStepIndex = 0;
      notifyListeners();
    }
  }

  /// Check if tutorial should be shown
  Future<bool> shouldShowTutorial() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final completed = prefs.getBool(_tutorialCompletedKey) ?? false;
      final skipped = prefs.getBool(_tutorialSkippedKey) ?? false;
      return !completed && !skipped;
    } catch (e) {
      debugPrint('❌ [TUTORIAL] Error checking status: $e');
      return false;
    }
  }

  /// Called when user completes an interaction
  void completeCurrentStep() {
    if (!_isActive) return;

    debugPrint('✅ [TUTORIAL] Step ${_currentStepIndex + 1} completed');

    if (_currentStepIndex < _steps.length - 1) {
      _currentStepIndex++;
      notifyListeners();
    } else {
      _completeTutorial();
    }
  }

  /// Move to next step (for navigation-based transitions)
  void advanceToNextStep() {
    if (!_isActive) return;
    if (_currentStepIndex < _steps.length - 1) {
      _currentStepIndex++;
      notifyListeners();
    } else {
      _completeTutorial();
    }
  }

  /// Complete the tutorial
  Future<void> _completeTutorial() async {
    debugPrint('🎉 [TUTORIAL] Tutorial completed!');
    _isActive = false;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_tutorialCompletedKey, true);
    } catch (e) {
      debugPrint('❌ [TUTORIAL] Error saving completion: $e');
    }
  }

  /// Skip the tutorial
  Future<void> skipTutorial() async {
    debugPrint('⏭️ [TUTORIAL] Tutorial skipped');
    _isActive = false;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_tutorialSkippedKey, true);
    } catch (e) {
      debugPrint('❌ [TUTORIAL] Error saving skip: $e');
    }
  }

  /// Reset tutorial (for testing or settings)
  Future<void> resetTutorial() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_tutorialCompletedKey);
      await prefs.remove(_tutorialSkippedKey);
      _currentStepIndex = 0;
      _isActive = false;
      _isInitialized = false;
      debugPrint('🔄 [TUTORIAL] Tutorial reset');
      notifyListeners();
    } catch (e) {
      debugPrint('❌ [TUTORIAL] Error resetting: $e');
    }
  }

  /// Restart tutorial from settings
  Future<void> restartTutorial() async {
    await resetTutorial();
    _isActive = true;
    _isInitialized = true;
    notifyListeners();
  }

  /// Get the bounding rect of a target element
  Rect? getTargetRect(GlobalKey key) {
    try {
      final RenderBox? renderBox =
          key.currentContext?.findRenderObject() as RenderBox?;
      if (renderBox == null) return null;

      final position = renderBox.localToGlobal(Offset.zero);
      final size = renderBox.size;

      return Rect.fromLTWH(
        position.dx,
        position.dy,
        size.width,
        size.height,
      );
    } catch (e) {
      debugPrint('⚠️ [TUTORIAL] Error getting target rect: $e');
      return null;
    }
  }

  /// Check if a tap is within the target area
  bool isTapOnTarget(Offset tapPosition) {
    final targetKey = currentTargetKey;
    if (targetKey == null) return false;

    final rect = getTargetRect(targetKey);
    if (rect == null) return false;

    // Add some padding for easier tapping
    final expandedRect = rect.inflate(10);
    return expandedRect.contains(tapPosition);
  }
}
