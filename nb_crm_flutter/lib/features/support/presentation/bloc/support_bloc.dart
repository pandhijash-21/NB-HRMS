import 'dart:async';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/bloc/load_status.dart';
import '../../data/support_repository.dart';
import '../../domain/support_models.dart';

// ---------------------------------------------------------------------------
// Support Events
// ---------------------------------------------------------------------------
abstract class SupportEvent extends Equatable {
  const SupportEvent();

  @override
  List<Object?> get props => [];
}

class SupportMyTicketsRequested extends SupportEvent {
  const SupportMyTicketsRequested();
}

class SupportQueueRequested extends SupportEvent {
  const SupportQueueRequested({this.includeClosed = false});
  final bool includeClosed;

  @override
  List<Object?> get props => [includeClosed];
}

class SupportTicketDetailRequested extends SupportEvent {
  const SupportTicketDetailRequested(this.ticketId);
  final String ticketId;

  @override
  List<Object?> get props => [ticketId];
}

class SupportTicketCreated extends SupportEvent {
  const SupportTicketCreated({
    required this.title,
    required this.description,
    this.photoUrl,
    this.assignedHandlerId,
  });

  final String title;
  final String description;
  final String? photoUrl;
  final int? assignedHandlerId;

  @override
  List<Object?> get props => [title, description, photoUrl, assignedHandlerId];
}

class SupportTicketReassigned extends SupportEvent {
  const SupportTicketReassigned({
    required this.ticketId,
    required this.handlerId,
    this.note,
  });

  final String ticketId;
  final int handlerId;
  final String? note;

  @override
  List<Object?> get props => [ticketId, handlerId, note];
}

class SupportTicketEtaSet extends SupportEvent {
  const SupportTicketEtaSet({
    required this.ticketId,
    required this.etaAt,
    this.note,
  });

  final String ticketId;
  final DateTime etaAt;
  final String? note;

  @override
  List<Object?> get props => [ticketId, etaAt, note];
}

class SupportTicketResolved extends SupportEvent {
  const SupportTicketResolved({
    required this.ticketId,
    required this.remarks,
  });

  final String ticketId;
  final String remarks;

  @override
  List<Object?> get props => [ticketId, remarks];
}

class SupportTicketConfirmed extends SupportEvent {
  const SupportTicketConfirmed(this.ticketId);
  final String ticketId;

  @override
  List<Object?> get props => [ticketId];
}

class SupportTicketDenied extends SupportEvent {
  const SupportTicketDenied({
    required this.ticketId,
    required this.remarks,
  });

  final String ticketId;
  final String remarks;

  @override
  List<Object?> get props => [ticketId, remarks];
}

class SupportTicketForceClosed extends SupportEvent {
  const SupportTicketForceClosed({
    required this.ticketId,
    this.note,
  });

  final String ticketId;
  final String? note;

  @override
  List<Object?> get props => [ticketId, note];
}

class SupportTransferRequested extends SupportEvent {
  const SupportTransferRequested({
    required this.ticketId,
    required this.targetHandlerId,
    required this.reason,
  });

  final String ticketId;
  final int targetHandlerId;
  final String reason;

  @override
  List<Object?> get props => [ticketId, targetHandlerId, reason];
}

class SupportTransferResponded extends SupportEvent {
  const SupportTransferResponded({
    required this.ticketId,
    required this.accept,
    this.remarks,
  });

  final String ticketId;
  final bool accept;
  final String? remarks;

  @override
  List<Object?> get props => [ticketId, accept, remarks];
}

class SupportMessagesRequested extends SupportEvent {
  const SupportMessagesRequested(this.ticketId);
  final String ticketId;

  @override
  List<Object?> get props => [ticketId];
}

class SupportMessageSent extends SupportEvent {
  const SupportMessageSent({
    required this.ticketId,
    required this.message,
    this.attachmentUrl,
    this.attachmentName,
  });

  final String ticketId;
  final String message;
  final String? attachmentUrl;
  final String? attachmentName;

  @override
  List<Object?> get props => [ticketId, message, attachmentUrl, attachmentName];
}

class SupportRemoteRequested extends SupportEvent {
  const SupportRemoteRequested({
    required this.ticketId,
    this.accessLevel = 'FULL_CONTROL',
    this.uacEnabled = true,
  });

  final String ticketId;
  final String accessLevel;
  final bool uacEnabled;

