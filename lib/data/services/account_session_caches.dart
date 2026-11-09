import 'package:flutter/foundation.dart';

import 'package:shoply/data/services/meal_photo_storage_service.dart';
import 'package:shoply/data/services/offer_price_service.dart';
import 'package:shoply/data/services/open_prices_service.dart';
import 'package:shoply/data/services/store_locator_service.dart';
import 'package:shoply/data/services/user_location_service.dart';

/// Teil B's in-memory caches that hold something of the signed-in account
/// (A8 request): the last location fix, offer searches with the zip code,
/// shelf prices of the account's items, nearby markets and signed photo
/// URLs. `main.dart` empties them on `signedOut`, next to Teil A's clean-up
/// of the stored values.
///
/// Already per account elsewhere, so not in here: the region and the
/// favourite markets (their providers start again for another account),
/// Avo's conversation (`AvoAssistantService` and `avoChatProvider` follow
/// the user id), the market per list (`ListStoreRepository`) and the
/// learned categories (`AiCategorizationService`).
abstract final class AccountSessionCaches {
  static void clearForSignOut() {
    UserLocationService.instance.clearMemory();
    OfferPriceService.instance.clearSessionCache();
    OpenPricesService.instance.clearMemory();
    StoreLocatorService.instance.clearCache();
    MealPhotoStorageService.instance.clearSignedUrls();
    debugPrint('✅ [ACCOUNT] Session caches of Teil B cleared');
  }
}
