import 'package:intl/intl.dart';
import 'package:shoply/core/localization/app_translations.dart';

/// Units with a short label in the app language (`list_detail_unit_*`).
const Set<String> _knownUnits = {
  'kg',
  'g',
  'l',
  'ml',
  'dozen',
  'pack',
  'bottle',
  'can',
  'box',
  'bunch',
};

/// Spellings of "pieces" in older rows.
const Set<String> _pieceUnits = {
  'pcs',
  'pc',
  'stk',
  'stk.',
  'st',
  'st.',
  'stück',
  'x',
  'piece',
  'pieces',
};

/// Whether [unit] means pieces (or no unit at all).
bool isPieceUnit(String? unit) {
  final lower = unit?.trim().toLowerCase() ?? '';
  return lower.isEmpty || _pieceUnits.contains(lower);
}

/// The quantity as shown under an item everywhere (list, shopping mode,
/// Avo cards): "3 St.", "1,5 L", "500 g", "2 Beutel" (free text from older
/// rows stays as typed). Null for a single piece without a unit, which needs
/// no second line (D2).
///
/// The number uses the app language ("1,5" / "1.5") without a trailing ",0".
String? formatQuantity(
  double quantity,
  String? unit, {
  required String languageCode,
}) {
  final number = NumberFormat('0.##', languageCode).format(quantity);
  final raw = unit?.trim() ?? '';
  final lower = raw.toLowerCase();
  if (isPieceUnit(raw)) {
    if (quantity == 1) return null;
    return '$number ${AppTranslations.get('list_detail_unit_pcs', languageCode)}';
  }
  if (_knownUnits.contains(lower)) {
    final label = AppTranslations.get('list_detail_unit_$lower', languageCode);
    return '$number $label';
  }
  return '$number $raw';
}
