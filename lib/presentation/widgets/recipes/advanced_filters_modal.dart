import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shoply/core/constants/app_colors.dart';
import 'package:shoply/data/models/recipe_filter.dart';
import 'package:shoply/presentation/state/recipe_filter_provider.dart';

class AdvancedFiltersModal extends ConsumerStatefulWidget {
  const AdvancedFiltersModal({super.key});

  @override
  ConsumerState<AdvancedFiltersModal> createState() => _AdvancedFiltersModalState();
}

class _AdvancedFiltersModalState extends ConsumerState<AdvancedFiltersModal> {
  late AdvancedFilterOptions _options;
  late RangeValues _timeRange;

  @override
  void initState() {
    super.initState();
    _options = ref.read(recipeFilterProvider).advancedFilters;
    _timeRange = RangeValues(
      (_options.minTimeMinutes ?? 0).toDouble(),
      (_options.maxTimeMinutes ?? 180).toDouble(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Text(
                  'Advanced Filters',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Time Range
                  _buildSectionTitle('Time Range'),
                  const SizedBox(height: 12),
                  Text(
                    '${_timeRange.start.round()} - ${_timeRange.end.round()} minutes',
                    style: theme.textTheme.bodyMedium,
                  ),
                  RangeSlider(
                    values: _timeRange,
                    min: 0,
                    max: 180,
                    divisions: 36,
                    labels: RangeLabels(
                      '${_timeRange.start.round()}min',
                      '${_timeRange.end.round()}min',
                    ),
                    onChanged: (values) {
                      setState(() => _timeRange = values);
                    },
                  ),
                  const SizedBox(height: 24),

                  // Diet Restrictions
                  _buildSectionTitle('Diet Restrictions'),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildChip('Vegetarian', 'vegetarian'),
                      _buildChip('Vegan', 'vegan'),
                      _buildChip('Gluten-Free', 'gluten-free'),
                      _buildChip('Keto', 'keto'),
                      _buildChip('Low-Carb', 'low-carb'),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Meal Types
                  _buildSectionTitle('Meal Types'),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildMealTypeChip('Breakfast', 'breakfast'),
                      _buildMealTypeChip('Lunch', 'lunch'),
                      _buildMealTypeChip('Dinner', 'dinner'),
                      _buildMealTypeChip('Snack', 'snack'),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Difficulty
                  _buildSectionTitle('Difficulty'),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _buildDifficultyButton('Easy', 'easy'),
                      const SizedBox(width: 8),
                      _buildDifficultyButton('Medium', 'medium'),
                      const SizedBox(width: 8),
                      _buildDifficultyButton('Advanced', 'advanced'),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Cuisine
                  _buildSectionTitle('Cuisine'),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildCuisineChip('Italian', 'italian'),
                      _buildCuisineChip('Asian', 'asian'),
                      _buildCuisineChip('Mexican', 'mexican'),
                      _buildCuisineChip('Mediterranean', 'mediterranean'),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Nutritional
                  _buildSectionTitle('Nutritional'),
                  const SizedBox(height: 12),
                  CheckboxListTile(
                    title: const Text('High Protein'),
                    value: _options.highProtein,
                    onChanged: (value) {
                      setState(() {
                        _options = _options.copyWith(highProtein: value);
                      });
                    },
                    contentPadding: EdgeInsets.zero,
                  ),
                  CheckboxListTile(
                    title: const Text('Low Calorie'),
                    value: _options.lowCalorie,
                    onChanged: (value) {
                      setState(() {
                        _options = _options.copyWith(lowCalorie: value);
                      });
                    },
                    contentPadding: EdgeInsets.zero,
                  ),
                  CheckboxListTile(
                    title: const Text('High Fiber'),
                    value: _options.highFiber,
                    onChanged: (value) {
                      setState(() {
                        _options = _options.copyWith(highFiber: value);
                      });
                    },
                    contentPadding: EdgeInsets.zero,
                  ),
                  const SizedBox(height: 24),

                  // Servings Range
                  _buildSectionTitle('Servings'),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          decoration: const InputDecoration(
                            labelText: 'Min',
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: TextInputType.number,
                          onChanged: (value) {
                            final min = int.tryParse(value);
                            if (min != null) {
                              setState(() {
                                _options = _options.copyWith(minServings: min);
                              });
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextField(
                          decoration: const InputDecoration(
                            labelText: 'Max',
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: TextInputType.number,
                          onChanged: (value) {
                            final max = int.tryParse(value);
                            if (max != null) {
                              setState(() {
                                _options = _options.copyWith(maxServings: max);
                              });
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Footer buttons
          SafeArea(
            child: Container(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
              decoration: BoxDecoration(
              color: isDarkMode ? AppColors.recipeDarkSurface : AppColors.recipeLightSurface,
              border: Border(
                top: BorderSide(
                  color: isDarkMode ? AppColors.recipeDarkBorder : AppColors.recipeLightBorder,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        ref.read(recipeFilterProvider.notifier).clearAllFilters();
                        Navigator.pop(context);
                      },
                      child: const Text('Clear All'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        _applyFilters();
                        Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.recipeAccentColor(context),
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Apply'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
    );
  }

  Widget _buildChip(String label, String id) {
    final isSelected = _options.dietRestrictions.contains(id);
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          final newSet = Set<String>.from(_options.dietRestrictions);
          if (selected) {
            newSet.add(id);
          } else {
            newSet.remove(id);
          }
          _options = _options.copyWith(dietRestrictions: newSet);
        });
      },
    );
  }

  Widget _buildMealTypeChip(String label, String id) {
    final isSelected = _options.mealTypes.contains(id);
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          final newSet = Set<String>.from(_options.mealTypes);
          if (selected) {
            newSet.add(id);
          } else {
            newSet.remove(id);
          }
          _options = _options.copyWith(mealTypes: newSet);
        });
      },
    );
  }

  Widget _buildCuisineChip(String label, String id) {
    final isSelected = _options.cuisineTypes.contains(id);
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          final newSet = Set<String>.from(_options.cuisineTypes);
          if (selected) {
            newSet.add(id);
          } else {
            newSet.remove(id);
          }
          _options = _options.copyWith(cuisineTypes: newSet);
        });
      },
    );
  }

  Widget _buildDifficultyButton(String label, String id) {
    final isSelected = _options.difficulty == id;
    return Expanded(
      child: OutlinedButton(
        onPressed: () {
          setState(() {
            _options = _options.copyWith(
              difficulty: isSelected ? null : id,
            );
          });
        },
        style: OutlinedButton.styleFrom(
          backgroundColor: isSelected ? AppColors.recipeAccentColor(context) : null,
          foregroundColor: isSelected ? Colors.white : null,
        ),
        child: Text(label),
      ),
    );
  }

  void _applyFilters() {
    final updatedOptions = _options.copyWith(
      minTimeMinutes: _timeRange.start.round(),
      maxTimeMinutes: _timeRange.end.round(),
    );
    ref.read(recipeFilterProvider.notifier).updateAdvancedFilters(updatedOptions);
  }
}
