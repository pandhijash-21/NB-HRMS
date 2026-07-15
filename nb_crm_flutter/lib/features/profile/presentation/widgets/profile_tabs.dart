import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/profile_models.dart';

class GeneralViewTab extends StatelessWidget {
  final EmployeeProfile profile;

  const GeneralViewTab({super.key, required this.profile});

  @override
  Widget build(BuildContext context) {
    final info = profile.generalInfo;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildSectionCard(
            context: context,
            title: 'Employment Details',
            icon: Icons.work_outline,
            children: [
              _buildField('Full Name', info?.fullName ?? '—'),
              _buildField('Employee Code', info?.employeeCode ?? '—'),
              _buildField('Organization', info?.organization ?? '—'),
              _buildField('Department', info?.department ?? '—'),
              _buildField('Functional Dept', info?.functionalDepartment ?? '—'),
              _buildField('Designation', info?.designation ?? '—'),
              _buildField('Employee Category', info?.employeeCategory ?? '—'),
              _buildField('Appointment Type', info?.appointmentType ?? '—'),
              _buildField('Shift', info?.shift ?? '—'),
            ],
          ),
          const SizedBox(height: 16),
          _buildSectionCard(
            context: context,
            title: 'Timeline & Reporting',
            icon: Icons.timeline,
            children: [
              _buildField(
                'Joining Date',
                info != null ? _formatDate(info.joiningDate) : '—',
              ),
              _buildField(
                'Original Joining Date',
                info != null ? _formatDate(info.originalJoiningDate) : '—',
              ),
              _buildField('Increment Month', info?.incrementMonth ?? '—'),
              _buildField(
                '1st Reporting ID',
                info?.firstReportingId?.toString() ?? '—',
              ),
              _buildField(
                '2nd Reporting ID',
                info?.secondReportingId?.toString() ?? '—',
              ),
              _buildField(
                '3rd Reporting ID',
                info?.thirdReportingId?.toString() ?? '—',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class PersonalViewTab extends StatelessWidget {
  final EmployeeProfile profile;

  const PersonalViewTab({super.key, required this.profile});

  @override
  Widget build(BuildContext context) {
    final info = profile.personalInfo;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildSectionCard(
            context: context,
            title: 'Identity & Details',
            icon: Icons.person_outline,
            children: [
              _buildField(
                'Date of Birth',
                info != null ? _formatDate(info.birthDate) : '—',
              ),
              _buildField('Gender', info?.gender ?? '—'),
              _buildField('Marital Status', info?.maritalStatus ?? '—'),
              _buildField('Blood Group', info?.bloodGroup ?? '—'),
              _buildField('Nationality', info?.nationality ?? '—'),
              _buildField('Birth Place', info?.birthPlace ?? '—'),
              _buildField('Home Town', info?.homeTown ?? '—'),
              _buildField('Mother Tongue', info?.motherTongue ?? '—'),
            ],
          ),
          const SizedBox(height: 16),
          _buildSectionCard(
            context: context,
            title: 'Government Identity & Caste',
            icon: Icons.badge_outlined,
            children: [
              _buildField('Aadhaar Number', info?.aadhaarNo ?? '—'),
              _buildField('PAN Number', info?.panNo ?? '—'),
              _buildField('Caste Category', info?.castCategory ?? '—'),
              _buildField('Sub-Caste', info?.subCaste ?? '—'),
              _buildField('Nominee Name', info?.nomineeName ?? '—'),
              _buildField('Nominee Relation', info?.nomineeRelation ?? '—'),
            ],
          ),
          const SizedBox(height: 16),
          _buildSectionCard(
            context: context,
            title: 'Passport Details',
            icon: Icons.flight_takeoff,
            children: [
              _buildField('Passport Number', info?.passportNo ?? '—'),
              _buildField('Issue Place', info?.passportIssuePlace ?? '—'),
              _buildField(
                'Issue Date',
                info?.passportIssueDate != null
                    ? _formatDate(info!.passportIssueDate!)
                    : '—',
              ),
              _buildField(
                'Expiry Date',
                info?.passportExpiryDate != null
                    ? _formatDate(info!.passportExpiryDate!)
                    : '—',
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildSectionCard(
            context: context,
            title: 'Photo & Signature',
            icon: Icons.photo_camera_outlined,
            children: [
              _buildMediaPlaceholder(
                context,
                label: 'Profile Photo',
                url: profile.photoUrl,
                emptyHint: 'No photo uploaded — use Edit Profile → Personal',
              ),
              _buildMediaPlaceholder(
                context,
                label: 'Digital Signature',
                url: profile.signatureUrl,
                emptyHint: 'No signature uploaded — use Edit Profile → Personal',
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildSectionCard(
            context: context,
            title: 'Uploaded Documents',
            icon: Icons.description_outlined,
            children: [
              _buildDocItem(context, 'Aadhaar Card', info?.aadhaarCardUrl),
              _buildDocItem(context, 'PAN Card', info?.panCardUrl),
              _buildDocItem(context, 'Passport Document', profile.otherInfo?.passportUrl),
            ],
          ),
        ],
      ),
    );
  }
}

class AddressViewTab extends StatelessWidget {
  final EmployeeProfile profile;

  const AddressViewTab({super.key, required this.profile});

  AddressInfo? _findType(String type) {
    final t = type.toUpperCase();
    for (final a in profile.addresses) {
      if (a.addressType.toUpperCase() == t) return a;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.sizeOf(context).width >= 720;
    final local = _findType('LOCAL');
    final permanent = _findType('PERMANENT');
    // Also surface any unexpected address rows so data never disappears.
    final others = profile.addresses
        .where((a) =>
            a.addressType.toUpperCase() != 'LOCAL' &&
            a.addressType.toUpperCase() != 'PERMANENT')
        .toList();

    final localWidget = _buildAddressCard(
      context,
      'Local Address',
      local,
      isLocal: true,
    );
    final permanentWidget = _buildAddressCard(
      context,
      'Permanent Address',
      permanent,
      isLocal: false,
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          if (isWide)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: localWidget),
                const SizedBox(width: 16),
                Expanded(child: permanentWidget),
              ],
            )
          else ...[
            localWidget,
            const SizedBox(height: 16),
            permanentWidget,
          ],
          ...others.map(
            (a) => Padding(
              padding: const EdgeInsets.only(top: 16),
              child: _buildAddressCard(
                context,
                '${a.addressType} Address',
                a,
                isLocal: false,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddressCard(
    BuildContext context,
    String title,
    AddressInfo? addr, {
    required bool isLocal,
  }) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isLocal ? Icons.home_outlined : Icons.pin_drop_outlined,
                  color: AppColors.bronze,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppColors.midnight,
                        ),
                  ),
                ),
                if (addr == null)
                  const Text(
                    'Not filled',
                    style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                  ),
              ],
            ),
            const Divider(height: 24),
            _buildFieldDetail('Flat / Block No', addr?.flatBlockNo),
            _buildFieldDetail('Building / Society', addr?.buildingSociety),
            _buildFieldDetail('Area', addr?.area),
            _buildFieldDetail('City', addr?.city),
            _buildFieldDetail('State', addr?.state),
            _buildFieldDetail('Country', addr?.country ?? 'INDIA'),
            _buildFieldDetail('Zip / Postal Code', addr?.zipPostalCode),
            _buildFieldDetail('Mobile No', addr?.mobileNo),
            _buildFieldDetail('Phone No', addr?.phoneNo),
            if (isLocal) ...[
              _buildFieldDetail('Intercom No', addr?.intercomNo),
              _buildFieldDetail('Personal Email', addr?.personalEmail),
              _buildFieldDetail('Institute Email', addr?.instituteEmail),
              _buildFieldDetail('Personal Web URL', addr?.url),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildFieldDetail(String label, String? value) {
    final display = (value == null || value.trim().isEmpty) ? '—' : value;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
                fontSize: 13,
              ),
            ),
          ),
          Expanded(
            child: Text(
              display,
              style: TextStyle(
                color: display == '—' ? AppColors.textSecondary : AppColors.textPrimary,
                fontSize: 13,
                fontStyle: display == '—' ? FontStyle.italic : FontStyle.normal,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class OtherViewTab extends StatelessWidget {
  final EmployeeProfile profile;

  const OtherViewTab({super.key, required this.profile});

  @override
  Widget build(BuildContext context) {
    final info = profile.otherInfo;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildSectionCard(
            context: context,
            title: 'Traits & Handicaps',
            icon: Icons.star_border,
            children: [
              _buildField('Skill Set', info?.skillSet ?? '—'),
              _buildField('Hobbies', info?.hobbies ?? '—'),
              _buildField('Strength', info?.strength ?? '—'),
              _buildField('Weakness', info?.weakness ?? '—'),
              _buildField(
                'Is Physically Handicapped',
                info == null ? '—' : (info.isHandicapped ? 'YES' : 'NO'),
              ),
              _buildField('Handicap Details', info?.handicapDetails ?? '—'),
              _buildField('Height (ft)', info?.heightInFeet?.toString() ?? '—'),
              _buildField('Weight (kg)', info?.weightInKg?.toString() ?? '—'),
            ],
          ),
        ],
      ),
    );
  }
}

class FamilyViewTab extends StatelessWidget {
  final EmployeeProfile profile;

  const FamilyViewTab({super.key, required this.profile});

  @override
  Widget build(BuildContext context) {
    final members = profile.familyMembers;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (members.isEmpty)
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: AppColors.border),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Wrap(
                spacing: 24,
                runSpacing: 12,
                children: [
                  _buildWrapField('Name', '—'),
                  _buildWrapField('Relationship', '—'),
                  _buildWrapField('DOB', '—'),
                  _buildWrapField('Mobile No', '—'),
                  _buildWrapField('Email', '—'),
                  _buildWrapField('City', '—'),
                  _buildWrapField('Aadhaar No', '—'),
                  _buildWrapField('Is Nominee', '—'),
                ],
              ),
            ),
          ),
        ...members.map((member) {
          return Card(
            elevation: 1,
            margin: const EdgeInsets.only(bottom: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: AppColors.border),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          member.name.isEmpty ? '—' : member.name,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.midnight,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.mist,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          member.relation,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: AppColors.slate,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 20),
                  Wrap(
                    spacing: 24,
                    runSpacing: 12,
                    children: [
                      _buildWrapField('Relationship', member.relation),
                      _buildWrapField(
                        'DOB',
                        member.dateOfBirth != null
                            ? _formatDate(member.dateOfBirth!)
                            : '—',
                      ),
                      _buildWrapField('Mobile No', member.mobileNo ?? '—'),
                      _buildWrapField('Email', member.personalEmail ?? '—'),
                      _buildWrapField('City', member.city ?? '—'),
                      _buildWrapField('Aadhaar No', member.aadhaarNo ?? '—'),
                      _buildWrapField('Is Nominee', member.isNominee ? 'YES' : 'NO'),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildDocItem(context, 'Aadhaar Document', member.aadhaarUrl),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }
}

class AcademicViewTab extends StatelessWidget {
  final EmployeeProfile profile;

  const AcademicViewTab({super.key, required this.profile});

  @override
  Widget build(BuildContext context) {
    final quals = profile.academicQuals;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (quals.isEmpty)
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: AppColors.border),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Academic Qualification',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.midnight,
                    ),
                  ),
                  const Divider(height: 20),
                  Wrap(
                    spacing: 24,
                    runSpacing: 12,
                    children: [
                      _buildWrapField('Degree / Type', '—'),
                      _buildWrapField('Medium', '—'),
                      _buildWrapField('Board / University', '—'),
                      _buildWrapField('Institute / College', '—'),
                      _buildWrapField('Passing Year', '—'),
                      _buildWrapField('Percentage', '—'),
                      _buildWrapField('Grade', '—'),
                      _buildWrapField('Specialization', '—'),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Marksheet / Certificate placeholders',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildDocCard(context, 'Degree / Certificate', null),
                      ...List.generate(
                        8,
                        (i) => _buildDocCard(context, 'SEM ${i + 1} Marksheet', null),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ...quals.map((qual) {
          return Card(
            elevation: 1,
            margin: const EdgeInsets.only(bottom: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: AppColors.border),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          qual.degreeName ?? qual.degreeType,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.midnight,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: qual.isVerified
                              ? AppColors.successSoft
                              : AppColors.errorSoft,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          qual.isVerified ? 'VERIFIED' : 'PENDING',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: qual.isVerified
                                ? AppColors.success
                                : AppColors.error,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 20),
                  Wrap(
                    spacing: 24,
                    runSpacing: 12,
                    children: [
                      _buildWrapField('Degree Type', qual.degreeType),
                      _buildWrapField('Medium', qual.medium ?? '—'),
                      _buildWrapField('Board / University',
                          qual.boardUniversity.isEmpty ? '—' : qual.boardUniversity),
                      _buildWrapField('Institute / College',
                          qual.schoolCollege.isEmpty ? '—' : qual.schoolCollege),
                      _buildWrapField('Passing Year', '${qual.passingYear}'),
                      _buildWrapField(
                        'Percentage',
                        qual.percentage != null ? '${qual.percentage}%' : '—',
                      ),
                      _buildWrapField('Grade', qual.grade ?? '—'),
                      _buildWrapField('Specialization', qual.specialization ?? '—'),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Attached Documents',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: AppColors.midnight,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildDocCard(context, 'Degree / Certificate', qual.certificateUrl),
                      _buildDocCard(context, 'SEM 1 Marksheet', qual.sem1MarksheetUrl),
                      _buildDocCard(context, 'SEM 2 Marksheet', qual.sem2MarksheetUrl),
                      _buildDocCard(context, 'SEM 3 Marksheet', qual.sem3MarksheetUrl),
                      _buildDocCard(context, 'SEM 4 Marksheet', qual.sem4MarksheetUrl),
                      _buildDocCard(context, 'SEM 5 Marksheet', qual.sem5MarksheetUrl),
                      _buildDocCard(context, 'SEM 6 Marksheet', qual.sem6MarksheetUrl),
                      _buildDocCard(context, 'SEM 7 Marksheet', qual.sem7MarksheetUrl),
                      _buildDocCard(context, 'SEM 8 Marksheet', qual.sem8MarksheetUrl),
                    ],
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildDocCard(BuildContext context, String label, String? url) {
    final hasUrl = url != null && url.isNotEmpty;
    return SizedBox(
      width: 150,
      child: Card(
        elevation: 0,
        color: hasUrl ? Colors.white : AppColors.mist.withValues(alpha: 0.45),
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(
            color: hasUrl ? AppColors.border : AppColors.bronze.withValues(alpha: 0.5),
          ),
        ),
        child: InkWell(
          onTap: hasUrl ? () => _handleDocClick(context, label, url) : null,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  hasUrl ? Icons.description_outlined : Icons.cloud_upload_outlined,
                  size: 20,
                  color: hasUrl ? AppColors.bronze : AppColors.textSecondary,
                ),
                const SizedBox(height: 6),
                Text(
                  label,
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  hasUrl ? 'View file' : 'Upload placeholder',
                  style: TextStyle(
                    fontSize: 10,
                    color: hasUrl ? AppColors.bronzeDark : AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class BankViewTab extends StatelessWidget {
  final EmployeeProfile profile;

  const BankViewTab({super.key, required this.profile});

  @override
  Widget build(BuildContext context) {
    final info = profile.bankInfo;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildSectionCard(
            context: context,
            title: 'Primary Bank Information',
            icon: Icons.account_balance,
            children: [
              _buildField('Bank Name', info?.bankName ?? '—'),
              _buildField('Account Number', info?.bankAccountNo ?? '—'),
              _buildField('Branch Code', info?.bankBranchCode ?? '—'),
              _buildField('IFSC Code', info?.ifscCode ?? '—'),
            ],
          ),
        ],
      ),
    );
  }
}

class SalaryViewTab extends StatelessWidget {
  final EmployeeProfile profile;

  const SalaryViewTab({super.key, required this.profile});

  @override
  Widget build(BuildContext context) {
    final info = profile.salaryInfo;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildSectionCard(
            context: context,
            title: 'Salary Structure',
            icon: Icons.payments_outlined,
            children: [
              _buildField('Pay Commission', info?.payCommission ?? '—'),
              _buildField('Pay Grade', info?.payGrade ?? '—'),
              _buildField(
                'Basic Salary',
                info?.basicSalary != null ? '₹${info!.basicSalary}' : '—',
              ),
              _buildField('AGP', info?.agp != null ? '₹${info!.agp}' : '—'),
              _buildField(
                'Gross Salary',
                info?.grossSalary != null ? '₹${info!.grossSalary}' : '—',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Experience has no REST list API yet — still show the field labels from the web form.
class ExperienceViewTab extends StatelessWidget {
  const ExperienceViewTab({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: AppColors.border),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.work_history_outlined, color: AppColors.bronze),
                      SizedBox(width: 8),
                      Text(
                        'Work Experience',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.midnight,
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 24),
                  const Text(
                    'REST API for experience is not available yet. '
                    'Field layout matches the legacy form:',
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 24,
                    runSpacing: 12,
                    children: [
                      _buildWrapField('Type', '—'),
                      _buildWrapField('Designation', '—'),
                      _buildWrapField('Organization', '—'),
                      _buildWrapField('From Date', '—'),
                      _buildWrapField('To Date', '—'),
                      _buildWrapField('Job Description', '—'),
                      _buildWrapField('Last Salary', '—'),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Document upload placeholders',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildDocItem(context, 'Experience Letter', null),
                      _buildDocItem(context, 'Last Paycheck', null),
                      _buildDocItem(context, 'Recommendation Letters', null),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

Widget _buildSectionCard({
  required BuildContext context,
  required String title,
  required IconData icon,
  required List<Widget> children,
}) {
  return Card(
    elevation: 0,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
      side: const BorderSide(color: AppColors.border),
    ),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppColors.bronze),
              const SizedBox(width: 8),
              Text(
                title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppColors.midnight,
                    ),
              ),
            ],
          ),
          const Divider(height: 24),
          Wrap(
            spacing: 24,
            runSpacing: 16,
            children: children,
          ),
        ],
      ),
    ),
  );
}

Widget _buildField(String label, String value) {
  return SizedBox(
    width: 250,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.w500,
            color: AppColors.textPrimary,
            fontSize: 14,
          ),
        ),
      ],
    ),
  );
}

Widget _buildWrapField(String label, String value) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: const TextStyle(
          color: AppColors.textSecondary,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
      const SizedBox(height: 2),
      Text(
        value,
        style: const TextStyle(
          color: AppColors.textPrimary,
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
      ),
    ],
  );
}

Widget _buildMediaPlaceholder(
  BuildContext context, {
  required String label,
  required String? url,
  required String emptyHint,
}) {
  final hasUrl = url != null && url.isNotEmpty;
  return SizedBox(
    width: 250,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          height: 100,
          width: double.infinity,
          decoration: BoxDecoration(
            color: hasUrl ? Colors.white : AppColors.mist.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: hasUrl ? AppColors.border : AppColors.bronze.withValues(alpha: 0.55),
            ),
          ),
          child: hasUrl
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(9),
                  child: Image.network(
                    url,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Center(
                      child: TextButton(
                        onPressed: () => _handleDocClick(context, label, url),
                        child: const Text('Open URL'),
                      ),
                    ),
                  ),
                )
              : Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.cloud_upload_outlined, color: AppColors.textSecondary),
                      const SizedBox(height: 6),
                      Text(
                        emptyHint,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
        ),
      ],
    ),
  );
}

Widget _buildDocItem(BuildContext context, String label, String? url) {
  final hasUrl = url != null && url.isNotEmpty;
  return SizedBox(
    width: 250,
    child: Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: hasUrl ? Colors.white : AppColors.mist.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: hasUrl ? AppColors.border : AppColors.bronze.withValues(alpha: 0.5),
        ),
      ),
      child: Row(
        children: [
          Icon(
            hasUrl ? Icons.attach_file : Icons.cloud_upload_outlined,
            size: 18,
            color: hasUrl ? AppColors.bronze : AppColors.textSecondary,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 2),
                InkWell(
                  onTap: hasUrl ? () => _handleDocClick(context, label, url) : null,
                  child: Text(
                    hasUrl ? 'View attachment' : 'Upload placeholder (use Edit)',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: hasUrl
                          ? AppColors.bronze
                          : AppColors.textSecondary.withValues(alpha: 0.85),
                      decoration: hasUrl ? TextDecoration.underline : null,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

void _handleDocClick(BuildContext context, String title, String url) {
  // Show clean Dialog with url detail and copy action
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(
        'Document URL:\n$url\n\n(In production, this opens in browser/viewer)',
        style: const TextStyle(fontSize: 13),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Close'),
        ),
      ],
    ),
  );
}

String _formatDate(DateTime date) {
  return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
}
