import 'package:flutter/material.dart';
import 'package:shoply/data/services/supabase_service.dart';

enum TutorialStepType {
  info,
  click,
  finish,
}

enum TutorialStepId {
  welcome,
  openShoppingList,
  showListItems,
  showInputField,
  navigateToRecipes,
  showRecipes,
  showCreateRecipe,
  tutorialComplete,
}

class TutorialStep {
  final TutorialStepId id;
  final TutorialStepType type;
  final String message;
  final GlobalKey? targetKey;
  final TutorialStepId? nextStep;
  final String? buttonText;

  const TutorialStep({
    required this.id,
    required this.type,
    required this.message,
    this.targetKey,
    this.nextStep,
    this.buttonText,
  });
}

class DynamicTutorialService extends ChangeNotifier {
  static final DynamicTutorialService _instance = DynamicTutorialService._internal();
  static DynamicTutorialService get instance => _instance;
  
  DynamicTutorialService._internal();

  bool _isActive = false;
  bool _isInitialized = false;
  TutorialStepId? _currentStepId;
  String? _currentUserId;
  String? _targetListId;
  bool _hasLists = false;
  bool _hasRecipes = false;
  bool _listHasItems = false;
  
  final GlobalKey firstListCardKey = GlobalKey(debugLabel: 'firstListCard');
  final GlobalKey listItemsAreaKey = GlobalKey(debugLabel: 'listItemsArea');
  final GlobalKey addItemInputKey = GlobalKey(debugLabel: 'addItemInput');
  final GlobalKey recipesTabKey = GlobalKey(debugLabel: 'recipesTab');
  final GlobalKey homeTabKey = GlobalKey(debugLabel: 'homeTab');
  final GlobalKey recipesAreaKey = GlobalKey(debugLabel: 'recipesArea');
  final GlobalKey addRecipeButtonKey = GlobalKey(debugLabel: 'addRecipeButton');
  
  bool get isActive => _isActive;
  bool get isInitialized => _isInitialized;
  TutorialStepId? get currentStepId => _currentStepId;
  String? get targetListId => _targetListId;
  bool get hasLists => _hasLists;
  bool get hasRecipes => _hasRecipes;
  bool get listHasItems => _listHasItems;
  
  TutorialStep? get currentStep {
    if (_currentStepId == null) return null;
    return _getStepConfig(_currentStepId!);
  }
  
  GlobalKey? get currentTargetKey {
    return currentStep?.targetKey;
  }
  
