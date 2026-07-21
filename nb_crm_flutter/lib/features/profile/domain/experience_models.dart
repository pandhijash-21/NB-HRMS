class EmployeeExperience {
  const EmployeeExperience({
    required this.id,
    required this.employeeId,
    required this.type,
    required this.designation,
    required this.organizationName,
    required this.fromDate,
    required this.toDate,
    this.jobDescription,
    this.lastSalary,
    this.experienceLetterUrl,
    this.lastPaycheckUrl,
    this.recommendationLetters = const [],
  });

  final String id;
  final int employeeId;
  final String type;
  final String designation;
  final String organizationName;
  final DateTime fromDate;
  final DateTime toDate;
  final String? jobDescription;
  final double? lastSalary;
  final String? experienceLetterUrl;
  final String? lastPaycheckUrl;
  final List<String> recommendationLetters;

  factory EmployeeExperience.fromJson(Map<String, dynamic> json) {
    return EmployeeExperience(
      id: json['id'].toString(),
      employeeId: int.parse(json['employeeId'].toString()),
      type: json['type']?.toString() ?? '',
      designation: json['designation']?.toString() ?? '',
      organizationName: json['organizationName']?.toString() ?? '',
      fromDate: DateTime.parse(json['fromDate'].toString()),
      toDate: DateTime.parse(json['toDate'].toString()),
      jobDescription: json['jobDescription']?.toString(),
      lastSalary: double.tryParse('${json['lastSalary'] ?? ''}'),
      experienceLetterUrl: json['experienceLetterUrl']?.toString(),
      lastPaycheckUrl: json['lastPaycheckUrl']?.toString(),
      recommendationLetters: (json['recommendationLetters'] is List)
          ? (json['recommendationLetters'] as List)
                .map((e) => e.toString())
                .toList()
          : const [],
    );
  }
}
