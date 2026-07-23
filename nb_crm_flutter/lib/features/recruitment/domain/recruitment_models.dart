import 'recruitment_dates.dart';

class JobRequirement {
  final String id;
  final String instituteId;
  final String department;
  final String designationId;
  final String employmentTypeCode;
  final String jobLocation;
  final String branchLocation;
  final int vacancies;
  final String? reportingManagerUserId;
  final double? ctc;
  final String? requiredEducation;
  final String? requiredExperience;
  final String? requiredSkills;
  final bool isActive;
  final String? instituteName;
  final String? designationName;
  final int candidateCount;

  const JobRequirement({
    required this.id,
    required this.instituteId,
    required this.department,
    required this.designationId,
    required this.employmentTypeCode,
    required this.jobLocation,
    required this.branchLocation,
    required this.vacancies,
    this.reportingManagerUserId,
    this.ctc,
    this.requiredEducation,
    this.requiredExperience,
    this.requiredSkills,
    required this.isActive,
    this.instituteName,
    this.designationName,
    this.candidateCount = 0,
  });

  factory JobRequirement.fromJson(Map<String, dynamic> json) {
    final institute = json['institute'];
    final designation = json['designation'];
    final count = json['_count'];
    return JobRequirement(
      id: json['id']?.toString() ?? '',
      instituteId: json['instituteId']?.toString() ?? '',
      department: json['department']?.toString() ?? '',
      designationId: json['designationId']?.toString() ?? '',
      employmentTypeCode: json['employmentTypeCode']?.toString() ?? '',
      jobLocation: json['jobLocation']?.toString() ?? '',
      branchLocation: json['branchLocation']?.toString() ?? '',
      vacancies: (json['vacancies'] as num?)?.toInt() ?? 1,
      reportingManagerUserId: json['reportingManagerUserId']?.toString(),
      ctc: json['ctc'] == null ? null : double.tryParse(json['ctc'].toString()),
      requiredEducation: json['requiredEducation']?.toString(),
      requiredExperience: json['requiredExperience']?.toString(),
      requiredSkills: json['requiredSkills']?.toString(),
      isActive: json['isActive'] == true,
      instituteName: institute is Map ? institute['name']?.toString() : null,
      designationName: designation is Map ? designation['name']?.toString() : null,
      candidateCount: count is Map ? (count['candidates'] as num?)?.toInt() ?? 0 : 0,
    );
  }

  String get title => designationName?.isNotEmpty == true
      ? designationName!
      : 'Requirement';
}

class InterviewRound {
  final String id;
  final String candidateId;
  final int roundNumber;
  final String interviewTypeCode;
  final String interviewerUserId;
  final String? interviewerName;
  final DateTime? scheduledAt;
  final String statusCode;
  final String? remarks;
  final DateTime? completedAt;
  final DateTime? adminConfirmedAt;
  final String? adminConfirmedBy;

  const InterviewRound({
    required this.id,
    required this.candidateId,
    required this.roundNumber,
    required this.interviewTypeCode,
    required this.interviewerUserId,
    this.interviewerName,
    this.scheduledAt,
    required this.statusCode,
    this.remarks,
    this.completedAt,
    this.adminConfirmedAt,
    this.adminConfirmedBy,
  });

  bool get isLocked => adminConfirmedAt != null;

  bool get canInterviewerUpdate => !isLocked;

  bool get awaitsAdminConfirm =>
      !isLocked &&
      statusCode != 'INTERVIEW_SCHEDULED' &&
      statusCode != 'RESCHEDULED';

  factory InterviewRound.fromJson(Map<String, dynamic> json) {
    final scheduledRaw = json['scheduledAt'];
    return InterviewRound(
      id: json['id']?.toString() ?? '',
      candidateId: json['candidateId']?.toString() ?? '',
      roundNumber: (json['roundNumber'] as num?)?.toInt() ?? 1,
      interviewTypeCode: json['interviewTypeCode']?.toString() ?? '',
      interviewerUserId: json['interviewerUserId']?.toString() ?? '',
      interviewerName: json['interviewerName']?.toString(),
      scheduledAt: scheduledRaw != null ? DateTime.tryParse(scheduledRaw.toString()) : null,
      statusCode: json['statusCode']?.toString() ?? 'INTERVIEW_SCHEDULED',
      remarks: json['remarks']?.toString(),
      completedAt: json['completedAt'] != null
          ? DateTime.tryParse(json['completedAt'].toString())
          : null,
      adminConfirmedAt: json['adminConfirmedAt'] != null
          ? DateTime.tryParse(json['adminConfirmedAt'].toString())
          : null,
      adminConfirmedBy: json['adminConfirmedBy']?.toString(),
    );
  }
}

