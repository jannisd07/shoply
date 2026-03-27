class ItemMergeService {
  
  /// Prüft, ob zwei Item-Namen dasselbe Produkt beschreiben
  /// Verwendet lokale Logik ohne API-Aufrufe für schnellere Performance
  /// Beispiel: "Brot" und "brot" → true
  /// Beispiel: "Roggenbrot" und "Weißbrot" → false
  Future<bool> areItemsSame(String item1, String item2) async {
    final name1 = _normalize(item1);
    final name2 = _normalize(item2);
    
    // 1. Exakte Übereinstimmung (nach Normalisierung)
    if (name1 == name2) {
      print('🔍 [ItemMerge] "$item1" vs "$item2" → SAME (exact match)');
      return true;
    }
    
    // 2. Plural-Check: Einer ist Plural des anderen
    if (_isPluralOf(name1, name2) || _isPluralOf(name2, name1)) {
      print('🔍 [ItemMerge] "$item1" vs "$item2" → SAME (plural)');
      return true;
    }
    
    // 3. Einer enthält den anderen komplett (z.B. "Brot" in "Brot")
    // Aber NICHT wenn es ein Präfix ist (z.B. "Brot" != "Brotaufstrich")
    if (name1 == name2) {
      print('🔍 [ItemMerge] "$item1" vs "$item2" → SAME');
      return true;
    }
    
    print('🔍 [ItemMerge] "$item1" vs "$item2" → DIFFERENT');
    return false;
  }
  
  /// Normalisiert einen Item-Namen für den Vergleich
  String _normalize(String name) {
    return name
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'\s+'), ' ') // Mehrfache Leerzeichen entfernen
        .replaceAll('ä', 'ae')
        .replaceAll('ö', 'oe')
        .replaceAll('ü', 'ue')
        .replaceAll('ß', 'ss');
  }
  
  /// Prüft, ob name1 eine Plural-Form von name2 ist
  bool _isPluralOf(String name1, String name2) {
    // Deutsche Plural-Endungen
    final pluralEndings = ['n', 'en', 'e', 's', 'er', 'nen'];
    
    for (final ending in pluralEndings) {
      if (name1 == name2 + ending) {
        return true;
      }
      // Umlaut-Plural (z.B. Apfel → Äpfel)
      if (name1.replaceAll('ae', 'a').replaceAll('oe', 'o').replaceAll('ue', 'u') == name2) {
        return true;
      }
    }
    
    return false;
  }
}
