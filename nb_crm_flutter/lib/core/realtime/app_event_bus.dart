import 'dart:async';

/// Base class for all real-time application events.
abstract class AppRealtimeEvent {
  const AppRealtimeEvent();
}

/// Real-time event for CRM lead creations, allocations, updates, transfers, or deletions.
class CrmLeadRealtimeEvent extends AppRealtimeEvent {
  const CrmLeadRealtimeEvent({
    required this.leadId,
    this.action,
    this.data,
  });

  final String leadId;
  final String? action;
  final Map<String, dynamic>? data;

  @override
  String toString() => 'CrmLeadRealtimeEvent(leadId: $leadId, action: $action)';
}

/// Real-time event for CRM unit inventory status updates (Available, Booked, Blocked).
class CrmUnitRealtimeEvent extends AppRealtimeEvent {
  const CrmUnitRealtimeEvent({
    required this.unitId,
    required this.projectId,
    required this.status,
    this.data,
  });

  final String unitId;
  final String projectId;
  final String status;
  final Map<String, dynamic>? data;

  @override
  String toString() =>
      'CrmUnitRealtimeEvent(unitId: $unitId, projectId: $projectId, status: $status)';
}

/// Real-time event for ERP modules (Purchase, DPR, Work Orders, BOQ, Inventory, Projects).
class ErpRealtimeEvent extends AppRealtimeEvent {
  const ErpRealtimeEvent({
    required this.module,
    this.entityId,
    this.action,
    this.data,
  });

  final String module;
  final String? entityId;
  final String? action;
  final Map<String, dynamic>? data;

  @override
  String toString() =>
      'ErpRealtimeEvent(module: $module, entityId: $entityId, action: $action)';
}

/// Global event bus for real-time reactivity without manual reloads.
class AppEventBus {
  AppEventBus._();
  static final AppEventBus instance = AppEventBus._();

  final StreamController<AppRealtimeEvent> _streamController =
      StreamController<AppRealtimeEvent>.broadcast();

  /// Listen to events of type [T].
  Stream<T> on<T extends AppRealtimeEvent>() {
    return _streamController.stream.where((event) => event is T).cast<T>();
  }

  /// Fire an event into the bus.
  void fire(AppRealtimeEvent event) {
    if (!_streamController.isClosed) {
      _streamController.add(event);
    }
  }

  /// Helper to fire a CRM lead mutation event.
  void fireCrmLeadMutated(String leadId, {String? action, Map<String, dynamic>? data}) {
    fire(CrmLeadRealtimeEvent(leadId: leadId, action: action, data: data));
  }

  /// Helper to fire a CRM unit status update event.
  void fireCrmUnitStatusChanged({
    required String unitId,
    required String projectId,
    required String status,
    Map<String, dynamic>? data,
  }) {
    fire(CrmUnitRealtimeEvent(
      unitId: unitId,
      projectId: projectId,
      status: status,
      data: data,
    ));
  }

  /// Helper to fire an ERP mutation event.
  void fireErpMutated({
    required String module,
    String? entityId,
    String? action,
    Map<String, dynamic>? data,
  }) {
    fire(ErpRealtimeEvent(
      module: module,
      entityId: entityId,
      action: action,
      data: data,
    ));
  }
}
