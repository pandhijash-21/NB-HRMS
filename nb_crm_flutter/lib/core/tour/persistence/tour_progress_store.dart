import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/tour_models.dart';

class TourProgressStore {
  TourProgressStore._();
  static final TourProgressStore instance = TourProgressStore._();

  static const _onboardingKey = 'software_tour_onboarding_seen';

  String _progressKey(String userId) => 'software_tour_progress_$userId';
  String _resumeKey(String userId) => 'software_tour_resume_$userId';

  Future<bool> hasSeenOnboarding(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('${_onboardingKey}_$userId') ?? false;
  }

  Future<void> markOnboardingSeen(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('${_onboardingKey}_$userId', true);
  }

  Future<Map<String, String>> loadStatuses(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_progressKey(userId));
    if (raw == null || raw.isEmpty) return {};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        return decoded.map((k, v) => MapEntry(k.toString(), v.toString()));
      }
    } catch (_) {}
    return {};
  }

  Future<void> setSectionStatus({
    required String userId,
    required String sectionId,
    required TourProgressStatus status,
  }) async {
    final current = await loadStatuses(userId);
    current[sectionId] = status.name;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_progressKey(userId), jsonEncode(current));
  }

  Future<void> saveResume({
    required String userId,
    required TourMode mode,
    required List<String> sectionIds,
    required int stepIndex,
    required String? currentSectionId,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _resumeKey(userId),
      jsonEncode({
        'mode': mode.name,
        'sectionIds': sectionIds,
        'stepIndex': stepIndex,
        'currentSectionId': currentSectionId,
      }),
    );
  }

  Future<Map<String, dynamic>?> loadResume(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_resumeKey(userId));
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    } catch (_) {}
    return null;
  }

  Future<void> clearResume(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_resumeKey(userId));
  }

  String _knownKey(String userId) => 'software_tour_known_sections_$userId';

  Future<Set<String>> loadKnownSections(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_knownKey(userId));
    if (raw == null || raw.isEmpty) return {};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded.map((e) => e.toString()).toSet();
      }
    } catch (_) {}
    return {};
  }

  Future<void> saveKnownSections(String userId, Iterable<String> sectionIds) async {
    final prefs = await SharedPreferences.getInstance();
    final ids = sectionIds.toSet().toList()..sort();
    await prefs.setString(_knownKey(userId), jsonEncode(ids));
  }
}
