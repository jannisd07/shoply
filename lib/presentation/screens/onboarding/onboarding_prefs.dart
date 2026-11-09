import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shoply/presentation/screens/auth/auth_gateway.dart'
    show kPasswordResetPendingKey;
import 'package:shoply/presentation/screens/onboarding/onboarding_steps.dart';

/// The device has been through the first-start flow (or signed in with an
/// account that was set up). The key stays, so people who onboarded before
/// the redesign never see it again (Konzept 17 §1.2).
const String kOnboardingCompleteKey = 'onboarding_complete_v1';

/// The step to resume in (Konzept 17 §5.5, §9.6). Absent when no flow runs.
const String kOnboardingStepKey = 'onb_step';

/// Module choice from before the account (Konzept 17 §1.2, table).
const String kPendingModulesKey = 'onb_pending_modules';

/// The rest of the answers (mode, diet, allergies, goal, list name) as JSON,
/// so a killed app comes back with every input.
const String kOnboardingDraftKey = 'onb_draft_v2';

/// A private link opened without a session (Konzept 17 §5.1, §9.6).
const String kPendingLinkKey = 'pending_link';

/// Pending links expire after a week (Konzept 17 §5.1).
const Duration kPendingLinkMaxAge = Duration(days: 7);

/// A remembered private link: the app path and when it was opened.
@immutable
class PendingLink {
  const PendingLink({required this.path, required this.savedAt});

  /// App path with query, e.g. `/join/AB12CD` or `/invite/<id>?code=AB12CD`.
  final String path;
  final DateTime savedAt;

  Uri get uri => Uri.parse(path);

  /// The share code when the link is an invitation that can be joined.
  String? get joinCode {
    final u = uri;
    final segments = u.pathSegments;
    if (segments.length >= 2 && segments.first == 'join') return segments[1];
    if (segments.isNotEmpty &&
        (segments.first == 'invite' || segments.first == 'list')) {
      final code = u.queryParameters['code'];
      if (code != null && code.isNotEmpty) return code;
    }
    return null;
  }

  /// An invitation to a list (Willkommen shows the invitation line).
  bool get isInvitation {
    final first = uri.pathSegments.isEmpty ? '' : uri.pathSegments.first;
    return first == 'join' || first == 'invite' || first == 'list';
  }

  bool isExpired(DateTime now) => now.difference(savedAt) > kPendingLinkMaxAge;

  Map<String, Object> toJson() => {
    'path': path,
    'at': savedAt.toUtc().toIso8601String(),
  };

  static PendingLink? fromJson(String? raw) {
    if (raw == null) return null;
    try {
      final map = (jsonDecode(raw) as Map).cast<String, Object?>();
      final path = map['path'];
      final at = DateTime.tryParse(map['at'] as String? ?? '');
      if (path is! String || at == null) return null;
      return PendingLink(path: path, savedAt: at);
    } catch (_) {
      return null;
    }
  }
}

/// Whether [location] (a matched app path) is a private link that needs an
/// account: shared lists, invitations, a list, an author page (Konzept 17
/// §1.3). Recipe links are public and not part of it.
bool isPrivateLink(String location) {
  final segments = Uri.parse(location).pathSegments;
  if (segments.length < 2) return false;
  return const {
    'invite',
    'list',
    'join',
    'lists',
    'author',
  }.contains(segments.first);
}

/// The onboarding state on this device, read synchronously after [load]
/// (the router asks on every navigation; Konzept 17 §3.1: one cache for the
/// flag instead of two, Inventar Bug 18).
class OnboardingPrefs {
  OnboardingPrefs._();

  static final OnboardingPrefs instance = OnboardingPrefs._();

  SharedPreferences? _prefs;

  bool get isLoaded => _prefs != null;

  /// Loads SharedPreferences once; later calls return at once.
  Future<void> load() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  /// Uses [prefs] (main already loaded it; tests pass a mock instance).
  void attach(SharedPreferences prefs) => _prefs = prefs;

  @visibleForTesting
  void detach() => _prefs = null;

  SharedPreferences? get raw => _prefs;

  bool get deviceOnboarded => _prefs?.getBool(kOnboardingCompleteKey) ?? false;

  /// The step a running flow stopped at, if any.
  OnboardingStep? get resumeStep =>
      OnboardingStep.fromId(_prefs?.getString(kOnboardingStepKey));

  /// Set by Teil "Konto" between the reset code and the new password
  /// (Konzept 17 §4.4, Inventar Bug 9).
  bool get passwordResetPending =>
      _prefs?.getBool(kPasswordResetPendingKey) ?? false;

  /// The remembered private link; null when none or older than a week.
  PendingLink? pendingLink({DateTime? now}) {
    final link = PendingLink.fromJson(_prefs?.getString(kPendingLinkKey));
    if (link == null) return null;
    return link.isExpired(now ?? DateTime.now()) ? null : link;
  }

  Future<void> rememberLink(String path, {DateTime? now}) async {
    await load();
    final link = PendingLink(path: path, savedAt: now ?? DateTime.now());
    await _prefs!.setString(kPendingLinkKey, jsonEncode(link.toJson()));
  }

  Future<void> clearLink() async {
    await load();
    await _prefs!.remove(kPendingLinkKey);
  }

  Future<void> setResumeStep(OnboardingStep? step) async {
    await load();
    if (step == null) {
      await _prefs!.remove(kOnboardingStepKey);
    } else {
      await _prefs!.setString(kOnboardingStepKey, step.id);
    }
  }

  Future<void> setDeviceOnboarded() async {
    await load();
    await _prefs!.setBool(kOnboardingCompleteKey, true);
  }
}

/// Whether an [OnboardingFlow] is on screen. While it is, the router leaves
/// the entry routes alone after a sign-in, because the flow itself decides
/// whether the account is new or set up (Konzept 17 §3.5, Inventar Bug 8).
abstract final class OnboardingFlowPresence {
  static int _mounted = 0;

  static bool get active => _mounted > 0;

  static void enter() => _mounted++;

  static void leave() {
    if (_mounted > 0) _mounted--;
  }

  @visibleForTesting
  static void reset() => _mounted = 0;
}
