final RegExp _nonAlphaNumeric = RegExp(r'[^a-z0-9\s]');
final RegExp _whitespace = RegExp(r'\s+');

/// Normalizes a product name for keyword / knowledge-base matching:
/// lowercase, umlauts transliterated (ä→ae, ö→oe, ü→ue, ß→ss), everything
/// except ASCII letters, digits and spaces removed, whitespace collapsed.
///
/// Umlauts must be transliterated BEFORE stripping: Dart's `\w` is
/// ASCII-only, so stripping first would delete them ('öl' → 'l').
String normalizeProductName(String name) {
  return name
      .toLowerCase()
      .replaceAll('ä', 'ae')
      .replaceAll('ö', 'oe')
      .replaceAll('ü', 'ue')
      .replaceAll('ß', 'ss')
      .replaceAll(_nonAlphaNumeric, '')
      .replaceAll(_whitespace, ' ')
      .trim();
}
