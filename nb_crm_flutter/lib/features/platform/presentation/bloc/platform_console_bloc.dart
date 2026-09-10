import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/bloc/load_status.dart';
import '../../../../core/network/api_envelope.dart';
import '../../data/platform_repository.dart';
import '../../domain/platform_models.dart';
import 'platform_console_event.dart';
import 'platform_console_state.dart';

class PlatformConsoleBloc
    extends Bloc<PlatformConsoleEvent, PlatformConsoleState> {
  PlatformConsoleBloc({required PlatformRepository repository})
      : _repo = repository,
        super(const PlatformConsoleState()) {
    on<PlatformConsoleLoadRequested>(_onLoad);
    on<PlatformConsoleRefreshRequested>(_onRefresh);
    on<PlatformCompanyCreated>(_onCompanyCreated);
    on<PlatformCompanyUpdated>(_onCompanyUpdated);
    on<PlatformCompanyTrashed>(_onCompanyTrashed);
    on<PlatformCompanyRestored>(_onCompanyRestored);
    on<PlatformCompanyPurged>(_onCompanyPurged);
    on<PlatformAdminPasswordReset>(_onAdminPasswordReset);
    on<PlatformAdminUnlocked>(_onAdminUnlocked);
    on<PlatformAdminTrashed>(_onAdminTrashed);
    on<PlatformAdminRestored>(_onAdminRestored);
    on<PlatformAdminPurged>(_onAdminPurged);
    on<PlatformTrashEmptied>(_onTrashEmptied);
    on<PlatformClearMessage>(_onClearMessage);

    add(const PlatformConsoleLoadRequested());
  }

  final PlatformRepository _repo;

  Future<void> _onLoad(
    PlatformConsoleLoadRequested event,
    Emitter<PlatformConsoleState> emit,
  ) async {
    emit(state.copyWith(status: LoadStatus.loading, clearError: true));
    try {
      final results = await Future.wait([
        _repo.getStats(),
        _repo.listCompanies(),
        _repo.listAdmins(),
        _repo.getTrash(),
      ]);

      emit(state.copyWith(
        status: LoadStatus.success,
        stats: results[0] as PlatformStats,
        companies: results[1] as List<ClientCompany>,
        admins: results[2] as List<PlatformAdminUser>,
        trash: results[3] as PlatformTrashData,
      ));
    } on ApiException catch (e) {
      emit(state.copyWith(
        status: LoadStatus.failure,
        errorMessage: e.message,
      ));
    } catch (e) {
      emit(state.copyWith(
        status: LoadStatus.failure,
        errorMessage: 'Unable to load platform console data.',
      ));
    }
  }

  Future<void> _onRefresh(
    PlatformConsoleRefreshRequested event,
    Emitter<PlatformConsoleState> emit,
  ) async {
    try {
      final results = await Future.wait([
        _repo.getStats(),
        _repo.listCompanies(),
        _repo.listAdmins(),
        _repo.getTrash(),
      ]);

      emit(state.copyWith(
        status: LoadStatus.success,
        stats: results[0] as PlatformStats,
        companies: results[1] as List<ClientCompany>,
        admins: results[2] as List<PlatformAdminUser>,
        trash: results[3] as PlatformTrashData,
      ));
    } catch (_) {}
  }

  Future<void> _onCompanyCreated(
    PlatformCompanyCreated event,
    Emitter<PlatformConsoleState> emit,
  ) async {
    emit(state.copyWith(
      isActionInProgress: true,
      clearActionError: true,
      clearActionSuccess: true,
    ));
    try {
      await _repo.onboardCompany({
        'name': event.name,
        'domain': event.domain,
        'plan': event.plan,
        'status': event.status,
        if (event.adminUsername != null) 'adminUsername': event.adminUsername,
        if (event.adminEmail != null) 'adminEmail': event.adminEmail,
        if (event.adminPassword != null) 'adminPassword': event.adminPassword,
      });

      final results = await Future.wait([
        _repo.getStats(),
        _repo.listCompanies(),
      ]);

      emit(state.copyWith(
        isActionInProgress: false,
        stats: results[0] as PlatformStats,
        companies: results[1] as List<ClientCompany>,
        actionSuccessMessage: 'Company "${event.name}" created successfully.',
      ));
    } on ApiException catch (e) {
      emit(state.copyWith(isActionInProgress: false, actionError: e.message));
    } catch (_) {
      emit(state.copyWith(
        isActionInProgress: false,
        actionError: 'Failed to create company. Please try again.',
      ));
    }
  }

  Future<void> _onCompanyUpdated(
    PlatformCompanyUpdated event,
    Emitter<PlatformConsoleState> emit,
  ) async {
    emit(state.copyWith(
      isActionInProgress: true,
      clearActionError: true,
      clearActionSuccess: true,
    ));
    try {
      await _repo.updateCompany(
        event.id,
        {
          if (event.name != null) 'name': event.name,
          if (event.domain != null) 'domain': event.domain,
          if (event.plan != null) 'plan': event.plan,
          if (event.status != null) 'status': event.status,
        },
      );

      final companies = await _repo.listCompanies();
      emit(state.copyWith(
        isActionInProgress: false,
        companies: companies,
        actionSuccessMessage: 'Company updated successfully.',
      ));
    } on ApiException catch (e) {
      emit(state.copyWith(isActionInProgress: false, actionError: e.message));
    } catch (_) {
      emit(state.copyWith(
        isActionInProgress: false,
        actionError: 'Failed to update company.',
      ));
    }
  }

  Future<void> _onCompanyTrashed(
    PlatformCompanyTrashed event,
    Emitter<PlatformConsoleState> emit,
  ) async {
    emit(state.copyWith(
      isActionInProgress: true,
      clearActionError: true,
      clearActionSuccess: true,
    ));
    try {
      await _repo.trashCompany(event.id, superadminPassword: event.superadminPassword);
      final results = await Future.wait([
        _repo.getStats(),
        _repo.listCompanies(),
        _repo.getTrash(),
      ]);

      emit(state.copyWith(
        isActionInProgress: false,
        stats: results[0] as PlatformStats,
        companies: results[1] as List<ClientCompany>,
        trash: results[2] as PlatformTrashData,
        actionSuccessMessage: 'Company moved to 30-Day Trash.',
      ));
    } on ApiException catch (e) {
      emit(state.copyWith(isActionInProgress: false, actionError: e.message));
    } catch (_) {
      emit(state.copyWith(
        isActionInProgress: false,
        actionError: 'Failed to delete company.',
      ));
    }
  }

  Future<void> _onCompanyRestored(
    PlatformCompanyRestored event,
    Emitter<PlatformConsoleState> emit,
  ) async {
    emit(state.copyWith(
      isActionInProgress: true,
      clearActionError: true,
      clearActionSuccess: true,
    ));
    try {
      await _repo.restoreCompany(event.id);
      final results = await Future.wait([
        _repo.getStats(),
        _repo.listCompanies(),
        _repo.getTrash(),
      ]);

      emit(state.copyWith(
        isActionInProgress: false,
        stats: results[0] as PlatformStats,
        companies: results[1] as List<ClientCompany>,
        trash: results[2] as PlatformTrashData,
        actionSuccessMessage: 'Company restored from Trash.',
      ));
    } on ApiException catch (e) {
      emit(state.copyWith(isActionInProgress: false, actionError: e.message));
    } catch (_) {
      emit(state.copyWith(
        isActionInProgress: false,
        actionError: 'Failed to restore company.',
      ));
    }
  }

  Future<void> _onCompanyPurged(
    PlatformCompanyPurged event,
    Emitter<PlatformConsoleState> emit,
  ) async {
    emit(state.copyWith(
      isActionInProgress: true,
      clearActionError: true,
      clearActionSuccess: true,
    ));
    try {
      await _repo.purgeCompany(event.id, superadminPassword: event.superadminPassword);
      final results = await Future.wait([
        _repo.getStats(),
        _repo.getTrash(),
      ]);

      emit(state.copyWith(
        isActionInProgress: false,
        stats: results[0] as PlatformStats,
        trash: results[1] as PlatformTrashData,
        actionSuccessMessage: 'Company permanently removed.',
      ));
    } on ApiException catch (e) {
      emit(state.copyWith(isActionInProgress: false, actionError: e.message));
    } catch (_) {
      emit(state.copyWith(
        isActionInProgress: false,
        actionError: 'Failed to permanently purge company.',
      ));
    }
  }

  Future<void> _onAdminPasswordReset(
    PlatformAdminPasswordReset event,
    Emitter<PlatformConsoleState> emit,
  ) async {
    emit(state.copyWith(
      isActionInProgress: true,
      clearActionError: true,
      clearActionSuccess: true,
    ));
    try {
      await _repo.resetAdminPassword(event.adminId, event.newPassword);
      emit(state.copyWith(
        isActionInProgress: false,
        actionSuccessMessage: 'Admin password reset successfully.',
      ));
    } on ApiException catch (e) {
      emit(state.copyWith(isActionInProgress: false, actionError: e.message));
    } catch (_) {
      emit(state.copyWith(
        isActionInProgress: false,
        actionError: 'Failed to reset admin password.',
      ));
    }
  }

  Future<void> _onAdminUnlocked(
    PlatformAdminUnlocked event,
    Emitter<PlatformConsoleState> emit,
  ) async {
    emit(state.copyWith(
      isActionInProgress: true,
      clearActionError: true,
      clearActionSuccess: true,
    ));
    try {
      await _repo.unlockAdminAccount(event.adminId);
      final admins = await _repo.listAdmins();
      emit(state.copyWith(
        isActionInProgress: false,
        admins: admins,
        actionSuccessMessage: 'Admin account unlocked successfully.',
      ));
    } on ApiException catch (e) {
      emit(state.copyWith(isActionInProgress: false, actionError: e.message));
    } catch (_) {
      emit(state.copyWith(
        isActionInProgress: false,
        actionError: 'Failed to unlock admin account.',
      ));
    }
  }

  Future<void> _onAdminTrashed(
    PlatformAdminTrashed event,
    Emitter<PlatformConsoleState> emit,
  ) async {
    emit(state.copyWith(
      isActionInProgress: true,
      clearActionError: true,
      clearActionSuccess: true,
    ));
    try {
      await _repo.trashAdmin(event.id, superadminPassword: event.superadminPassword);
      final results = await Future.wait([
        _repo.getStats(),
        _repo.listAdmins(),
        _repo.getTrash(),
      ]);

      emit(state.copyWith(
        isActionInProgress: false,
        stats: results[0] as PlatformStats,
        admins: results[1] as List<PlatformAdminUser>,
        trash: results[2] as PlatformTrashData,
        actionSuccessMessage: 'Admin moved to 30-Day Trash.',
      ));
    } on ApiException catch (e) {
      emit(state.copyWith(isActionInProgress: false, actionError: e.message));
    } catch (_) {
      emit(state.copyWith(
        isActionInProgress: false,
        actionError: 'Failed to delete admin.',
      ));
    }
  }

  Future<void> _onAdminRestored(
    PlatformAdminRestored event,
    Emitter<PlatformConsoleState> emit,
  ) async {
    emit(state.copyWith(
      isActionInProgress: true,
      clearActionError: true,
      clearActionSuccess: true,
    ));
    try {
      await _repo.restoreAdmin(event.id);
      final results = await Future.wait([
        _repo.getStats(),
        _repo.listAdmins(),
        _repo.getTrash(),
      ]);

      emit(state.copyWith(
        isActionInProgress: false,
        stats: results[0] as PlatformStats,
        admins: results[1] as List<PlatformAdminUser>,
        trash: results[2] as PlatformTrashData,
        actionSuccessMessage: 'Admin restored from Trash.',
      ));
    } on ApiException catch (e) {
      emit(state.copyWith(isActionInProgress: false, actionError: e.message));
    } catch (_) {
      emit(state.copyWith(
        isActionInProgress: false,
        actionError: 'Failed to restore admin.',
      ));
    }
  }

  Future<void> _onAdminPurged(
    PlatformAdminPurged event,
    Emitter<PlatformConsoleState> emit,
  ) async {
    emit(state.copyWith(
      isActionInProgress: true,
      clearActionError: true,
      clearActionSuccess: true,
    ));
    try {
      await _repo.purgeAdmin(event.id, superadminPassword: event.superadminPassword);
      final results = await Future.wait([
        _repo.getStats(),
        _repo.getTrash(),
      ]);

      emit(state.copyWith(
        isActionInProgress: false,
        stats: results[0] as PlatformStats,
        trash: results[1] as PlatformTrashData,
        actionSuccessMessage: 'Admin permanently removed.',
      ));
    } on ApiException catch (e) {
      emit(state.copyWith(isActionInProgress: false, actionError: e.message));
    } catch (_) {
      emit(state.copyWith(
        isActionInProgress: false,
        actionError: 'Failed to permanently purge admin.',
      ));
    }
  }

  Future<void> _onTrashEmptied(
    PlatformTrashEmptied event,
    Emitter<PlatformConsoleState> emit,
  ) async {
    emit(state.copyWith(
      isActionInProgress: true,
      clearActionError: true,
      clearActionSuccess: true,
    ));
    try {
      await _repo.emptyTrash(superadminPassword: event.superadminPassword);
      final results = await Future.wait([
        _repo.getStats(),
        _repo.getTrash(),
      ]);

      emit(state.copyWith(
        isActionInProgress: false,
        stats: results[0] as PlatformStats,
        trash: results[1] as PlatformTrashData,
        actionSuccessMessage: 'Trash emptied successfully.',
      ));
    } on ApiException catch (e) {
      emit(state.copyWith(isActionInProgress: false, actionError: e.message));
    } catch (_) {
      emit(state.copyWith(
        isActionInProgress: false,
        actionError: 'Failed to empty trash.',
      ));
    }
  }

  void _onClearMessage(
    PlatformClearMessage event,
    Emitter<PlatformConsoleState> emit,
  ) {
    emit(state.copyWith(clearActionError: true, clearActionSuccess: true));
  }
}
