import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shoply/core/constants/app_colors.dart';
import 'package:shoply/core/localization/localization_helper.dart';
import 'package:shoply/core/widgets/design_system.dart';
import 'package:shoply/data/models/food_log_entry.dart';
import 'package:shoply/data/models/food_product.dart';
import 'package:shoply/data/services/meal_photo_analysis_service.dart';
import 'package:shoply/presentation/state/auth_provider.dart';
import 'package:shoply/presentation/state/nutrition_provider.dart';

/// Opens the "add food" flow for one meal on one day: search Open Food
/// Facts by name, enter a barcode, or type calories/macros manually.
Future<void> showFoodEntrySheet(
  BuildContext context, {
  required MealType mealType,
  required DateTime date,
}) {
  return showAppBottomSheet(
    context: context,
    maxHeight: MediaQuery.of(context).size.height * 0.88,
    builder: (_) => FoodEntrySheet(mealType: mealType, date: date),
  );
}

class FoodEntrySheet extends ConsumerStatefulWidget {
  final MealType mealType;
  final DateTime date;

  const FoodEntrySheet({super.key, required this.mealType, required this.date});

  @override
  ConsumerState<FoodEntrySheet> createState() => _FoodEntrySheetState();
}

enum _EntryTab { search, barcode, photo, manual }