  Future<void> initialize() async {
    final user = SupabaseService.instance.currentUser;
    if (user == null) {
      _isInitialized = false;
      return;
    }
    
    if (_currentUserId != user.id) {
      _isInitialized = false;
      _currentUserId = user.id;
    }
    
    if (_isInitialized) return;
    
    try {
      final response = await SupabaseService.instance
          .from('users')
          .select('tutorial_completed')
          .eq('id', user.id)
          .maybeSingle();
      
      final completed = response?['tutorial_completed'] as bool? ?? false;
      
      _isInitialized = true;
      
      if (!completed) {
        _isActive = true;
        _currentStepId = TutorialStepId.welcome;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error checking tutorial status: $e');
      _isInitialized = true;
    }
  }
  
  void resetForNewUser() {
    _isInitialized = false;
    _isActive = false;
    _currentStepId = null;
    _currentUserId = null;
    _targetListId = null;
    notifyListeners();
  }
  
  void updateListsData({required bool hasLists, String? firstListId}) {
    _hasLists = hasLists;
    _targetListId = firstListId;
  }
  
  void updateListItemsData({required bool hasItems}) {
    _listHasItems = hasItems;
  }
  
  void updateRecipesData({required bool hasRecipes}) {
    _hasRecipes = hasRecipes;
  }
  
  TutorialStep _getStepConfig(TutorialStepId stepId) {
    switch (stepId) {
      case TutorialStepId.welcome:
        return TutorialStep(
          id: stepId,
          type: TutorialStepType.info,
          message: 'Ich bin Avo, dein Einkaufshelfer! Lass mich dir kurz zeigen, wie Shoply funktioniert.',
          nextStep: TutorialStepId.openShoppingList,
          buttonText: "Los geht's!",
        );
        
      case TutorialStepId.openShoppingList:
        return TutorialStep(
          id: stepId,
          type: TutorialStepType.click,
          message: _hasLists 
              ? 'Hier sind deine Einkaufslisten. Tippe auf eine, um sie zu öffnen!'
              : 'Hier ist deine erste Einkaufsliste. Tippe drauf!',
          targetKey: firstListCardKey,
          nextStep: TutorialStepId.showListItems,
        );
        
      case TutorialStepId.showListItems:
        return TutorialStep(
          id: stepId,
          type: TutorialStepType.info,
          message: _listHasItems
              ? 'Super! Hier siehst du deine Artikel. Tippe zum Abhaken!'
              : 'Hier erscheinen deine Artikel – nach Kategorie sortiert.',
          targetKey: listItemsAreaKey,
          nextStep: TutorialStepId.showInputField,
          buttonText: 'Verstanden',
        );
        
      case TutorialStepId.showInputField:
        return TutorialStep(
          id: stepId,
          type: TutorialStepType.info,
          message: 'Hier fügst du neue Artikel hinzu. Ich sortiere sie automatisch in Kategorien! 🪄',
          targetKey: addItemInputKey,
          nextStep: TutorialStepId.navigateToRecipes,
          buttonText: 'Cool!',
        );
        
      case TutorialStepId.navigateToRecipes:
        return TutorialStep(
          id: stepId,
          type: TutorialStepType.click,
          message: 'Jetzt zeig ich dir die Rezepte! Tippe auf das Symbol unten.',
          targetKey: recipesTabKey,
          nextStep: TutorialStepId.showRecipes,
        );
        
      case TutorialStepId.showRecipes:
        return TutorialStep(
          id: stepId,
          type: TutorialStepType.info,
          message: _hasRecipes
              ? 'Hier findest du Rezepte! Die Zutaten kannst du direkt zur Liste hinzufügen.'
              : 'Hier findest du Rezepte von der Community. Probier mal eins aus!',
          targetKey: recipesAreaKey,
          nextStep: TutorialStepId.showCreateRecipe,
          buttonText: 'Weiter',
        );
        
      case TutorialStepId.showCreateRecipe:
        return TutorialStep(
          id: stepId,
          type: TutorialStepType.info,
          message: 'Hier kannst du eigene Rezepte erstellen und teilen!',
          targetKey: addRecipeButtonKey,
          nextStep: TutorialStepId.tutorialComplete,
          buttonText: 'Alles klar!',
        );
        
      case TutorialStepId.tutorialComplete:
        return TutorialStep(
          id: stepId,
          type: TutorialStepType.finish,
          message: 'Du bist startklar! Viel Spaß beim Einkaufen. Bei Fragen findest du mich in den Einstellungen. 🥑',
          buttonText: 'Loslegen!',
        );
    }
  }
  
  void nextStep() {
    final step = currentStep;
    if (step == null) return;
    
    if (step.nextStep != null) {
      _currentStepId = step.nextStep;
      notifyListeners();
    } else {
      completeTutorial();
    }
  }
  
  void completeCurrentStep() {
    nextStep();
  }
  
  void onRouteChanged(String route) {
    if (!_isActive) return;
    
    if (route == '/recipes' && _currentStepId == TutorialStepId.navigateToRecipes) {
      _currentStepId = TutorialStepId.showRecipes;
      notifyListeners();
    }
  }
  
  void onListOpened() {
    if (!_isActive) return;
    
    if (_currentStepId == TutorialStepId.openShoppingList) {
      _currentStepId = TutorialStepId.showListItems;
      notifyListeners();
    }
  }
  
  Rect? getTargetRect(GlobalKey key) {
    final context = key.currentContext;
    if (context == null) return null;
    
    final renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null || !renderBox.hasSize) return null;
    
    final position = renderBox.localToGlobal(Offset.zero);
    return Rect.fromLTWH(
      position.dx,
      position.dy,
      renderBox.size.width,
      renderBox.size.height,
    );
  }
  
  bool isTapOnTarget(Offset globalPosition) {
    final targetKey = currentTargetKey;
    if (targetKey == null) return false;
    
    final rect = getTargetRect(targetKey);
    if (rect == null) return false;
    
    final expandedRect = rect.inflate(10);
    return expandedRect.contains(globalPosition);
  }
  
  Future<void> skipTutorial() async {
    _isActive = false;
    _currentStepId = null;
    
    await _saveTutorialCompleted();
    
    notifyListeners();
  }
  
  Future<void> completeTutorial() async {
    _isActive = false;
    _currentStepId = null;
    
    await _saveTutorialCompleted();
    
    notifyListeners();
  }
  
  Future<void> _saveTutorialCompleted() async {
    final user = SupabaseService.instance.currentUser;
    if (user == null) return;
    
    try {
      await SupabaseService.instance
          .from('users')
          .update({'tutorial_completed': true})
          .eq('id', user.id);
    } catch (e) {
      debugPrint('Error saving tutorial status: $e');
    }
  }
  
  Future<void> restartTutorial() async {
    final user = SupabaseService.instance.currentUser;
    if (user == null) return;
    
    try {
      await SupabaseService.instance
          .from('users')
          .update({'tutorial_completed': false})
          .eq('id', user.id);
    } catch (e) {
      debugPrint('Error resetting tutorial status: $e');
    }
    
    _isInitialized = false;
    _isActive = true;
    _currentStepId = TutorialStepId.welcome;
    
    notifyListeners();
  }
  
  void startTutorial() {
    _isActive = true;
    _currentStepId = TutorialStepId.welcome;
    notifyListeners();
  }
}
