import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FormDraftInfo {
  final String formId;
  final String? entityId;
  final String? draftId;
  final DateTime savedAt;
  final Map<String, dynamic> data;

  const FormDraftInfo({
    required this.formId,
    this.entityId,
    this.draftId,
    required this.savedAt,
    required this.data,
  });

  String get formattedTime {
    final now = DateTime.now();
    if (savedAt.year == now.year && savedAt.month == now.month && savedAt.day == now.day) {
      return 'Today at ${DateFormat('hh:mm a').format(savedAt)}';
    }
    return DateFormat('d MMM, hh:mm a').format(savedAt);
  }
}

class MultiDraftSummary {
  final String draftId;
  final String title;
  final String? subtitle;
  final DateTime savedAt;
  final Map<String, dynamic> data;

  const MultiDraftSummary({
    required this.draftId,
    required this.title,
    this.subtitle,
    required this.savedAt,
    this.data = const {},
  });

  String get formattedTime {
    final now = DateTime.now();
    if (savedAt.year == now.year && savedAt.month == now.month && savedAt.day == now.day) {
      return 'Today at ${DateFormat('hh:mm a').format(savedAt)}';
    }
    return DateFormat('d MMM, hh:mm a').format(savedAt);
  }

  Map<String, dynamic> toIndexJson() => {
        'draftId': draftId,
        'title': title,
        'subtitle': subtitle,
        'savedAt': savedAt.toIso8601String(),
      };

  factory MultiDraftSummary.fromIndexJson(
    Map<String, dynamic> json, [
    Map<String, dynamic>? fullData,
  ]) {
    return MultiDraftSummary(
      draftId: json['draftId']?.toString() ?? '',
      title: json['title']?.toString() ?? 'Draft',
      subtitle: json['subtitle']?.toString(),
      savedAt: DateTime.tryParse(json['savedAt']?.toString() ?? '') ?? DateTime.now(),
      data: fullData ?? const {},
    );
  }
}

/// Central service for realtime form auto-saving, multi-draft management,
/// and instant draft restoration across all CRM, ERP, and HRMS forms.
class FormDraftService {
  static final FormDraftService instance = FormDraftService._();
  FormDraftService._();

  static const String _prefix = 'nb_form_draft_';
  final Map<String, Timer> _debounceTimers = {};
  final _draftUpdates = StreamController<String>.broadcast();

  Stream<String> get onDraftChanged => _draftUpdates.stream;

  String _buildKey(String formId, {String? entityId}) {
    final ePart = (entityId != null && entityId.isNotEmpty) ? '_$entityId' : '_new';
    return '$_prefix$formId$ePart';
  }

  String _buildMultiKey(String formId, String draftId) {
    return '$_prefix${formId}_md_$draftId';
  }

  String _buildMultiIndexKey(String formId) {
    return '$_prefix${formId}_md_index';
  }

  String _buildMultiActiveKey(String formId) {
    return '$_prefix${formId}_md_active';
  }

  /// Determines if a payload contains meaningful user input (not just defaults)
  bool hasMeaningfulContent(Map<String, dynamic> data) {
    return data.entries.any((entry) {
      final k = entry.key;
      // Skip pure metadata
      if (k == 'formId' || k == 'savedAt' || k == 'draftId') return false;
      final v = entry.value;
      if (v == null) return false;
      if (v is String) {
        final t = v.trim();
        return t.isNotEmpty && t != '0' && t != '0.00';
      }
      if (v is Iterable) return v.isNotEmpty;
      if (v is Map) return v.isNotEmpty;
      if (v is bool) return true;
      if (v is num) return v != 0;
      return true;
    });
  }

  /// Automatically creates or updates draft data in real-time.
  /// If [immediate] is true, executes without debounce (ideal for onPop / leave midway / dispose).
  void autoSave({
    required String formId,
    required Map<String, dynamic> data,
    String? entityId,
    Duration debounce = const Duration(milliseconds: 350),
    bool immediate = false,
    VoidCallback? onSaved,
  }) {
    final key = _buildKey(formId, entityId: entityId);
    _debounceTimers[key]?.cancel();

    if (!hasMeaningfulContent(data)) {
      unawaited(clearDraft(formId, entityId: entityId));
      return;
    }

    Future<void> executeWrite() async {
      try {
        final prefs = await SharedPreferences.getInstance();
        final payload = {
          'formId': formId,
          'entityId': entityId,
          'savedAt': DateTime.now().toIso8601String(),
          'data': data,
        };
        await prefs.setString(key, jsonEncode(payload));
        _draftUpdates.add(key);
        onSaved?.call();
      } catch (e) {
        debugPrint('[FormDraftService] Failed to auto-save draft ($key): $e');
      }
    }

    if (immediate) {
      unawaited(executeWrite());
    } else {
      _debounceTimers[key] = Timer(debounce, executeWrite);
    }
  }