  @override
  List<Object?> get props => [ticketId, accessLevel, uacEnabled];
}

class SupportRemoteResponded extends SupportEvent {
  const SupportRemoteResponded({
    required this.sessionId,
    required this.accept,
    required this.ticketId,
  });

  final String sessionId;
  final bool accept;
  final String ticketId;

  @override
  List<Object?> get props => [sessionId, accept, ticketId];
}

class SupportRemoteEnded extends SupportEvent {
  const SupportRemoteEnded({
    required this.sessionId,
    required this.ticketId,
  });

  final String sessionId;
  final String ticketId;

  @override
  List<Object?> get props => [sessionId, ticketId];
}

// ---------------------------------------------------------------------------
// Support State
// ---------------------------------------------------------------------------
class SupportState extends Equatable {
  const SupportState({
    this.status = LoadStatus.initial,
    this.myTickets = const [],
    this.queueTickets = const [],
    this.selectedTicket,
    this.messages = const [],
    this.activeRemoteSession,
    this.capabilities,
    this.handlers = const [],
    this.errorMessage,
    this.actionSuccessMessage,
  });

  final LoadStatus status;
  final List<SupportTicket> myTickets;
  final List<SupportTicket> queueTickets;
  final SupportTicket? selectedTicket;
  final List<SupportTicketMessage> messages;
  final SupportRemoteSession? activeRemoteSession;
  final SupportCapabilities? capabilities;
  final List<SupportHandler> handlers;
  final String? errorMessage;
  final String? actionSuccessMessage;

  SupportState copyWith({
    LoadStatus? status,
    List<SupportTicket>? myTickets,
    List<SupportTicket>? queueTickets,
    SupportTicket? selectedTicket,
    List<SupportTicketMessage>? messages,
    SupportRemoteSession? activeRemoteSession,
    SupportCapabilities? capabilities,
    List<SupportHandler>? handlers,
    String? errorMessage,
    String? actionSuccessMessage,
  }) {
    return SupportState(
      status: status ?? this.status,
      myTickets: myTickets ?? this.myTickets,
      queueTickets: queueTickets ?? this.queueTickets,
      selectedTicket: selectedTicket ?? this.selectedTicket,
      messages: messages ?? this.messages,
      activeRemoteSession: activeRemoteSession ?? this.activeRemoteSession,
      capabilities: capabilities ?? this.capabilities,
      handlers: handlers ?? this.handlers,
      errorMessage: errorMessage,
      actionSuccessMessage: actionSuccessMessage,
    );
  }

  @override
  List<Object?> get props => [
        status,
        myTickets,
        queueTickets,
        selectedTicket,
        messages,
        activeRemoteSession,
        capabilities,
        handlers,
        errorMessage,
        actionSuccessMessage,
      ];
}

// ---------------------------------------------------------------------------
// Support BLoC
// ---------------------------------------------------------------------------
class SupportBloc extends Bloc<SupportEvent, SupportState> {
  SupportBloc({required this.repository}) : super(const SupportState()) {
    on<SupportMyTicketsRequested>(_onMyTicketsRequested);
    on<SupportQueueRequested>(_onQueueRequested);
    on<SupportTicketDetailRequested>(_onTicketDetailRequested);
    on<SupportTicketCreated>(_onTicketCreated);
    on<SupportTicketReassigned>(_onTicketReassigned);
    on<SupportTicketEtaSet>(_onTicketEtaSet);
    on<SupportTicketResolved>(_onTicketResolved);
    on<SupportTicketConfirmed>(_onTicketConfirmed);
    on<SupportTicketDenied>(_onTicketDenied);
    on<SupportTicketForceClosed>(_onTicketForceClosed);
    on<SupportTransferRequested>(_onTransferRequested);
    on<SupportTransferResponded>(_onTransferResponded);
    on<SupportMessagesRequested>(_onMessagesRequested);
    on<SupportMessageSent>(_onMessageSent);
    on<SupportRemoteRequested>(_onRemoteRequested);
    on<SupportRemoteResponded>(_onRemoteResponded);
    on<SupportRemoteEnded>(_onRemoteEnded);
  }

  final SupportRepository repository;

