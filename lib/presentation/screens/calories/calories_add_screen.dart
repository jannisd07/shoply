import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:shoply/core/constants/app_brand.dart';
import 'package:shoply/core/design/design.dart';
import 'package:shoply/core/localization/localization_helper.dart';
import 'package:shoply/data/models/calorie_day.dart';
import 'package:shoply/data/models/food_log_entry.dart';
import 'package:shoply/data/models/food_product.dart';
import 'package:shoply/data/models/user_food.dart';
import 'package:shoply/data/services/connectivity_service.dart';
import 'package:shoply/data/services/native/barcode_scanner_channel.dart';
import 'package:shoply/data/services/native/meal_camera_channel.dart';
import 'package:shoply/data/services/open_food_facts_service.dart';
import 'package:shoply/presentation/providers/app_flags_provider.dart';
import 'package:shoply/presentation/providers/subscription_provider.dart';
import 'package:shoply/presentation/screens/calories/calories_photo_screen.dart';
import 'package:shoply/presentation/screens/calories/widgets/calorie_amount_food.dart';
import 'package:shoply/presentation/screens/calories/widgets/calorie_barcode.dart';
import 'package:shoply/presentation/screens/calories/widgets/calorie_date_menu.dart';
import 'package:shoply/presentation/screens/calories/widgets/calorie_entry_actions.dart';
import 'package:shoply/presentation/screens/calories/widgets/calorie_format.dart';
import 'package:shoply/presentation/screens/calories/widgets/calorie_meal_title.dart';
import 'package:shoply/presentation/screens/calories/widgets/calorie_recent_row.dart';
import 'package:shoply/presentation/state/calorie_diary_provider.dart';
import 'package:shoply/presentation/state/calorie_entry_provider.dart';
import 'package:shoply/presentation/state/nutrition_provider.dart';
import 'package:shoply/presentation/widgets/design/app_button.dart';
import 'package:shoply/presentation/widgets/design/avo_figure.dart';
import 'package:shoply/presentation/widgets/design/avo_icons.dart';
import 'package:shoply/presentation/widgets/design/empty_state.dart';
import 'package:shoply/presentation/widgets/design/glass_icon_button.dart';
import 'package:shoply/presentation/widgets/design/glass_toolbar.dart';
import 'package:shoply/presentation/widgets/design/inset_section.dart';
import 'package:shoply/presentation/widgets/design/item_row.dart';
import 'package:shoply/presentation/widgets/design/search_field.dart';
import 'package:shoply/presentation/widgets/design/segmented_control.dart';
import 'package:shoply/presentation/widgets/design/settings_rows.dart';
import 'package:shoply/presentation/widgets/design/skeleton.dart';
import 'package:shoply/presentation/widgets/design/status_row.dart';
import 'package:shoply/routes/route_paths.dart';

/// How many foods "Zuletzt gegessen" shows without a search (S3).
const int _kRecentShown = 8;

/// Online hits wait for this pause in typing (S3: 300 ms).
const Duration _kSearchPause = Duration(milliseconds: 300);

// D2 X-Essen cards: 300 high (at least; they grow with large text), radius
// 26, symbol 34; rows 60 with a 44 image.
const double _kCardMinHeight = 300; // D2
const double _kCardGlyph = 34; // D2
const double _kRowMin = 60; // D2
const double _kRowVertical = 9; // D2
const double _kManualGlyph = 17; // D2 square.and.pencil
const int _kProPhotosPerDay = 15; // app_flags.ai_limits pro meal_photo

final Uri _kOffSite = Uri.parse('https://world.openfoodfacts.org');

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
  const CaloriesAddScreen({super.key, this.meal, this.dateKey});

  /// `?meal=`; null picks the meal by the time of day.
  final MealType? meal;

  /// `?date=`; null logs for today.
  final String? dateKey;

  @override
  ConsumerState<CaloriesAddScreen> createState() => _CaloriesAddScreenState();
}

class _CaloriesAddScreenState extends ConsumerState<CaloriesAddScreen> {
  late MealType _meal = widget.meal ?? mealForTime(ref.read(calorieClockProvider)());
  late String? _dateKey = widget.dateKey;
  String _query = '';
  String _onlineQuery = '';
  Timer? _pause;

