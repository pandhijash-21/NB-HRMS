import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/bloc/load_status.dart';
import '../../data/profile_repository.dart';
import '../../domain/profile_models.dart';
import 'profile_state.dart';

class ProfileCubit extends Cubit<ProfileState> {
  ProfileCubit({required this.profileRepository}) : super(const ProfileState());

  final ProfileRepository profileRepository;

  int? get employeeId => state.employeeId;

  Future<void> loadProfile(int id) async {
    emit(state.copyWith(status: LoadStatus.loading, employeeId: id));
    try {
      final profile = await profileRepository.getProfile(id);
      emit(state.copyWith(status: LoadStatus.success, profile: profile));
    } catch (e) {
      emit(state.copyWith(status: LoadStatus.failure, errorMessage: e.toString()));
    }
  }

  Future<void> refresh() async {
    final id = state.employeeId;
    if (id == null) return;
    try {
      final profile = await profileRepository.getProfile(id);
      emit(state.copyWith(status: LoadStatus.success, profile: profile));
    } catch (e) {
      emit(state.copyWith(errorMessage: e.toString()));
    }
  }

  Future<Map<String, dynamic>?> updateGeneralInfoDirect(Map<String, dynamic> data) async {
    final id = state.employeeId;
    if (id == null) throw Exception('No employee ID selected.');
    final rematch = await profileRepository.updateGeneralInfo(id, data);
    final profile = await profileRepository.getProfile(id);
    emit(state.copyWith(profile: profile));
    return rematch;
  }

  Future<void> updateEmployeeAbbreviation(String? abbreviation) async {
    final id = state.employeeId;
    if (id == null) throw Exception('No employee ID selected.');
    if (abbreviation == null || abbreviation.trim().isEmpty) return;
    await profileRepository.updateEmployeeCore(id, {'abbreviation': abbreviation.trim()});
    final profile = await profileRepository.getProfile(id);
    emit(state.copyWith(profile: profile));
  }

  Future<void> updatePersonalInfoDirect(Map<String, dynamic> data) async {
    final id = state.employeeId;
    if (id == null) throw Exception('No employee ID selected.');
    await profileRepository.updatePersonalInfoDirect(id, data);
    final profile = await profileRepository.getProfile(id);
    emit(state.copyWith(profile: profile));
  }

  Future<bool> updateAddressInfoDirect(String type, Map<String, dynamic> data) async {
    final id = state.employeeId;
    if (id == null) throw Exception('No employee ID selected.');
    final requiresReverify = await profileRepository.updateAddressInfoDirect(id, type, data);
    final profile = await profileRepository.getProfile(id);
    emit(state.copyWith(profile: profile));
    return requiresReverify;
  }

  Future<void> submitPersonalChangeRequest(Map<String, dynamic> data) async {
    await profileRepository.submitChangeRequest(module: 'PERSONAL', newData: data);
    await loadPendingChangeRequest('PERSONAL');
  }

  Future<void> submitAddressChangeRequest({
    required Map<String, dynamic> local,
    required Map<String, dynamic> permanent,
  }) async {
    await profileRepository.submitChangeRequest(module: 'ADDRESS_LOCAL', newData: local);
    await profileRepository.submitChangeRequest(module: 'ADDRESS_PERMANENT', newData: permanent);
    await loadPendingChangeRequest('ADDRESS_LOCAL');
    await loadPendingChangeRequest('ADDRESS_PERMANENT');
  }

  Future<void> submitOtherChangeRequest(Map<String, dynamic> data) async {
    await profileRepository.submitChangeRequest(module: 'OTHER', newData: data);
    await loadPendingChangeRequest('OTHER');
  }

  Future<void> submitBankChangeRequest(Map<String, dynamic> data) async {
    await profileRepository.submitChangeRequest(module: 'BANK', newData: data);
    await loadPendingChangeRequest('BANK');
  }

  Future<void> updateBankInfo(Map<String, dynamic> data) async {
    final id = state.employeeId;
    if (id == null) throw Exception('No employee ID selected.');
    await profileRepository.updateBankInfo(id, data);
    final profile = await profileRepository.getProfile(id);
    emit(state.copyWith(profile: profile));
  }

  Future<void> updateOtherInfo(Map<String, dynamic> data) async {
    final id = state.employeeId;
    if (id == null) throw Exception('No employee ID selected.');
    await profileRepository.updateOtherInfo(id, data);
    final profile = await profileRepository.getProfile(id);
    emit(state.copyWith(profile: profile));
  }

  Future<String?> addFamilyMember(Map<String, dynamic> data) async {
    final id = state.employeeId;
    if (id == null) throw Exception('No employee ID selected.');
    final createdId = await profileRepository.addFamilyMember(id, data);
    final profile = await profileRepository.getProfile(id);
    emit(state.copyWith(profile: profile));
    return createdId;
  }

  Future<void> updateFamilyMember(String memberId, Map<String, dynamic> data) async {
    final id = state.employeeId;
    if (id == null) throw Exception('No employee ID selected.');
    await profileRepository.updateFamilyMember(id, memberId, data);
    final profile = await profileRepository.getProfile(id);
    emit(state.copyWith(profile: profile));
  }

  Future<void> deleteFamilyMember(String memberId) async {
    final id = state.employeeId;
    if (id == null) throw Exception('No employee ID selected.');
    await profileRepository.deleteFamilyMember(id, memberId);
    final profile = await profileRepository.getProfile(id);
    emit(state.copyWith(profile: profile));
  }

  Future<void> addAcademicQualification(Map<String, dynamic> data) async {
    final id = state.employeeId;
    if (id == null) throw Exception('No employee ID selected.');
    await profileRepository.addAcademicQualification(id, data);
    final profile = await profileRepository.getProfile(id);
    emit(state.copyWith(profile: profile));
  }

  Future<void> updateAcademicQualification(String qualId, Map<String, dynamic> data) async {
    final id = state.employeeId;
    if (id == null) throw Exception('No employee ID selected.');
    await profileRepository.updateAcademicQualification(id, qualId, data);
    final profile = await profileRepository.getProfile(id);
    emit(state.copyWith(profile: profile));
  }

  Future<void> deleteAcademicQualification(String qualId) async {
    final id = state.employeeId;
    if (id == null) throw Exception('No employee ID selected.');
    await profileRepository.deleteAcademicQualification(id, qualId);
    final profile = await profileRepository.getProfile(id);
    emit(state.copyWith(profile: profile));
  }

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
    final id = state.employeeId;
    if (id == null) throw Exception('No employee ID selected.');
    final url = await profileRepository.uploadFile(
      employeeId: id,
      kebabType: kebabType,
      file: file,
      bytes: bytes,
      filename: filename,
      qualId: qualId,
      sem: sem,
      memberId: memberId,
      experienceId: experienceId,
    );

    final current = state.profile;
    if (current != null) {
      if (kebabType == 'marksheet' ||
          kebabType == 'certificate' ||
          kebabType == 'aadhaar-family' ||
          kebabType == 'experience-letter' ||
          kebabType == 'last-paycheck' ||
          kebabType == 'recommendation') {
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
      emit(state.copyWith(profile: updated));
    }
    return url;
  }

  Future<Map<String, dynamic>?> loadPendingChangeRequest(String module) async {
    try {
      final res = await profileRepository.getPendingChangeRequest(module);
      final updated = Map<String, Map<String, dynamic>?>.from(state.pendingChangeRequests);
      updated[module] = res;
      emit(state.copyWith(pendingChangeRequests: updated));
      return res;
    } catch (_) {
      return null;
    }
  }
}
