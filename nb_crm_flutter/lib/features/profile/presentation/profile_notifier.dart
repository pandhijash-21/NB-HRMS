import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
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
    // Prefer data refresh without wiping UI to a loading spinner when possible.
    state = await AsyncValue.guard(() => _repo.getProfile(employeeId));
  }

  /// Update general info direct (admin write).
  /// Returns rematch summary when Punch ID changed (machine punches imported).
  Future<Map<String, dynamic>?> updateGeneralInfoDirect(Map<String, dynamic> data) async {
    Map<String, dynamic>? rematch;
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      rematch = await _repo.updateGeneralInfo(employeeId, data);
      return _repo.getProfile(employeeId);
    });
    return rematch;
  }

  /// Update abbreviation on core employee row.
  Future<void> updateEmployeeAbbreviation(String? abbreviation) async {
    if (abbreviation == null || abbreviation.trim().isEmpty) return;
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await _repo.updateEmployeeCore(employeeId, {'abbreviation': abbreviation.trim()});
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

  /// Submit change requests for Local + Permanent address (self-service).
  Future<void> submitAddressChangeRequest({
    required Map<String, dynamic> local,
    required Map<String, dynamic> permanent,
  }) async {
    await _repo.submitChangeRequest(module: 'ADDRESS_LOCAL', newData: local);
    await _repo.submitChangeRequest(module: 'ADDRESS_PERMANENT', newData: permanent);
    ref.invalidate(pendingRequestProvider('ADDRESS_LOCAL'));
    ref.invalidate(pendingRequestProvider('ADDRESS_PERMANENT'));
  }

  /// Submit change request for Other info (self-service).
  Future<void> submitOtherChangeRequest(Map<String, dynamic> data) async {
    await _repo.submitChangeRequest(module: 'OTHER', newData: data);
    ref.invalidate(pendingRequestProvider('OTHER'));
  }

  /// Submit change request for Bank info (self-service).
  Future<void> submitBankChangeRequest(Map<String, dynamic> data) async {
    await _repo.submitChangeRequest(module: 'BANK', newData: data);
    ref.invalidate(pendingRequestProvider('BANK'));
  }

  /// Update bank info (direct — privileged only).
  Future<void> updateBankInfo(Map<String, dynamic> data) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await _repo.updateBankInfo(employeeId, data);
      return _repo.getProfile(employeeId);
    });
  }

  /// Update other info (direct — privileged only).
  Future<void> updateOtherInfo(Map<String, dynamic> data) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await _repo.updateOtherInfo(employeeId, data);
      return _repo.getProfile(employeeId);
    });
  }

  /// CRUD Family
  Future<String?> addFamilyMember(Map<String, dynamic> data) async {
    // Avoid AsyncLoading while a dialog may be open (locked widget tree on web).
    final createdId = await _repo.addFamilyMember(employeeId, data);
    state = await AsyncValue.guard(() => _repo.getProfile(employeeId));
    return createdId;
  }

  Future<void> updateFamilyMember(String memberId, Map<String, dynamic> data) async {
    await _repo.updateFamilyMember(employeeId, memberId, data);
    state = await AsyncValue.guard(() => _repo.getProfile(employeeId));
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
    // Avoid AsyncLoading while a dialog may be open (locked widget tree on web).
    await _repo.addAcademicQualification(employeeId, data);
    state = await AsyncValue.guard(() => _repo.getProfile(employeeId));
  }

  Future<void> updateAcademicQualification(String qualId, Map<String, dynamic> data) async {
    await _repo.updateAcademicQualification(employeeId, qualId, data);
    state = await AsyncValue.guard(() => _repo.getProfile(employeeId));
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
    File? file,
    Uint8List? bytes,
    String? filename,
    String? qualId,
    int? sem,
    String? memberId,
    String? experienceId,
  }) async {
    final url = await _repo.uploadFile(
      employeeId: employeeId,
      kebabType: kebabType,
      file: file,
      bytes: bytes,
      filename: filename,
      qualId: qualId,
      sem: sem,
      memberId: memberId,
      experienceId: experienceId,
    );

    final current = state.asData?.value;
    if (current != null) {
      // Academic / family uploads are applied by the dialog (or already saved server-side
      // when qualId/memberId is present). Avoid rebuilding the profile tree while a dialog
      // is open — that triggers "widget tree was locked" on web.
      if (kebabType == 'marksheet' ||
          kebabType == 'certificate' ||
          kebabType == 'aadhaar-family') {
        return url;
      }

      EmployeeProfile updated = current;
      switch (kebabType) {
        case 'photo':
          updated = current.copyWithMedia(photoUrl: url);
        case 'signature':
          updated = current.copyWithMedia(signatureUrl: url);
        case 'aadhaar-card':
          final personal = current.personalInfo;
          if (personal != null) {
            updated = current.copyWithPersonalInfo(personal.copyWith(aadhaarCardUrl: url));
          }
        case 'pan-card':
          final personal = current.personalInfo;
          if (personal != null) {
            updated = current.copyWithPersonalInfo(personal.copyWith(panCardUrl: url));
          }
        case 'other-document':
          final personal = current.personalInfo;
          if (personal != null) {
            updated = current.copyWithPersonalInfo(personal.copyWith(otherDocumentUrl: url));
          }
        case 'passport':
          final other = current.otherInfo;
          updated = current.copyWithOtherInfo(
            other?.copyWith(passportUrl: url) ??
                OtherInfo(
                  id: '',
                  employeeId: current.id,
                  isHandicapped: false,
                  passportUrl: url,
                ),
          );
        case 'cancelled-cheque':
          final bank = current.bankInfo;
          updated = current.copyWithBankInfo(
            bank?.copyWith(cancelledChequeUrl: url) ??
                BankInfo(
                  id: '',
                  employeeId: current.id,
                  cancelledChequeUrl: url,
                ),
          );
        case 'passbook':
          final bank = current.bankInfo;
          updated = current.copyWithBankInfo(
            bank?.copyWith(passbookUrl: url) ??
                BankInfo(
                  id: '',
                  employeeId: current.id,
                  passbookUrl: url,
                ),
          );
      }
      state = AsyncValue.data(updated);
    }
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