class RecruitmentCandidate {
  final String id;
  final String requirementId;
  final String fullName;
  final String contactNumber;
  final String sourceCode;
  final DateTime? resumeReceivedDate;
  final String? resumeUrl;
  final String? resumeFileName;
  final String currentStatusCode;
  final double? offeredSalary;
  final DateTime? expectedJoiningDate;
  final DateTime? actualJoiningDate;
  final String? hireRemarks;
  final int? hiredEmployeeId;
  final JobRequirement? requirement;
  final List<InterviewRound> rounds;
  final String? hiredEmployeeCode;

  const RecruitmentCandidate({
    required this.id,
    required this.requirementId,
    required this.fullName,
    required this.contactNumber,
    required this.sourceCode,
    this.resumeReceivedDate,
    this.resumeUrl,
    this.resumeFileName,
    required this.currentStatusCode,
    this.offeredSalary,
    this.expectedJoiningDate,
    this.actualJoiningDate,
    this.hireRemarks,
    this.hiredEmployeeId,
    this.requirement,
    this.rounds = const [],
    this.hiredEmployeeCode,
  });

  factory RecruitmentCandidate.fromJson(Map<String, dynamic> json) {
    final req = json['requirement'];
    final hired = json['hiredEmployee'];
    final roundsRaw = json['rounds'];
    return RecruitmentCandidate(
      id: json['id']?.toString() ?? '',
      requirementId: json['requirementId']?.toString() ?? '',
      fullName: json['fullName']?.toString() ?? '',
      contactNumber: json['contactNumber']?.toString() ?? '',
      sourceCode: json['sourceCode']?.toString() ?? '',
      resumeReceivedDate: parseApiDate(json['resumeReceivedDate']),
      resumeUrl: json['resumeUrl']?.toString(),
      resumeFileName: json['resumeFileName']?.toString(),
      currentStatusCode: json['currentStatusCode']?.toString() ?? '',
      offeredSalary: json['offeredSalary'] == null
          ? null
          : double.tryParse(json['offeredSalary'].toString()),
      expectedJoiningDate: parseApiDate(json['expectedJoiningDate']),
      actualJoiningDate: parseApiDate(json['actualJoiningDate']),
      hireRemarks: json['hireRemarks']?.toString(),
      hiredEmployeeId: json['hiredEmployeeId'] == null
          ? null
          : int.tryParse(json['hiredEmployeeId'].toString()),
      requirement: req is Map
          ? JobRequirement.fromJson(Map<String, dynamic>.from(req))
          : null,
      rounds: roundsRaw is List
          ? roundsRaw
              .map((e) => InterviewRound.fromJson(Map<String, dynamic>.from(e as Map)))
              .toList()
          : const [],
      hiredEmployeeCode: hired is Map
          ? (hired['generalInfo'] is Map
              ? hired['generalInfo']['employeeCode']?.toString()
              : null)
          : null,
    );
  }

  bool get canHire => currentStatusCode == 'SELECTED' && hiredEmployeeId == null;

  bool get canScheduleNext =>
      hiredEmployeeId == null &&
      (currentStatusCode == 'SELECTED_FOR_NEXT_ROUND' ||
          currentStatusCode == 'FINAL_ROUND');
}

class MyInterviewItem {
  final InterviewRound round;
  final RecruitmentCandidate candidate;
  final bool canUpdate;

  const MyInterviewItem({
    required this.round,
    required this.candidate,
    this.canUpdate = true,
  });

  factory MyInterviewItem.fromJson(Map<String, dynamic> json) {
    final cand = json['candidate'];
    final round = InterviewRound.fromJson(json);
    final canUpdate = json['canUpdate'] == true ||
        (json['canUpdate'] == null && !round.isLocked);
    return MyInterviewItem(
      round: round,
      canUpdate: canUpdate,
      candidate: cand is Map
          ? RecruitmentCandidate.fromJson(Map<String, dynamic>.from(cand))
          : RecruitmentCandidate(
              id: '',
              requirementId: '',
              fullName: 'Unknown',
              contactNumber: '',
              sourceCode: '',
              currentStatusCode: '',
            ),
    );
  }
}
