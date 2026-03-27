import 'package:flutter/material.dart';

/// Utility class for keyboard handling
class KeyboardUtils {
  /// Dismiss keyboard when called
  static void dismiss(BuildContext context) {
    FocusScope.of(context).unfocus();
  }
  
  /// Create a scroll controller that dismisses keyboard on scroll
  static ScrollController createDismissibleController(BuildContext context) {
    final controller = ScrollController();
    controller.addListener(() {
      if (FocusScope.of(context).hasFocus) {
        FocusScope.of(context).unfocus();
      }
    });
    return controller;
  }
}

/// A widget that wraps content and dismisses keyboard on tap outside text fields
class DismissKeyboardOnTap extends StatelessWidget {
  final Widget child;
  
  const DismissKeyboardOnTap({super.key, required this.child});
  
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => KeyboardUtils.dismiss(context),
      behavior: HitTestBehavior.translucent,
      child: child,
    );
  }
}

/// A ScrollView that dismisses keyboard when user starts scrolling
class KeyboardDismissibleScrollView extends StatelessWidget {
  final Widget child;
  final ScrollController? controller;
  final EdgeInsetsGeometry? padding;
  final ScrollPhysics? physics;
  final bool reverse;
  
  const KeyboardDismissibleScrollView({
    super.key,
    required this.child,
    this.controller,
    this.padding,
    this.physics,
    this.reverse = false,
  });
  
  @override
  Widget build(BuildContext context) {
    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification is ScrollStartNotification) {
          KeyboardUtils.dismiss(context);
        }
        return false;
      },
      child: SingleChildScrollView(
        controller: controller,
        padding: padding,
        physics: physics,
        reverse: reverse,
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        child: child,
      ),
    );
  }
}

/// A ListView that dismisses keyboard when user starts scrolling
class KeyboardDismissibleListView extends StatelessWidget {
  final IndexedWidgetBuilder itemBuilder;
  final int itemCount;
  final ScrollController? controller;
  final EdgeInsetsGeometry? padding;
  final ScrollPhysics? physics;
  final Widget? header;
  
  const KeyboardDismissibleListView({
    super.key,
    required this.itemBuilder,
    required this.itemCount,
    this.controller,
    this.padding,
    this.physics,
    this.header,
  });
  
  @override
  Widget build(BuildContext context) {
    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification is ScrollStartNotification) {
          KeyboardUtils.dismiss(context);
        }
        return false;
      },
      child: ListView.builder(
        controller: controller,
        padding: padding,
        physics: physics,
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        itemCount: header != null ? itemCount + 1 : itemCount,
        itemBuilder: (context, index) {
          if (header != null && index == 0) {
            return header!;
          }
          final actualIndex = header != null ? index - 1 : index;
          return itemBuilder(context, actualIndex);
        },
      ),
    );
  }
}

/// Extension on ScrollController to add keyboard dismissal
extension KeyboardDismissScrollController on ScrollController {
  void addKeyboardDismissListener(BuildContext context) {
    addListener(() {
      if (FocusScope.of(context).hasFocus) {
        FocusScope.of(context).unfocus();
      }
    });
  }
}
