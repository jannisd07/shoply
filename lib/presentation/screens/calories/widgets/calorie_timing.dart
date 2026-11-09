/// Waits of the calories area that are behaviour, not animation
/// (`kalorien.md`): screens use these instead of their own durations.
abstract final class CalorieTiming {
  /// Online search hits wait for this pause in typing (S3: 300 ms).
  static const Duration searchPause = Duration(milliseconds: 300);

  /// Live numbers are announced after this much calm (S7, S14: 1 s).
  static const Duration announceAfter = Duration(seconds: 1);
}
