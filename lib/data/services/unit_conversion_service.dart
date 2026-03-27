/// Service for converting units between metric and imperial systems
class UnitConversionService {
  static final UnitConversionService instance = UnitConversionService._();
  UnitConversionService._();

  // =============================================
  // WEIGHT CONVERSIONS
  // =============================================

  /// Convert grams to ounces
  double gramsToOunces(double grams) => grams * 0.035274;
  
  /// Convert ounces to grams
  double ouncesToGrams(double ounces) => ounces / 0.035274;
  
  /// Convert kilograms to pounds
  double kgToPounds(double kg) => kg * 2.20462;
  
  /// Convert pounds to kilograms
  double poundsToKg(double pounds) => pounds / 2.20462;

  // =============================================
  // VOLUME CONVERSIONS
  // =============================================

  /// Convert milliliters to cups
  double mlToCups(double ml) => ml / 236.588;
  
  /// Convert cups to milliliters
  double cupsToMl(double cups) => cups * 236.588;
  
  /// Convert liters to quarts
  double litersToQuarts(double liters) => liters * 1.05669;
  
  /// Convert quarts to liters
  double quartsToLiters(double quarts) => quarts / 1.05669;
  
  /// Convert milliliters to tablespoons
  double mlToTbsp(double ml) => ml / 14.787;
  
  /// Convert tablespoons to milliliters
  double tbspToMl(double tbsp) => tbsp * 14.787;
  
  /// Convert milliliters to teaspoons
  double mlToTsp(double ml) => ml / 4.929;
  
  /// Convert teaspoons to milliliters
  double tspToMl(double tsp) => tsp * 4.929;

  // =============================================
  // TEMPERATURE CONVERSIONS
  // =============================================

  /// Convert Celsius to Fahrenheit
  double celsiusToFahrenheit(double celsius) => (celsius * 9 / 5) + 32;
  
  /// Convert Fahrenheit to Celsius
  double fahrenheitToCelsius(double fahrenheit) => (fahrenheit - 32) * 5 / 9;

  // =============================================
  // LENGTH CONVERSIONS
  // =============================================

  /// Convert centimeters to inches
  double cmToInches(double cm) => cm / 2.54;
  
  /// Convert inches to centimeters
  double inchesToCm(double inches) => inches * 2.54;

  // =============================================
  // SMART CONVERSION
  // =============================================

  /// Convert an ingredient amount from metric to imperial
  IngredientConversion convertToImperial(double amount, String unit) {
    final unitLower = unit.toLowerCase().trim();
    
    switch (unitLower) {
      case 'g':
      case 'gram':
      case 'grams':
      case 'gramm':
        if (amount >= 450) {
          return IngredientConversion(
            amount: kgToPounds(amount / 1000),
            unit: 'lb',
            originalAmount: amount,
            originalUnit: unit,
          );
        } else {
          return IngredientConversion(
            amount: gramsToOunces(amount),
            unit: 'oz',
            originalAmount: amount,
            originalUnit: unit,
          );
        }
        
      case 'kg':
      case 'kilogram':
      case 'kilograms':
        return IngredientConversion(
          amount: kgToPounds(amount),
          unit: 'lb',
          originalAmount: amount,
          originalUnit: unit,
        );
        
      case 'ml':
      case 'milliliter':
      case 'milliliters':
        if (amount >= 240) {
          return IngredientConversion(
            amount: mlToCups(amount),
            unit: 'cups',
            originalAmount: amount,
            originalUnit: unit,
          );
        } else if (amount >= 15) {
          return IngredientConversion(
            amount: mlToTbsp(amount),
            unit: 'tbsp',
            originalAmount: amount,
            originalUnit: unit,
          );
        } else {
          return IngredientConversion(
            amount: mlToTsp(amount),
            unit: 'tsp',
            originalAmount: amount,
            originalUnit: unit,
          );
        }
        
      case 'l':
      case 'liter':
      case 'liters':
        return IngredientConversion(
          amount: litersToQuarts(amount),
          unit: 'qt',
          originalAmount: amount,
          originalUnit: unit,
        );
        
      case 'cm':
      case 'centimeter':
      case 'centimeters':
        return IngredientConversion(
          amount: cmToInches(amount),
          unit: 'in',
          originalAmount: amount,
          originalUnit: unit,
        );
        
      default:
        // Units that don't need conversion (pieces, cups, tbsp, tsp, etc.)
        return IngredientConversion(
          amount: amount,
          unit: unit,
          originalAmount: amount,
          originalUnit: unit,
        );
    }
  }

