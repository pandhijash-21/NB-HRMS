/// Domain models for the Employee Profile section.
/// Matches the Prisma schema backend payload from `GET /employees/{id}`.
library;

Map<String, dynamic>? _asMap(Object? value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  return null;
}

List<Map<String, dynamic>> _asMapList(Object? value) {
  if (value is! List) return const [];
  return value.map(_asMap).whereType<Map<String, dynamic>>().toList();
}

class EmployeePosition {
  final String id;
  final String name;
  final String linkedRoleId;
  final String linkedRoleName;

  const EmployeePosition({
    required this.id,
    required this.name,
    required this.linkedRoleId,
    required this.linkedRoleName,
  });

  factory EmployeePosition.fromJson(Map<String, dynamic> json) {
    return EmployeePosition(
      id: json['id']?.toString() ?? '',
      name: json['name'] as String? ?? '',
      linkedRoleId: json['linkedRoleId']?.toString() ?? '',
      linkedRoleName: json['linkedRoleName'] as String? ?? '',
    );
  }
}

class EmployeeProfile {
  final int id;
  final String? abbreviation;
  final String status;
  final String? photoUrl;
  final String? signatureUrl;
  final EmployeePosition? position;
  final GeneralInfo? generalInfo;
  final PersonalInfo? personalInfo;
  final List<AddressInfo> addresses;
  final OtherInfo? otherInfo;
  final List<FamilyMember> familyMembers;
  final List<AcademicQualification> academicQuals;
  final SalaryInfo? salaryInfo;
  final BankInfo? bankInfo;

  const EmployeeProfile({
    required this.id,
    this.abbreviation,
    required this.status,
    this.photoUrl,
    this.signatureUrl,
    this.position,
    this.generalInfo,
    this.personalInfo,
    required this.addresses,
    this.otherInfo,
    required this.familyMembers,
    required this.academicQuals,
    this.salaryInfo,
    this.bankInfo,
  });

