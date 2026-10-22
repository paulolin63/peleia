import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../config/app_config.dart';

class UserProfile {
  static const maxNoteChars = 280;
  static const storageKey = 'user_profile_v1';

  final String? ageGroup;
  final String? outdoorExposure;
  final String? declaredSkinType;
  final String? acne;
  final String? spfHabit;
  final List<String> avoidIngredients;
  final List<String> conditions;
  final String note;

  const UserProfile({
    this.ageGroup,
    this.outdoorExposure,
    this.declaredSkinType,
    this.acne,
    this.spfHabit,
    this.avoidIngredients = const [],
    this.conditions = const [],
    this.note = '',
  });

  UserProfile copyWith({
    String? ageGroup,
    String? outdoorExposure,
    String? declaredSkinType,
    String? acne,
    String? spfHabit,
    List<String>? avoidIngredients,
    List<String>? conditions,
    String? note,
  }) {
    return UserProfile(
      ageGroup: ageGroup ?? this.ageGroup,
      outdoorExposure: outdoorExposure ?? this.outdoorExposure,
      declaredSkinType: declaredSkinType ?? this.declaredSkinType,
      acne: acne ?? this.acne,
      spfHabit: spfHabit ?? this.spfHabit,
      avoidIngredients: avoidIngredients ?? this.avoidIngredients,
      conditions: conditions ?? this.conditions,
      note: note ?? this.note,
    );
  }

  Map<String, dynamic> toJson() => {
        'age_group': ageGroup,
        'outdoor_exposure': outdoorExposure,
        'declared_skin_type': declaredSkinType,
        'acne': acne,
        'spf_habit': spfHabit,
        'avoid_ingredients': avoidIngredients,
        'conditions': conditions,
        'note': note,
      };

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    final note = (json['note'] as String? ?? '').trim();
    return UserProfile(
      ageGroup: json['age_group'] as String?,
      outdoorExposure: json['outdoor_exposure'] as String?,
      declaredSkinType: json['declared_skin_type'] as String?,
      acne: json['acne'] as String?,
      spfHabit: json['spf_habit'] as String?,
      avoidIngredients: _strings(json['avoid_ingredients']),
      conditions: _strings(json['conditions']),
      note: note.length > maxNoteChars ? note.substring(0, maxNoteChars) : note,
    );
  }

  /// Ids de ingredientes bloqueados, incluindo os que a condição declara (ex.: gestante).
  Set<String> avoidedIds(AppConfig config) {
    final ids = avoidIngredients.toSet();
    for (final condition in config.conditions) {
      if (conditions.contains(condition.id)) ids.addAll(condition.excludes);
    }
    return ids;
  }

  List<String> avoidedLabels(AppConfig config) {
    final ids = avoidedIds(config);
    return [
      for (final option in config.ingredients)
        if (ids.contains(option.id)) option.label,
    ];
  }
}

class UserProfileStore {
  static Future<UserProfile> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(UserProfile.storageKey);
    if (raw != null && raw.isNotEmpty) {
      try {
        return UserProfile.fromJson(jsonDecode(raw) as Map<String, dynamic>);
      } catch (_) {}
    }
    return UserProfile(
      ageGroup: prefs.getString('user_age_group'),
      outdoorExposure: prefs.getString('user_outdoor_exposure'),
      declaredSkinType: prefs.getString('user_skin_type_quiz'),
    );
  }

  static Future<void> save(UserProfile profile) async {
    final prefs = await SharedPreferences.getInstance();
    final note = profile.note.length > UserProfile.maxNoteChars
        ? profile.note.substring(0, UserProfile.maxNoteChars)
        : profile.note;
    final stored = profile.copyWith(note: note);
    await prefs.setString(UserProfile.storageKey, jsonEncode(stored.toJson()));
    if (stored.ageGroup != null) await prefs.setString('user_age_group', stored.ageGroup!);
    if (stored.outdoorExposure != null) {
      await prefs.setString('user_outdoor_exposure', stored.outdoorExposure!);
    }
    if (stored.declaredSkinType != null) {
      await prefs.setString('user_skin_type_quiz', stored.declaredSkinType!);
    }
  }
}

List<String> _strings(dynamic value) => value is List ? value.whereType<String>().toList() : const [];
