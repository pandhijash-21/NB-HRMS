/// Shared company-profile fields used by Organization and Institute.
class CompanyProfileFields {
  const CompanyProfileFields({
    this.registrationNo,
    this.establishmentYear,
    this.contactPerson,
    this.mobileNo,
    this.contactNo,
    this.email,
    this.webAddress,
    this.panNo,
    this.gstNo,
    this.cinNo,
    this.country,
    this.state,
    this.city,
    this.address1,
    this.address2,
    this.pinCode,
    this.tagLine,
    this.hostingUrl,
    this.pageSize,
    this.dateFormat,
    this.timeZone,
    this.socialPostUrl,
    this.bankName,
    this.accountHolderName,
    this.bankAccountNo,
    this.ifscCode,
    this.bankBranch,
  });

  final String? registrationNo;
  final int? establishmentYear;
  final String? contactPerson;
  final String? mobileNo;
  final String? contactNo;
  final String? email;
  final String? webAddress;
  final String? panNo;
  final String? gstNo;
  final String? cinNo;
  final String? country;
  final String? state;
  final String? city;
  final String? address1;
  final String? address2;
  final String? pinCode;
  final String? tagLine;
  final String? hostingUrl;
  final String? pageSize;
  final String? dateFormat;
  final String? timeZone;
  final String? socialPostUrl;
  final String? bankName;
  final String? accountHolderName;
  final String? bankAccountNo;
  final String? ifscCode;
  final String? bankBranch;

  factory CompanyProfileFields.fromJson(Map<String, dynamic> json) {
    return CompanyProfileFields(
      registrationNo: json['registrationNo'] as String?,
      establishmentYear: _asIntOrNull(json['establishmentYear']),
      contactPerson: json['contactPerson'] as String?,
      mobileNo: json['mobileNo'] as String?,
      contactNo: json['contactNo'] as String?,
      email: json['email'] as String?,
      webAddress: json['webAddress'] as String?,
      panNo: json['panNo'] as String?,
      gstNo: json['gstNo'] as String?,
      cinNo: json['cinNo'] as String?,
      country: json['country'] as String?,
      state: json['state'] as String?,
      city: json['city'] as String?,
      address1: json['address1'] as String?,
      address2: json['address2'] as String?,
      pinCode: json['pinCode'] as String?,
      tagLine: json['tagLine'] as String?,
      hostingUrl: json['hostingUrl'] as String?,
      pageSize: json['pageSize'] as String?,
      dateFormat: json['dateFormat'] as String?,
      timeZone: json['timeZone'] as String?,
      socialPostUrl: json['socialPostUrl'] as String?,
      bankName: json['bankName'] as String?,
      accountHolderName: json['accountHolderName'] as String?,
      bankAccountNo: json['bankAccountNo'] as String?,
      ifscCode: json['ifscCode'] as String?,
      bankBranch: json['bankBranch'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'registrationNo': registrationNo,
        'establishmentYear': establishmentYear,
        'contactPerson': contactPerson,
        'mobileNo': mobileNo,
        'contactNo': contactNo,
        'email': email,
        'webAddress': webAddress,
        'panNo': panNo,
        'gstNo': gstNo,
        'cinNo': cinNo,
        'country': country,
        'state': state,
        'city': city,
        'address1': address1,
        'address2': address2,
        'pinCode': pinCode,
        'tagLine': tagLine,
        'hostingUrl': hostingUrl,
        'pageSize': pageSize,
        'dateFormat': dateFormat,
        'timeZone': timeZone,
        'socialPostUrl': socialPostUrl,
        'bankName': bankName,
        'accountHolderName': accountHolderName,
        'bankAccountNo': bankAccountNo,
        'ifscCode': ifscCode,
        'bankBranch': bankBranch,
      };

  static int? _asIntOrNull(Object? value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString());
  }
}

class ParentOrganizationRef {
  const ParentOrganizationRef({
    required this.id,
    required this.code,
    required this.name,
  });

  final String id;
  final String code;
  final String name;

  factory ParentOrganizationRef.fromJson(Map<String, dynamic> json) {
    return ParentOrganizationRef(
      id: json['id']?.toString() ?? '',
      code: json['code'] as String? ?? '',
      name: json['name'] as String? ?? '',
    );
  }
}