  factory EmployeeProfile.fromJson(Map<String, dynamic> json) {
    final general = _asMap(json['generalInfo']);
    final personal = _asMap(json['personalInfo']);
    final other = _asMap(json['otherInfo']);
    final salary = _asMap(json['salaryInfo']);
    final bank = _asMap(json['bankInfo']);
    final position = _asMap(json['position']);

    return EmployeeProfile(
      id: json['id'] is int ? json['id'] as int : int.parse(json['id'].toString()),
      abbreviation: json['abbreviation'] as String?,
      status: json['status'] as String? ?? 'ACTIVE',
      photoUrl: json['photoUrl'] as String?,
      signatureUrl: json['signatureUrl'] as String?,
      position: position != null ? EmployeePosition.fromJson(position) : null,
      generalInfo: general != null ? GeneralInfo.fromJson(general) : null,
      personalInfo: personal != null ? PersonalInfo.fromJson(personal) : null,
      addresses: _asMapList(json['addresses']).map(AddressInfo.fromJson).toList(),
      otherInfo: other != null ? OtherInfo.fromJson(other) : null,
      familyMembers: _asMapList(json['familyMembers']).map(FamilyMember.fromJson).toList(),
      academicQuals: _asMapList(json['academicQuals']).map(AcademicQualification.fromJson).toList(),
      salaryInfo: salary != null ? SalaryInfo.fromJson(salary) : null,
      bankInfo: bank != null ? BankInfo.fromJson(bank) : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'abbreviation': abbreviation,
        'status': status,
        'photoUrl': photoUrl,
        'signatureUrl': signatureUrl,
        'position': position != null
            ? {
                'id': position!.id,
                'name': position!.name,
                'linkedRoleId': position!.linkedRoleId,
                'linkedRoleName': position!.linkedRoleName,
              }
            : null,
        'generalInfo': generalInfo?.toJson(),
        'personalInfo': personalInfo?.toJson(),
        'addresses': addresses.map((e) => e.toJson()).toList(),
        'otherInfo': otherInfo?.toJson(),
        'familyMembers': familyMembers.map((e) => e.toJson()).toList(),
        'academicQuals': academicQuals.map((e) => e.toJson()).toList(),
        'salaryInfo': salaryInfo?.toJson(),
        'bankInfo': bankInfo?.toJson(),
      };

  EmployeeProfile copyWithMedia({String? photoUrl, String? signatureUrl}) {
    return EmployeeProfile(
      id: id,
      abbreviation: abbreviation,
      status: status,
      photoUrl: photoUrl ?? this.photoUrl,
      signatureUrl: signatureUrl ?? this.signatureUrl,
      position: position,
      generalInfo: generalInfo,
      personalInfo: personalInfo,
      addresses: addresses,
      otherInfo: otherInfo,
      familyMembers: familyMembers,
      academicQuals: academicQuals,
      salaryInfo: salaryInfo,
      bankInfo: bankInfo,
    );
  }

  EmployeeProfile copyWithPersonalInfo(PersonalInfo personalInfo) {
    return EmployeeProfile(
      id: id,
      abbreviation: abbreviation,
      status: status,
      photoUrl: photoUrl,
      signatureUrl: signatureUrl,
      position: position,
      generalInfo: generalInfo,
      personalInfo: personalInfo,
      addresses: addresses,
      otherInfo: otherInfo,
      familyMembers: familyMembers,
      academicQuals: academicQuals,
      salaryInfo: salaryInfo,
      bankInfo: bankInfo,
    );
  }

  EmployeeProfile copyWithOtherInfo(OtherInfo otherInfo) {
    return EmployeeProfile(
      id: id,
      abbreviation: abbreviation,
      status: status,
      photoUrl: photoUrl,
      signatureUrl: signatureUrl,
      position: position,
      generalInfo: generalInfo,
      personalInfo: personalInfo,
      addresses: addresses,
      otherInfo: otherInfo,
      familyMembers: familyMembers,
      academicQuals: academicQuals,
      salaryInfo: salaryInfo,
      bankInfo: bankInfo,
    );
  }

  EmployeeProfile copyWithBankInfo(BankInfo bankInfo) {
    return EmployeeProfile(
      id: id,
      abbreviation: abbreviation,
      status: status,
      photoUrl: photoUrl,
      signatureUrl: signatureUrl,
      position: position,
      generalInfo: generalInfo,
      personalInfo: personalInfo,
      addresses: addresses,
      otherInfo: otherInfo,
      familyMembers: familyMembers,
      academicQuals: academicQuals,
      salaryInfo: salaryInfo,
      bankInfo: bankInfo,
    );
  }
}

class GeneralInfo {
  final String id;
  final int employeeId;
  final String fullName;
  final DateTime originalJoiningDate;
  final DateTime joiningDate;
  final String? incrementMonth;
  final String organization;
  final String? instituteId;
  final String? instituteName;
  final String? subOrganization;
  final String department;
  final String? functionalDepartment;
  final int? firstReportingId;
  final int? secondReportingId;
  final int? thirdReportingId;
  final String? firstApproverUserId;
  final String? secondApproverUserId;
  final String? thirdApproverUserId;
  final String employeeCategory;
  final String designation;
  final String? designationId;
  final String? shift;
  final String? appointmentType;
  final String? employeeCode;
  /// Biometric machine Empcode — used only for eTimeOffice punch matching.
  final String? punchId;
  final List<String>? _weeklyOffDays;
  List<String> get weeklyOffDays => _weeklyOffDays == null || _weeklyOffDays!.isEmpty
      ? const ['SUN']
      : _weeklyOffDays!;

  const GeneralInfo({
    required this.id,
    required this.employeeId,
    required this.fullName,
    required this.originalJoiningDate,
    required this.joiningDate,
    this.incrementMonth,
    required this.organization,
    this.instituteId,
    this.instituteName,
    this.subOrganization,
    required this.department,
    this.functionalDepartment,
    this.firstReportingId,
    this.secondReportingId,
    this.thirdReportingId,
    this.firstApproverUserId,
    this.secondApproverUserId,
    this.thirdApproverUserId,
    required this.employeeCategory,
    required this.designation,
    this.designationId,
    this.shift,
    this.appointmentType,
    this.employeeCode,
    this.punchId,
    List<String>? weeklyOffDays,
  }) : _weeklyOffDays = weeklyOffDays;

