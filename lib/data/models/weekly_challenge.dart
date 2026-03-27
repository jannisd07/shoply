import 'package:equatable/equatable.dart';

/// Weekly cooking challenge
class WeeklyChallenge extends Equatable {
  final String id;
  final String title;
  final String? titleDE;
  final String description;
  final String? descriptionDE;
  final String? imageUrl;
  final DateTime startDate;
  final DateTime endDate;
  final String? prizeDescription;
  final String? prizeDescriptionDE;
  final String? hashtag;
  final bool isActive;
  final int entryCount;

  const WeeklyChallenge({
    required this.id,
    required this.title,
    this.titleDE,
    required this.description,
    this.descriptionDE,
    this.imageUrl,
    required this.startDate,
    required this.endDate,
    this.prizeDescription,
    this.prizeDescriptionDE,
    this.hashtag,
    this.isActive = true,
    this.entryCount = 0,
  });

  /// Get localized title based on language code
  String getLocalizedTitle(String languageCode) {
    if (languageCode == 'de' && titleDE != null) {
      return titleDE!;
    }
    return title;
  }

  /// Get localized description
  String getLocalizedDescription(String languageCode) {
    if (languageCode == 'de' && descriptionDE != null) {
      return descriptionDE!;
    }
    return description;
  }

  /// Check if challenge is currently active
  bool get isCurrentlyActive {
    final now = DateTime.now();
    return isActive && now.isAfter(startDate) && now.isBefore(endDate.add(const Duration(days: 1)));
  }

  /// Days remaining in challenge
  int get daysRemaining {
    final now = DateTime.now();
    return endDate.difference(now).inDays;
  }

  factory WeeklyChallenge.fromJson(Map<String, dynamic> json) {
    return WeeklyChallenge(
      id: json['id'] as String,
      title: json['title'] as String,
      titleDE: json['title_de'] as String?,
      description: json['description'] as String,
      descriptionDE: json['description_de'] as String?,
      imageUrl: json['image_url'] as String?,
      startDate: DateTime.parse(json['start_date'] as String),
      endDate: DateTime.parse(json['end_date'] as String),
      prizeDescription: json['prize_description'] as String?,
      prizeDescriptionDE: json['prize_description_de'] as String?,
      hashtag: json['hashtag'] as String?,
      isActive: json['is_active'] as bool? ?? true,
      entryCount: json['entry_count'] as int? ?? 0,
    );
  }

  @override
  List<Object?> get props => [id, title, startDate, endDate, isActive];
}

/// An entry submitted to a weekly challenge
class ChallengeEntry extends Equatable {
  final String id;
  final String challengeId;
  final String oderId;
  final String recipeId;
  final String? photoUrl;
  final String? notes;
  final DateTime createdAt;

  const ChallengeEntry({
    required this.id,
    required this.challengeId,
    required this.oderId,
    required this.recipeId,
    this.photoUrl,
    this.notes,
    required this.createdAt,
  });

  factory ChallengeEntry.fromJson(Map<String, dynamic> json) {
    return ChallengeEntry(
      id: json['id'] as String,
      challengeId: json['challenge_id'] as String,
      oderId: json['user_id'] as String,
      recipeId: json['recipe_id'] as String,
      photoUrl: json['photo_url'] as String?,
      notes: json['notes'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  @override
  List<Object?> get props => [id, challengeId, oderId, recipeId];
}
