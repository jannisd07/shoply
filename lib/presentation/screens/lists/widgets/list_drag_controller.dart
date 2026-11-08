import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import 'package:shoply/core/design/design.dart';

/// How close to the top or bottom edge the finger must be to scroll.
const double _edgeZone = 120;

/// Scroll speed in points per second at the edge and where the zone starts.
const double _maxSpeed = 1500;
const double _minSpeed = 300;

/// Drag state and edge auto-scroll while a row of the list is lifted
/// (Konzept 11 §1.1: "Auto-Scroll am Rand mit Ticker statt Timer").
///
/// Holds plain fields instead of widget state: nothing on screen depends on
/// them while dragging, so a drag never rebuilds the list.
class ListDragController {
  ListDragController(this.scrollController, TickerProvider vsync) {
    _ticker = vsync.createTicker(_onTick);
  }

  final ScrollController scrollController;
  late final Ticker _ticker;

  /// Aisle the lifted row came from, or null.
  String? draggedFromCategory;

  int _direction = 0; // -1 up, 0 none, 1 down
  double _speed = 0;
  Duration _lastTick = Duration.zero;

  void startDrag(String categoryId) => draggedFromCategory = categoryId;

  void endDrag() {
    draggedFromCategory = null;
    _stop();
  }

  void dispose() => _ticker.dispose();

  /// Scrolls while the finger at [globalY] is near the top (below the
  /// toolbar) or the bottom (above the add field and the tab bar).
  void handleDragUpdate(BuildContext context, double globalY) {
    if (!scrollController.hasClients) return;
    final top = MediaQuery.paddingOf(context).top + AvoSizes.toolbarButton;
    final bottom =
        MediaQuery.sizeOf(context).height -
        ShellInsets.bottom(context, withAccessory: true);
    final fromTop = globalY - top;
    final fromBottom = bottom - globalY;
    if (fromTop < _edgeZone) {
      _scroll(-1, fromTop);
    } else if (fromBottom < _edgeZone) {
      _scroll(1, fromBottom);
    } else {
      _stop();
    }
  }

  void _scroll(int direction, double distance) {
    // Closer to the edge is faster, on a quadratic curve for a soft start.
    final proximity = 1 - (distance / _edgeZone).clamp(0.0, 1.0);
    _speed = _minSpeed + (_maxSpeed - _minSpeed) * proximity * proximity;
    _direction = direction;
    if (!_ticker.isActive) {
      _lastTick = Duration.zero;
      _ticker.start();
    }
  }

  void _stop() {
    _direction = 0;
    _speed = 0;
    if (_ticker.isActive) _ticker.stop();
  }

  void _onTick(Duration elapsed) {
    final dt = (elapsed - _lastTick).inMicroseconds / 1e6;
    _lastTick = elapsed;
    if (!scrollController.hasClients || _direction == 0 || dt <= 0) return;
    final position = scrollController.position;
    final next = (position.pixels + _direction * _speed * dt).clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    );
    if (next != position.pixels) scrollController.jumpTo(next);
  }
}
