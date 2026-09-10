import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/bloc/load_status.dart';
import '../../data/boq_repository.dart';
import '../../domain/boq_models.dart';
import '../../domain/resource_models.dart';

// ---------------------------------------------------------------------------
// Events
// ---------------------------------------------------------------------------
abstract class ErpBoqEvent extends Equatable {
  const ErpBoqEvent();

  @override
  List<Object?> get props => [];
}

class ErpBoqListRequested extends ErpBoqEvent {
  const ErpBoqListRequested({this.projectId});
  final String? projectId;

  @override
  List<Object?> get props => [projectId];
}

class ErpBoqDetailRequested extends ErpBoqEvent {
  const ErpBoqDetailRequested(this.id);
  final String id;

  @override
  List<Object?> get props => [id];
}

class ErpBoqCreated extends ErpBoqEvent {
  const ErpBoqCreated(this.body);
  final Map<String, dynamic> body;

  @override
  List<Object?> get props => [body];
}

class ErpBoqUpdated extends ErpBoqEvent {
  const ErpBoqUpdated({required this.id, required this.body});
  final String id;
  final Map<String, dynamic> body;

  @override
  List<Object?> get props => [id, body];
}

class ErpBoqDeleted extends ErpBoqEvent {
  const ErpBoqDeleted(this.id);
  final String id;

  @override
  List<Object?> get props => [id];
}

class ErpBoqResourcesRequested extends ErpBoqEvent {
  const ErpBoqResourcesRequested({this.includeInactive = false});
  final bool includeInactive;

  @override
  List<Object?> get props => [includeInactive];
}

class ErpBoqMaterialCreated extends ErpBoqEvent {
  const ErpBoqMaterialCreated(this.body);
  final Map<String, dynamic> body;

  @override
  List<Object?> get props => [body];
}

class ErpBoqMaterialStockAdded extends ErpBoqEvent {
  const ErpBoqMaterialStockAdded({required this.id, required this.body});
  final String id;
  final Map<String, dynamic> body;

  @override
  List<Object?> get props => [id, body];
}

class ErpBoqMaterialOutwardDispatched extends ErpBoqEvent {
  const ErpBoqMaterialOutwardDispatched({
    required this.id,
    required this.quantity,
    required this.contractorId,
    this.remarks,
  });

  final String id;
  final double quantity;
  final String contractorId;
  final String? remarks;

  @override
  List<Object?> get props => [id, quantity, contractorId, remarks];
}

class ErpBoqMaterialDeleted extends ErpBoqEvent {
  const ErpBoqMaterialDeleted(this.id);
  final String id;

  @override
  List<Object?> get props => [id];
}

class ErpBoqMachineCreated extends ErpBoqEvent {
  const ErpBoqMachineCreated(this.body);
  final Map<String, dynamic> body;

  @override
  List<Object?> get props => [body];
}

class ErpBoqMachineStockAdded extends ErpBoqEvent {
  const ErpBoqMachineStockAdded({required this.id, required this.body});
  final String id;
  final Map<String, dynamic> body;

  @override
  List<Object?> get props => [id, body];
}

class ErpBoqMachineIssued extends ErpBoqEvent {
  const ErpBoqMachineIssued({
    required this.id,
    required this.quantity,
    required this.contractorId,
    this.issueDate,
    this.remarks,
  });

  final String id;
  final double quantity;
  final String contractorId;
  final DateTime? issueDate;
  final String? remarks;

  @override
  List<Object?> get props => [id, quantity, contractorId, issueDate, remarks];
}

class ErpBoqMachineReturned extends ErpBoqEvent {
  const ErpBoqMachineReturned({
    required this.issueId,
    required this.quantity,
    this.returnDate,
    this.remarks,
  });

  final String issueId;
  final double quantity;
  final DateTime? returnDate;
  final String? remarks;

  @override
  List<Object?> get props => [issueId, quantity, returnDate, remarks];
}

class ErpBoqMachineDeleted extends ErpBoqEvent {
  const ErpBoqMachineDeleted(this.id);
  final String id;

  @override
  List<Object?> get props => [id];
}

class ErpBoqLabourCreated extends ErpBoqEvent {
  const ErpBoqLabourCreated(this.body);
  final Map<String, dynamic> body;

  @override
  List<Object?> get props => [body];
}

class ErpBoqLabourDeleted extends ErpBoqEvent {
  const ErpBoqLabourDeleted(this.id);
  final String id;

  @override
  List<Object?> get props => [id];
}