  Future<void> _onMyTicketsRequested(
    SupportMyTicketsRequested event,
    Emitter<SupportState> emit,
  ) async {
    emit(state.copyWith(status: LoadStatus.loading));
    try {
      final tickets = await repository.listMine();
      emit(state.copyWith(
        status: LoadStatus.success,
        myTickets: tickets,
      ));
    } catch (e) {
      emit(state.copyWith(
        status: LoadStatus.failure,
        errorMessage: e.toString(),
      ));
    }
  }

  Future<void> _onQueueRequested(
    SupportQueueRequested event,
    Emitter<SupportState> emit,
  ) async {
    emit(state.copyWith(status: LoadStatus.loading));
    try {
      final queue = await repository.listQueue(includeClosed: event.includeClosed);
      emit(state.copyWith(
        status: LoadStatus.success,
        queueTickets: queue,
      ));
    } catch (e) {
      emit(state.copyWith(
        status: LoadStatus.failure,
        errorMessage: e.toString(),
      ));
    }
  }

  Future<void> _onTicketDetailRequested(
    SupportTicketDetailRequested event,
    Emitter<SupportState> emit,
  ) async {
    emit(state.copyWith(status: LoadStatus.loading));
    try {
      final ticket = await repository.getById(event.ticketId);
      final messages = await repository.listMessages(event.ticketId);
      final remote = await repository.getActiveRemoteSession(event.ticketId);
      emit(state.copyWith(
        status: LoadStatus.success,
        selectedTicket: ticket,
        messages: messages,
        activeRemoteSession: remote,
      ));
    } catch (e) {
      emit(state.copyWith(
        status: LoadStatus.failure,
        errorMessage: e.toString(),
      ));
    }
  }

  Future<void> _onTicketCreated(
    SupportTicketCreated event,
    Emitter<SupportState> emit,
  ) async {
    emit(state.copyWith(status: LoadStatus.loading));
    try {
      final ticket = await repository.create(
        title: event.title,
        description: event.description,
        photoUrl: event.photoUrl,
        assignedHandlerId: event.assignedHandlerId,
      );
      final updatedList = [ticket, ...state.myTickets];
      emit(state.copyWith(
        status: LoadStatus.success,
        myTickets: updatedList,
        selectedTicket: ticket,
        actionSuccessMessage: 'Ticket #${ticket.ticketNo} created successfully',
      ));
    } catch (e) {
      emit(state.copyWith(
        status: LoadStatus.failure,
        errorMessage: e.toString(),
      ));
    }
  }

  Future<void> _onTicketReassigned(
    SupportTicketReassigned event,
    Emitter<SupportState> emit,
  ) async {
    try {
      final updated = await repository.reassignTicket(
        event.ticketId,
        handlerId: event.handlerId,
        note: event.note,
      );
      emit(state.copyWith(
        selectedTicket: updated,
        actionSuccessMessage: 'Ticket #${updated.ticketNo} reassigned',
      ));
      add(const SupportQueueRequested());
    } catch (e) {
      emit(state.copyWith(errorMessage: e.toString()));
    }
  }

  Future<void> _onTicketEtaSet(
    SupportTicketEtaSet event,
    Emitter<SupportState> emit,
  ) async {
    try {
      final updated = await repository.setInReview(
        event.ticketId,
        etaAt: event.etaAt,
        note: event.note,
      );
      emit(state.copyWith(
        selectedTicket: updated,
        actionSuccessMessage: 'Review and ETA updated',
      ));
    } catch (e) {
      emit(state.copyWith(errorMessage: e.toString()));
    }
  }

  Future<void> _onTicketResolved(
    SupportTicketResolved event,
    Emitter<SupportState> emit,
  ) async {
    try {
      final updated = await repository.resolve(
        event.ticketId,
        remarks: event.remarks,
      );
      emit(state.copyWith(
        selectedTicket: updated,
        actionSuccessMessage: 'Ticket #${updated.ticketNo} marked as resolved',
      ));
    } catch (e) {
      emit(state.copyWith(errorMessage: e.toString()));
    }
  }

  Future<void> _onTicketConfirmed(
    SupportTicketConfirmed event,
    Emitter<SupportState> emit,
  ) async {
    try {
      final updated = await repository.confirm(event.ticketId);
      emit(state.copyWith(
        selectedTicket: updated,
        actionSuccessMessage: 'Ticket #${updated.ticketNo} confirmed and closed',
      ));
    } catch (e) {
      emit(state.copyWith(errorMessage: e.toString()));
    }
  }

