import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/bloc/load_status.dart';
import '../../data/work_order_repository.dart';
import '../../domain/work_order_models.dart';

// ---------------------------------------------------------------------------
// Events
// ---------------------------------------------------------------------------
abstract class ErpWorkOrdersEvent extends Equatable {
  const ErpWorkOrdersEvent();

  @override
  List<Object?> get props => [];
}

class ErpWorkOrdersListRequested extends ErpWorkOrdersEvent {
  const ErpWorkOrdersListRequested();
}

class ErpWorkOrderDetailRequested extends ErpWorkOrdersEvent {
  const ErpWorkOrderDetailRequested(this.id);
  final String id;

  @override
  List<Object?> get props => [id];
}

class ErpWorkOrderCreated extends ErpWorkOrdersEvent {
  const ErpWorkOrderCreated(this.body);
  final Map<String, dynamic> body;

  @override
  List<Object?> get props => [body];
}

class ErpWorkOrderUpdated extends ErpWorkOrdersEvent {
  const ErpWorkOrderUpdated({required this.id, required this.body});
  final String id;
  final Map<String, dynamic> body;

  @override
  List<Object?> get props => [id, body];
}

class ErpWorkOrderStatusUpdated extends ErpWorkOrdersEvent {
  const ErpWorkOrderStatusUpdated({required this.id, required this.status});
  final String id;
  final String status;

  @override
  List<Object?> get props => [id, status];
}

class ErpWorkOrderApprovalUpdated extends ErpWorkOrdersEvent {
  const ErpWorkOrderApprovalUpdated({required this.id, required this.approvalStatus});
  final String id;
  final String approvalStatus;

  @override
  List<Object?> get props => [id, approvalStatus];
}

class ErpWorkOrderDeleted extends ErpWorkOrdersEvent {
  const ErpWorkOrderDeleted(this.id);
  final String id;

  @override
  List<Object?> get props => [id];
}

class ErpActivitiesRequested extends ErpWorkOrdersEvent {
  const ErpActivitiesRequested({this.includeInactive = false, this.isAdmin = false});
  final bool includeInactive;
  final bool isAdmin;

  @override
  List<Object?> get props => [includeInactive, isAdmin];
}

class ErpActivityCreated extends ErpWorkOrdersEvent {
  const ErpActivityCreated(this.body);
  final Map<String, dynamic> body;

  @override
  List<Object?> get props => [body];
}

class ErpActivityUpdated extends ErpWorkOrdersEvent {
  const ErpActivityUpdated({required this.id, required this.body});
  final String id;
  final Map<String, dynamic> body;

  @override
  List<Object?> get props => [id, body];
}

class ErpActivityToggled extends ErpWorkOrdersEvent {
  const ErpActivityToggled(this.id);
  final String id;

  @override
  List<Object?> get props => [id];
}

class ErpActivityDeleted extends ErpWorkOrdersEvent {
  const ErpActivityDeleted(this.id);
  final String id;

  @override
  List<Object?> get props => [id];
}

class ErpContractorsRequested extends ErpWorkOrdersEvent {
  const ErpContractorsRequested({this.includeInactive = false});
  final bool includeInactive;

  @override
  List<Object?> get props => [includeInactive];
}

class ErpContractorDetailRequested extends ErpWorkOrdersEvent {
  const ErpContractorDetailRequested(this.id);
  final String id;

  @override
  List<Object?> get props => [id];
}

class ErpContractorCreated extends ErpWorkOrdersEvent {
  const ErpContractorCreated(this.body);
  final Map<String, dynamic> body;

  @override
  List<Object?> get props => [body];
}

class ErpContractorUpdated extends ErpWorkOrdersEvent {
  const ErpContractorUpdated({required this.id, required this.body});
  final String id;
  final Map<String, dynamic> body;

  @override
  List<Object?> get props => [id, body];
}

class ErpContractorToggled extends ErpWorkOrdersEvent {
  const ErpContractorToggled(this.id);
  final String id;

  @override
  List<Object?> get props => [id];
}

class ErpContractorDeleted extends ErpWorkOrdersEvent {
  const ErpContractorDeleted(this.id);
  final String id;

  @override
  List<Object?> get props => [id];
}

// ---------------------------------------------------------------------------
// State
// ---------------------------------------------------------------------------
class ErpWorkOrdersState extends Equatable {
  const ErpWorkOrdersState({
    this.status = LoadStatus.initial,
    this.workOrders = const [],
    this.selectedWorkOrder,
    this.activities = const [],
    this.contractors = const [],
    this.selectedContractor,
    this.isActing = false,
    this.errorMessage,
    this.actionMessage,
  });

