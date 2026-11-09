import 'package:shoply/presentation/widgets/design/avo_icons.dart';

/// Symbols of the account pages that `AvoIcons` does not have yet (Konzept
/// 18 E18-01: `photo`, `camera`, `checklist`, `clock.arrow.circlepath`,
/// `person.crop.circle`, `flame`). Drawn on the 24 grid with the D2 stroke
/// (1.8, round caps), like the set; `flame` is the D2 X-Profil glyph. They
/// move to `AvoIcons` once that file is open again.
abstract final class AccountIcons {
  /// SF Symbol `photo`: frame, hill, sun.
  static const photo = AvoIconData([
    AvoIconRect(3, 4.5, 18, 15, radius: 3),
    AvoIconPath('M3.6 16.4l4.6-4.5a1.5 1.5 0 0 1 2.1 0l5.6 5.6'),
    AvoIconPath('M14 15.4l1.7-1.7a1.5 1.5 0 0 1 2.1 0l2.7 2.7'),
    AvoIconCircle(15.6, 9.4, 1.6, style: AvoIconStyle.fill),
  ]);

  /// SF Symbol `camera`.
  static const camera = AvoIconData([
    AvoIconPath(
      'M3.5 8.6a2 2 0 0 1 2-2h2.2l1.5-2.1h5.6l1.5 2.1h2.2a2 2 0 0 1 2 2'
      'V17a2 2 0 0 1-2 2h-13a2 2 0 0 1-2-2z',
    ),
    AvoIconCircle(12, 12.6, 3.4),
  ]);

  /// SF Symbol `checklist`: three ticks and lines.
  static const checklist = AvoIconData([
    AvoIconPath('M3.5 6.5l1.5 1.5 2.7-3'),
    AvoIconPath('M3.5 12.5l1.5 1.5 2.7-3'),
    AvoIconPath('M3.5 18.5l1.5 1.5 2.7-3'),
    AvoIconPath('M11 6.5h9.5M11 12.5h9.5M11 18.5h9.5'),
  ]);

  /// SF Symbol `clock.arrow.circlepath`: history.
  static const history = AvoIconData([
    AvoIconPath('M4.1 13.4A8 8 0 1 0 6 6.3'),
    AvoIconPath('M3.6 3.6v4.2h4.2'),
    AvoIconPath('M12 8v4.4l3 1.8'),
  ]);

  /// SF Symbol `person.crop.circle`.
  static const personCircle = AvoIconData([
    AvoIconCircle(12, 12, 8.8),
    AvoIconCircle(12, 10, 3.2),
    AvoIconPath('M6.2 18.3c1.3-2 3.4-3.1 5.8-3.1s4.5 1.1 5.8 3.1'),
  ]);

  /// SF Symbol `flame` (D2 X-Profil "Kalorien" glyph as an outline).
  static const flame = AvoIconData([
    AvoIconPath(
      'M12 3c1 4 6 6 6 11a6 6 0 0 1-12 0c0-3 2-4 2-7 2 1 3 3 3 4 1-2 1-5 '
      '1-8z',
    ),
  ]);

  /// SF Symbol `arrow.triangle.2.circlepath`: the sync sign (Konzept 00
  /// §12.7) on the avatar and behind the name while a change waits.
  static const sync = AvoIconData([
    AvoIconPath('M19.5 11a7.5 7.5 0 0 0-13.4-4.1'),
    AvoIconPath('M6.4 3.4v3.8h3.8'),
    AvoIconPath('M4.5 13a7.5 7.5 0 0 0 13.4 4.1'),
    AvoIconPath('M17.6 20.6v-3.8h-3.8'),
  ], strokeWidth: 2.2);
}
