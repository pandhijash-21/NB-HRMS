import 'package:equatable/equatable.dart';

import '../../../../core/bloc/load_status.dart';
import '../../domain/profile_models.dart';

class ProfileState extends Equatable {
  const ProfileState({
    this.status = LoadStatus.initial,
    this.profile,
    this.employeeId,
    this.errorMessage,
    this.pendingChangeRequests = const {},
  });

  final LoadStatus status;
  final EmployeeProfile? profile;
  final int? employeeId;
  final String? errorMessage;
  final Map<String, Map<String, dynamic>?> pendingChangeRequests;

  ProfileState copyWith({
    LoadStatus? status,
    EmployeeProfile? profile,
    int? employeeId,
    String? errorMessage,
    Map<String, Map<String, dynamic>?>? pendingChangeRequests,
  }) {
    return ProfileState(
      status: status ?? this.status,
      profile: profile ?? this.profile,
      employeeId: employeeId ?? this.employeeId,
      errorMessage: errorMessage,
      pendingChangeRequests: pendingChangeRequests ?? this.pendingChangeRequests,
    );
  }

  @override
  List<Object?> get props => [status, profile, employeeId, errorMessage, pendingChangeRequests];
}