  final LoadStatus status;
  final List<ErpWorkOrder> workOrders;
  final ErpWorkOrder? selectedWorkOrder;
  final List<ErpActivity> activities;
  final List<ErpContractor> contractors;
  final ErpContractor? selectedContractor;
  final bool isActing;
  final String? errorMessage;
  final String? actionMessage;

  ErpWorkOrdersState copyWith({
    LoadStatus? status,
    List<ErpWorkOrder>? workOrders,
    ErpWorkOrder? selectedWorkOrder,
    bool clearSelectedWorkOrder = false,
    List<ErpActivity>? activities,
    List<ErpContractor>? contractors,
    ErpContractor? selectedContractor,
    bool clearSelectedContractor = false,
    bool? isActing,
    String? errorMessage,
    String? actionMessage,
  }) {
    return ErpWorkOrdersState(
      status: status ?? this.status,
      workOrders: workOrders ?? this.workOrders,
      selectedWorkOrder: clearSelectedWorkOrder
          ? null
          : (selectedWorkOrder ?? this.selectedWorkOrder),
      activities: activities ?? this.activities,
      contractors: contractors ?? this.contractors,
      selectedContractor: clearSelectedContractor
          ? null
          : (selectedContractor ?? this.selectedContractor),
      isActing: isActing ?? this.isActing,
      errorMessage: errorMessage,
      actionMessage: actionMessage,
    );
  }

  @override
  List<Object?> get props => [
        status,
        workOrders,
        selectedWorkOrder,
        activities,
        contractors,
        selectedContractor,
        isActing,
        errorMessage,
        actionMessage,
      ];
}

// ---------------------------------------------------------------------------
// BLoC
// ---------------------------------------------------------------------------
class ErpWorkOrdersBloc extends Bloc<ErpWorkOrdersEvent, ErpWorkOrdersState> {
  ErpWorkOrdersBloc({required WorkOrderRepository workOrderRepository})
      : _workOrderRepository = workOrderRepository,
        super(const ErpWorkOrdersState()) {
    on<ErpWorkOrdersListRequested>(_onListRequested);
    on<ErpWorkOrderDetailRequested>(_onDetailRequested);
    on<ErpWorkOrderCreated>(_onCreated);
    on<ErpWorkOrderUpdated>(_onUpdated);
    on<ErpWorkOrderStatusUpdated>(_onStatusUpdated);
    on<ErpWorkOrderApprovalUpdated>(_onApprovalUpdated);
    on<ErpWorkOrderDeleted>(_onDeleted);
    on<ErpActivitiesRequested>(_onActivitiesRequested);
    on<ErpActivityCreated>(_onActivityCreated);
    on<ErpActivityUpdated>(_onActivityUpdated);
    on<ErpActivityToggled>(_onActivityToggled);
    on<ErpActivityDeleted>(_onActivityDeleted);
    on<ErpContractorsRequested>(_onContractorsRequested);
    on<ErpContractorDetailRequested>(_onContractorDetailRequested);
    on<ErpContractorCreated>(_onContractorCreated);
    on<ErpContractorUpdated>(_onContractorUpdated);
    on<ErpContractorToggled>(_onContractorToggled);
    on<ErpContractorDeleted>(_onContractorDeleted);
  }

  final WorkOrderRepository _workOrderRepository;

  Future<void> _onListRequested(
    ErpWorkOrdersListRequested event,
    Emitter<ErpWorkOrdersState> emit,
  ) async {
    emit(state.copyWith(status: LoadStatus.loading));
    try {
      final workOrders = await _workOrderRepository.list();
      emit(state.copyWith(status: LoadStatus.success, workOrders: workOrders));
    } catch (e) {
      emit(state.copyWith(status: LoadStatus.failure, errorMessage: e.toString()));
    }
  }

  Future<void> _onDetailRequested(
    ErpWorkOrderDetailRequested event,
    Emitter<ErpWorkOrdersState> emit,
  ) async {
    emit(state.copyWith(status: LoadStatus.loading));
    try {
      final wo = await _workOrderRepository.getById(event.id);
      emit(state.copyWith(status: LoadStatus.success, selectedWorkOrder: wo));
    } catch (e) {
      emit(state.copyWith(status: LoadStatus.failure, errorMessage: e.toString()));
    }
  }