  @override
  void dispose() {
    _pause?.cancel();
    super.dispose();
  }

  void _close() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(RoutePaths.home);
    }
  }

  void _search(String q) {
    setState(() => _query = q);
    _pause?.cancel();
    _pause = Timer(_kSearchPause, () {
      if (mounted) setState(() => _onlineQuery = q.trim());
    });
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
    } catch (e) {
      debugPrint('⚠️ [CalorieAdd] Photo picker failed: ${e.runtimeType}');
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
    var method = ref.watch(calorieInputMethodProvider);
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
          ref.read(calorieInputMethodProvider.notifier).choose(m);
        },
      ),
    );

    final content = switch (method) {
      CalorieInputMethod.photo => _photoSegment(context),
      CalorieInputMethod.barcode => _barcodeSegment(context),
      CalorieInputMethod.search => _searchSegment(context),
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
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: content),
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

  // ── "Suche" ─────────────────────────────────────────────────────────

  List<Widget> _searchSegment(BuildContext context) {
    final colors = context.colors;
    final recents = ref.watch(recentFoodsProvider);
    final own = ref.watch(userFoodsProvider);
    final offline = ref.watch(isOfflineProvider);
    final query = _query.trim().toLowerCase();
    final recentMatches = query.isEmpty
        ? recents.foods.take(_kRecentShown).toList()
        : recents.foods
            .where((f) =>
                f.template.foodName.toLowerCase().contains(query) ||
                (f.template.brand?.toLowerCase().contains(query) ?? false))
            .toList();
    final ownMatches = query.isEmpty ? const <UserFood>[] : own.where((f) => f.name.toLowerCase().contains(query)).toList();

    final online = _onlineQuery.length >= 2 && !offline && _onlineQuery.toLowerCase() == query;
    final hits = online ? ref.watch(calorieFoodSearchProvider(_onlineQuery)) : null;
    final onlineDone = hits != null && !hits.isLoading;
    final hitList = hits?.valueOrNull ?? const <FoodProduct>[];
    final searchedAll = offline || onlineDone;
    final nothing = query.isNotEmpty && recentMatches.isEmpty && ownMatches.isEmpty && hitList.isEmpty && searchedAll && !(hits?.hasError ?? false);

    return [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: AvoSpacing.screen),
        child: AvoSearchField(hint: context.tr('cal_search_placeholder'), onChanged: _search),
      ),
      if (offline) ...[
        const SizedBox(height: AvoSpacing.s),
        StatusRow(kind: StatusKind.offline, text: context.tr('cal_search_offline')),
      ] else if (hits?.hasError ?? false) ...[
        const SizedBox(height: AvoSpacing.s),
        StatusRow(
          kind: StatusKind.sectionError,
          text: context.tr('cal_search_error'),
          actionLabel: context.tr('retry'),
          onAction: () => ref.invalidate(calorieFoodSearchProvider(_onlineQuery)),
        ),
      ] else if (recents.failed) ...[
        const SizedBox(height: AvoSpacing.s),
        StatusRow(
          kind: StatusKind.sectionError,
          text: context.tr('cal_recent_error'),
          actionLabel: context.tr('retry'),
          onAction: () => retryRecentFoods(ref),
        ),
      ],
      if (recentMatches.isNotEmpty)
        InsetSection(
          header: context.tr('cal_sec_recent'),
          children: [
            for (final f in recentMatches)
              RecentFoodRow(
                key: ValueKey('cal-recent-${f.key}'),
                food: f,
                onLog: () => _log(f),
                onOtherAmount: () => _openAmount(CalorieAmountFood.fromEntry(f.template)),
                onRemove: () => ref.read(recentFoodsHiddenProvider.notifier).hide(f.key),
              ),
          ],
        )
      else if (query.isEmpty && !recents.failed && !recents.known)
        Padding(
          padding: const EdgeInsets.only(top: AvoSpacing.section),
          child: InsetSection(children: [
            SkeletonSection(rows: 3, withImage: false, loadingLabel: context.tr('cal_loading')),
          ]),
        )
      else if (query.isEmpty && !recents.failed)
        Padding(
          padding: const EdgeInsets.fromLTRB(AvoSpacing.xxxl, AvoSpacing.xl, AvoSpacing.xxxl, 0),
          child: Text(
            context.tr('cal_recent_first_run'),
            style: context.text(AvoTextStyle.footnote, color: colors.secondaryLabel),
          ),
        ),
      if (ownMatches.isNotEmpty)
        InsetSection(
          header: context.tr('cal_sec_own'),
          children: [
            for (final f in ownMatches)
              _FoodRow(
                key: ValueKey('cal-own-${f.id}'),
                name: f.name,
                subtitle: context.tr('cal_kcal_per_100g', params: {'kcal': context.kcal(f.kcal100)}),
                onTap: () => _openAmount(CalorieAmountFood.fromUserFood(f)),
              ),
          ],
        ),
      if (hitList.isNotEmpty) ...[
        InsetSection(
          header: context.tr('cal_sec_foods'),
          separatorIndent: context.isAccessibilityText ? AvoSpacing.l : AvoSpacing.l + AvoSizes.thumbSmall + AvoSpacing.m,
          children: [
            for (final p in hitList)
              _FoodRow(
                key: ValueKey('cal-off-${p.barcode}'),
                name: p.name,
                imageUrl: p.imageUrl,
                reserveImage: true,
                subtitle: _productLine(context, p),
                onTap: () => _openAmount(CalorieAmountFood.fromProduct(p, origin: FoodEntryOrigin.search)),
              ),
          ],
        ),
        _OffSource(color: colors.secondaryLabel),
      ],
      if (nothing)
        Padding(
          padding: const EdgeInsets.only(top: AvoSpacing.l),
          child: Column(
            children: [
              EmptyState(
                pose: AvoPose.thinking,
                title: context.tr('cal_search_none', params: {'query': _query.trim()}),
              ),
              const SizedBox(height: AvoSpacing.l),
              AppButton.primary(label: context.tr('cal_manual_row'), onPressed: () => _openManual(name: _query)),
            ],
          ),
        )
      else ...[
        const SizedBox(height: AvoSpacing.section),
        InsetSection(children: [
          NavRow(
            leading: ExcludeSemantics(
              child: Icon(CupertinoIcons.square_pencil, size: _kManualGlyph, color: colors.secondaryLabel),
            ),
            title: context.tr('cal_manual_row'),
            subtitle: context.tr('cal_manual_row_sub'),
            onTap: () => _openManual(name: _query),
          ),
        ]),
      ],
    ];
  }

  String _productLine(BuildContext context, FoodProduct p) {
    final kcal = p.caloriesPer100g;
    final brand = p.brand?.trim();
    if (kcal == null) return brand ?? '';
    final per = context.tr(p.isLiquid ? 'cal_kcal_per_100ml' : 'cal_kcal_per_100g', params: {'kcal': context.kcal(kcal)});
    return brand == null || brand.isEmpty ? per : '$brand · $per';
  }

  // ── "Foto" ──────────────────────────────────────────────────────────

  List<Widget> _photoSegment(BuildContext context) {
    final colors = context.colors;
    final offline = ref.watch(isOfflineProvider);
    final limit = ref.watch(caloriePhotoLimitReachedProvider);
    final pro = ref.watch(isSubscribedProvider);
    final Widget card;
    if (limit) {
      card = _SegmentCard(
        glyph: CupertinoIcons.camera,
        text: pro
            ? context.tr('cal_photo_limit_pro')
            : context.tr('cal_photo_limit_free', params: {'pro': AppBrand.proName, 'n': '$_kProPhotosPerDay'}),
        children: [
          AppButton.primary(label: context.tr('cal_manual_row'), onPressed: _openManual),
          if (!pro)
            AppButton.plain(
              label: context.tr('cal_see_pro', params: {'pro': AppBrand.proName}),
              onPressed: () => unawaited(context.push('/pro?feature=cal_photo')),
            ),
        ],
      );
    } else {
      card = _SegmentCard(
        glyph: CupertinoIcons.camera,
        text: context.tr('cal_photo_prompt'),
        children: [
          Semantics(
            hint: offline ? context.tr('cal_photo_offline') : null,
            child: AppButton.primary(
              label: context.tr('cal_photo_take'),
              icon: const Icon(CupertinoIcons.camera_fill),
              onPressed: offline ? null : _takePhoto,
            ),
          ),
          AppButton.plain(label: context.tr('cal_photo_pick'), onPressed: offline ? null : _pickPhoto),
          if (offline)
            Text(
              context.tr('cal_photo_offline'),
              textAlign: TextAlign.center,
              style: context.text(AvoTextStyle.footnote, color: colors.secondaryLabel),
            ),
        ],
      );
    }
    return [
      card,
      Padding(
        padding: const EdgeInsets.fromLTRB(AvoSpacing.screen + AvoSpacing.l, AvoSpacing.s, AvoSpacing.screen + AvoSpacing.l, 0),
        child: Text(context.tr('cal_photo_note'), style: context.text(AvoTextStyle.footnote, color: colors.secondaryLabel)),
      ),
    ];
  }

  // ── "Barcode" ───────────────────────────────────────────────────────

  _BarcodeOutcome? _barcodeOutcome;
  String? _typedCode;

  Future<void> _lookupTyped(String code) async {
    setState(() {
      _typedCode = code;
      _barcodeOutcome = _BarcodeOutcome.searching;
    });
    try {
      final product = await ref.read(calorieBarcodeLookupProvider)(code);
      if (!mounted) return;
      if (product == null) {
        setState(() => _barcodeOutcome = _BarcodeOutcome.notFound);
        return;
      }
      setState(() => _barcodeOutcome = null);
      _openAmount(CalorieAmountFood.fromProduct(product, origin: FoodEntryOrigin.barcode));
    } on OffRequestFailed catch (e) {
      if (mounted) setState(() => _barcodeOutcome = e.reason == 'offline' ? _BarcodeOutcome.offline : _BarcodeOutcome.failed);
    }
  }

  List<Widget> _barcodeSegment(BuildContext context) {
    final colors = context.colors;
    final supported = ref.watch(calorieScannerSupportedProvider).valueOrNull ?? true;
    final scans = ref.watch(calorieProductCacheProvider).recentScans;
    final code = _typedCode;
    final outcome = _barcodeOutcome;
    return [
      if (supported)
        _SegmentCard(
          glyph: CupertinoIcons.barcode_viewfinder,
          text: context.tr('cal_barcode_prompt'),
          children: [
            AppButton.primary(
              label: context.tr('cal_barcode_open'),
              onPressed: () => unawaited(context.push(_location('/scan'))),
            ),
          ],
        ),
      InsetSection(
        footer: supported ? null : context.tr('cal_barcode_unsupported'),
        children: [CalorieBarcodeField(onSubmit: _lookupTyped)],
      ),
      if (outcome != null && code != null) ...[
        const SizedBox(height: AvoSpacing.s),
        switch (outcome) {
          _BarcodeOutcome.searching => Padding(
              padding: const EdgeInsets.symmetric(horizontal: AvoSpacing.screen + AvoSpacing.l),
              child: Semantics(
                liveRegion: true,
                child: Text(
                  context.tr('cal_scan_searching', params: {'code': formatGtin(code)}),
                  style: context.text(AvoTextStyle.subhead, color: colors.secondaryLabel, tabular: true),
                ),
              ),
            ),
          _BarcodeOutcome.notFound => StatusRow(kind: StatusKind.sectionError, text: context.tr('cal_scan_not_found')),
          _BarcodeOutcome.offline => StatusRow(kind: StatusKind.offline, text: context.tr('cal_scan_offline')),
          _BarcodeOutcome.failed => StatusRow(
              kind: StatusKind.sectionError,
              text: context.tr('cal_search_error'),
              actionLabel: context.tr('retry'),
              onAction: () => _lookupTyped(code),
            ),
        },
        if (outcome == _BarcodeOutcome.notFound || outcome == _BarcodeOutcome.offline)
          Padding(
            padding: const EdgeInsets.fromLTRB(AvoSpacing.screen, AvoSpacing.s, AvoSpacing.screen, 0),
            child: AppButton.secondary(
              label: context.tr('cal_manual_row'),
              expand: true,
              onPressed: () => _openManual(barcode: code),
            ),
          ),
      ],
      if (scans.isNotEmpty)
        InsetSection(
          header: context.tr('cal_sec_recent_scans'),
          separatorIndent: context.isAccessibilityText ? AvoSpacing.l : AvoSpacing.l + AvoSizes.thumbSmall + AvoSpacing.m,
          children: [
            for (final p in scans)
              _FoodRow(
                key: ValueKey('cal-scan-${p.barcode}'),
                name: p.name,
                imageUrl: p.imageUrl,
                reserveImage: true,
                subtitle: _productLine(context, p),
                onTap: () => _openAmount(CalorieAmountFood.fromProduct(p, origin: FoodEntryOrigin.barcode)),
              ),
          ],
        ),
    ];
  }
}

