class HubPartner {

  final String id;
  final String role;
  final String email;
  final String username;
  final String? phone;
  final String? companyOrFirmName;
  final String? contactPersonName;
  final String? companyLogo;
  final String? professionalStream;
  final String? constitution;
  final String? icaiMembershipNo;
  final String? copNo;
  final String? pan;
  final String? gstin;
  final String? reraNo;
  final String? dateOfIncorporation;
  final String? address;
  final String? city;
  final String? pincode;
  final String? website;
  final List<String> natureOfBusiness;
  final List<String> areasOfPractice;
  final bool declarationAccepted;
  final String status;
  final String permissionLevel;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const HubPartner({
    required this.id,
    required this.role,
    required this.email,
    required this.username,
    this.phone,
    this.companyOrFirmName,
    this.contactPersonName,
    this.companyLogo,
    this.professionalStream,
    this.constitution,
    this.icaiMembershipNo,
    this.copNo,
    this.pan,
    this.gstin,
    this.reraNo,
    this.dateOfIncorporation,
    this.address,
    this.city,
    this.pincode,
    this.website,
    this.natureOfBusiness = const [],
    this.areasOfPractice = const [],
    this.declarationAccepted = false,
    this.status = 'ACTIVE',
    this.permissionLevel = 'L1',
    this.createdAt,
    this.updatedAt,
  });

  factory HubPartner.fromJson(Map<String, dynamic> json) {
    List<String> parseStringList(dynamic raw) {
      if (raw == null) return [];
      if (raw is List) {
        return raw.map((e) => e.toString().trim()).where((e) => e.isNotEmpty).toList();
      }
      if (raw is String) {
        return raw.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
      }
      return [];
    }

    DateTime? parseDateTime(dynamic raw) {
      if (raw == null) return null;
      if (raw is DateTime) return raw;
      if (raw is String && raw.trim().isNotEmpty) {
        return DateTime.tryParse(raw.trim());
      }
      return null;
    }

    return HubPartner(
      id: (json['id'] ?? '').toString(),
      role: (json['role'] ?? 'CP').toString().toUpperCase(),
      email: (json['email'] ?? '').toString(),
      username: (json['username'] ?? '').toString(),
      phone: json['phone']?.toString(),
      companyOrFirmName: (json['company_or_firm_name'] ?? json['companyOrFirmName'] ?? json['firmName'] ?? json['companyName'])?.toString(),
      contactPersonName: (json['contact_person_name'] ?? json['contactPersonName'] ?? json['name'] ?? json['fullName'])?.toString(),
      companyLogo: (json['company_logo'] ?? json['companyLogo'])?.toString(),
      professionalStream: (json['professional_stream'] ?? json['professionalStream'])?.toString(),
      constitution: json['constitution']?.toString(),
      icaiMembershipNo: (json['icai_membership_no'] ?? json['icaiMembershipNo'])?.toString(),
      copNo: (json['cop_no'] ?? json['copNo'])?.toString(),
      pan: json['pan']?.toString(),
      gstin: json['gstin']?.toString(),
      reraNo: (json['rera_no'] ?? json['reraNo'])?.toString(),
      dateOfIncorporation: (json['date_of_incorporation'] ?? json['dateOfIncorporation'])?.toString(),
      address: json['address']?.toString(),
      city: json['city']?.toString(),
      pincode: json['pincode']?.toString(),
      website: json['website']?.toString(),
      natureOfBusiness: parseStringList(json['nature_of_business'] ?? json['natureOfBusiness']),
      areasOfPractice: parseStringList(json['areas_of_practice'] ?? json['areasOfPractice']),
      declarationAccepted: json['declaration_accepted'] == true ||
          json['declarationAccepted'] == true ||
          json['declaration_accepted'] == 1,
      status: (json['status'] ?? 'ACTIVE').toString().toUpperCase(),
      permissionLevel: (json['permission_level'] ?? json['permissionLevel'] ?? 'READ_ONLY').toString(),
      createdAt: parseDateTime(json['created_at'] ?? json['createdAt']),
      updatedAt: parseDateTime(json['updated_at'] ?? json['updatedAt']),
    );
  }

  Map<String, dynamic> toJson() {
    final firm = companyOrFirmName?.trim();
    final contact = contactPersonName?.trim();
    return {
      'id': id,
      'role': role,
      'email': email.trim().toLowerCase(),
      'username': username.trim(),
      if (phone != null) 'phone': phone,
      if (firm != null && firm.isNotEmpty) ...{
        'company_or_firm_name': firm,
        'companyOrFirmName': firm,
      },
      if (contact != null && contact.isNotEmpty) ...{
        'contact_person_name': contact,
        'contactPersonName': contact,
        'name': contact,
      },
      if (companyLogo != null) ...{
        'company_logo': companyLogo,
        'companyLogo': companyLogo,
      },
      if (professionalStream != null) ...{
        'professional_stream': professionalStream,
        'professionalStream': professionalStream,
      },
      if (constitution != null) 'constitution': constitution,
      if (icaiMembershipNo != null) ...{
        'icai_membership_no': icaiMembershipNo,
        'icaiMembershipNo': icaiMembershipNo,
      },
      if (copNo != null) ...{
        'cop_no': copNo,
        'copNo': copNo,
      },
      if (pan != null) 'pan': pan,
      if (gstin != null) 'gstin': gstin,
      if (reraNo != null) ...{
        'rera_no': reraNo,
        'reraNo': reraNo,
      },
      if (dateOfIncorporation != null) ...{
        'date_of_incorporation': dateOfIncorporation,
        'dateOfIncorporation': dateOfIncorporation,
      },
      if (address != null) 'address': address,
      if (city != null) 'city': city,
      if (pincode != null) 'pincode': pincode,
      if (website != null) 'website': website,
      'nature_of_business': natureOfBusiness,
      'areas_of_practice': areasOfPractice,
      'declaration_accepted': declarationAccepted,
      'declarationAccepted': declarationAccepted,
      'status': status,
      'permission_level': permissionLevel,
      'permissionLevel': permissionLevel,
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
      if (updatedAt != null) 'updated_at': updatedAt!.toIso8601String(),
    };
  }

  String get displayName {
    if (companyOrFirmName != null && companyOrFirmName!.trim().isNotEmpty) {
      return companyOrFirmName!.trim();
    }
    if (contactPersonName != null && contactPersonName!.trim().isNotEmpty) {
      return contactPersonName!.trim();
    }
    return username;
  }

  String get roleDisplay {
    switch (role.toUpperCase()) {
      case 'CP':
        return 'Channel Partner (CP)';
      case 'AP':
        return 'Associate Partner (AP)';
      case 'CA':
        return 'Chartered Accountant (CA)';
      default:
        return role;
    }
  }

  bool get isActive => status.toUpperCase() == 'ACTIVE';

  String get formattedAddress {
    final parts = [
      if (address != null && address!.trim().isNotEmpty) address!.trim(),
      if (city != null && city!.trim().isNotEmpty) city!.trim(),
      if (pincode != null && pincode!.trim().isNotEmpty) pincode!.trim(),
    ];
    return parts.join(', ');
  }
}