class _FoodEntrySheetState extends ConsumerState<FoodEntrySheet> {
  _EntryTab _tab = _EntryTab.search;
  final _searchController = TextEditingController();
  final _barcodeController = TextEditingController();
  String _debouncedQuery = '';
  String _lookupBarcode = '';
  Timer? _debounce;
  bool _analyzingPhoto = false;
  MealPhotoEstimate? _photoEstimate;
  bool _photoAnalysisFailed = false;
  final _photoNameController = TextEditingController();
  final _photoCaloriesController = TextEditingController();
  final _photoProteinController = TextEditingController();
  final _photoCarbsController = TextEditingController();
  final _photoFatController = TextEditingController();

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _barcodeController.dispose();
    _photoNameController.dispose();
    _photoCaloriesController.dispose();
    _photoProteinController.dispose();
    _photoCarbsController.dispose();
    _photoFatController.dispose();
    super.dispose();
  }

  Future<void> _pickAndAnalyzePhoto(ImageSource source) async {
    final file = await ImagePicker().pickImage(source: source, maxWidth: 1024, imageQuality: 80);
    if (file == null) return;
    setState(() {
      _analyzingPhoto = true;
      _photoAnalysisFailed = false;
      _photoEstimate = null;
    });
    final bytes = await file.readAsBytes();
    final estimate = await MealPhotoAnalysisService.instance.analyzePhoto(bytes);
    if (!mounted) return;
    setState(() {
      _analyzingPhoto = false;
      _photoEstimate = estimate;
      _photoAnalysisFailed = estimate == null;
      if (estimate != null) {
        _photoNameController.text = estimate.foodName;
        _photoCaloriesController.text = '${estimate.calories}';
        _photoProteinController.text = estimate.proteinG?.round().toString() ?? '';
        _photoCarbsController.text = estimate.carbsG?.round().toString() ?? '';
        _photoFatController.text = estimate.fatG?.round().toString() ?? '';
      }
    });
  }

  Future<void> _savePhotoEntry() async {
    final authUser = ref.read(authUserProvider).valueOrNull;
    if (authUser == null) return;
    final calories = int.tryParse(_photoCaloriesController.text.trim()) ?? 0;
    if (_photoNameController.text.trim().isEmpty) return;
    await _logEntry(FoodLogEntry(
      id: '',
      userId: authUser.id,
      loggedDate: widget.date,
      mealType: widget.mealType,
      source: FoodLogSource.photo,
      foodName: _photoNameController.text.trim(),
      calories: calories,
      proteinG: double.tryParse(_photoProteinController.text.trim()),
      carbsG: double.tryParse(_photoCarbsController.text.trim()),
      fatG: double.tryParse(_photoFatController.text.trim()),
      createdAt: DateTime.now(),
    ));
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      if (mounted) setState(() => _debouncedQuery = value.trim());
    });
  }

  Future<void> _logEntry(FoodLogEntry entry) async {
    await ref.read(foodLogServiceProvider).addEntry(entry);
    invalidateNutritionLog(ref);
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _pickProduct(FoodProduct product) async {
    final authUser = ref.read(authUserProvider).valueOrNull;
    if (authUser == null) return;
    final grams = await showQuantityGramsDialog(context, product: product);
    if (grams == null) return;
    await _logEntry(FoodLogEntry(
      id: '',
      userId: authUser.id,
      loggedDate: widget.date,
      mealType: widget.mealType,
      source: FoodLogSource.barcode,
      foodName: product.name,
      brand: product.brand,
      quantity: grams,
      unit: 'g',
      calories: product.caloriesFor(grams),
      proteinG: product.proteinFor(grams),
      carbsG: product.carbsFor(grams),
      fatG: product.fatFor(grams),
      barcode: product.barcode,
      createdAt: DateTime.now(),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final textPrimary = AppColors.textPrimary(context);

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(context.tr('add_food_title'),
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: textPrimary)),
            const SizedBox(height: 14),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _tabChip(_EntryTab.search, context.tr('add_food_tab_search')),
                  const SizedBox(width: 8),
                  _tabChip(_EntryTab.barcode, context.tr('add_food_tab_barcode')),
                  const SizedBox(width: 8),
                  _tabChip(_EntryTab.photo, context.tr('add_food_tab_photo')),
                  const SizedBox(width: 8),
                  _tabChip(_EntryTab.manual, context.tr('add_food_tab_manual')),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Flexible(
              child: switch (_tab) {
                _EntryTab.search => _buildSearchTab(),
                _EntryTab.barcode => _buildBarcodeTab(),
                _EntryTab.photo => _buildPhotoTab(),
                _EntryTab.manual => _ManualEntryForm(
                    mealType: widget.mealType,
                    date: widget.date,
                    onSave: _logEntry,
                  ),
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _tabChip(_EntryTab tab, String label) {
    return AppChip(label: label, isSelected: _tab == tab, onTap: () => setState(() => _tab = tab));
  }

  Widget _buildSearchTab() {
    final textSecondary = AppColors.textSecondary(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppTextField(
          controller: _searchController,
          hintText: context.tr('add_food_search_hint'),
          prefixIcon: Icons.search,
          onChanged: _onSearchChanged,
        ),
        const SizedBox(height: 12),
        if (_debouncedQuery.length < 2)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Text(context.tr('add_food_search_prompt'),
                style: TextStyle(color: textSecondary, fontSize: 13)),
          )
        else
          Flexible(
            child: Consumer(
              builder: (context, ref, _) {
                final results = ref.watch(foodSearchProvider(_debouncedQuery));
                return results.when(
                  loading: () => const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  error: (_, __) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Text(context.tr('add_food_search_error'),
                        style: TextStyle(color: textSecondary, fontSize: 13)),
                  ),
                  data: (products) {
                    if (products.isEmpty) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        child: Text(context.tr('add_food_search_empty'),
                            style: TextStyle(color: textSecondary, fontSize: 13)),
                      );
                    }
                    return ListView.separated(
                      shrinkWrap: true,
                      itemCount: products.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 4),
                      itemBuilder: (context, i) => _ProductTile(
                        product: products[i],
                        onTap: () => _pickProduct(products[i]),
                      ),
                    );
                  },
                );
              },
            ),
          ),
      ],
    );
  }

  Widget _buildBarcodeTab() {
    final textSecondary = AppColors.textSecondary(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(context.tr('add_food_barcode_hint'),
            style: TextStyle(color: textSecondary, fontSize: 12.5, height: 1.4)),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: AppTextField(
                controller: _barcodeController,
                hintText: context.tr('add_food_barcode_placeholder'),
                keyboardType: TextInputType.number,
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              height: 52,
              child: ElevatedButton(
                onPressed: () {
                  HapticFeedback.selectionClick();
                  setState(() => _lookupBarcode = _barcodeController.text.trim());
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accentColor(context),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text(context.tr('add_food_barcode_lookup')),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (_lookupBarcode.isNotEmpty)
          Consumer(
            builder: (context, ref, _) {
              final result = ref.watch(barcodeLookupProvider(_lookupBarcode));
              return result.when(
                loading: () => const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (_, __) => Text(context.tr('add_food_search_error'),
                    style: TextStyle(color: textSecondary, fontSize: 13)),
                data: (product) {
                  if (product == null) {
                    return Text(context.tr('add_food_barcode_not_found'),
                        style: TextStyle(color: textSecondary, fontSize: 13));
                  }
                  return _ProductTile(product: product, onTap: () => _pickProduct(product));
                },
              );
            },
          ),
      ],
    );
  }

  Widget _buildPhotoTab() {
    final textSecondary = AppColors.textSecondary(context);
    final accent = AppColors.accentColor(context);

    if (_analyzingPhoto) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 12),
            Text(context.tr('add_food_photo_analyzing'),
                style: TextStyle(color: textSecondary, fontSize: 13)),
          ],
        ),
      );
    }

    if (_photoEstimate != null) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome, size: 16, color: accent),
              const SizedBox(width: 6),
              Text(context.tr('add_food_photo_confidence_${_photoEstimate!.confidence}'),
                  style: TextStyle(fontSize: 12, color: textSecondary)),
            ],
          ),
          const SizedBox(height: 10),
          AppTextField(controller: _photoNameController, labelText: context.tr('add_food_name')),
          const SizedBox(height: 10),
          AppTextField(
            controller: _photoCaloriesController,
            labelText: context.tr('add_food_calories'),
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: AppTextField(
                    controller: _photoProteinController, labelText: context.tr('add_food_protein')),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: AppTextField(
                    controller: _photoCarbsController, labelText: context.tr('add_food_carbs')),
              ),
              const SizedBox(width: 8),
              Expanded(
                child:
                    AppTextField(controller: _photoFatController, labelText: context.tr('add_food_fat')),
              ),
            ],
          ),
          const SizedBox(height: 16),
          AppButton(text: context.tr('add'), onPressed: _savePhotoEntry),
        ],
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(context.tr('add_food_photo_hint'),
            style: TextStyle(color: textSecondary, fontSize: 12.5, height: 1.4)),
        if (_photoAnalysisFailed) ...[
          const SizedBox(height: 10),
          Text(context.tr('add_food_photo_failed'),
              style: const TextStyle(color: AppColors.error, fontSize: 12.5)),
        ],
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: AppOutlineButton(
                text: context.tr('add_food_photo_camera'),
                icon: Icons.camera_alt_outlined,
                onPressed: () => _pickAndAnalyzePhoto(ImageSource.camera),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: AppOutlineButton(
                text: context.tr('add_food_photo_gallery'),
                icon: Icons.photo_library_outlined,
                onPressed: () => _pickAndAnalyzePhoto(ImageSource.gallery),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _ProductTile extends StatelessWidget {
  final FoodProduct product;
  final VoidCallback onTap;

  const _ProductTile({required this.product, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final textPrimary = AppColors.textPrimary(context);
    final textSecondary = AppColors.textSecondary(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: product.imageUrl != null
                  ? Image.network(product.imageUrl!,
                      width: 44, height: 44, fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _placeholderImage(context))
                  : _placeholderImage(context),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(product.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: textPrimary)),
                  Text(
                    [
                      if (product.brand != null) product.brand!,
                      if (product.hasNutrition) '${product.caloriesPer100g} kcal/100g',
                    ].join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: textSecondary),
                  ),
                ],
              ),
            ),
            Icon(Icons.add_circle_outline, color: AppColors.accentColor(context)),
          ],
        ),
      ),
    );
  }

  Widget _placeholderImage(BuildContext context) => Container(
        width: 44,
        height: 44,
        color: AppColors.surface(context),
        child: Icon(Icons.fastfood_outlined, size: 20, color: AppColors.textTertiary(context)),
      );
}

