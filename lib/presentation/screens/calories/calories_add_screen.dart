import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:shoply/core/design/design.dart';
import 'package:shoply/core/localization/localization_helper.dart';
import 'package:shoply/data/models/calorie_day.dart';
import 'package:shoply/data/models/food_log_entry.dart';
import 'package:shoply/data/services/native/barcode_scanner_channel.dart';
import 'package:shoply/data/services/native/meal_camera_channel.dart';
import 'package:shoply/data/services/native/native_channel_errors.dart';
import 'package:shoply/presentation/providers/app_flags_provider.dart';
import 'package:shoply/presentation/screens/calories/calories_photo_screen.dart';
import 'package:shoply/presentation/screens/calories/widgets/calorie_add_barcode.dart';
import 'package:shoply/presentation/screens/calories/widgets/calorie_add_parts.dart';
import 'package:shoply/presentation/screens/calories/widgets/calorie_add_photo.dart';
import 'package:shoply/presentation/screens/calories/widgets/calorie_add_search.dart';
import 'package:shoply/presentation/screens/calories/widgets/calorie_amount_food.dart';
import 'package:shoply/presentation/screens/calories/widgets/calorie_date_menu.dart';
import 'package:shoply/presentation/screens/calories/widgets/calorie_entry_actions.dart';
import 'package:shoply/presentation/screens/calories/widgets/calorie_format.dart';
import 'package:shoply/presentation/screens/calories/widgets/calorie_meal_title.dart';
import 'package:shoply/presentation/state/calorie_diary_provider.dart';
import 'package:shoply/presentation/state/calorie_entry_provider.dart';
import 'package:shoply/presentation/state/nutrition_provider.dart';
import 'package:shoply/presentation/widgets/design/avo_icons.dart';
import 'package:shoply/presentation/widgets/design/glass_icon_button.dart';
import 'package:shoply/presentation/widgets/design/glass_toolbar.dart';
import 'package:shoply/presentation/widgets/design/segmented_control.dart';
import 'package:shoply/routes/route_paths.dart';

/// "Essen eintragen" (`kalorien.md` S3, D2 `X-Essen`): the one place to log
/// food, full screen above the tab bar at `/calories/add` (`?meal=`,
/// `?date=`). Closing returns to where it was opened.
///
/// The title is the meal menu ("Mittagessen eintragen ⌄"); on another day a
/// second line "Für Do., 5. Nov." opens the date menu. Below it the input
/// method "Foto | Barcode | Suche" (last used one; "Suche" the first time;
/// no "Foto" while the AI is switched off). "Suche": "Zuletzt gegessen"
/// logs with one tap and stays open, the search finds own foods and, after
/// a pause in typing, Open Food Facts; "Manuell eintragen" opens S8.
class CaloriesAddScreen extends ConsumerStatefulWidget {
  const CaloriesAddScreen({super.key, this.meal, this.dateKey, this.tab});

  /// `?meal=`; null picks the meal by the time of day.
  final MealType? meal;

  /// `?date=`; null logs for today.
  final String? dateKey;

  /// `?tab=photo|barcode|search`; null opens the segment used last.
  final CalorieInputMethod? tab;

  @override
  ConsumerState<CaloriesAddScreen> createState() => _CaloriesAddScreenState();
}

class _CaloriesAddScreenState extends ConsumerState<CaloriesAddScreen> {
  late MealType _meal = widget.meal ?? mealForTime(ref.read(calorieClockProvider)());
  late String? _dateKey = widget.dateKey;

  /// The segment `?tab=` asked for, until the person picks one.
  late CalorieInputMethod? _tab = widget.tab;

