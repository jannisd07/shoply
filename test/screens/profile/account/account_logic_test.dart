import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shoply/core/localization/app_translations.dart';
import 'package:shoply/data/models/shopping_list_model.dart';
import 'package:shoply/presentation/screens/lists/widgets/share_members.dart';
import 'package:shoply/presentation/screens/profile/account/account_backend.dart';
import 'package:shoply/presentation/screens/profile/account/account_local_data.dart';
import 'package:shoply/presentation/screens/profile/account/account_search.dart';
import 'package:shoply/presentation/screens/profile/account/account_widgets.dart';
import 'package:shoply/presentation/screens/profile/account/deletion_summary.dart';
import 'package:shoply/presentation/screens/profile/account/profile_edit_controller.dart';
import 'package:shoply/routes/route_paths.dart';

ShoppingListModel _list(String id, String owner, {bool shared = false}) {
  final now = DateTime(2026, 11, 7);
  return ShoppingListModel(
    id: id,
    name: id,
    ownerId: owner,
    isShared: shared,
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  group('sign-out clean-up (§7.2, K18-09)', () {
    test(
      'keeps Darstellung, Sprache and device facts, drops the rest',
      () async {
        SharedPreferences.setMockInitialValues({
          'theme_mode': 'dark',
          'language': 'de',
          'onboarding_complete_v1': true,
          'notif_permission_prompted_v1': true,
          'app_review_open_count': 7,
          'app_flags_v1': '{}',
          'app_modules_v1': '{"calories":true}',
          'calorie_tracking_enabled': true,
          'tips_state_v1': '{}',
          'offers_zip_code_v2': '79098',
          'subscription_status': true,
          'avo_pro_hint_shown_at': '2026-11-01',
          'pinned_list_u1': 'w',
          'onb_draft_v2': '{}',
          'password_reset_pending': true,
          'cal_write_queue_v1': '[]',
          'show_article_images': false,
          'notif_shopping_started': false,
          'setp_notif_time_restock': '9:00',
          'notif_master_enabled': true,
        });
        final prefs = await SharedPreferences.getInstance();
        final removed = await clearAccountBoundPreferences(prefs);
        expect(prefs.getKeys(), {
          'theme_mode',
          'language',
          'onboarding_complete_v1',
          'notif_permission_prompted_v1',
          'app_review_open_count',
          'app_flags_v1',
        });
        expect(removed, contains('app_modules_v1'));
        expect(removed, contains('offers_zip_code_v2'));
        expect(removed, contains('subscription_status'));
        expect(removed, contains('tips_state_v1'));
        expect(removed, contains('notif_shopping_started'));
        expect(removed, contains('setp_notif_time_restock'));
      },
    );
  });

  group('identity', () {
    test('sign-in method from app_metadata', () {
      expect(
        signInMethodFromMetadata({'provider': 'apple'}),
        SignInMethod.apple,
      );
      expect(
        signInMethodFromMetadata({'provider': 'google'}),
        SignInMethod.google,
      );
      expect(
        signInMethodFromMetadata({'provider': 'email'}),
        SignInMethod.email,
      );
      expect(signInMethodFromMetadata(null), SignInMethod.email);
    });

    test('emails break after @ and dots only', () {
      expect(breakableEmail('a.b@c.de'), 'a.​b@​c.​de');
    });

    test('a proof is fresh for 5 minutes', () {
      final at = DateTime(2026, 11, 7, 10);
      final proof = ReauthProof(method: SignInMethod.apple, at: at);
      expect(proof.isFresh(at.add(const Duration(minutes: 4))), isTrue);
      expect(proof.isFresh(at.add(const Duration(minutes: 5))), isFalse);
    });
  });

  group('display name (§4.3)', () {
    test('2 to 40 characters after trimming', () {
      expect(isValidDisplayName(' J '), isFalse);
      expect(isValidDisplayName('Jo'), isTrue);
      expect(isValidDisplayName('  Jannis D.  '), isTrue);
      expect(isValidDisplayName('A' * 40), isTrue);
      expect(isValidDisplayName('A' * 41), isFalse);
      // An emoji counts as one character.
      expect(isValidDisplayName('👍👍'), isTrue);
    });
  });

  group('photo (§4.3)', () {
    test('crops a landscape photo to a centred 512 px square JPEG', () {
      final source = img.Image(width: 900, height: 600);
      final bytes = Uint8List.fromList(img.encodePng(source));
      final out = img.decodeJpg(squareProfileJpeg(bytes))!;
      expect(out.width, kProfilePhotoSide);
      expect(out.height, kProfilePhotoSide);
    });

    test('rejects data that is not an image', () {
      expect(
        () => squareProfileJpeg(Uint8List.fromList([1, 2, 3])),
        throwsFormatException,
      );
    });
  });

  group('deletion summary (§7.3, F18-08)', () {
    test('own, handed over and left lists', () {
      final members = {
        'shared': [
          ListMember(
            userId: 'u1',
            name: 'Jannis',
            isOwner: true,
            joinedAt: DateTime(2026, 1, 1),
          ),
          ListMember(
            userId: 'mia',
            name: 'Mia',
            joinedAt: DateTime(2026, 5, 1),
          ),
          ListMember(
            userId: 'lena',
            name: 'Lena',
            joinedAt: DateTime(2026, 2, 1),
          ),
        ],
        'alone': [const ListMember(userId: 'u1', name: 'J', isOwner: true)],
      };
      final sorted = sortListsForDeletion(
        userId: 'u1',
        lists: [
          _list('plain', 'u1'),
          _list('alone', 'u1', shared: true),
          _list('shared', 'u1', shared: true),
          _list('unknown', 'u1', shared: true),
          _list('foreign', 'lena', shared: true),
        ],
        membersOf: (list) => members[list.id],
      );
      expect(sorted.own, 2);
      expect(sorted.left, 1);
      expect(sorted.handovers, const [
        ListHandover(listName: 'shared', memberName: 'Lena'),
        ListHandover(listName: 'unknown'),
      ]);
    });

    test('unknown join dates come last', () {
      final heir = firstJoined([
        const ListMember(userId: 'a', name: 'A'),
        ListMember(userId: 'b', name: 'B', joinedAt: DateTime(2026, 3, 1)),
      ]);
      expect(heir.userId, 'b');
    });
  });

  group('search entries (§3.5)', () {
    test('every key exists in both languages', () {
      final keys = <String>{
        for (final e in accountSearchEntries) ...[
          e.titleKey,
          ...e.pathKeys,
          ...e.keywordsKeys,
        ],
      };
      for (final key in keys) {
        expect(AppTranslations.get(key, 'en'), isNot(key), reason: key);
        expect(AppTranslations.get(key, 'de'), isNot(key), reason: key);
      }
    });

    test('rows point to their pages; "löschen" finds both places', () {
      for (final e in accountSearchEntries) {
        expect([
          RoutePaths.settingsProfile,
          RoutePaths.settingsAccount,
        ], contains(e.route));
        final row = e.rowId;
        if (row == null) continue;
        expect(
          row.startsWith(
            e.route == RoutePaths.settingsProfile ? 'profile.' : 'account.',
          ),
          isTrue,
          reason: row,
        );
      }
      final deleteHits = accountSearchEntries.where(
        (e) => e.keywordsKeys.any(
          (k) => AppTranslations.get(k, 'de').contains('löschen'),
        ),
      );
      expect(deleteHits.map((e) => e.rowId), {
        ProfileEditRows.photo,
        AccountRows.delete,
      });
    });
  });
}
