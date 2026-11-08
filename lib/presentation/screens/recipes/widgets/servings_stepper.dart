import 'package:flutter/widgets.dart';

import 'package:shoply/core/localization/localization_helper.dart';
import 'package:shoply/presentation/widgets/design/value_stepper.dart';

/// Servings of a recipe, 1 to 20: the D2 [ValueStepper] with the rolling
/// number, selection haptic per step and repeat on hold (Konzept 13 §12.4).
/// Shared by the detail and "Zutaten auf die Liste"; VoiceOver reads
/// "Portionen" with the value.
class ServingsStepper extends StatelessWidget {
  const ServingsStepper({
    super.key,
    required this.value,
    required this.onChanged,
    this.min = 1,
    this.max = 20,
  });

  final int value;
  final ValueChanged<int> onChanged;
  final int min;
  final int max;

  @override
  Widget build(BuildContext context) => ValueStepper(
    value: value.clamp(min, max),
    onChanged: onChanged,
    min: min,
    max: max,
    semanticLabel: context.tr('recipe_detail_servings'),
  );
}
