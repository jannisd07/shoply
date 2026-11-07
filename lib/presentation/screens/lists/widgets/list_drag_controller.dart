import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Drag state and edge auto-scroll for the list detail screen.
///
/// Holds plain fields instead of widget state: nothing on screen depends on
/// them while dragging, so a drag never rebuilds the list.
class ListDragController {
  ListDragController(this.scrollController);

  final ScrollController scrollController;

  /// Category the item currently being dragged came from, or null.
  String? draggedFromCategory;

  Timer? _autoScrollTimer;
  int _scrollDirection = 0; // -1 = up, 0 = none, 1 = down
  double _scrollSpeed = 0.0;

  // Scroll zone: how close to the edge the finger must be to start scrolling.
  static const _scrollEdgeThreshold = 180.0;
  // Pixels per frame (at 60fps the max is ~1500px/sec).
  static const _maxScrollSpeed = 25.0;
  static const _minScrollSpeed = 8.0;

  void startDrag(String categoryId) {
    draggedFromCategory = categoryId;
  }

  void endDrag() {
    draggedFromCategory = null;
    _stopAutoScroll();
  }

  void dispose() {
    _autoScrollTimer?.cancel();
  }

  /// Auto-scrolls the list while the finger is near the top or bottom edge,
  /// so items can be dragged between categories that are far apart.
  void handleDragUpdate(BuildContext context, double globalY) {
    if (!scrollController.hasClients) return;

    final media = MediaQuery.of(context);
    // Top zone starts right below the status bar; bottom zone sits above
    // the bottom safe area.
    final topEdge = media.padding.top + 60;
    final bottomEdge = media.size.height - media.padding.bottom - 100;

    final distanceFromTop = globalY - topEdge;
    final distanceFromBottom = bottomEdge - globalY;

    if (distanceFromTop < _scrollEdgeThreshold) {
      _setScroll(-1, distanceFromTop);
    } else if (distanceFromBottom < _scrollEdgeThreshold) {
      _setScroll(1, distanceFromBottom);
    } else {
      _scrollDirection = 0;
      _scrollSpeed = 0.0;
    }
  }

  void _setScroll(int direction, double distanceFromEdge) {
    // Closer to the edge = faster, on a quadratic curve for smooth start.
    final normalized = (distanceFromEdge / _scrollEdgeThreshold).clamp(
      0.0,
      1.0,
    );
    final proximity = 1.0 - normalized;
    _scrollSpeed = _minScrollSpeed +
        (_maxScrollSpeed - _minScrollSpeed) * proximity * proximity;

    if (_scrollDirection != direction) {
      _scrollDirection = direction;
      HapticFeedback.selectionClick();
    }
    _autoScrollTimer ??= Timer.periodic(
      const Duration(milliseconds: 16),
      (_) => _performAutoScroll(),
    );
  }

  void _stopAutoScroll() {
    _autoScrollTimer?.cancel();
    _autoScrollTimer = null;
    _scrollDirection = 0;
    _scrollSpeed = 0.0;
  }

  void _performAutoScroll() {
    if (!scrollController.hasClients || _scrollDirection == 0) return;

    final offset = scrollController.offset;
    final maxOffset = scrollController.position.maxScrollExtent;
    if (_scrollDirection < 0 && offset <= 0) return;
    if (_scrollDirection > 0 && offset >= maxOffset) return;

    scrollController.jumpTo(
      (offset + _scrollDirection * _scrollSpeed).clamp(0.0, maxOffset),
    );
  }
}
