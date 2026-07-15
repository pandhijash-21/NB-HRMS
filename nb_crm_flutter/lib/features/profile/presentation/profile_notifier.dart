import 'dart:async';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/profile_repository.dart';
import '../domain/profile_models.dart';
import '../../auth/presentation/auth_providers.dart';

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  return ProfileRepository(dioClient: ref.watch(dioClientProvider));
});

/// Holds the currently active profile employee ID.
class ActiveProfileEmployeeId extends Notifier<int?> {
  @override
  int? build() => null;

  void set(int? id) => state = id;
}

final activeProfileEmployeeIdProvider = NotifierProvider.autoDispose<ActiveProfileEmployeeId, int?>(
  ActiveProfileEmployeeId.new,
);

/// Notifier for the currently active employee profile.
class ProfileNotifier extends AsyncNotifier<EmployeeProfile> {
  ProfileRepository get _repo => ref.read(profileRepositoryProvider);

  int get employeeId {
    final id = ref.read(activeProfileEmployeeIdProvider);
    if (id == null) throw Exception('No employee ID selected.');
    return id;
  }

  @override
  FutureOr<EmployeeProfile> build() {
    final id = ref.watch(activeProfileEmployeeIdProvider);
    if (id == null) {
      throw Exception('No employee ID selected.');
    }
    return _repo.getProfile(id);
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _repo.getProfile(employeeId));
  }

  /// Update general info direct (admin write).
  Future<void> updateGeneralInfoDirect(Map<String, dynamic> data) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await _repo.updateGeneralInfo(employeeId, data);
      return _repo.getProfile(employeeId);
    });
  }

  /// Update personal info direct (admin write).
  Future<void> updatePersonalInfoDirect(Map<String, dynamic> data) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await _repo.updatePersonalInfoDirect(employeeId, data);
      return _repo.getProfile(employeeId);
    });
  }

  /// Update address info direct (admin write).
  Future<void> updateAddressInfoDirect(String type, Map<String, dynamic> data) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await _repo.updateAddressInfoDirect(employeeId, type, data);
      return _repo.getProfile(employeeId);
    });
  }

  /// Submit change request for Personal info (self-service).
  Future<void> submitPersonalChangeRequest(Map<String, dynamic> data) async {
    await _repo.submitChangeRequest(module: 'PERSONAL', newData: data);
    ref.invalidate(pendingRequestProvider('PERSONAL'));
  }

  /// Submit change request for Address info (self-service).
  Future<void> submitAddressChangeRequest(Map<String, dynamic> data) async {
    await _repo.submitChangeRequest(module: 'ADDRESS', newData: data);
    ref.invalidate(pendingRequestProvider('ADDRESS'));
  }

  /// Update bank info (direct).
  Future<void> updateBankInfo(Map<String, dynamic> data) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await _repo.updateBankInfo(employeeId, data);
      return _repo.getProfile(employeeId);
    });
  }

  /// Update other info (direct).
  Future<void> updateOtherInfo(Map<String, dynamic> data) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await _repo.updateOtherInfo(employeeId, data);
      return _repo.getProfile(employeeId);
    });
  }

  /// CRUD Family
  Future<void> addFamilyMember(Map<String, dynamic> data) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await _repo.addFamilyMember(employeeId, data);
      return _repo.getProfile(employeeId);
    });
  }

  Future<void> updateFamilyMember(String memberId, Map<String, dynamic> data) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await _repo.updateFamilyMember(employeeId, memberId, data);
      return _repo.getProfile(employeeId);
    });
  }

  Future<void> deleteFamilyMember(String memberId) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await _repo.deleteFamilyMember(employeeId, memberId);
      return _repo.getProfile(employeeId);
    });
  }

  /// CRUD Academic
  Future<void> addAcademicQualification(Map<String, dynamic> data) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await _repo.addAcademicQualification(employeeId, data);
      return _repo.getProfile(employeeId);
    });
  }

  Future<void> updateAcademicQualification(String qualId, Map<String, dynamic> data) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await _repo.updateAcademicQualification(employeeId, qualId, data);
      return _repo.getProfile(employeeId);
    });
  }

  Future<void> deleteAcademicQualification(String qualId) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await _repo.deleteAcademicQualification(employeeId, qualId);
      return _repo.getProfile(employeeId);
    });
  }

  /// Upload file helper
  Future<String> uploadFile({
    required String kebabType,
    required File file,
    String? qualId,
    int? sem,
    String? memberId,
    String? experienceId,
  }) async {
    final url = await _repo.uploadFile(
      employeeId: employeeId,
      kebabType: kebabType,
      file: file,
      qualId: qualId,
      sem: sem,
      memberId: memberId,
      experienceId: experienceId,
    );
    // Reload state after upload
    await refresh();
    return url;
  }
}

/// Provider for ProfileNotifier.
final profileProvider = AsyncNotifierProvider.autoDispose<ProfileNotifier, EmployeeProfile>(
  ProfileNotifier.new,
);

/// Provider to get the pending change-request if any exists for the self-service employee.
final pendingRequestProvider = FutureProvider.autoDispose.family<Map<String, dynamic>?, String>((ref, module) async {
  final repo = ref.read(profileRepositoryProvider);
  return repo.getPendingChangeRequest(module);
});