  /// Save immediately without debounce (use on back button / route pop / app leave).
  Future<void> saveNow({
    required String formId,
    required Map<String, dynamic> data,
    String? entityId,
  }) async {
    final key = _buildKey(formId, entityId: entityId);
    _debounceTimers[key]?.cancel();
    if (!hasMeaningfulContent(data)) {
      await clearDraft(formId, entityId: entityId);
      return;
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      final payload = {
        'formId': formId,
        'entityId': entityId,
        'savedAt': DateTime.now().toIso8601String(),
        'data': data,
      };
      await prefs.setString(key, jsonEncode(payload));
      _draftUpdates.add(key);
    } catch (e) {
      debugPrint('[FormDraftService] Failed to saveNow ($key): $e');
    }
  }

  /// Immediately load saved draft data
  Future<Map<String, dynamic>?> loadDraft({
    required String formId,
    String? entityId,
  }) async {
    final info = await loadDraftInfo(formId, entityId: entityId);
    return info?.data;
  }

  /// Load draft with timestamp & metadata
  Future<FormDraftInfo?> loadDraftInfo(
    String formId, {
    String? entityId,
  }) async {
    try {
      final key = _buildKey(formId, entityId: entityId);
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(key);
      if (raw == null || raw.isEmpty) return null;
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      final data = decoded['data'] as Map<String, dynamic>?;
      if (data == null || data.isEmpty) return null;
      final savedAt = DateTime.tryParse(decoded['savedAt']?.toString() ?? '') ?? DateTime.now();
      return FormDraftInfo(
        formId: formId,
        entityId: entityId,
        savedAt: savedAt,
        data: data,
      );
    } catch (e) {
      debugPrint('[FormDraftService] Failed to load draft info ($formId): $e');
      return null;
    }
  }

  /// Delete draft once form is submitted or discarded
  Future<void> clearDraft(String formId, {String? entityId}) async {
    final key = _buildKey(formId, entityId: entityId);
    try {
      _debounceTimers[key]?.cancel();
      _debounceTimers.remove(key);
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(key);
      _draftUpdates.add(key);
    } catch (e) {
      debugPrint('[FormDraftService] Failed to clear draft ($key): $e');
    }
  }

  /// Check if a draft exists
  Future<bool> hasDraft(String formId, {String? entityId}) async {
    final info = await loadDraftInfo(formId, entityId: entityId);
    return info != null;
  }

  // ==========================================
  // MULTI-DRAFT SUPPORT (e.g. For DPR & Complex Forms)
  // ==========================================

  /// Save or auto-save a specific draft inside a multi-draft collection
  void autoSaveMultiDraft({
    required String formId,
    required String draftId,
    required String title,
    String? subtitle,
    required Map<String, dynamic> data,
    Duration debounce = const Duration(milliseconds: 350),
    bool immediate = false,
    VoidCallback? onSaved,
  }) {
    final key = _buildMultiKey(formId, draftId);
    _debounceTimers[key]?.cancel();

    if (!hasMeaningfulContent(data)) {
      // Do not delete existing draft automatically on transient empty field,
      // but if immediate save requested on truly blank draft, keep or clear.
      return;
    }

    Future<void> executeWrite() async {
      try {
        final prefs = await SharedPreferences.getInstance();
        final now = DateTime.now();
        final payload = {
          'formId': formId,
          'draftId': draftId,
          'title': title,
          'subtitle': subtitle,
          'savedAt': now.toIso8601String(),
          'data': data,
        };
        await prefs.setString(key, jsonEncode(payload));

        // Update multi-draft index list
        final indexKey = _buildMultiIndexKey(formId);
        final rawIndex = prefs.getString(indexKey);
        List<dynamic> indexList = [];
        if (rawIndex != null && rawIndex.isNotEmpty) {
          try {
            indexList = jsonDecode(rawIndex) as List<dynamic>;
          } catch (_) {}
        }
        // Remove existing entry if present
        indexList.removeWhere((item) => (item is Map) && item['draftId'] == draftId);
        // Insert at beginning (most recently edited)
        indexList.insert(0, {
          'draftId': draftId,
          'title': title,
          'subtitle': subtitle,
          'savedAt': now.toIso8601String(),
        });
        await prefs.setString(indexKey, jsonEncode(indexList));

        // Mark as current active draft
        await prefs.setString(_buildMultiActiveKey(formId), draftId);

        _draftUpdates.add(key);
        onSaved?.call();
      } catch (e) {
        debugPrint('[FormDraftService] Failed to autoSaveMultiDraft ($key): $e');
      }
    }

    if (immediate) {
      unawaited(executeWrite());
    } else {
      _debounceTimers[key] = Timer(debounce, executeWrite);
    }
  }

  /// Synchronous/immediate save for multi-draft (e.g. on leave midway / pop)
  Future<void> saveMultiDraftNow({
    required String formId,
    required String draftId,
    required String title,
    String? subtitle,
    required Map<String, dynamic> data,
  }) async {
    autoSaveMultiDraft(
      formId: formId,
      draftId: draftId,
      title: title,
      subtitle: subtitle,
      data: data,
      immediate: true,
    );
  }

