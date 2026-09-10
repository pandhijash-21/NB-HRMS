import 'package:flutter/foundation.dart';

import '../../../../core/bloc/load_status.dart';
import '../../domain/platform_models.dart';

@immutable
class PlatformConsoleState {
  const PlatformConsoleState({
    this.status = LoadStatus.initial,
    this.stats,
    this.companies = const [],
    this.admins = const [],
    this.trash,
    this.isActionInProgress = false,
    this.actionError,
    this.actionSuccessMessage,
    this.errorMessage,
  });

  final LoadStatus status;
  final PlatformStats? stats;
  final List<ClientCompany> companies;
  final List<PlatformAdminUser> admins;
  final PlatformTrashData? trash;
  final bool isActionInProgress;
  final String? actionError;
  final String? actionSuccessMessage;
  final String? errorMessage;

  PlatformConsoleState copyWith({
    LoadStatus? status,
    PlatformStats? stats,
    List<ClientCompany>? companies,
    List<PlatformAdminUser>? admins,
    PlatformTrashData? trash,
    bool? isActionInProgress,
    String? actionError,
    bool clearActionError = false,
    String? actionSuccessMessage,
    bool clearActionSuccess = false,
    String? errorMessage,
    bool clearError = false,
  }) {
    return PlatformConsoleState(
      status: status ?? this.status,
      stats: stats ?? this.stats,
      companies: companies ?? this.companies,
      admins: admins ?? this.admins,
      trash: trash ?? this.trash,
      isActionInProgress: isActionInProgress ?? this.isActionInProgress,
      actionError: clearActionError ? null : (actionError ?? this.actionError),
      actionSuccessMessage:
          clearActionSuccess ? null : (actionSuccessMessage ?? this.actionSuccessMessage),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PlatformConsoleState &&
          runtimeType == other.runtimeType &&
          status == other.status &&
          stats == other.stats &&
          listEquals(companies, other.companies) &&
          listEquals(admins, other.admins) &&
          trash == other.trash &&
          isActionInProgress == other.isActionInProgress &&
          actionError == other.actionError &&
          actionSuccessMessage == other.actionSuccessMessage &&
          errorMessage == other.errorMessage;

  @override
  int get hashCode =>
      status.hashCode ^
      stats.hashCode ^
      companies.hashCode ^
      admins.hashCode ^
      trash.hashCode ^
      isActionInProgress.hashCode ^
      actionError.hashCode ^
      actionSuccessMessage.hashCode ^
      errorMessage.hashCode;
}