// ---------------------------------------------------------------------------
// State
// ---------------------------------------------------------------------------
class ErpBoqState extends Equatable {
  const ErpBoqState({
    this.status = LoadStatus.initial,
    this.boqs = const [],
    this.selectedBoq,
    this.materials = const [],
    this.machines = const [],
    this.labour = const [],
    this.activeMachineIssues = const [],
    this.isActing = false,
    this.errorMessage,
    this.actionMessage,
  });

  final LoadStatus status;
  final List<ErpBoq> boqs;
  final ErpBoq? selectedBoq;
  final List<ErpMaterial> materials;
  final List<ErpMachine> machines;
  final List<ErpLabour> labour;
  final List<ErpMachineIssue> activeMachineIssues;
  final bool isActing;
  final String? errorMessage;
  final String? actionMessage;

  ErpBoqState copyWith({
    LoadStatus? status,
    List<ErpBoq>? boqs,
    ErpBoq? selectedBoq,
    bool clearSelectedBoq = false,
    List<ErpMaterial>? materials,
    List<ErpMachine>? machines,
    List<ErpLabour>? labour,
    List<ErpMachineIssue>? activeMachineIssues,
    bool? isActing,
    String? errorMessage,
    String? actionMessage,
  }) {
    return ErpBoqState(
      status: status ?? this.status,
      boqs: boqs ?? this.boqs,
      selectedBoq: clearSelectedBoq ? null : (selectedBoq ?? this.selectedBoq),
      materials: materials ?? this.materials,
      machines: machines ?? this.machines,
      labour: labour ?? this.labour,
      activeMachineIssues: activeMachineIssues ?? this.activeMachineIssues,
      isActing: isActing ?? this.isActing,
      errorMessage: errorMessage,
      actionMessage: actionMessage,
    );
  }

  @override
  List<Object?> get props => [
        status,
        boqs,
        selectedBoq,
        materials,
        machines,
        labour,
        activeMachineIssues,
        isActing,
        errorMessage,
        actionMessage,
      ];
}

// ---------------------------------------------------------------------------
// BLoC
// ---------------------------------------------------------------------------
class ErpBoqBloc extends Bloc<ErpBoqEvent, ErpBoqState> {
  ErpBoqBloc({required BoqRepository boqRepository})
      : _boqRepository = boqRepository,
        super(const ErpBoqState()) {
    on<ErpBoqListRequested>(_onListRequested);
    on<ErpBoqDetailRequested>(_onDetailRequested);
    on<ErpBoqCreated>(_onBoqCreated);
    on<ErpBoqUpdated>(_onBoqUpdated);
    on<ErpBoqDeleted>(_onBoqDeleted);
    on<ErpBoqResourcesRequested>(_onResourcesRequested);
    on<ErpBoqMaterialCreated>(_onMaterialCreated);
    on<ErpBoqMaterialStockAdded>(_onMaterialStockAdded);
    on<ErpBoqMaterialOutwardDispatched>(_onMaterialOutwardDispatched);
    on<ErpBoqMaterialDeleted>(_onMaterialDeleted);
    on<ErpBoqMachineCreated>(_onMachineCreated);
    on<ErpBoqMachineStockAdded>(_onMachineStockAdded);
    on<ErpBoqMachineIssued>(_onMachineIssued);
    on<ErpBoqMachineReturned>(_onMachineReturned);
    on<ErpBoqMachineDeleted>(_onMachineDeleted);
    on<ErpBoqLabourCreated>(_onLabourCreated);
    on<ErpBoqLabourDeleted>(_onLabourDeleted);
  }

  final BoqRepository _boqRepository;

  Future<void> _onListRequested(
    ErpBoqListRequested event,
    Emitter<ErpBoqState> emit,
  ) async {
    emit(state.copyWith(status: LoadStatus.loading));
    try {
      final boqs = await _boqRepository.list(projectId: event.projectId);
      emit(state.copyWith(status: LoadStatus.success, boqs: boqs));
    } catch (e) {
      emit(state.copyWith(status: LoadStatus.failure, errorMessage: e.toString()));
    }
  }

  Future<void> _onDetailRequested(
    ErpBoqDetailRequested event,
    Emitter<ErpBoqState> emit,
  ) async {
    emit(state.copyWith(status: LoadStatus.loading));
    try {
      final boq = await _boqRepository.getById(event.id);
      emit(state.copyWith(status: LoadStatus.success, selectedBoq: boq));
    } catch (e) {
      emit(state.copyWith(status: LoadStatus.failure, errorMessage: e.toString()));
    }
  }

