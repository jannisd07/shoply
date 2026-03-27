import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:shoply/data/models/store_flyer_model.dart';
import 'package:shoply/core/constants/app_dimensions.dart';
import 'package:shoply/core/constants/app_text_styles.dart';
import 'package:shoply/presentation/screens/flyers/flyer_viewer_screen.dart';

/// Prospekt-Karte Widget
class FlyerCard extends StatelessWidget {
  final StoreFlyerModel flyer;

  const FlyerCard({
    super.key,
    required this.flyer,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          CupertinoPageRoute(
            fullscreenDialog: true,
            builder: (context) => FlyerViewerScreen(flyer: flyer),
          ),
        );
      },
      child: Container(
        width: 160,
        margin: const EdgeInsets.only(right: AppDimensions.spacingMedium),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Prospekt Cover
            Container(
              height: 220,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Stack(
                  children: [
                    // Cover Image
                    Image.network(
                      flyer.coverImageUrl,
                      width: double.infinity,
                      height: double.infinity,
                      fit: BoxFit.cover,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return Center(
                          child: CupertinoActivityIndicator(),
                        );
                      },
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          color: Colors.grey.shade200,
                          child: Center(
                            child: Icon(
                              CupertinoIcons.doc_text,
                              size: 48,
                              color: Colors.grey.shade400,
                            ),
                          ),
                        );
                      },
                    ),
                    
                    // Gradient Overlay für bessere Text-Lesbarkeit
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.black.withValues(alpha: 0.7),
                            ],
                          ),
                        ),
                        child: Row(
                          children: [
                            // Store Logo (klein)
                            Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              padding: const EdgeInsets.all(4),
                              child: Image.network(
                                flyer.logoUrl,
                                fit: BoxFit.contain,
                                errorBuilder: (context, error, stackTrace) {
                                  return Icon(
                                    CupertinoIcons.bag,
                                    size: 20,
                                    color: Colors.grey,
                                  );
                                },
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '${flyer.pageCount} Seiten',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    
                    // "NEU" Badge (optional)
                    if (flyer.isActive && 
                        DateTime.now().difference(flyer.validFrom).inDays < 2)
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'NEU',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 8),
            
            // Store Name
            Text(
              flyer.storeName,
              style: AppTextStyles.label.copyWith(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            
            const SizedBox(height: 4),
            
            // Gültigkeitsdauer
            Text(
              flyer.validityPeriod,
              style: AppTextStyles.bodySmall.copyWith(
                color: Colors.grey.shade600,
                fontSize: 12,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

/// Horizontale Prospekt-Liste
class FlyersHorizontalList extends StatelessWidget {
  final List<StoreFlyerModel> flyers;
  final String title;
  final VoidCallback? onSeeAll;

  const FlyersHorizontalList({
    super.key,
    required this.flyers,
    this.title = 'Aktuelle Prospekte',
    this.onSeeAll,
  });

  @override
  Widget build(BuildContext context) {
    if (flyers.isEmpty) {
      return const SizedBox.shrink();
    }

    return SizedBox(
      height: 380, // FESTE HÖHE für Sliver!
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppDimensions.screenHorizontalPadding,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: AppTextStyles.h2.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (onSeeAll != null)
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: onSeeAll,
                    child: Text(
                      'Alle ansehen',
                      style: TextStyle(
                        color: CupertinoColors.activeBlue,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          
          const SizedBox(height: AppDimensions.spacingMedium),
          
          // Horizontale Scrollbare Liste
          Expanded(
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(
                horizontal: AppDimensions.screenHorizontalPadding,
              ),
              itemCount: flyers.length,
              itemBuilder: (context, index) {
                return FlyerCard(flyer: flyers[index]);
              },
            ),
          ),
        ],
      ),
    );
  }
}