  void _close() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(RoutePaths.home);
    }
  }

  void _openDateMenu(BuildContext anchor, String shown, String today) {
    showCalorieDateMenu(
      anchor,
      shownKey: shown,
      todayKey: today,
      kcalByDay: calorieMenuDaysKcal(ref, today),
      onPick: (key) => setState(() => _dateKey = key == today ? null : key),
    );
  }

  Map<String, String> get _params => {
        'meal': _meal.dbValue,
        if (_dateKey case final d?) 'date': d,
      };

  String _location(String path, [Map<String, String> extra = const {}]) =>
      Uri(path: '${RoutePaths.calories}$path', queryParameters: {..._params, ...extra}).toString();

  void _openAmount(CalorieAmountFood food) =>
      unawaited(context.push(_location('/add/food/${Uri.encodeComponent(food.id)}'), extra: food));

  void _openManual({String? name, String? barcode}) => unawaited(context.push(_location('/add/manual', {
        if (name != null && name.trim().isNotEmpty) 'name': name.trim(),
        'barcode': ?barcode,
      })));

  /// Logs [food] for the chosen day; "today" is read at the tap, so a screen
  /// left open over midnight logs for the new day.
  Future<bool> _log(RecentFood food) async {
    final saved = await logFoodAgain(context, ref, food.template, dateKey: _dateKey, meal: _meal);
    return saved != null;
  }

  Future<void> _takePhoto() async {
    final camera = ref.read(calorieCameraProvider);
    final allowed = await ensureMealCameraAccess(context, camera);
    if (!mounted) return;
    // "Nicht jetzt" stays here; a refusal opens S4, which says why and
    // offers the photos instead.
    if (!allowed && await camera.permission() == CameraPermission.notDetermined) return;
    if (mounted) unawaited(context.push(_location('/add/photo')));
  }

  Future<void> _pickPhoto() async {
    final MealPhotoResult result;
    try {
      result = await ref.read(calorieCameraProvider).pickPhoto();
    } on NativeChannelException catch (e) {
      debugPrint('⚠️ [CalorieAdd] Photo picker failed: ${e.code.name}');
      if (mounted && e.code != NativeErrorCode.busy) showPhotoPickFailed(context);
      return;
    }
    final photo = result.bytes;
    if (!mounted || photo == null || !result.hasPhoto) return;
    openMealEstimate(context, photo, meal: _meal, dateKey: _dateKey);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final today = ref.watch(calorieTodayKeyProvider);
    final shown = switch (_dateKey) {
      final k? when k.compareTo(today) < 0 => k,
      _ => today,
    };
    // The chosen day starts loading at once, so its numbers are known
    // before anything is logged for it.
    ref.watch(calorieDayProvider(shown));
    // The date menu shows the week's kcal from the server too.
    ref.watch(calorieRecentDayTotalsProvider(today));
    final aiOn = ref.watch(aiRemoteEnabledProvider);
    CalorieInputMethod method = _tab ?? ref.watch(calorieInputMethodProvider);
    if (method == CalorieInputMethod.photo && !aiOn) method = CalorieInputMethod.search;

    final header = Padding(
      padding: EdgeInsets.fromLTRB(
        AvoSpacing.screen,
        GlassToolbar.topOffset(context),
        AvoSpacing.screen,
        AvoSpacing.m,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GlassIconButton(
            icon: const AvoIcon(AvoIcons.xmark),
            semanticLabel: context.tr('common_close'),
            onPressed: _close,
          ),
          const SizedBox(width: AvoSpacing.s),
          Expanded(
            child: CalorieMealTitle(
              meal: _meal,
              onMeal: (m) => setState(() => _meal = m),
              dateLine: shown == today
                  ? null
                  : context.tr('cal_add_for_date', params: {'date': context.shortDate(parseCalorieDayKey(shown))}),
              onDate: (anchor) => _openDateMenu(anchor, shown, today),
            ),
          ),
          const SizedBox(width: AvoSpacing.s),
          // Keeps the title centred (D2 X-Essen).
          const SizedBox.square(dimension: AvoSizes.toolbarButton),
        ],
      ),
    );

    final segments = Padding(
      padding: const EdgeInsets.fromLTRB(AvoSpacing.screen, AvoSpacing.xxs, AvoSpacing.screen, AvoSpacing.m),
      child: AppSegmentedControl<CalorieInputMethod>(
        semanticLabel: context.tr('cal_input_method_a11y'),
        segments: [
          if (aiOn) SegmentItem(value: CalorieInputMethod.photo, label: context.tr('cal_seg_photo')),
          SegmentItem(value: CalorieInputMethod.barcode, label: context.tr('cal_seg_barcode')),
          SegmentItem(value: CalorieInputMethod.search, label: context.tr('cal_seg_search')),
        ],
        selected: method,
        onChanged: (m) {
          unawaited(AvoHaptics.selection());
          setState(() => _tab = null);
          ref.read(calorieInputMethodProvider.notifier).choose(m);
        },
      ),
    );

    final actions = CalorieAddActions(
      openAmount: _openAmount,
      openManual: _openManual,
      openScanner: () => unawaited(context.push(_location('/scan'))),
      takePhoto: _takePhoto,
      pickPhoto: _pickPhoto,
      logAgain: _log,
    );
    final Widget content = switch (method) {
      CalorieInputMethod.photo => CalorieAddPhoto(actions: actions),
      CalorieInputMethod.barcode => CalorieAddBarcode(actions: actions),
      CalorieInputMethod.search => CalorieAddSearch(actions: actions),
    };

    return ColoredBox(
      color: colors.background,
      child: Column(
        children: [
          header,
          segments,
          Expanded(
            child: Stack(
              children: [
                SingleChildScrollView(
                  padding: EdgeInsets.only(
                    top: AvoSpacing.xs,
                    bottom: MediaQuery.paddingOf(context).bottom + AvoSpacing.xxl,
                  ),
                  keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                  child: content,
                ),
                const Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: ScrollEdgeFade(height: AvoSpacing.l),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