  Future<void> _onBoqCreated(
    ErpBoqCreated event,
    Emitter<ErpBoqState> emit,
  ) async {
    emit(state.copyWith(isActing: true));
    try {
      final boq = await _boqRepository.create(event.body);
      final updated = [boq, ...state.boqs];
      emit(state.copyWith(
        isActing: false,
        boqs: updated,
        actionMessage: 'BOQ created successfully',
      ));
    } catch (e) {
      emit(state.copyWith(isActing: false, errorMessage: e.toString()));
    }
  }

  Future<void> _onBoqUpdated(
    ErpBoqUpdated event,
    Emitter<ErpBoqState> emit,
  ) async {
    emit(state.copyWith(isActing: true));
    try {
      final boq = await _boqRepository.update(event.id, event.body);
      final updated = state.boqs.map((b) => b.id == boq.id ? boq : b).toList();
      emit(state.copyWith(
        isActing: false,
        boqs: updated,
        selectedBoq: boq,
        actionMessage: 'BOQ updated successfully',
      ));
    } catch (e) {
      emit(state.copyWith(isActing: false, errorMessage: e.toString()));
    }
  }

  Future<void> _onBoqDeleted(
    ErpBoqDeleted event,
    Emitter<ErpBoqState> emit,
  ) async {
    emit(state.copyWith(isActing: true));
    try {
      await _boqRepository.remove(event.id);
      final updated = state.boqs.where((b) => b.id != event.id).toList();
      emit(state.copyWith(
        isActing: false,
        boqs: updated,
        actionMessage: 'BOQ deleted successfully',
      ));
    } catch (e) {
      emit(state.copyWith(isActing: false, errorMessage: e.toString()));
    }
  }

  Future<void> _onResourcesRequested(
    ErpBoqResourcesRequested event,
    Emitter<ErpBoqState> emit,
  ) async {
    emit(state.copyWith(status: LoadStatus.loading));
    try {
      final results = await Future.wait([
        _boqRepository.listMaterials(includeInactive: event.includeInactive),
        _boqRepository.listMachines(includeInactive: event.includeInactive),
        _boqRepository.listLabour(),
        _boqRepository.listActiveMachineIssues(),
      ]);
      emit(state.copyWith(
        status: LoadStatus.success,
        materials: results[0] as List<ErpMaterial>,
        machines: results[1] as List<ErpMachine>,
        labour: results[2] as List<ErpLabour>,
        activeMachineIssues: results[3] as List<ErpMachineIssue>,
      ));
    } catch (e) {
      emit(state.copyWith(status: LoadStatus.failure, errorMessage: e.toString()));
    }
  }

  Future<void> _onMaterialCreated(
    ErpBoqMaterialCreated event,
    Emitter<ErpBoqState> emit,
  ) async {
    emit(state.copyWith(isActing: true));
    try {
      final mat = await _boqRepository.createMaterial(event.body);
      final updated = [...state.materials, mat];
      emit(state.copyWith(
        isActing: false,
        materials: updated,
        actionMessage: 'Material created successfully',
      ));
    } catch (e) {
      emit(state.copyWith(isActing: false, errorMessage: e.toString()));
    }
  }

  Future<void> _onMaterialStockAdded(
    ErpBoqMaterialStockAdded event,
    Emitter<ErpBoqState> emit,
  ) async {
    emit(state.copyWith(isActing: true));
    try {
      final mat = await _boqRepository.addMaterialStock(event.id, event.body);
      final updated = state.materials.map((m) => m.id == mat.id ? mat : m).toList();
      emit(state.copyWith(
        isActing: false,
        materials: updated,
        actionMessage: 'Stock added successfully',
      ));
    } catch (e) {
      emit(state.copyWith(isActing: false, errorMessage: e.toString()));
    }
  }

  Future<void> _onMaterialOutwardDispatched(
    ErpBoqMaterialOutwardDispatched event,
    Emitter<ErpBoqState> emit,
  ) async {
    emit(state.copyWith(isActing: true));
    try {
      await _boqRepository.dispatchMaterialOutward(
        event.id,
        quantity: event.quantity,
        contractorId: event.contractorId,
        remarks: event.remarks,
      );
      final materials = await _boqRepository.listMaterials();
      emit(state.copyWith(
        isActing: false,
        materials: materials,
        actionMessage: 'Material dispatched successfully',
      ));
    } catch (e) {
      emit(state.copyWith(isActing: false, errorMessage: e.toString()));
    }
  }

  Future<void> _onMaterialDeleted(
    ErpBoqMaterialDeleted event,
    Emitter<ErpBoqState> emit,
  ) async {
    emit(state.copyWith(isActing: true));
    try {
      await _boqRepository.removeMaterial(event.id);
      final updated = state.materials.where((m) => m.id != event.id).toList();
      emit(state.copyWith(
        isActing: false,
        materials: updated,
        actionMessage: 'Material removed successfully',
      ));
    } catch (e) {
      emit(state.copyWith(isActing: false, errorMessage: e.toString()));
    }
  }

