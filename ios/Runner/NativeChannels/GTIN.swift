import Foundation

/// Product numbers the barcode scanner accepts: EAN-13, EAN-8, UPC-A
/// (returned as 13 digits with a leading 0) and UPC-E (expanded to UPC-A,
/// then 13 digits). Anything with a wrong check digit is a misread.
/// Mirrors `BarcodeScannerChannel.normalizeGtin` on the Dart side.
enum GTIN {
  /// `symbology` is `"ean13"`, `"ean8"` or `"upce"`; only UPC-E changes how
  /// eight digits are read.
  static func normalize(_ payload: String, symbology: String?) -> String? {
    let digits = payload.filter { !$0.isWhitespace }
    guard !digits.isEmpty, digits.allSatisfy({ $0.isASCII && $0.isNumber }) else { return nil }
    let code: String
    switch (symbology, digits.count) {
    case ("upce", 8):
      guard let upcA = expandUPCE(digits) else { return nil }
      code = "0" + upcA
    case (_, 12):
      code = "0" + digits
    case (_, 13), (_, 8):
      code = digits
    default:
      return nil
    }
    return hasValidCheckDigit(code) ? code : nil
  }

  /// Eight-digit UPC-E (number system, six digits, check digit) to the
  /// twelve-digit UPC-A it stands for.
  static func expandUPCE(_ code: String) -> String? {
    let d = Array(code)
    guard d.count == 8, d[0] == "0" || d[0] == "1" else { return nil }
    let body: [Character]
    switch d[6] {
    case "0", "1", "2": body = [d[1], d[2], d[6], "0", "0", "0", "0", d[3], d[4], d[5]]
    case "3": body = [d[1], d[2], d[3], "0", "0", "0", "0", "0", d[4], d[5]]
    case "4": body = [d[1], d[2], d[3], d[4], "0", "0", "0", "0", "0", d[5]]
    default: body = [d[1], d[2], d[3], d[4], d[5], "0", "0", "0", "0", d[6]]
    }
    return String([d[0]] + body + [d[7]])
  }

  static func hasValidCheckDigit(_ code: String) -> Bool {
    let digits = code.compactMap { $0.wholeNumberValue }
    guard digits.count == code.count, let check = digits.last, digits.count >= 2 else {
      return false
    }
    var sum = 0
    for (offset, digit) in digits.dropLast().reversed().enumerated() {
      sum += offset.isMultiple(of: 2) ? digit * 3 : digit
    }
    return (10 - sum % 10) % 10 == check
  }

  /// "4 056489 123453" for EAN-13, "9638 5074" for EAN-8, as printed on packs.
  static func formatted(_ code: String) -> String {
    let c = Array(code)
    switch c.count {
    case 13: return "\(c[0]) \(String(c[1...6])) \(String(c[7...12]))"
    case 8: return "\(String(c[0...3])) \(String(c[4...7]))"
    default: return code
    }
  }
}