  Future<void> _onCreated(
    ErpWorkOrderCreated event,
    Emitter<ErpWorkOrdersState> emit,
  ) async {
    emit(state.copyWith(isActing: true));
    try {
      final wo = await _workOrderRepository.create(event.body);
      final updated = [wo, ...state.workOrders];
      emit(state.copyWith(
        isActing: false,
        workOrders: updated,
        actionMessage: 'Work Order created successfully',
      ));
    } catch (e) {
      emit(state.copyWith(isActing: false, errorMessage: e.toString()));
    }
  }

  Future<void> _onUpdated(
    ErpWorkOrderUpdated event,
    Emitter<ErpWorkOrdersState> emit,
  ) async {
    emit(state.copyWith(isActing: true));
    try {
      final wo = await _workOrderRepository.update(event.id, event.body);
      final updated = state.workOrders.map((w) => w.id == wo.id ? wo : w).toList();
      emit(state.copyWith(
        isActing: false,
        workOrders: updated,
        selectedWorkOrder: wo,
        actionMessage: 'Work Order updated successfully',
      ));
    } catch (e) {
      emit(state.copyWith(isActing: false, errorMessage: e.toString()));
    }
  }

  Future<void> _onStatusUpdated(
    ErpWorkOrderStatusUpdated event,
    Emitter<ErpWorkOrdersState> emit,
  ) async {
    emit(state.copyWith(isActing: true));
    try {
      final wo = await _workOrderRepository.updateStatus(event.id, event.status);
      final updated = state.workOrders.map((w) => w.id == wo.id ? wo : w).toList();
      emit(state.copyWith(
        isActing: false,
        workOrders: updated,
        selectedWorkOrder: wo,
        actionMessage: 'Status updated to ${event.status}',
      ));
    } catch (e) {
      emit(state.copyWith(isActing: false, errorMessage: e.toString()));
    }
  }

  Future<void> _onApprovalUpdated(
    ErpWorkOrderApprovalUpdated event,
    Emitter<ErpWorkOrdersState> emit,
  ) async {
    emit(state.copyWith(isActing: true));
    try {
      final wo = await _workOrderRepository.updateApproval(event.id, event.approvalStatus);
      final updated = state.workOrders.map((w) => w.id == wo.id ? wo : w).toList();
      emit(state.copyWith(
        isActing: false,
        workOrders: updated,
        selectedWorkOrder: wo,
        actionMessage: 'Approval updated to ${event.approvalStatus}',
      ));
    } catch (e) {
      emit(state.copyWith(isActing: false, errorMessage: e.toString()));
    }
  }

  Future<void> _onDeleted(
    ErpWorkOrderDeleted event,
    Emitter<ErpWorkOrdersState> emit,
  ) async {
    emit(state.copyWith(isActing: true));
    try {
      await _workOrderRepository.remove(event.id);
      final updated = state.workOrders.where((w) => w.id != event.id).toList();
      emit(state.copyWith(
        isActing: false,
        workOrders: updated,
        actionMessage: 'Work Order deleted successfully',
      ));
    } catch (e) {
      emit(state.copyWith(isActing: false, errorMessage: e.toString()));
    }
  }

  Future<void> _onActivitiesRequested(
    ErpActivitiesRequested event,
    Emitter<ErpWorkOrdersState> emit,
  ) async {
    emit(state.copyWith(status: LoadStatus.loading));
    try {
      final activities = event.isAdmin
          ? await _workOrderRepository.listActivitiesAdmin()
          : await _workOrderRepository.listActivities(includeInactive: event.includeInactive);
      emit(state.copyWith(status: LoadStatus.success, activities: activities));
    } catch (e) {
      emit(state.copyWith(status: LoadStatus.failure, errorMessage: e.toString()));
    }
  }

  Future<void> _onActivityCreated(
    ErpActivityCreated event,
    Emitter<ErpWorkOrdersState> emit,
  ) async {
    emit(state.copyWith(isActing: true));
    try {
      final act = await _workOrderRepository.createActivity(event.body);
      final updated = [...state.activities, act];
      emit(state.copyWith(
        isActing: false,
        activities: updated,
        actionMessage: 'Activity created successfully',
      ));
    } catch (e) {
      emit(state.copyWith(isActing: false, errorMessage: e.toString()));
    }
  }

  Future<void> _onActivityUpdated(
    ErpActivityUpdated event,
    Emitter<ErpWorkOrdersState> emit,
  ) async {
    emit(state.copyWith(isActing: true));
    try {
      final act = await _workOrderRepository.updateActivity(event.id, event.body);
      final updated = state.activities.map((a) => a.id == act.id ? act : a).toList();
      emit(state.copyWith(
        isActing: false,
        activities: updated,
        actionMessage: 'Activity updated successfully',
      ));
    } catch (e) {
      emit(state.copyWith(isActing: false, errorMessage: e.toString()));
    }
  }