  factory GeneralInfo.fromJson(Map<String, dynamic> json) {
    final institute = _asMap(json['institute']);
    return GeneralInfo(
      id: json['id'] as String? ?? '',
      employeeId: json['employeeId'] is int ? json['employeeId'] as int : int.parse(json['employeeId'].toString()),
      fullName: json['fullName'] as String? ?? '',
      originalJoiningDate: json['originalJoiningDate'] != null
          ? DateTime.parse(json['originalJoiningDate'].toString())
          : DateTime.now(),
      joiningDate: json['joiningDate'] != null
          ? DateTime.parse(json['joiningDate'].toString())
          : DateTime.now(),
      incrementMonth: json['incrementMonth'] as String?,
      organization: json['organization'] as String? ?? 'GANDHINAGAR UNIVERSITY',
      instituteId: json['instituteId'] as String?,
      instituteName: institute?['name'] as String?,
      subOrganization: json['subOrganization'] as String?,
      department: json['department'] as String? ?? '',
      functionalDepartment: json['functionalDepartment'] as String?,
      firstReportingId: json['firstReportingId'] as int?,
      secondReportingId: json['secondReportingId'] as int?,
      thirdReportingId: json['thirdReportingId'] as int?,
      firstApproverUserId: json['firstApproverUserId'] as String?,
      secondApproverUserId: json['secondApproverUserId'] as String?,
      thirdApproverUserId: json['thirdApproverUserId'] as String?,
      employeeCategory: json['employeeCategory'] as String? ?? 'NON_TEACHING',
      designation: json['designation'] as String? ?? '',
      designationId: json['designationId'] as String?,
      shift: json['shift'] as String?,
      appointmentType: json['appointmentType'] as String?,
      employeeCode: json['employeeCode'] as String?,
      punchId: json['punchId'] as String?,
      weeklyOffDays: (json['weeklyOffDays'] as List?)
              ?.map((e) => e.toString().toUpperCase())
              .toList() ??
          const ['SUN'],
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'employeeId': employeeId,
        'fullName': fullName,
        'originalJoiningDate': originalJoiningDate.toIso8601String(),
        'joiningDate': joiningDate.toIso8601String(),
        'incrementMonth': incrementMonth,
        'organization': organization,
        'instituteId': instituteId,
        'instituteName': instituteName,
        'subOrganization': subOrganization,
        'department': department,
        'functionalDepartment': functionalDepartment,
        'firstReportingId': firstReportingId,
        'secondReportingId': secondReportingId,
        'thirdReportingId': thirdReportingId,
        'firstApproverUserId': firstApproverUserId,
        'secondApproverUserId': secondApproverUserId,
        'thirdApproverUserId': thirdApproverUserId,
        'employeeCategory': employeeCategory,
        'designation': designation,
        'designationId': designationId,
        'shift': shift,
        'appointmentType': appointmentType,
        'employeeCode': employeeCode,
        'punchId': punchId,
        'weeklyOffDays': weeklyOffDays,
      };
}

class PersonalInfo {
  final String id;
  final int employeeId;
  final DateTime birthDate;
  final String? birthPlace;
  final String? homeTown;
  final String gender;
  final String maritalStatus;
  final String nationality;
  final String? motherTongue;
  final String? bloodGroup;
  final String? castCategory;
  final String? subCaste;
  final String? nomineeName;
  final String? nomineeRelation;
  final String? aadhaarNo; // encrypted from server or plain if decryped on download
  final String? panNo;
  final String? aadhaarCardUrl;
  final String? panCardUrl;
  final String? otherDocumentUrl;
  final String? passportNo;
  final String? passportIssuePlace;
  final DateTime? passportIssueDate;
  final DateTime? passportExpiryDate;