/// Prompts for a gram quantity and previews the resulting calories before
/// logging a looked-up [product].
Future<double?> showQuantityGramsDialog(BuildContext context, {required FoodProduct product}) {
  final controller = TextEditingController(text: '100');
  return showDialog<double>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) {
        final grams = double.tryParse(controller.text.trim()) ?? 0;
        return AlertDialog(
          title: Text(product.name, maxLines: 2, overflow: TextOverflow.ellipsis),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppTextField(
                controller: controller,
                labelText: context.tr('add_food_quantity_grams'),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 12),
              if (product.hasNutrition)
                Text('${product.caloriesFor(grams)} kcal',
                    style: const TextStyle(fontWeight: FontWeight.w600)),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(context.tr('cancel')),
            ),
            TextButton(
              onPressed: grams > 0 ? () => Navigator.of(context).pop(grams) : null,
              child: Text(context.tr('add')),
            ),
          ],
        );
      },
    ),
  );
}

class _ManualEntryForm extends ConsumerStatefulWidget {
  final MealType mealType;
  final DateTime date;
  final Future<void> Function(FoodLogEntry) onSave;

  const _ManualEntryForm({required this.mealType, required this.date, required this.onSave});

  @override
  ConsumerState<_ManualEntryForm> createState() => _ManualEntryFormState();
}