  Future<void> _onMachineCreated(
    ErpBoqMachineCreated event,
    Emitter<ErpBoqState> emit,
  ) async {
    emit(state.copyWith(isActing: true));
    try {
      final machine = await _boqRepository.createMachine(event.body);
      final updated = [...state.machines, machine];
      emit(state.copyWith(
        isActing: false,
        machines: updated,
        actionMessage: 'Machine added successfully',
      ));
    } catch (e) {
      emit(state.copyWith(isActing: false, errorMessage: e.toString()));
    }
  }

  Future<void> _onMachineStockAdded(
    ErpBoqMachineStockAdded event,
    Emitter<ErpBoqState> emit,
  ) async {
    emit(state.copyWith(isActing: true));
    try {
      final machine = await _boqRepository.addMachineStock(event.id, event.body);
      final updated = state.machines.map((m) => m.id == machine.id ? machine : m).toList();
      emit(state.copyWith(
        isActing: false,
        machines: updated,
        actionMessage: 'Machine stock added successfully',
      ));
    } catch (e) {
      emit(state.copyWith(isActing: false, errorMessage: e.toString()));
    }
  }

  Future<void> _onMachineIssued(
    ErpBoqMachineIssued event,
    Emitter<ErpBoqState> emit,
  ) async {
    emit(state.copyWith(isActing: true));
    try {
      await _boqRepository.issueMachine(
        event.id,
        quantity: event.quantity,
        contractorId: event.contractorId,
        issueDate: event.issueDate,
        remarks: event.remarks,
      );
      final issues = await _boqRepository.listActiveMachineIssues();
      final machines = await _boqRepository.listMachines();
      emit(state.copyWith(
        isActing: false,
        machines: machines,
        activeMachineIssues: issues,
        actionMessage: 'Machine issued successfully',
      ));
    } catch (e) {
      emit(state.copyWith(isActing: false, errorMessage: e.toString()));
    }
  }

  Future<void> _onMachineReturned(
    ErpBoqMachineReturned event,
    Emitter<ErpBoqState> emit,
  ) async {
    emit(state.copyWith(isActing: true));
    try {
      await _boqRepository.returnMachine(
        event.issueId,
        quantity: event.quantity,
        returnDate: event.returnDate,
        remarks: event.remarks,
      );
      final issues = await _boqRepository.listActiveMachineIssues();
      final machines = await _boqRepository.listMachines();
      emit(state.copyWith(
        isActing: false,
        machines: machines,
        activeMachineIssues: issues,
        actionMessage: 'Machine returned successfully',
      ));
    } catch (e) {
      emit(state.copyWith(isActing: false, errorMessage: e.toString()));
    }
  }

  Future<void> _onMachineDeleted(
    ErpBoqMachineDeleted event,
    Emitter<ErpBoqState> emit,
  ) async {
    emit(state.copyWith(isActing: true));
    try {
      await _boqRepository.removeMachine(event.id);
      final updated = state.machines.where((m) => m.id != event.id).toList();
      emit(state.copyWith(
        isActing: false,
        machines: updated,
        actionMessage: 'Machine deleted successfully',
      ));
    } catch (e) {
      emit(state.copyWith(isActing: false, errorMessage: e.toString()));
    }
  }

  Future<void> _onLabourCreated(
    ErpBoqLabourCreated event,
    Emitter<ErpBoqState> emit,
  ) async {
    emit(state.copyWith(isActing: true));
    try {
      final labour = await _boqRepository.createLabour(event.body);
      final updated = [...state.labour, labour];
      emit(state.copyWith(
        isActing: false,
        labour: updated,
        actionMessage: 'Labour type added successfully',
      ));
    } catch (e) {
      emit(state.copyWith(isActing: false, errorMessage: e.toString()));
    }
  }

  Future<void> _onLabourDeleted(
    ErpBoqLabourDeleted event,
    Emitter<ErpBoqState> emit,
  ) async {
    emit(state.copyWith(isActing: true));
    try {
      await _boqRepository.removeLabour(event.id);
      final updated = state.labour.where((l) => l.id != event.id).toList();
      emit(state.copyWith(
        isActing: false,
        labour: updated,
        actionMessage: 'Labour type deleted successfully',
      ));
    } catch (e) {
      emit(state.copyWith(isActing: false, errorMessage: e.toString()));
    }
  }
}
