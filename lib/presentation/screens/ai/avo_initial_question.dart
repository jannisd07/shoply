/// Decides when a question handed to the Avo tab (`/avo?q=…`, from the
/// "Frag Avo …" field on Home) is sent: exactly once per hand-over, never
/// again on a rebuild, a tab switch or a return to the tab.
class AvoInitialQuestion {
  String? _lastHandedOver;

  /// The question to send now, or null. [question] is the current `q` of the
  /// route; a new, different `q` counts as a new hand-over.
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
