import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:shoply/core/constants/app_colors.dart';
import 'package:shoply/core/constants/paper_colors.dart';
import 'package:shoply/core/localization/localization_helper.dart';
import 'package:shoply/data/models/recipe.dart';
import 'package:shoply/data/services/notification_service.dart';
import 'package:shoply/presentation/screens/recipes/widgets/recipe_editor_palette.dart';
import 'package:shoply/presentation/screens/recipes/widgets/step_progress_ring.dart';

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

class _CookingModeScreenState extends State<CookingModeScreen> {
  /// Local notification id for the step timer.
  static const _timerNotificationId = 700100;

  int _currentStep = 0;
  final Set<int> _checkedIngredients = {};
  late int _currentServings;

  // Step timer. The remaining time is computed from a wall-clock end time,
  // so it stays correct while iOS suspends the app (a per-second decrement
  // froze in the background), and a local notification fires at the end.
  Timer? _timer;
  DateTime? _timerEndsAt;
  final _remainingSeconds = ValueNotifier<int>(0);
  bool _timerRunning = false;
  int? _activeTimerStep;

  late PageController _pageController;
  RecipeEditorPalette _p = const RecipeEditorPalette(false);

  int get _totalSteps => widget.recipe.instructions.length + 1;

  List<Ingredient> get _adjustedIngredients {
    return widget.recipe.ingredients
        .map(
          (ing) => ing.adjustForServings(
            widget.recipe.defaultServings,
            _currentServings,
          ),
        )
        .toList();
  }

  bool get _allIngredientsChecked =>
      _checkedIngredients.length == _adjustedIngredients.length;

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
    if (_timerEndsAt != null) {
      NotificationService.instance.cancel(_timerNotificationId);
    }
    _remainingSeconds.dispose();
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
      backgroundColor: _p.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _ServingsSelectorSheet(
        currentServings: _currentServings,
        palette: _p,
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
    _activeTimerStep = _currentStep;
    _runTimer(Duration(minutes: minutes));
  }