  const PersonalInfo({
    required this.id,
    required this.employeeId,
    required this.birthDate,
    this.birthPlace,
    this.homeTown,
    required this.gender,
    required this.maritalStatus,
    required this.nationality,
    this.motherTongue,
    this.bloodGroup,
    this.castCategory,
    this.subCaste,
    this.nomineeName,
    this.nomineeRelation,
    this.aadhaarNo,
    this.panNo,
    this.aadhaarCardUrl,
    this.panCardUrl,
    this.otherDocumentUrl,
    this.passportNo,
    this.passportIssuePlace,
    this.passportIssueDate,
    this.passportExpiryDate,
  });

  factory PersonalInfo.fromJson(Map<String, dynamic> json) {
    return PersonalInfo(
      id: json['id'] as String? ?? '',
      employeeId: json['employeeId'] is int ? json['employeeId'] as int : int.parse(json['employeeId'].toString()),
      birthDate: json['birthDate'] != null ? DateTime.parse(json['birthDate'].toString()) : DateTime.now(),
      birthPlace: json['birthPlace'] as String?,
      homeTown: json['homeTown'] as String?,
      gender: json['gender'] as String? ?? 'MALE',
      maritalStatus: json['maritalStatus'] as String? ?? 'SINGLE',
      nationality: json['nationality'] as String? ?? 'INDIAN',
      motherTongue: json['motherTongue'] as String?,
      bloodGroup: json['bloodGroup'] as String?,
      castCategory: json['castCategory'] as String?,
      subCaste: json['subCaste'] as String?,
      nomineeName: json['nomineeName'] as String?,
      nomineeRelation: json['nomineeRelation'] as String?,
      aadhaarNo: json['aadhaarNo'] as String?,
      panNo: json['panNo'] as String?,
      aadhaarCardUrl: json['aadhaarCardUrl'] as String?,
      panCardUrl: json['panCardUrl'] as String?,
      otherDocumentUrl: json['otherDocumentUrl'] as String?,
      passportNo: json['passportNo'] as String?,
      passportIssuePlace: json['passportIssuePlace'] as String?,
      passportIssueDate: json['passportIssueDate'] != null ? DateTime.parse(json['passportIssueDate'].toString()) : null,
      passportExpiryDate: json['passportExpiryDate'] != null ? DateTime.parse(json['passportExpiryDate'].toString()) : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'employeeId': employeeId,
        'birthDate': birthDate.toIso8601String(),
        'birthPlace': birthPlace,
        'homeTown': homeTown,
        'gender': gender,
        'maritalStatus': maritalStatus,
        'nationality': nationality,
        'motherTongue': motherTongue,
        'bloodGroup': bloodGroup,
        'castCategory': castCategory,
        'subCaste': subCaste,
        'nomineeName': nomineeName,
        'nomineeRelation': nomineeRelation,
        'aadhaarNo': aadhaarNo,
        'panNo': panNo,
        'aadhaarCardUrl': aadhaarCardUrl,
        'panCardUrl': panCardUrl,
        'otherDocumentUrl': otherDocumentUrl,
        'passportNo': passportNo,
        'passportIssuePlace': passportIssuePlace,
        'passportIssueDate': passportIssueDate?.toIso8601String(),
        'passportExpiryDate': passportExpiryDate?.toIso8601String(),
      };

  PersonalInfo copyWith({
    String? aadhaarCardUrl,
    String? panCardUrl,
    String? otherDocumentUrl,
  }) {
    return PersonalInfo(
      id: id,
      employeeId: employeeId,
      birthDate: birthDate,
      birthPlace: birthPlace,
      homeTown: homeTown,
      gender: gender,
      maritalStatus: maritalStatus,
      nationality: nationality,
      motherTongue: motherTongue,
      bloodGroup: bloodGroup,
      castCategory: castCategory,
      subCaste: subCaste,
      nomineeName: nomineeName,
      nomineeRelation: nomineeRelation,
      aadhaarNo: aadhaarNo,
      panNo: panNo,
      aadhaarCardUrl: aadhaarCardUrl ?? this.aadhaarCardUrl,
      panCardUrl: panCardUrl ?? this.panCardUrl,
      otherDocumentUrl: otherDocumentUrl ?? this.otherDocumentUrl,
      passportNo: passportNo,
      passportIssuePlace: passportIssuePlace,
      passportIssueDate: passportIssueDate,
      passportExpiryDate: passportExpiryDate,
    );
  }
}

class AddressInfo {
  final String id;
  final int employeeId;
  final String addressType; // 'LOCAL' or 'PERMANENT'
  final String? flatBlockNo;
  final String? buildingSociety;
  final String? area;
  final String? city;
  final String? state;
  final String? country;
  final String? zipPostalCode;
  final String? phoneNo;
  final String? mobileNo;
  // Local address specific
  final String? intercomNo;
  final String? personalEmail;
  final String? instituteEmail;
  final String? url;

