/// Parses a user-entered decimal number, accepting both '.' and ',' as the
/// decimal separator (German iOS keyboards only offer ','). Returns null for
/// empty or invalid input.
double? parseLocaleDouble(String input) =>
    double.tryParse(input.trim().replaceAll(',', '.'));
