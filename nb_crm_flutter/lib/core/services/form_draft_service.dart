import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FormDraftInfo {
  final String formId;
  final String? entityId;
  final DateTime savedAt;
  final Map<String, dynamic> data;

  const FormDraftInfo({
    required this.formId,
    this.entityId,
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

/// Central service for realtime form auto-saving and draft restoration across all forms
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

  /// Automatically creates or updates draft data in real-time (debounced ~350ms)
  void autoSave({
    required String formId,
    required Map<String, dynamic> data,
    String? entityId,
    Duration debounce = const Duration(milliseconds: 350),
    VoidCallback? onSaved,
  }) {
    final key = _buildKey(formId, entityId: entityId);
    _debounceTimers[key]?.cancel();

    // Check if there is actual user-entered content
    final hasContent = data.values.any((v) {
      if (v == null) return false;
      if (v is String) return v.trim().isNotEmpty && v != '0' && v != '0.00';
      if (v is Iterable) return v.isNotEmpty;
      if (v is Map) return v.isNotEmpty;
      return true;
    });

    if (!hasContent) {
      unawaited(clearDraft(formId, entityId: entityId));
      return;
    }

    _debounceTimers[key] = Timer(debounce, () async {
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
    });
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
}