enum _BarcodeOutcome { searching, notFound, offline, failed }

/// The photo and barcode cards (D2 X-Essen: at least 300 high, radius 26,
/// `fill`, the symbol 34 in grey, a sentence, the actions).
class _SegmentCard extends StatelessWidget {
  const _SegmentCard({required this.glyph, required this.text, required this.children});

  final IconData glyph;
  final String text;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AvoSpacing.screen),
      child: DecoratedBox(
        decoration: BoxDecoration(color: colors.fill, borderRadius: BorderRadius.circular(AvoRadii.group)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: _kCardMinHeight, minWidth: double.infinity),
          child: Padding(
            padding: const EdgeInsets.all(AvoSpacing.xl),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                ExcludeSemantics(child: Icon(glyph, size: _kCardGlyph, color: colors.secondaryLabel)),
                const SizedBox(height: AvoSpacing.m),
                Text(text, textAlign: TextAlign.center, style: context.text(AvoTextStyle.body)),
                const SizedBox(height: AvoSpacing.l),
                for (final c in children) ...[c, const SizedBox(height: AvoSpacing.xs)],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A food hit (own food, Open Food Facts, recent scan): optional 44 pt
/// product photo on white (gone from AX1 on), name, "Milbona · 63 kcal pro
/// 100 g", chevron; opens S7.
class _FoodRow extends StatelessWidget {
  const _FoodRow({
    super.key,
    required this.name,
    required this.subtitle,
    required this.onTap,
    this.imageUrl,
    this.reserveImage = false,
  });

  final String name;
  final String subtitle;
  final String? imageUrl;
  final bool reserveImage;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final image = imageUrl;
    final showImage = reserveImage && !context.isAccessibilityText;
    return Semantics(
      container: true,
      button: true,
      label: [name, if (subtitle.isNotEmpty) subtitle].join(', '),
      onTap: onTap,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: _kRowMin),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AvoSpacing.l, vertical: _kRowVertical),
            child: Row(
              children: [
                if (showImage) ...[
                  SizedBox.square(
                    dimension: AvoSizes.thumbSmall,
                    child: image == null
                        ? DecoratedBox(
                            decoration: BoxDecoration(
                              color: colors.fill,
                              borderRadius: BorderRadius.circular(AvoRadii.imageSmall),
                            ),
                          )
                        : ItemThumb(image: NetworkImage(image)),
                  ),
                  const SizedBox(width: AvoSpacing.m),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(name, style: context.text(AvoTextStyle.body)),
                      if (subtitle.isNotEmpty)
                        Text(subtitle, style: context.text(AvoTextStyle.subhead, color: colors.secondaryLabel)),
                    ],
                  ),
                ),
                const SizedBox(width: AvoSpacing.s),
                ExcludeSemantics(
                  child: AvoIcon(AvoIcons.chevronRight, size: AvoSpacing.l, color: colors.tertiaryLabel),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// "Daten: Open Food Facts" as a link (the source Open Food Facts asks for).
class _OffSource extends StatelessWidget {
  const _OffSource({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    final text = context.tr('cal_off_source');
    void open() => unawaited(launchUrl(_kOffSite, mode: LaunchMode.externalApplication));
    return Semantics(
      link: true,
      label: text,
      onTap: open,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: open,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: AvoSizes.hitTarget),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(AvoSpacing.screen + AvoSpacing.l, AvoSpacing.s, AvoSpacing.screen, 0),
            child: Text(text, style: context.text(AvoTextStyle.footnote, color: color)),
          ),
        ),
      ),
    );
  }
}
