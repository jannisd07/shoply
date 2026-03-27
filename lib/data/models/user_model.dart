import 'package:equatable/equatable.dart';

class UserModel extends Equatable {
  final String id;
  final String email;
  final String? displayName;
  final String? avatarUrl;
  final String? authProvider;
  final int? age;
  final double? height;
  final String? heightUnit; // 'cm' or 'ft'
  final String? gender; // 'male', 'female', 'other', 'prefer_not_to_say'
  final List<String> dietPreferences; // z.B. ['vegan', 'vegetarian', 'keto']
  final List<String> allergies; // z.B. ['gluten', 'lactose', 'nuts']
  final bool notificationEnabled;
  final String language;
  final String theme;
  final String? fcmToken;
  final bool onboardingCompleted;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? lastLogin;

  const UserModel({
    required this.id,
    required this.email,
    this.displayName,
    this.avatarUrl,
    this.authProvider,
    this.age,
    this.height,
    this.heightUnit,
    this.gender,
    this.dietPreferences = const [],
    this.allergies = const [],
    this.notificationEnabled = true,
    this.language = 'de',
    this.theme = 'light',
    this.fcmToken,
    this.onboardingCompleted = false,
    required this.createdAt,
    required this.updatedAt,
    this.lastLogin,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as String,
      email: json['email'] as String,
      displayName: json['display_name'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      authProvider: json['auth_provider'] as String?,
      age: json['age'] as int?,
      height: json['height'] != null 
          ? (json['height'] as num).toDouble() 
          : null,
      heightUnit: json['height_unit'] as String?,
      gender: json['gender'] as String?,
      dietPreferences: json['diet_preferences'] != null
          ? List<String>.from(json['diet_preferences'] as List)
          : [],
      allergies: json['allergies'] != null
          ? List<String>.from(json['allergies'] as List)
          : [],
      notificationEnabled: json['notification_enabled'] as bool? ?? true,
      language: json['language'] as String? ?? 'de',
      theme: json['theme'] as String? ?? 'light',
      fcmToken: json['fcm_token'] as String?,
      onboardingCompleted: json['onboarding_completed'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      lastLogin: json['last_login'] != null
          ? DateTime.parse(json['last_login'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'display_name': displayName,
      'avatar_url': avatarUrl,
      'auth_provider': authProvider,
      'age': age,
      'height': height,
      'height_unit': heightUnit,
      'gender': gender,
      'diet_preferences': dietPreferences,
      'allergies': allergies,
      'notification_enabled': notificationEnabled,
      'language': language,
      'theme': theme,
      'fcm_token': fcmToken,
      'onboarding_completed': onboardingCompleted,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'last_login': lastLogin?.toIso8601String(),
    };
  }

  UserModel copyWith({
    String? id,
    String? email,
    String? displayName,
    String? avatarUrl,
    String? authProvider,
    int? age,
    double? height,
    String? heightUnit,
    String? gender,
    List<String>? dietPreferences,
    List<String>? allergies,
    bool? notificationEnabled,
    String? language,
    String? theme,
    String? fcmToken,
    bool? onboardingCompleted,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? lastLogin,
  }) {
    return UserModel(
      id: id ?? this.id,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      authProvider: authProvider ?? this.authProvider,
      age: age ?? this.age,
      height: height ?? this.height,
      heightUnit: heightUnit ?? this.heightUnit,
      gender: gender ?? this.gender,
      dietPreferences: dietPreferences ?? this.dietPreferences,
      allergies: allergies ?? this.allergies,
      notificationEnabled: notificationEnabled ?? this.notificationEnabled,
      language: language ?? this.language,
      theme: theme ?? this.theme,
      fcmToken: fcmToken ?? this.fcmToken,
      onboardingCompleted: onboardingCompleted ?? this.onboardingCompleted,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      lastLogin: lastLogin ?? this.lastLogin,
    );
  }

  @override
  List<Object?> get props => [
        id,
        email,
        displayName,
        avatarUrl,
        authProvider,
        age,
        height,
        heightUnit,
        gender,
        dietPreferences,
        allergies,
        notificationEnabled,
        language,
        theme,
        fcmToken,
        onboardingCompleted,
        createdAt,
        updatedAt,
        lastLogin,
      ];
}
