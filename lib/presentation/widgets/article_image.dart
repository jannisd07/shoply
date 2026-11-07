import 'package:flutter/widgets.dart';

import 'package:shoply/core/design/design.dart';
import 'package:shoply/data/models/shopping_item_model.dart';

/// Picture of an item, [size] points square with corner [radius] (contract
/// `b_slots.dart`; D2: 44/10, 52/12, 88/20).
///
/// Shell until B4: a neutral square in `fill`, so hosts lay out with the
/// final size. B4 shows an illustration, an Open Food Facts photo with its
/// source line, or the category symbol. Decorative for VoiceOver.
class ArticleImage extends StatelessWidget {
  const ArticleImage({
    super.key,
    required this.item,
    this.size = 44,
    this.radius = 10,
  });

  final ShoppingItemModel item;
  final double size;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: SizedBox.square(
        dimension: size,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: context.colors.fill,
            borderRadius: BorderRadius.circular(radius),
          ),
        ),
      ),
    );
  }
}
