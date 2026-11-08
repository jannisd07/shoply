/// Decides when a text from the Avo tab's URL (`?prompt=` or `?q=`) fills
/// the composer: once per distinct text, never again on a rebuild, a tab
/// switch or a return to the tab. It never sends; sending at once is only
/// for in-app hand-overs (`AvoAsk`, `openAvoWithQuestion`).
class AvoInitialQuestion {
  String? _lastHandedOver;

  /// The text to fill in now, or null. [question] is the current URL text; a
  /// new, different one counts as a new hand-over.
  String? take(String? question) {
    final q = question?.trim();
    if (q == null || q.isEmpty) {
      _lastHandedOver = null;
      return null;
    }
    if (q == _lastHandedOver) return null;
    _lastHandedOver = q;
    return q;
  }
}