  Future<void> _onActivityToggled(
    ErpActivityToggled event,
    Emitter<ErpWorkOrdersState> emit,
  ) async {
    try {
      final act = await _workOrderRepository.toggleActivity(event.id);
      final updated = state.activities.map((a) => a.id == act.id ? act : a).toList();
      emit(state.copyWith(activities: updated));
    } catch (e) {
      emit(state.copyWith(errorMessage: e.toString()));
    }
  }

  Future<void> _onActivityDeleted(
    ErpActivityDeleted event,
    Emitter<ErpWorkOrdersState> emit,
  ) async {
    emit(state.copyWith(isActing: true));
    try {
      await _workOrderRepository.removeActivity(event.id);
      final updated = state.activities.where((a) => a.id != event.id).toList();
      emit(state.copyWith(
        isActing: false,
        activities: updated,
        actionMessage: 'Activity removed successfully',
      ));
    } catch (e) {
      emit(state.copyWith(isActing: false, errorMessage: e.toString()));
    }
  }

  Future<void> _onContractorsRequested(
    ErpContractorsRequested event,
    Emitter<ErpWorkOrdersState> emit,
  ) async {
    emit(state.copyWith(status: LoadStatus.loading));
    try {
      final contractors = await _workOrderRepository.listContractors(
        includeInactive: event.includeInactive,
      );
      emit(state.copyWith(status: LoadStatus.success, contractors: contractors));
    } catch (e) {
      emit(state.copyWith(status: LoadStatus.failure, errorMessage: e.toString()));
    }
  }

  Future<void> _onContractorDetailRequested(
    ErpContractorDetailRequested event,
    Emitter<ErpWorkOrdersState> emit,
  ) async {
    emit(state.copyWith(status: LoadStatus.loading));
    try {
      final contractor = await _workOrderRepository.getContractor(event.id);
      emit(state.copyWith(status: LoadStatus.success, selectedContractor: contractor));
    } catch (e) {
      emit(state.copyWith(status: LoadStatus.failure, errorMessage: e.toString()));
    }
  }

  Future<void> _onContractorCreated(
    ErpContractorCreated event,
    Emitter<ErpWorkOrdersState> emit,
  ) async {
    emit(state.copyWith(isActing: true));
    try {
      final con = await _workOrderRepository.createContractor(event.body);
      final updated = [...state.contractors, con];
      emit(state.copyWith(
        isActing: false,
        contractors: updated,
        actionMessage: 'Contractor registered successfully',
      ));
    } catch (e) {
      emit(state.copyWith(isActing: false, errorMessage: e.toString()));
    }
  }

  Future<void> _onContractorUpdated(
    ErpContractorUpdated event,
    Emitter<ErpWorkOrdersState> emit,
  ) async {
    emit(state.copyWith(isActing: true));
    try {
      final con = await _workOrderRepository.updateContractor(event.id, event.body);
      final updated = state.contractors.map((c) => c.id == con.id ? con : c).toList();
      emit(state.copyWith(
        isActing: false,
        contractors: updated,
        selectedContractor: con,
        actionMessage: 'Contractor details updated successfully',
      ));
    } catch (e) {
      emit(state.copyWith(isActing: false, errorMessage: e.toString()));
    }
  }

  Future<void> _onContractorToggled(
    ErpContractorToggled event,
    Emitter<ErpWorkOrdersState> emit,
  ) async {
    try {
      final con = await _workOrderRepository.toggleContractor(event.id);
      final updated = state.contractors.map((c) => c.id == con.id ? con : c).toList();
      emit(state.copyWith(contractors: updated));
    } catch (e) {
      emit(state.copyWith(errorMessage: e.toString()));
    }
  }

  Future<void> _onContractorDeleted(
    ErpContractorDeleted event,
    Emitter<ErpWorkOrdersState> emit,
  ) async {
    emit(state.copyWith(isActing: true));
    try {
      await _workOrderRepository.removeContractor(event.id);
      final updated = state.contractors.where((c) => c.id != event.id).toList();
      emit(state.copyWith(
        isActing: false,
        contractors: updated,
        actionMessage: 'Contractor removed successfully',
      ));
    } catch (e) {
      emit(state.copyWith(isActing: false, errorMessage: e.toString()));
    }
  }
}