  const AddressInfo({
    required this.id,
    required this.employeeId,
    required this.addressType,
    this.flatBlockNo,
    this.buildingSociety,
    this.area,
    this.city,
    this.state,
    this.country,
    this.zipPostalCode,
    this.phoneNo,
    this.mobileNo,
    this.intercomNo,
    this.personalEmail,
    this.instituteEmail,
    this.url,
  });

  factory AddressInfo.fromJson(Map<String, dynamic> json) {
    final rawType = (json['addressType'] ?? json['address_type'] ?? 'LOCAL').toString();
    return AddressInfo(
      id: json['id']?.toString() ?? '',
      employeeId: json['employeeId'] is int
          ? json['employeeId'] as int
          : int.tryParse('${json['employeeId'] ?? ''}') ?? 0,
      addressType: rawType.toUpperCase(),
      flatBlockNo: json['flatBlockNo'] as String? ?? json['flat_block_no'] as String?,
      buildingSociety: json['buildingSociety'] as String? ?? json['building_society'] as String?,
      area: json['area'] as String?,
      city: json['city'] as String?,
      state: json['state'] as String?,
      country: json['country'] as String? ?? 'INDIA',
      zipPostalCode: json['zipPostalCode'] as String? ?? json['zip_postal_code'] as String?,
      phoneNo: json['phoneNo'] as String? ?? json['phone_no'] as String?,
      mobileNo: json['mobileNo'] as String? ?? json['mobile_no'] as String?,
      intercomNo: json['intercomNo'] as String? ?? json['intercom_no'] as String?,
      personalEmail: json['personalEmail'] as String? ?? json['personal_email'] as String?,
      instituteEmail: json['instituteEmail'] as String? ?? json['institute_email'] as String?,
      url: json['url'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'employeeId': employeeId,
        'addressType': addressType,
        'flatBlockNo': flatBlockNo,
        'buildingSociety': buildingSociety,
        'area': area,
        'city': city,
        'state': state,
        'country': country,
        'zipPostalCode': zipPostalCode,
        'phoneNo': phoneNo,
        'mobileNo': mobileNo,
        'intercomNo': intercomNo,
        'personalEmail': personalEmail,
        'instituteEmail': instituteEmail,
        'url': url,
      };
}

class OtherInfo {
  final String id;
  final int employeeId;
  final String? skillSet;
  final String? hobbies;
  final String? strength;
  final String? weakness;
  final bool isHandicapped;
  final String? handicapDetails;
  final String? passportUrl;
  final double? heightInFeet;
  final double? weightInKg;

  const OtherInfo({
    required this.id,
    required this.employeeId,
    this.skillSet,
    this.hobbies,
    this.strength,
    this.weakness,
    required this.isHandicapped,
    this.handicapDetails,
    this.passportUrl,
    this.heightInFeet,
    this.weightInKg,
  });

  factory OtherInfo.fromJson(Map<String, dynamic> json) {
    return OtherInfo(
      id: json['id'] as String? ?? '',
      employeeId: json['employeeId'] is int ? json['employeeId'] as int : int.parse(json['employeeId'].toString()),
      skillSet: json['skillSet'] as String?,
      hobbies: json['hobbies'] as String?,
      strength: json['strength'] as String?,
      weakness: json['weakness'] as String?,
      isHandicapped: json['isHandicapped'] == true,
      handicapDetails: json['handicapDetails'] as String?,
      passportUrl: json['passportUrl'] as String?,
      heightInFeet: json['heightInFeet'] != null ? double.tryParse(json['heightInFeet'].toString()) : null,
      weightInKg: json['weightInKg'] != null ? double.tryParse(json['weightInKg'].toString()) : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'employeeId': employeeId,
        'skillSet': skillSet,
        'hobbies': hobbies,
        'strength': strength,
        'weakness': weakness,
        'isHandicapped': isHandicapped,
        'handicapDetails': handicapDetails,
        'passportUrl': passportUrl,
        'heightInFeet': heightInFeet,
        'weightInKg': weightInKg,
      };

  OtherInfo copyWith({String? passportUrl}) {
    return OtherInfo(
      id: id,
      employeeId: employeeId,
      skillSet: skillSet,
      hobbies: hobbies,
      strength: strength,
      weakness: weakness,
      isHandicapped: isHandicapped,
      handicapDetails: handicapDetails,
      passportUrl: passportUrl ?? this.passportUrl,
      heightInFeet: heightInFeet,
      weightInKg: weightInKg,
    );
  }
}

class FamilyMember {
  final String id;
  final int employeeId;
  final String relation;
  final String name;
  final String? city;
  final String? mobileNo;
  final String? personalEmail;
  final DateTime? dateOfBirth;
  final String? aadhaarNo;
  final String? aadhaarUrl;
  final bool isNominee;
  final bool isDependent;
  final bool isEmployed;
  final String? employerName;

  const FamilyMember({
    required this.id,
    required this.employeeId,
    required this.relation,
    required this.name,
    this.city,
    this.mobileNo,
    this.personalEmail,
    this.dateOfBirth,
    this.aadhaarNo,
    this.aadhaarUrl,
    required this.isNominee,
    this.isDependent = false,
    this.isEmployed = false,
    this.employerName,
  });

  factory FamilyMember.fromJson(Map<String, dynamic> json) {
    return FamilyMember(
      id: json['id'] as String? ?? '',
      employeeId: json['employeeId'] is int ? json['employeeId'] as int : int.parse(json['employeeId'].toString()),
      relation: json['relation'] as String? ?? 'OTHER',
      name: json['name'] as String? ?? '',
      city: json['city'] as String?,
      mobileNo: json['mobileNo'] as String?,
      personalEmail: json['personalEmail'] as String?,
      dateOfBirth: json['dateOfBirth'] != null ? DateTime.parse(json['dateOfBirth'].toString()) : null,
      aadhaarNo: json['aadhaarNo'] as String?,
      aadhaarUrl: json['aadhaarUrl'] as String?,
      isNominee: json['isNominee'] == true,
      isDependent: json['isDependent'] == true || json['dependent'] == true,
      isEmployed: json['isEmployed'] == true || json['employed'] == true,
      employerName: json['employerName'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'employeeId': employeeId,
        'relation': relation,
        'name': name,
        'city': city,
        'mobileNo': mobileNo,
        'personalEmail': personalEmail,
        'dateOfBirth': dateOfBirth?.toIso8601String(),
        'aadhaarNo': aadhaarNo,
        'aadhaarUrl': aadhaarUrl,
        'isNominee': isNominee,
        'isDependent': isDependent,
        'isEmployed': isEmployed,
        'employerName': employerName,
      };

  FamilyMember copyWith({String? aadhaarUrl}) {
    return FamilyMember(
      id: id,
      employeeId: employeeId,
      relation: relation,
      name: name,
      city: city,
      mobileNo: mobileNo,
      personalEmail: personalEmail,
      dateOfBirth: dateOfBirth,
      aadhaarNo: aadhaarNo,
      aadhaarUrl: aadhaarUrl ?? this.aadhaarUrl,
      isNominee: isNominee,
      isDependent: isDependent,
      isEmployed: isEmployed,
      employerName: employerName,
    );
  }
}

class AcademicQualification {
  final String id;
  final int employeeId;
  final String degreeType;
  final String? degreeName;
  final String? medium;
  final String boardUniversity;
  final String schoolCollege;
  final int passingYear;
  final double? percentage;
  final String? grade;
  final String? specialization;
  final String? certificateUrl;
  final String? sem1MarksheetUrl;
  final String? sem2MarksheetUrl;
  final String? sem3MarksheetUrl;
  final String? sem4MarksheetUrl;
  final String? sem5MarksheetUrl;
  final String? sem6MarksheetUrl;
  final String? sem7MarksheetUrl;
  final String? sem8MarksheetUrl;
  final bool isVerified;

  const AcademicQualification({
    required this.id,
    required this.employeeId,
    required this.degreeType,
    this.degreeName,
    this.medium,
    required this.boardUniversity,
    required this.schoolCollege,
    required this.passingYear,
    this.percentage,
    this.grade,
    this.specialization,
    this.certificateUrl,
    this.sem1MarksheetUrl,
    this.sem2MarksheetUrl,
    this.sem3MarksheetUrl,
    this.sem4MarksheetUrl,
    this.sem5MarksheetUrl,
    this.sem6MarksheetUrl,
    this.sem7MarksheetUrl,
    this.sem8MarksheetUrl,
    required this.isVerified,
  });

  factory AcademicQualification.fromJson(Map<String, dynamic> json) {
    return AcademicQualification(
      id: json['id'] as String? ?? '',
      employeeId: json['employeeId'] is int ? json['employeeId'] as int : int.parse(json['employeeId'].toString()),
      degreeType: json['degreeType'] as String? ?? 'SSC',
      degreeName: json['degreeName'] as String?,
      medium: json['medium'] as String?,
      boardUniversity: json['boardUniversity'] as String? ?? '',
      schoolCollege: json['schoolCollege'] as String? ?? '',
      passingYear: json['passingYear'] is int ? json['passingYear'] as int : int.parse(json['passingYear'].toString()),
      percentage: json['percentage'] != null ? double.tryParse(json['percentage'].toString()) : null,
      grade: json['grade'] as String?,
      specialization: json['specialization'] as String?,
      certificateUrl: json['certificateUrl'] as String?,
      sem1MarksheetUrl: json['sem1MarksheetUrl'] as String?,
      sem2MarksheetUrl: json['sem2MarksheetUrl'] as String?,
      sem3MarksheetUrl: json['sem3MarksheetUrl'] as String?,
      sem4MarksheetUrl: json['sem4MarksheetUrl'] as String?,
      sem5MarksheetUrl: json['sem5MarksheetUrl'] as String?,
      sem6MarksheetUrl: json['sem6MarksheetUrl'] as String?,
      sem7MarksheetUrl: json['sem7MarksheetUrl'] as String?,
      sem8MarksheetUrl: json['sem8MarksheetUrl'] as String?,
      isVerified: json['isVerified'] == true,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'employeeId': employeeId,
        'degreeType': degreeType,
        'degreeName': degreeName,
        'medium': medium,
        'boardUniversity': boardUniversity,
        'schoolCollege': schoolCollege,
        'passingYear': passingYear,
        'percentage': percentage,
        'grade': grade,
        'specialization': specialization,
        'certificateUrl': certificateUrl,
        'sem1MarksheetUrl': sem1MarksheetUrl,
        'sem2MarksheetUrl': sem2MarksheetUrl,
        'sem3MarksheetUrl': sem3MarksheetUrl,
        'sem4MarksheetUrl': sem4MarksheetUrl,
        'sem5MarksheetUrl': sem5MarksheetUrl,
        'sem6MarksheetUrl': sem6MarksheetUrl,
        'sem7MarksheetUrl': sem7MarksheetUrl,
        'sem8MarksheetUrl': sem8MarksheetUrl,
        'isVerified': isVerified,
      };
}

class SalaryInfo {
  final String id;
  final int employeeId;
  final String? payCommission;
  final String? payGrade;
  final double? basicSalary;
  final double? agp;
  final double? grossSalary;

  const SalaryInfo({
    required this.id,
    required this.employeeId,
    this.payCommission,
    this.payGrade,
    this.basicSalary,
    this.agp,
    this.grossSalary,
  });

  factory SalaryInfo.fromJson(Map<String, dynamic> json) {
    final pcRef = json['payCommissionRef'] ?? json['pay_commission_ref'];
    String? payCommission = json['payCommission'] as String?;
    if ((payCommission == null || payCommission.isEmpty) && pcRef is Map) {
      payCommission = pcRef['name']?.toString() ?? pcRef['code']?.toString();
    }
    return SalaryInfo(
      id: json['id'] as String? ?? '',
      employeeId: json['employeeId'] is int
          ? json['employeeId'] as int
          : int.tryParse(json['employeeId']?.toString() ?? '') ?? 0,
      payCommission: payCommission,
      payGrade: json['payGrade'] as String?,
      basicSalary: json['basicSalary'] != null ? double.tryParse(json['basicSalary'].toString()) : null,
      agp: json['agp'] != null ? double.tryParse(json['agp'].toString()) : null,
      grossSalary: json['grossSalary'] != null ? double.tryParse(json['grossSalary'].toString()) : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'employeeId': employeeId,
        'payCommission': payCommission,
        'payGrade': payGrade,
        'basicSalary': basicSalary,
        'agp': agp,
        'grossSalary': grossSalary,
      };
}

class BankInfo {
  final String id;
  final int employeeId;
  final String? bankName;
  final String? bankAccountNo;
  final String? bankBranchCode;
  final String? ifscCode;
  final String? cancelledChequeUrl;
  final String? passbookUrl;

  const BankInfo({
    required this.id,
    required this.employeeId,
    this.bankName,
    this.bankAccountNo,
    this.bankBranchCode,
    this.ifscCode,
    this.cancelledChequeUrl,
    this.passbookUrl,
  });

  factory BankInfo.fromJson(Map<String, dynamic> json) {
    return BankInfo(
      id: json['id'] as String? ?? '',
      employeeId: json['employeeId'] is int ? json['employeeId'] as int : int.parse(json['employeeId'].toString()),
      bankName: json['bankName'] as String?,
      bankAccountNo: json['bankAccountNo'] as String?,
      bankBranchCode: json['bankBranchCode'] as String?,
      ifscCode: json['ifscCode'] as String?,
      cancelledChequeUrl: json['cancelledChequeUrl'] as String?,
      passbookUrl: json['passbookUrl'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'employeeId': employeeId,
        'bankName': bankName,
        'bankAccountNo': bankAccountNo,
        'bankBranchCode': bankBranchCode,
        'ifscCode': ifscCode,
        'cancelledChequeUrl': cancelledChequeUrl,
        'passbookUrl': passbookUrl,
      };

  BankInfo copyWith({
    String? cancelledChequeUrl,
    String? passbookUrl,
    String? bankName,
    String? bankAccountNo,
    String? bankBranchCode,
    String? ifscCode,
  }) {
    return BankInfo(
      id: id,
      employeeId: employeeId,
      bankName: bankName ?? this.bankName,
      bankAccountNo: bankAccountNo ?? this.bankAccountNo,
      bankBranchCode: bankBranchCode ?? this.bankBranchCode,
      ifscCode: ifscCode ?? this.ifscCode,
      cancelledChequeUrl: cancelledChequeUrl ?? this.cancelledChequeUrl,
      passbookUrl: passbookUrl ?? this.passbookUrl,
    );
  }
}