  void _runTimer(Duration duration) {
    _timer?.cancel();
    final endsAt = DateTime.now().add(duration);
    _timerEndsAt = endsAt;
    _remainingSeconds.value = duration.inSeconds;
    setState(() => _timerRunning = true);
    NotificationService.instance.scheduleNotification(
      id: _timerNotificationId,
      title: context.tr('cooking_mode_timer_done'),
      body: '${widget.recipe.name} · ${context.tr('cooking_mode_time_up')}',
      scheduledFor: endsAt,
    );
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  /// Seconds left until [_timerEndsAt], rounded up.
  int _secondsLeft(DateTime endsAt) =>
      (endsAt.difference(DateTime.now()).inMilliseconds / 1000).ceil();

  void _tick() {
    final endsAt = _timerEndsAt;
    if (endsAt == null) return;
    final left = _secondsLeft(endsAt);
    if (left > 0) {
      _remainingSeconds.value = left;
      return;
    }
    _stopTimer(remaining: 0);
    setState(() => _timerRunning = false);
    HapticFeedback.heavyImpact();
    _showTimerCompleteDialog();
  }

  /// Stops ticking and drops the scheduled notification.
  void _stopTimer({required int remaining}) {
    _timer?.cancel();
    _timerEndsAt = null;
    _remainingSeconds.value = remaining;
    NotificationService.instance.cancel(_timerNotificationId);
  }

  void _pauseTimer() {
    HapticFeedback.lightImpact();
    final endsAt = _timerEndsAt;
    final left = endsAt == null
        ? _remainingSeconds.value
        : _secondsLeft(endsAt);
    _stopTimer(remaining: left < 0 ? 0 : left);
    setState(() => _timerRunning = false);
  }

  void _resumeTimer() {
    HapticFeedback.lightImpact();
    if (_remainingSeconds.value <= 0) return;
    _runTimer(Duration(seconds: _remainingSeconds.value));
  }

  void _cancelTimer() {
    HapticFeedback.lightImpact();
    _stopTimer(remaining: 0);
    setState(() {
      _timerRunning = false;
      _activeTimerStep = null;
    });
  }

  void _showTimerCompleteDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: _p.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _p.green.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.timer_off, color: _p.green, size: 24),
            ),
            const SizedBox(width: 12),
            Text(
              context.tr('cooking_mode_timer_done'),
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: _p.textPrimary,
              ),
            ),
          ],
        ),
        content: Text(
          context.tr('cooking_mode_time_up'),
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 15, color: _p.textSecondary),
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              setState(() => _activeTimerStep = null);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _p.accent,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              context.tr('ok'),
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  static String _formatTime(int seconds) {
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  void _showExitConfirmation() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _p.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          context.tr('cooking_mode_exit_title'),
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: _p.textPrimary,
          ),
        ),
        content: Text(
          context.tr('cooking_mode_exit_message'),
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 15, color: _p.textSecondary),
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              context.tr('cancel'),
              style: TextStyle(color: _p.textSecondary),
            ),
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
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              context.tr('cooking_mode_exit_button'),
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    _p = RecipeEditorPalette.of(context);

    return Scaffold(
      backgroundColor: _p.bg,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _buildHeader(),

            if (_timerRunning || _remainingSeconds.value > 0) _buildTimerBar(),

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

            _buildNavigationBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: _p.bg,
        border: Border(bottom: BorderSide(color: _p.border, width: 0.5)),
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
                color: _p.card,
                shape: BoxShape.circle,
                border: Border.all(color: _p.border),
              ),
              child: Icon(Icons.close, color: _p.textPrimary, size: 22),
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
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: _p.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  _currentStep == 0
                      ? context.tr('cooking_mode_ingredients')
                      : context.tr(
                          'cooking_mode_step_of',
                          params: {
                            'current': '$_currentStep',
                            'total': '${widget.recipe.instructions.length}',
                          },
                        ),
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

  Widget _buildTimerBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [_p.accent.withOpacity(0.1), _p.accent.withOpacity(0.05)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _p.accent.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _p.accent.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(
              _timerRunning ? Icons.timer : Icons.pause_circle_outline,
              color: _p.accent,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          // Only this text rebuilds every second, not the whole screen.
          ValueListenableBuilder<int>(
            valueListenable: _remainingSeconds,
            builder: (context, seconds, _) => Text(
              _formatTime(seconds),
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: _p.accent,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
          const Spacer(),
          GestureDetector(
            onTap: _timerRunning ? _pauseTimer : _resumeTimer,
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: _p.accent.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(
                _timerRunning ? Icons.pause : Icons.play_arrow,
                color: _p.accent,
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
        ? '1 ${context.tr('cooking_mode_portion')}'
        : '$_currentServings ${context.tr('cooking_mode_portions')}';

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
                    _p.green.withOpacity(0.2),
                    _p.green.withOpacity(0.1),
                  ],
                ),
                shape: BoxShape.circle,
                border: Border.all(color: _p.green.withOpacity(0.3), width: 2),
              ),
              child: Icon(Icons.restaurant_menu, color: _p.green, size: 36),
            ),
            const SizedBox(height: 20),

            // Title
            Text(
              context.tr('cooking_mode_gather_ingredients'),
              textAlign: TextAlign.center,
              style: PaperTextStyles.serif(24, color: _p.textPrimary),
            ),
            const SizedBox(height: 8),

            // Subtitle
            Text(
              context.tr('cooking_mode_gather_subtitle'),
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 15, color: _p.textSecondary),
            ),
            const SizedBox(height: 12),

            // Servings badge - TAPPABLE
            GestureDetector(
              onTap: _showServingsSelector,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: _p.accent.withValues(alpha: _p.isDark ? 0.2 : 0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: _p.accent.withOpacity(0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.people, size: 18, color: _p.accent),
                    const SizedBox(width: 8),
                    Text(
                      servingsText,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: _p.accent,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Icon(Icons.edit, size: 14, color: _p.accent),
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
                color: _p.card,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _p.border),
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
                        color: _p.input,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: _p.border),
                      ),
                      child: Text(
                        _allIngredientsChecked
                            ? context.tr('deselect_all')
                            : context.tr('select_all'),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: _p.textSecondary,
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
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: isChecked
                              ? _p.green.withValues(
                                  alpha: _p.isDark ? 0.15 : 0.08,
                                )
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isChecked
                                ? _p.green.withOpacity(0.4)
                                : _p.border,
                          ),
                        ),
                        child: Row(
                          children: [
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              width: 22,
                              height: 22,
                              decoration: BoxDecoration(
                                color: isChecked
                                    ? _p.green
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: isChecked
                                      ? _p.green
                                      : _p.textSecondary.withOpacity(0.4),
                                  width: 2,
                                ),
                              ),
                              child: isChecked
                                  ? const Icon(
                                      Icons.check,
                                      color: Colors.white,
                                      size: 14,
                                    )
                                  : null,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                ingredient.displayText,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: isChecked
                                      ? _p.textSecondary
                                      : _p.textPrimary,
                                  decoration: isChecked
                                      ? TextDecoration.lineThrough
                                      : null,
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
                  colors: [_p.accent, _p.accent.withOpacity(0.7)],
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: _p.accent.withOpacity(0.3),
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
                color: _p.card,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _p.border),
              ),
              child: Text(
                instruction,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                  color: _p.textPrimary,
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
                  icon: Icon(Icons.timer, color: _p.accent),
                  label: Text(
                    context.tr(
                      'cooking_mode_start_timer',
                      params: {'minutes': '$timerMinutes'},
                    ),
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: _p.accent,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    side: BorderSide(color: _p.accent, width: 2),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavigationBar() {
    final isFirstStep = _currentStep == 0;
    final isLastStep = _currentStep == _totalSteps - 1;

    return SafeArea(
      top: false,
      minimum: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        decoration: BoxDecoration(
          color: _p.card,
          border: Border(top: BorderSide(color: _p.border, width: 0.5)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: _p.isDark ? 0.18 : 0.06),
              blurRadius: 16,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 48,
                child: OutlinedButton.icon(
                  onPressed: isFirstStep ? null : _previousStep,
                  icon: Icon(
                    Icons.arrow_back_rounded,
                    size: 18,
                    color: isFirstStep
                        ? _p.textSecondary.withOpacity(0.35)
                        : _p.textSecondary,
                  ),
                  label: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      context.tr('back'),
                      maxLines: 1,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: isFirstStep
                            ? _p.textSecondary.withOpacity(0.35)
                            : _p.textSecondary,
                      ),
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    side: BorderSide(
                      color: isFirstStep
                          ? _p.border.withOpacity(0.45)
                          : _p.border,
                    ),
                    minimumSize: const Size(0, 48),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: SizedBox(
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: isLastStep ? _closeCookingMode : _nextStep,
                  icon: Icon(
                    isLastStep
                        ? Icons.check_rounded
                        : Icons.arrow_forward_rounded,
                    size: 18,
                  ),
                  label: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      isLastStep
                          ? context.tr('done')
                          : context.tr('continue_text'),
                      maxLines: 1,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isLastStep ? _p.green : _p.accent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 0,
                    minimumSize: const Size(0, 48),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  int? _extractTimerMinutes(String text) {
    final patterns = [
      RegExp(
        r'(\d+)\s*(?:Minuten|minuten|Min\.|min\.?|minutes?)',
        caseSensitive: false,
      ),
      RegExp(
        r'(\d+)-(\d+)\s*(?:Minuten|minuten|Min\.|min\.?|minutes?)',
        caseSensitive: false,
      ),
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
  final RecipeEditorPalette palette;
  final void Function(int) onServingsChanged;

  const _ServingsSelectorSheet({
    required this.currentServings,
    required this.palette,
    required this.onServingsChanged,
  });

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
              color: palette.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),

          // Title
          Text(
            context.tr('servings'),
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: palette.textPrimary,
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
                    color: isSelected ? accentColor : palette.input,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isSelected ? accentColor : palette.border,
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      '$servings',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: isSelected ? Colors.white : palette.textPrimary,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),

          SizedBox(height: MediaQuery.paddingOf(context).bottom + 16),
        ],
      ),
    );
  }
}

/// Opens the cooking mode for [recipe] full screen above the tab bar. The
/// one entry point for every screen (A6 builds the D2 cooking mode behind
/// it; the signature stays).
Future<void> openCookingMode(
  BuildContext context, {
  required Recipe recipe,
  required int servings,
}) => Navigator.of(context, rootNavigator: true).push<void>(
  MaterialPageRoute(
    fullscreenDialog: true,
    builder: (context) => CookingModeScreen(recipe: recipe, servings: servings),
  ),
);