  /// Convert an ingredient amount from imperial to metric
  IngredientConversion convertToMetric(double amount, String unit) {
    final unitLower = unit.toLowerCase().trim();
    
    switch (unitLower) {
      case 'oz':
      case 'ounce':
      case 'ounces':
        return IngredientConversion(
          amount: ouncesToGrams(amount),
          unit: 'g',
          originalAmount: amount,
          originalUnit: unit,
        );
        
      case 'lb':
      case 'lbs':
      case 'pound':
      case 'pounds':
        return IngredientConversion(
          amount: poundsToKg(amount),
          unit: 'kg',
          originalAmount: amount,
          originalUnit: unit,
        );
        
      case 'cup':
      case 'cups':
        return IngredientConversion(
          amount: cupsToMl(amount),
          unit: 'ml',
          originalAmount: amount,
          originalUnit: unit,
        );
        
      case 'tbsp':
      case 'tablespoon':
      case 'tablespoons':
        return IngredientConversion(
          amount: tbspToMl(amount),
          unit: 'ml',
          originalAmount: amount,
          originalUnit: unit,
        );
        
      case 'tsp':
      case 'teaspoon':
      case 'teaspoons':
        return IngredientConversion(
          amount: tspToMl(amount),
          unit: 'ml',
          originalAmount: amount,
          originalUnit: unit,
        );
        
      case 'qt':
      case 'quart':
      case 'quarts':
        return IngredientConversion(
          amount: quartsToLiters(amount),
          unit: 'L',
          originalAmount: amount,
          originalUnit: unit,
        );
        
      case 'in':
      case 'inch':
      case 'inches':
        return IngredientConversion(
          amount: inchesToCm(amount),
          unit: 'cm',
          originalAmount: amount,
          originalUnit: unit,
        );
        
      default:
        return IngredientConversion(
          amount: amount,
          unit: unit,
          originalAmount: amount,
          originalUnit: unit,
        );
    }
  }

  /// Format temperature for display
  String formatTemperature(double celsius, {bool useImperial = false}) {
    if (useImperial) {
      final f = celsiusToFahrenheit(celsius).round();
      return '$f°F';
    } else {
      return '${celsius.round()}°C';
    }
  }

  /// Format amount for display (smart rounding)
  String formatAmount(double amount) {
    if (amount == amount.roundToDouble()) {
      return amount.toInt().toString();
    } else if (amount < 1) {
      // Show fractions for small amounts
      if ((amount - 0.25).abs() < 0.05) return '¼';
      if ((amount - 0.33).abs() < 0.05) return '⅓';
      if ((amount - 0.5).abs() < 0.05) return '½';
      if ((amount - 0.67).abs() < 0.05) return '⅔';
      if ((amount - 0.75).abs() < 0.05) return '¾';
      return amount.toStringAsFixed(1);
    } else {
      // Round to 1 decimal place
      final rounded = (amount * 10).round() / 10;
      if (rounded == rounded.roundToDouble()) {
        return rounded.toInt().toString();
      }
      return rounded.toStringAsFixed(1);
    }
  }
}

/// Result of a unit conversion
class IngredientConversion {
  final double amount;
  final String unit;
  final double originalAmount;
  final String originalUnit;

  const IngredientConversion({
    required this.amount,
    required this.unit,
    required this.originalAmount,
    required this.originalUnit,
  });

  /// Get display text
  String get displayText {
    final formattedAmount = UnitConversionService.instance.formatAmount(amount);
    return '$formattedAmount $unit';
  }

  /// Check if conversion was actually performed
  bool get wasConverted => unit != originalUnit;
}
