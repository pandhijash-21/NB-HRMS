import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/location_alert_sound.dart';
import '../../auth/presentation/auth_providers.dart';
import 'widgets/location_availability_widgets.dart';

bool canAccessFieldTracking(String? role) {
  final r = (role ?? '').toUpperCase().replaceAll(RegExp(r'[\s_]'), '');
  return const {
    'ADMIN',
    'HR',
    'SUPERADMIN',
    'SYSTEMADMIN',
    'DEVELOPER',
  }.contains(r);
}

class LocationAlertWatchState {
  const LocationAlertWatchState({
    this.alerts = const [],
    this.count = 0,
  });

  final List<dynamic> alerts;
  final int count;
}

class LocationAlertWatch extends Notifier<LocationAlertWatchState> {
  Timer? _timer;
  final Set<String> _seenIds = {};
  bool _primed = false;

  @override
  LocationAlertWatchState build() {
    ref.onDispose(() {
      _timer?.cancel();
      _timer = null;
    });

    final authenticated = ref.watch(
      authNotifierProvider.select((s) => s.isAuthenticated),
    );
    final role = ref.watch(
      authNotifierProvider.select((s) => s.user?.role),
    );
    _timer?.cancel();
    _timer = null;

    if (!authenticated || !canAccessFieldTracking(role)) {
      _primed = false;
      _seenIds.clear();
      return const LocationAlertWatchState();
    }

    _timer = Timer.periodic(const Duration(seconds: 8), (_) {
      unawaited(_refresh());
    });
    Future.microtask(_refresh);
    return const LocationAlertWatchState();
  }

  Future<void> refresh() => _refresh();

  Future<void> _refresh() async {
    try {
      final dio = ref.read(dioClientProvider);
      final raw = await dio.getEnvelope<List<dynamic>>(
        'tracking/alerts',
        parse: (r) => r as List<dynamic>,
      );
      if (!ref.mounted) return;
      final active = activeLocationAlerts(raw);
      final currentIds = <String>{};
      for (final a in active) {
        final id = a['id']?.toString();
        if (id != null && id.isNotEmpty) currentIds.add(id);
      }

      if (!_primed) {
        _seenIds
          ..clear()
          ..addAll(currentIds);
        _primed = true;
        state = LocationAlertWatchState(alerts: active, count: active.length);
        return;
      }

      final isNew = currentIds.difference(_seenIds);
      _seenIds.addAll(currentIds);
      if (_seenIds.length > 200) {
        _seenIds.removeWhere((id) => !currentIds.contains(id));
      }

      state = LocationAlertWatchState(alerts: active, count: active.length);
      if (isNew.isNotEmpty) {
        unawaited(LocationAlertSound.play());
      }
    } catch (_) {
      if (!ref.mounted) return;
      state = const LocationAlertWatchState();
    }
  }
}

final locationAlertWatchProvider =
    NotifierProvider<LocationAlertWatch, LocationAlertWatchState>(
      LocationAlertWatch.new,
    );
