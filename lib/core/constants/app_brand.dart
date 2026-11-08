/// The app's name in one place (owner decision 07.11.2026: "Avo").
///
/// Texts, Siri phrases, Avo's app knowledge (Teil B) and the paywall read the
/// name from here instead of spelling it out. The code base, the package
/// (`shoply`) and the bundle id (`com.dominik.shoply`) keep their old names.
abstract final class AppBrand {
  /// Name shown to people: app, Siri, widgets, store listing.
  static const String name = 'Avo';

  /// The subscription.
  static const String proName = 'Avo Pro';

  /// The mascot has the app's name.
  static const String mascotName = name;
}
