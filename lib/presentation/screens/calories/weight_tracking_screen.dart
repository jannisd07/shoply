import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shoply/core/constants/app_colors.dart';
import 'package:shoply/core/localization/localization_helper.dart';
import 'package:shoply/core/widgets/design_system.dart';
import 'package:shoply/presentation/screens/calories/widgets/weight_chart.dart';
import 'package:shoply/presentation/state/nutrition_provider.dart';

class WeightTrackingScreen extends ConsumerStatefulWidget {
  const WeightTrackingScreen({super.key});

  @override
  ConsumerState<WeightTrackingScreen> createState() => _WeightTrackingScreenState();
}

class _WeightTrackingScreenState extends ConsumerState<WeightTrackingScreen> {
  final _weightController = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _weightController.dispose();
    super.dispose();
  }

  Future<void> _logWeight() async {
    final weight = double.tryParse(_weightController.text.trim());
    if (weight == null || weight <= 0 || _saving) return;
    setState(() => _saving = true);
    HapticFeedback.mediumImpact();
    await ref.read(weightLogServiceProvider).logWeight(weightKg: weight);
    ref.invalidate(weightHistoryProvider);
    _weightController.clear();
    if (mounted) setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    final textPrimary = AppColors.textPrimary(context);
    final historyAsync = ref.watch(weightHistoryProvider);
    final goal = ref.watch(nutritionGoalProvider).valueOrNull;

    return Scaffold(
      backgroundColor: AppColors.background(context),
      appBar: AppBar(
        backgroundColor: AppColors.background(context),
        elevation: 0,
        title: Text(context.tr('weight_tracking_title'),
            style: TextStyle(color: textPrimary, fontWeight: FontWeight.w600)),
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            AppCard(
              child: historyAsync.when(
                loading: () => const SizedBox(
                    height: 180, child: Center(child: CircularProgressIndicator())),
                error: (_, __) => SizedBox(
                  height: 180,
                  child: Center(child: Text(context.tr('weight_tracking_error'))),
                ),
                data: (entries) => WeightChart(entries: entries, targetWeightKg: goal?.targetWeightKg),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: AppTextField(
                    controller: _weightController,
                    hintText: context.tr('weight_tracking_input_hint'),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _saving ? null : _logWeight,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accentColor(context),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text(context.tr('save')),
                  ),
                ),
              ],
            ),
            if (goal?.targetWeightKg != null) ...[
              const SizedBox(height: 8),
              Text(
                context.tr('weight_tracking_target', params: {'weight': goal!.targetWeightKg!.toStringAsFixed(1)}),
                style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary(context)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