  Future<void> _onTicketDenied(
    SupportTicketDenied event,
    Emitter<SupportState> emit,
  ) async {
    try {
      final updated = await repository.deny(
        event.ticketId,
        note: event.remarks,
      );
      emit(state.copyWith(
        selectedTicket: updated,
        actionSuccessMessage: 'Ticket resolution denied and reopened',
      ));
    } catch (e) {
      emit(state.copyWith(errorMessage: e.toString()));
    }
  }

  Future<void> _onTicketForceClosed(
    SupportTicketForceClosed event,
    Emitter<SupportState> emit,
  ) async {
    try {
      final updated = await repository.forceClose(
        event.ticketId,
        remarks: event.note ?? 'Force closed',
      );
      emit(state.copyWith(
        selectedTicket: updated,
        actionSuccessMessage: 'Ticket force-closed by IT',
      ));
    } catch (e) {
      emit(state.copyWith(errorMessage: e.toString()));
    }
  }

  Future<void> _onTransferRequested(
    SupportTransferRequested event,
    Emitter<SupportState> emit,
  ) async {
    try {
      final updated = await repository.requestTransfer(
        event.ticketId,
        targetHandlerEmployeeId: event.targetHandlerId,
        reason: event.reason,
      );
      emit(state.copyWith(
        selectedTicket: updated,
        actionSuccessMessage: 'Transfer requested to handler',
      ));
    } catch (e) {
      emit(state.copyWith(errorMessage: e.toString()));
    }
  }

  Future<void> _onTransferResponded(
    SupportTransferResponded event,
    Emitter<SupportState> emit,
  ) async {
    try {
      final updated = await repository.respondTransfer(
        event.ticketId,
        accept: event.accept,
        remarks: event.remarks,
      );
      emit(state.copyWith(
        selectedTicket: updated,
        actionSuccessMessage: event.accept ? 'Transfer accepted' : 'Transfer declined',
      ));
    } catch (e) {
      emit(state.copyWith(errorMessage: e.toString()));
    }
  }

  Future<void> _onMessagesRequested(
    SupportMessagesRequested event,
    Emitter<SupportState> emit,
  ) async {
    try {
      final messages = await repository.listMessages(event.ticketId);
      emit(state.copyWith(messages: messages));
    } catch (e) {
      emit(state.copyWith(errorMessage: e.toString()));
    }
  }

  Future<void> _onMessageSent(
    SupportMessageSent event,
    Emitter<SupportState> emit,
  ) async {
    try {
      final msg = await repository.sendMessage(
        event.ticketId,
        message: event.message,
        attachmentUrl: event.attachmentUrl,
        attachmentName: event.attachmentName,
      );
      emit(state.copyWith(messages: [...state.messages, msg]));
    } catch (e) {
      emit(state.copyWith(errorMessage: e.toString()));
    }
  }

  Future<void> _onRemoteRequested(
    SupportRemoteRequested event,
    Emitter<SupportState> emit,
  ) async {
    try {
      final session = await repository.requestRemoteSession(
        event.ticketId,
        accessLevel: event.accessLevel,
        uacEnabled: event.uacEnabled,
      );
      emit(state.copyWith(
        activeRemoteSession: session,
        actionSuccessMessage: 'Remote access requested from employee',
      ));
    } catch (e) {
      emit(state.copyWith(errorMessage: e.toString()));
    }
  }

  Future<void> _onRemoteResponded(
    SupportRemoteResponded event,
    Emitter<SupportState> emit,
  ) async {
    try {
      final session = await repository.respondRemoteSession(
        sessionId: event.sessionId,
        accept: event.accept,
      );
      emit(state.copyWith(
        activeRemoteSession: session,
        actionSuccessMessage: event.accept ? 'Remote session accepted' : 'Remote session declined',
      ));
      add(SupportTicketDetailRequested(event.ticketId));
    } catch (e) {
      emit(state.copyWith(errorMessage: e.toString()));
    }
  }

  Future<void> _onRemoteEnded(
    SupportRemoteEnded event,
    Emitter<SupportState> emit,
  ) async {
    try {
      final session = await repository.endRemoteSession(event.sessionId);
      emit(state.copyWith(
        activeRemoteSession: session,
        actionSuccessMessage: 'Remote session disconnected',
      ));
      add(SupportTicketDetailRequested(event.ticketId));
    } catch (e) {
      emit(state.copyWith(errorMessage: e.toString()));
    }
  }
}
