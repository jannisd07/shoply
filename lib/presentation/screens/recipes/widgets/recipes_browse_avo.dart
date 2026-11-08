import 'dart:async';

import 'package:flutter/widgets.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:shoply/presentation/widgets/slots/b_slots.dart';

/// Tells Avo that the person is in the Rezepte area (`screen: 'recipes'`)
/// while the screen is visible, and clears it again when the screen is left
/// (another tab, a pushed screen, closed), unless another screen has set its
/// own context meanwhile.
///
/// Each visit sets a new [AvoScreenContext] instance, so "still mine" is an
/// identity check: a pushed recipes page sets an equal value of its own and
/// is not cleared by the screen below it.
mixin RecipesAvoContext<T extends ConsumerStatefulWidget> on ConsumerState<T> {
  late final StateController<AvoScreenContext?> _avoController;
  AvoScreenContext? _avoOwn;
  bool? _avoVisible;

  /// Screen id Avo gets (`recipes`).
  String get avoScreen => 'recipes';

  @override
  void initState() {
    super.initState();
    _avoController = ref.read(avoScreenContextProvider.notifier);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // A tab root stays mounted: TickerMode is off while another tab shows,
    // and the route is not current while something is pushed on top.
    final visible =
        TickerMode.valuesOf(context).enabled &&
        (ModalRoute.of(context)?.isCurrent ?? true);
    if (visible == _avoVisible) return;
    _avoVisible = visible;
    // Providers may not change while the tree builds.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _avoVisible != visible) return;
      visible ? _claimAvo() : _releaseAvo();
    });
  }

  void _claimAvo() {
    final own = AvoScreenContext(screen: avoScreen);
    _avoOwn = own;
    _avoController.state = own;
  }

  void _releaseAvo() {
    final own = _avoOwn;
    _avoOwn = null;
    if (own != null && identical(_avoController.state, own)) {
      _avoController.state = null;
    }
  }

  @override
  void dispose() {
    final own = _avoOwn;
    final controller = _avoController;
    if (own != null) {
      scheduleMicrotask(() {
        if (controller.mounted && identical(controller.state, own)) {
          controller.state = null;
        }
      });
    }
    super.dispose();
  }
}