  /// Load a specific multi-draft by ID
  Future<FormDraftInfo?> loadMultiDraft(String formId, String draftId) async {
    try {
      final key = _buildMultiKey(formId, draftId);
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(key);
      if (raw == null || raw.isEmpty) return null;
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      final data = decoded['data'] as Map<String, dynamic>?;
      if (data == null || data.isEmpty) return null;
      final savedAt = DateTime.tryParse(decoded['savedAt']?.toString() ?? '') ?? DateTime.now();
      return FormDraftInfo(
        formId: formId,
        draftId: draftId,
        savedAt: savedAt,
        data: data,
      );
    } catch (e) {
      debugPrint('[FormDraftService] Failed to loadMultiDraft ($formId, $draftId): $e');
      return null;
    }
  }

  /// List all saved drafts for a given form (ordered by most recently saved)
  Future<List<MultiDraftSummary>> listMultiDrafts(String formId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final indexKey = _buildMultiIndexKey(formId);
      final rawIndex = prefs.getString(indexKey);
      if (rawIndex == null || rawIndex.isEmpty) {
        // Fallback: check if legacy single draft exists and migrate it!
        final singleDraft = await loadDraftInfo(formId);
        if (singleDraft != null) {
          final id = 'legacy_${singleDraft.savedAt.millisecondsSinceEpoch}';
          final summary = MultiDraftSummary(
            draftId: id,
            title: 'Saved Draft',
            subtitle: singleDraft.formattedTime,
            savedAt: singleDraft.savedAt,
            data: singleDraft.data,
          );
          await saveMultiDraftNow(
            formId: formId,
            draftId: id,
            title: summary.title,
            subtitle: summary.subtitle,
            data: singleDraft.data,
          );
          await clearDraft(formId);
          return [summary];
        }
        return [];
      }

      final list = jsonDecode(rawIndex) as List<dynamic>;
      final result = <MultiDraftSummary>[];
      for (final item in list) {
        if (item is Map<String, dynamic>) {
          final draftId = item['draftId']?.toString();
          if (draftId != null && draftId.isNotEmpty) {
            // Verify draft payload exists
            final payloadRaw = prefs.getString(_buildMultiKey(formId, draftId));
            Map<String, dynamic>? fullData;
            if (payloadRaw != null && payloadRaw.isNotEmpty) {
              try {
                final dec = jsonDecode(payloadRaw) as Map<String, dynamic>;
                fullData = dec['data'] as Map<String, dynamic>?;
              } catch (_) {}
            }
            if (fullData != null && fullData.isNotEmpty) {
              result.add(MultiDraftSummary.fromIndexJson(item, fullData));
            }
          }
        }
      }
      return result;
    } catch (e) {
      debugPrint('[FormDraftService] Failed to listMultiDrafts ($formId): $e');
      return [];
    }
  }

  /// Delete a specific multi-draft by ID
  Future<void> deleteMultiDraft(String formId, String draftId) async {
    try {
      final key = _buildMultiKey(formId, draftId);
      _debounceTimers[key]?.cancel();
      _debounceTimers.remove(key);
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(key);

      // Remove from index
      final indexKey = _buildMultiIndexKey(formId);
      final rawIndex = prefs.getString(indexKey);
      if (rawIndex != null && rawIndex.isNotEmpty) {
        final list = jsonDecode(rawIndex) as List<dynamic>;
        list.removeWhere((item) => (item is Map) && item['draftId'] == draftId);
        await prefs.setString(indexKey, jsonEncode(list));
      }

      // If this was active draft, clear active
      final activeKey = _buildMultiActiveKey(formId);
      final active = prefs.getString(activeKey);
      if (active == draftId) {
        await prefs.remove(activeKey);
      }

      _draftUpdates.add(key);
    } catch (e) {
      debugPrint('[FormDraftService] Failed to deleteMultiDraft ($formId, $draftId): $e');
    }
  }

  /// Gets the currently active draft ID if any
  Future<String?> getActiveMultiDraftId(String formId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_buildMultiActiveKey(formId));
    } catch (_) {
      return null;
    }
  }

  /// Sets the currently active draft ID
  Future<void> setActiveMultiDraftId(String formId, String? draftId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = _buildMultiActiveKey(formId);
      if (draftId == null) {
        await prefs.remove(key);
      } else {
        await prefs.setString(key, draftId);
      }
    } catch (_) {}
  }

  /// Clears active draft ID and deletes that specific multi-draft (call on successful submit)
  Future<void> clearSubmittedMultiDraft(String formId, String? draftId) async {
    if (draftId != null && draftId.isNotEmpty) {
      await deleteMultiDraft(formId, draftId);
    }
    await setActiveMultiDraftId(formId, null);
  }
}
