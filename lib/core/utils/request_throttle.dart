/// Spaces out the *start* of requests to an external API by at least
/// [minGap], also for concurrent callers (e.g. a `Future.wait` fan-out).
///
/// Each [wait] chains onto the previous turn, so its wait-and-stamp step runs
/// to completion before the next caller reads the last request time — without
/// that, N concurrent callers would all see the same stale timestamp and fire
/// together.
class RequestThrottle {
  RequestThrottle(this.minGap);

  final Duration minGap;

  DateTime _lastRequest = DateTime.fromMillisecondsSinceEpoch(0);
  Future<void> _queue = Future.value();

  /// Completes when the caller may start its request. Never throws.
  Future<void> wait() {
    final turn = _queue.then((_) async {
      final elapsed = DateTime.now().difference(_lastRequest);
      if (elapsed < minGap) await Future.delayed(minGap - elapsed);
      _lastRequest = DateTime.now();
    });
    _queue = turn;
    return turn;
  }
}