class _ManualEntryFormState extends ConsumerState<_ManualEntryForm> {
  final _nameController = TextEditingController();
  final _caloriesController = TextEditingController();
  final _proteinController = TextEditingController();
  final _carbsController = TextEditingController();
  final _fatController = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _caloriesController.dispose();
    _proteinController.dispose();
    _carbsController.dispose();
    _fatController.dispose();
    super.dispose();
  }

  bool get _canSave =>
      _nameController.text.trim().isNotEmpty && (int.tryParse(_caloriesController.text.trim()) ?? -1) >= 0;

  Future<void> _save() async {
    if (!_canSave || _saving) return;
    final authUser = ref.read(authUserProvider).valueOrNull;
    if (authUser == null) return;
    setState(() => _saving = true);
    await widget.onSave(FoodLogEntry(
      id: '',
      userId: authUser.id,
      loggedDate: widget.date,
      mealType: widget.mealType,
      source: FoodLogSource.manual,
      foodName: _nameController.text.trim(),
      calories: int.parse(_caloriesController.text.trim()),
      proteinG: double.tryParse(_proteinController.text.trim()),
      carbsG: double.tryParse(_carbsController.text.trim()),
      fatG: double.tryParse(_fatController.text.trim()),
      createdAt: DateTime.now(),
    ));
    if (mounted) setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppTextField(
          controller: _nameController,
          labelText: context.tr('add_food_name'),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 10),
        AppTextField(
          controller: _caloriesController,
          labelText: context.tr('add_food_calories'),
          keyboardType: TextInputType.number,
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: AppTextField(
                controller: _proteinController,
                labelText: context.tr('add_food_protein'),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: AppTextField(
                controller: _carbsController,
                labelText: context.tr('add_food_carbs'),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: AppTextField(
                controller: _fatController,
                labelText: context.tr('add_food_fat'),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        AppButton(text: context.tr('add'), onPressed: _canSave ? _save : null, isLoading: _saving),
      ],
    );
  }
}
