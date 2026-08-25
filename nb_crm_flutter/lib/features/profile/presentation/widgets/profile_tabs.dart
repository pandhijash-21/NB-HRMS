import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/name_utils.dart';
import '../../../../core/utils/open_stored_document.dart';
import '../../domain/profile_models.dart';
import '../../../admin/presentation/admin_notifier.dart';
import '../../../admin/domain/admin_models.dart';
import '../../../org/domain/org_models.dart';
import '../../../org/presentation/org_providers.dart';
import '../../../letters/domain/letter_models.dart';
import '../../../salary/presentation/salary_providers.dart';
import '../../../letters/presentation/letters_providers.dart';
import '../../../letters/presentation/letter_pdf.dart';
import 'employee_salary_monthly_section.dart';

class GeneralViewTab extends ConsumerWidget {
  final EmployeeProfile profile;

  const GeneralViewTab({super.key, required this.profile});

  AddressInfo? _localAddress() {
    for (final a in profile.addresses) {
      if (a.addressType.toUpperCase() == 'LOCAL') return a;
    }
    return null;
  }

  String _instituteLabel(List<Institute> institutes) {
    final info = profile.generalInfo;
    if (info?.instituteName != null && info!.instituteName!.isNotEmpty) {
      return info.instituteName!;
    }
    if (info?.instituteId != null) {
      for (final inst in institutes) {
        if (inst.id == info!.instituteId) return inst.name;
      }
    }
    final subOrg = info?.subOrganization;
    if (subOrg != null && subOrg.isNotEmpty) return subOrg;
    return '—';
  }

  String? _approverLabel(String? userId, List<EmployeeNameOption> names) {
    if (userId == null || userId.isEmpty) return null;
    for (final item in names) {
      if (item.userId == userId) return item.displayLabel;
    }
    return userId;
  }

  String _formatEnum(String? value) {
    if (value == null || value.trim().isEmpty) return '—';
    return value.replaceAll('_', ' ');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final info = profile.generalInfo;
    final local = _localAddress();
    final institutesAsync = ref.watch(institutesListProvider);
    final namesAsync = ref.watch(employeeNamesProvider);
    final institutes = institutesAsync.asData?.value ?? const <Institute>[];
    final names = namesAsync.asData?.value ?? const <EmployeeNameOption>[];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildSectionCard(
            context: context,
            title: 'Identity & Media',
            icon: Icons.badge_outlined,
            children: [
              _buildField(
                context,
                'Abbreviation',
                profile.abbreviation ??
                    generateAbbreviation(info?.fullName ?? ''),
              ),
              _buildMediaPlaceholder(
                context,
                label: 'Profile Photo',
                url: profile.photoUrl,
                emptyHint: 'No photo uploaded',
              ),
              _buildMediaPlaceholder(
                context,
                label: 'Digital Signature',
                url: profile.signatureUrl,
                emptyHint: 'No signature uploaded',
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildSectionCard(
            context: context,
            title: 'Contact & Access',
            icon: Icons.contact_mail_outlined,
            children: [
              _buildEmailField(
                context,
                'Personal Email (Gmail)',
                local?.personalEmail,
                verified: local?.isPersonalEmailVerified ?? false,
              ),
              _buildEmailField(
                context,
                'Institutional Email',
                local?.instituteEmail,
                verified: local?.isInstituteEmailVerified ?? false,
              ),
              _buildField(
                context,
                'Position (Permissions)',
                profile.position?.name ?? 'Staff — no admin position',
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildSectionCard(
            context: context,
            title: 'Employment Details',
            icon: Icons.work_outline,
            children: [
              _buildField(context, 'Full Name', info?.fullName ?? '—'),
              _buildField(context, 'Employee Code', info?.employeeCode ?? '—'),
              _buildField(context, 'Punch ID (biometric)', info?.punchId ?? '—'),
              _buildField(
                context,
                'Weekly Holidays',
                info == null || info.weeklyOffDays.isEmpty ? 'SUN' : info.weeklyOffDays.join(', '),
              ),
              _buildField(context, 'Organization', info?.organization ?? '—'),
              _buildField(context, 'Institute', _instituteLabel(institutes)),
              _buildField(context, 'Department', info?.department ?? '—'),
              _buildField(context, 'Functional Dept', info?.functionalDepartment ?? '—'),
              _buildField(context, 'Designation', info?.designation ?? '—'),
              _buildField(context, 'Employee Category', _formatEnum(info?.employeeCategory)),
              _buildField(context, 'Appointment Type', _formatEnum(info?.appointmentType)),
              _buildField(context, 'Shift', info?.shift ?? '—'),
            ],
          ),
          const SizedBox(height: 16),
          _buildSectionCard(
            context: context,
            title: 'Timeline & Reporting',
            icon: Icons.timeline,
            children: [
              _buildField(
                context,
                'Joining Date',
                info != null ? _formatDate(info.joiningDate) : '—',
              ),
              _buildField(
                context,
                'Original Joining Date',
                info != null ? _formatDate(info.originalJoiningDate) : '—',
              ),
              _buildField(context, 'Increment Month', info?.incrementMonth ?? '—'),
              _buildField(
                context,
                '1st Reporting',
                _approverLabel(info?.firstApproverUserId, names) ?? '—',
              ),
              _buildField(
                context,
                '2nd Reporting',
                _approverLabel(info?.secondApproverUserId, names) ?? '—',
              ),
              _buildField(
                context,
                '3rd Reporting',
                _approverLabel(info?.thirdApproverUserId, names) ?? '—',
              ),
            ],
          ),
          const SizedBox(height: 16),
          _AssignmentHistoryCard(employeeId: profile.id),
        ],
      ),
    );
  }
}

class _AssignmentHistoryCard extends ConsumerWidget {
  const _AssignmentHistoryCard({required this.employeeId});

  final int employeeId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(employeeAssignmentsProvider(employeeId));
    return async.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (list) {
        if (list.isEmpty) return const SizedBox.shrink();
        final sorted = List<EmployeeAssignment>.from(list)
          ..sort((a, b) => b.effectiveFrom.compareTo(a.effectiveFrom));
        return _buildSectionCard(
          context: context,
          title: 'Institute transfer & designation history',
          icon: Icons.swap_horiz_rounded,
          children: [
            for (var i = 0; i < sorted.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      assignmentEventLabel(
                        sorted[i],
                        i + 1 < sorted.length ? sorted[i + 1] : null,
                      ),
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                    ),
                    Text(
                      '${sorted[i].designation} · ${sorted[i].subOrganization ?? "—"}',
                      style: TextStyle(fontSize: 12, color: Theme.of(context).hintColor),
                    ),
                    Text(
                      '${_formatDate(sorted[i].effectiveFrom)} – ${sorted[i].effectiveTo == null ? "Present" : _formatDate(sorted[i].effectiveTo!)}',
                      style: TextStyle(fontSize: 11, color: Theme.of(context).hintColor),
                    ),
                    if (sorted[i].reason != null && sorted[i].reason!.isNotEmpty)
                      Text(
                        sorted[i].reason!,
                        style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic),
                      ),
                  ],
                ),
              ),
          ],
        );
      },
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
      padding: EdgeInsets.all(16),
      child: Column(
        children: [
          _buildSectionCard(
            context: context,
            title: 'Personal Details',
            icon: Icons.person_outline,
            children: [
              _buildField(
                context,
                'Date of Birth',
                info != null ? _formatDate(info.birthDate) : '—',
              ),
              _buildField(context, 'Birth Place', info?.birthPlace ?? '—'),
              _buildField(context, 'Home Town', info?.homeTown ?? '—'),
              _buildField(context, 'Gender', info?.gender ?? '—'),
              _buildField(context, 'Marital Status', info?.maritalStatus ?? '—'),
              _buildField(context, 'Nationality', info?.nationality ?? '—'),
              _buildField(context, 'Mother Tongue', info?.motherTongue ?? '—'),
              _buildField(context, 'Blood Group', _formatBloodGroup(info?.bloodGroup)),
              _buildField(context, 'Cast Category', info?.castCategory ?? '—'),
              _buildField(context, 'Sub Caste', info?.subCaste ?? '—'),
              _buildField(context, 'Nominee Name', info?.nomineeName ?? '—'),
              _buildField(context, 'Nominee Relation', info?.nomineeRelation ?? '—'),
              _buildField(context, 'Aadhaar Number', info?.aadhaarNo ?? '—'),
              _buildField(context, 'PAN Number', info?.panNo ?? '—'),
              _buildField(context, 'Passport No', info?.passportNo ?? '—'),
              _buildField(context, 'Passport Issue Place', info?.passportIssuePlace ?? '—'),
              _buildField(
                context,
                'Passport Issue Date',
                info?.passportIssueDate != null
                    ? _formatDate(info!.passportIssueDate!)
                    : '—',
              ),
              _buildField(
                context,
                'Passport Expiry Date',
                info?.passportExpiryDate != null
                    ? _formatDate(info!.passportExpiryDate!)
                    : '—',
              ),
            ],
          ),
          SizedBox(height: 16),
          _buildSectionCard(
            context: context,
            title: 'Uploaded Documents',
            icon: Icons.description_outlined,
            children: [
              _buildDocItem(context, 'Aadhaar Card', info?.aadhaarCardUrl),
              _buildDocItem(context, 'PAN Card', info?.panCardUrl),
              _buildDocItem(context, 'Passport Document', profile.otherInfo?.passportUrl),
              _buildDocItem(context, 'Other Document', info?.otherDocumentUrl),
            ],
          ),
        ],
      ),
    );
  }
}

String _formatBloodGroup(String? value) {
  if (value == null || value.isEmpty) return '—';
  return value.replaceAll('_POS', '+').replaceAll('_NEG', '-');
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
      padding: EdgeInsets.all(16),
      child: Column(
        children: [
          if (isWide)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: localWidget),
                SizedBox(width: 16),
                Expanded(child: permanentWidget),
              ],
            )
          else ...[
            localWidget,
            SizedBox(height: 16),
            permanentWidget,
          ],
          ...others.map(
            (a) => Padding(
              padding: EdgeInsets.only(top: 16),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : const Color(0xFF212F3D);

    return Card(
      elevation: 0,
      color: isDark ? const Color(0xFF1E1B18) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isDark ? const Color(0xFFC5A059).withOpacity(0.15) : const Color(0xFFCFD8DC),
          width: 1.5,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isLocal ? Icons.home_outlined : Icons.pin_drop_outlined,
                  color: const Color(0xFFC5A059),
                  size: 22,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                      color: textColor,
                    ),
                  ),
                ),
                if (addr == null)
                  Text(
                    'Not filled',
                    style: TextStyle(fontSize: 11, color: isDark ? Colors.white30 : const Color(0xFF607D8B)),
                  ),
              ],
            ),
            Divider(
              height: 28,
              thickness: 1.2,
              color: isDark ? const Color(0xFFC5A059).withOpacity(0.12) : Colors.black.withOpacity(0.06),
            ),
            _buildFieldDetail(context, 'Flat / Block No', addr?.flatBlockNo),
            _buildFieldDetail(context, 'Building / Society', addr?.buildingSociety),
            _buildFieldDetail(context, 'Area / Street', addr?.area),
            _buildFieldDetail(context, 'City', addr?.city),
            _buildFieldDetail(context, 'State', addr?.state),
            _buildFieldDetail(context, 'Pincode', addr?.zipPostalCode),
            _buildFieldDetail(context, 'Country', addr?.country ?? 'India'),
            _buildFieldDetail(context, 'Phone', addr?.phoneNo),
            _buildFieldDetail(context, 'Mobile', addr?.mobileNo),
            if (isLocal) ...[
              _buildFieldDetailWithStatus(
                context,
                'Personal Email',
                addr?.personalEmail,
                verified: addr?.isPersonalEmailVerified ?? false,
              ),
              _buildFieldDetailWithStatus(
                context,
                'Institutional Email',
                addr?.instituteEmail,
                verified: addr?.isInstituteEmailVerified ?? false,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildFieldDetail(BuildContext context, String label, String? value) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final display = (value == null || value.trim().isEmpty) ? '—' : value;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white60 : const Color(0xFF607D8B),
                fontSize: 12,
              ),
            ),
          ),
          Expanded(
            child: Text(
              display,
              style: TextStyle(
                color: display == '—' 
                    ? (isDark ? Colors.white30 : const Color(0xFF607D8B)) 
                    : (isDark ? Colors.white : const Color(0xFF212F3D)),
                fontSize: 13,
                fontWeight: display == '—' ? FontWeight.w500 : FontWeight.w700,
                fontStyle: display == '—' ? FontStyle.italic : FontStyle.normal,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFieldDetailWithStatus(
    BuildContext context,
    String label,
    String? value, {
    required bool verified,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final display = (value == null || value.trim().isEmpty) ? '—' : value;
    final hasEmail = display != '—';
    return Padding(
      padding: const EdgeInsets.only(bottom: 10.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white60 : const Color(0xFF607D8B),
                fontSize: 12,
              ),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  display,
                  style: TextStyle(
                    color: !hasEmail
                        ? (isDark ? Colors.white30 : const Color(0xFF607D8B))
                        : (isDark ? Colors.white : const Color(0xFF212F3D)),
                    fontSize: 13,
                    fontWeight: !hasEmail ? FontWeight.w500 : FontWeight.w700,
                    fontStyle: !hasEmail ? FontStyle.italic : FontStyle.normal,
                  ),
                ),
                if (hasEmail) ...[
                  const SizedBox(height: 4),
                  emailVerificationStatusChip(
                    context,
                    verified: verified,
                  ),
                ],
              ],
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
      padding: EdgeInsets.all(16),
      child: Column(
        children: [
          _buildSectionCard(
            context: context,
            title: 'Traits & Handicaps',
            icon: Icons.star_border,
            children: [
              _buildField(context, 'Skill Set', info?.skillSet ?? '—'),
              _buildField(context, 'Hobbies', info?.hobbies ?? '—'),
              _buildField(context, 'Strength', info?.strength ?? '—'),
              _buildField(context, 'Weakness', info?.weakness ?? '—'),
              _buildField(context, 
                'Is Physically Handicapped',
                info == null ? '—' : (info.isHandicapped ? 'YES' : 'NO'),
              ),
              _buildField(context, 'Handicap Details', info?.handicapDetails ?? '—'),
              _buildField(context, 'Height (ft)', info?.heightInFeet?.toString() ?? '—'),
              _buildField(context, 'Weight (kg)', info?.weightInKg?.toString() ?? '—'),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1E1B18) : Colors.white;
    final cardBorder = isDark ? const Color(0xFFC5A059).withOpacity(0.15) : const Color(0xFFCFD8DC);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (members.isEmpty)
          Card(
            elevation: 0,
            color: cardBg,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: cardBorder, width: 1.5),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Wrap(
                spacing: 24,
                runSpacing: 12,
                children: [
                  _buildWrapField(context, 'Name', '—'),
                  _buildWrapField(context, 'Relationship', '—'),
                  _buildWrapField(context, 'DOB', '—'),
                  _buildWrapField(context, 'Mobile No', '—'),
                  _buildWrapField(context, 'Email', '—'),
                  _buildWrapField(context, 'City', '—'),
                  _buildWrapField(context, 'Aadhaar No', '—'),
                  _buildWrapField(context, 'Is Nominee', '—'),
                ],
              ),
            ),
          ),
        ...members.map((member) {
          return Card(
            elevation: 0,
            margin: const EdgeInsets.only(bottom: 16),
            color: cardBg,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: cardBorder, width: 1.5),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          member.name.isEmpty ? '—' : member.name,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white : const Color(0xFF212F3D),
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF2B2722) : const Color(0xFFECEFF1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isDark ? const Color(0xFFC5A059).withOpacity(0.2) : const Color(0xFFCFD8DC),
                            width: 1,
                          ),
                        ),
                        child: Text(
                          member.relation.toUpperCase(),
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: isDark ? const Color(0xFFE2D6BE) : const Color(0xFF263238),
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                  Divider(
                    height: 28,
                    thickness: 1.2,
                    color: isDark ? const Color(0xFFC5A059).withOpacity(0.12) : Colors.black.withOpacity(0.06),
                  ),
                  Wrap(
                    spacing: 24,
                    runSpacing: 16,
                    children: [
                      _buildWrapField(context, 'Relationship', member.relation),
                      _buildWrapField(
                        context,
                        'DOB',
                        member.dateOfBirth != null
                            ? _formatDate(member.dateOfBirth!)
                            : '—',
                      ),
                      _buildWrapField(context, 'Mobile No', member.mobileNo ?? '—'),
                      _buildWrapField(context, 'Email', member.personalEmail ?? '—'),
                      _buildWrapField(context, 'City', member.city ?? '—'),
                      _buildWrapField(context, 'Aadhaar No', member.aadhaarNo ?? '—'),
                      _buildWrapField(context, 'Dependent', member.isDependent ? 'YES' : 'NO'),
                      _buildWrapField(context, 'Employed', member.isEmployed ? 'YES' : 'NO'),
                      _buildWrapField(context, 'Employer', member.employerName ?? '—'),
                      _buildWrapField(context, 'Is Nominee', member.isNominee ? 'YES' : 'NO'),
                    ],
                  ),
                  const SizedBox(height: 20),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1E1B18) : Colors.white;
    final cardBorder = isDark ? const Color(0xFFC5A059).withOpacity(0.15) : const Color(0xFFCFD8DC);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (quals.isEmpty)
          Card(
            elevation: 0,
            color: cardBg,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: cardBorder, width: 1.5),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.school_outlined, color: Color(0xFFC5A059), size: 22),
                      const SizedBox(width: 10),
                      Text(
                        'Academic Qualification',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : const Color(0xFF212F3D),
                        ),
                      ),
                    ],
                  ),
                  Divider(
                    height: 28,
                    thickness: 1.2,
                    color: isDark ? const Color(0xFFC5A059).withOpacity(0.12) : Colors.black.withOpacity(0.06),
                  ),
                  Wrap(
                    spacing: 24,
                    runSpacing: 16,
                    children: [
                      _buildWrapField(context, 'Degree / Type', '—'),
                      _buildWrapField(context, 'Medium', '—'),
                      _buildWrapField(context, 'Board / University', '—'),
                      _buildWrapField(context, 'Institute / College', '—'),
                      _buildWrapField(context, 'Passing Year', '—'),
                      _buildWrapField(context, 'Percentage', '—'),
                      _buildWrapField(context, 'Grade', '—'),
                      _buildWrapField(context, 'Specialization', '—'),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Marksheet / Certificate Placeholders',
                    style: TextStyle(
                      fontWeight: FontWeight.w700, 
                      fontSize: 13,
                      color: isDark ? Colors.white70 : const Color(0xFF212F3D),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
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
          final isVerified = qual.isVerified;
          final statusColor = isVerified ? Colors.green : Colors.orange;

          return Card(
            elevation: 0,
            margin: const EdgeInsets.only(bottom: 16),
            color: cardBg,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: cardBorder, width: 1.5),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            const Icon(Icons.school_outlined, color: Color(0xFFC5A059), size: 22),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                qual.degreeName ?? qual.degreeType,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: isDark ? Colors.white : const Color(0xFF212F3D),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: statusColor, width: 1.2),
                        ),
                        child: Text(
                          isVerified ? 'VERIFIED' : 'PENDING',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: statusColor,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                  Divider(
                    height: 28,
                    thickness: 1.2,
                    color: isDark ? const Color(0xFFC5A059).withOpacity(0.12) : Colors.black.withOpacity(0.06),
                  ),
                  Wrap(
                    spacing: 24,
                    runSpacing: 16,
                    children: [
                      _buildWrapField(context, 'Degree Type', qual.degreeType),
                      _buildWrapField(context, 'Medium', qual.medium ?? '—'),
                      _buildWrapField(context, 'Board / University',
                          qual.boardUniversity.isEmpty ? '—' : qual.boardUniversity),
                      _buildWrapField(context, 'Institute / College',
                          qual.schoolCollege.isEmpty ? '—' : qual.schoolCollege),
                      _buildWrapField(context, 'Passing Year', '${qual.passingYear}'),
                      _buildWrapField(context, 
                        'Percentage',
                        qual.percentage != null ? '${qual.percentage}%' : '—',
                      ),
                      _buildWrapField(context, 'Grade', qual.grade ?? '—'),
                      _buildWrapField(context, 'Specialization', qual.specialization ?? '—'),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Attached Documents',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: isDark ? Colors.white70 : const Color(0xFF212F3D),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hasUrl = url != null && url.isNotEmpty;
    return SizedBox(
      width: 150,
      child: Card(
        elevation: 0,
        color: hasUrl 
            ? (isDark ? const Color(0xFF1E1B18) : Colors.white) 
            : (isDark ? const Color(0xFF1A1816).withOpacity(0.4) : const Color(0xFFECEFF1).withOpacity(0.4)),
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(
            color: hasUrl 
                ? (isDark ? const Color(0xFFC5A059).withOpacity(0.2) : const Color(0xFFCFD8DC)) 
                : (isDark ? const Color(0xFFC5A059).withOpacity(0.1) : const Color(0xFFCFD8DC)),
            width: 1.2,
          ),
        ),
        child: InkWell(
          onTap: hasUrl ? () => _handleDocClick(context, label, url) : null,
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  hasUrl ? Icons.description_outlined : Icons.cloud_upload_outlined,
                  size: 20,
                  color: hasUrl 
                      ? (isDark ? const Color(0xFFC5A059) : const Color(0xFF263238)) 
                      : (isDark ? Colors.white30 : const Color(0xFF607D8B)),
                ),
                const SizedBox(height: 6),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11, 
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : const Color(0xFF212F3D),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  hasUrl ? 'View file' : 'Upload placeholder',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    color: hasUrl 
                        ? (isDark ? const Color(0xFFE2D6BE) : const Color(0xFF263238)) 
                        : (isDark ? Colors.white30 : const Color(0xFF607D8B)),
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
      padding: EdgeInsets.all(16),
      child: Column(
        children: [
          _buildSectionCard(
            context: context,
            title: 'Primary Bank Information',
            icon: Icons.account_balance,
            children: [
              _buildField(context, 'Bank Name', info?.bankName ?? '—'),
              _buildField(context, 'Account Number', info?.bankAccountNo ?? '—'),
              _buildField(context, 'Branch Code', info?.bankBranchCode ?? '—'),
              _buildField(context, 'IFSC Code', info?.ifscCode ?? '—'),
            ],
          ),
          const SizedBox(height: 16),
          _buildSectionCard(
            context: context,
            title: 'Bank Documents',
            icon: Icons.account_balance_wallet_outlined,
            children: [
              _buildDocPreview(context, 'Cancelled Cheque', info?.cancelledChequeUrl),
              _buildDocPreview(context, 'Passbook', info?.passbookUrl),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDocPreview(BuildContext context, String label, String? url) {
    final has = url != null && url.isNotEmpty;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          const SizedBox(height: 6),
          if (!has)
            Text('Not uploaded', style: TextStyle(fontSize: 13, color: AppColors.textSecondary))
          else
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: Image.network(url, fit: BoxFit.cover),
              ),
            ),
        ],
      ),
    );
  }
}

class DocumentsViewTab extends ConsumerWidget {
  final EmployeeProfile profile;
  final bool canManageLetters;

  const DocumentsViewTab({
    super.key,
    required this.profile,
    this.canManageLetters = false,
  });

  String _stripHtml(String html) {
    return html.replaceAll(RegExp(r'<[^>]*>'), ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  String _htmlToPlainText(String html) {
    return html
        .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'</(p|div|h[1-6]|li|tr)>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'<li[^>]*>', caseSensitive: false), '• ')
        .replaceAll(RegExp(r'<[^>]+>'), '')
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#039;', "'")
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')
        .trim();
  }

  String _escapeHtml(String input) {
    return input
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&#039;');
  }

  String _plainTextToHtml(String text) {
    final paragraphs = text
        .replaceAll('\r\n', '\n')
        .split(RegExp(r'\n{2,}'))
        .map((b) => b.trim())
        .where((b) => b.isNotEmpty)
        .toList();
    if (paragraphs.isEmpty) return '<div></div>';
    final body = paragraphs.map((block) {
      final withBreaks = _escapeHtml(block).replaceAll('\n', '<br/>');
      return '<p style="margin:0 0 12px;">$withBreaks</p>';
    }).join();
    return '<div style="font-family:Arial,sans-serif;font-size:14px;line-height:1.6;color:#111;">$body</div>';
  }

  Future<void> _showLetterEditDialog({
    required BuildContext context,
    required WidgetRef ref,
    required String title,
    required String initialHtml,
    required Future<void> Function(String html) onGenerate,
  }) async {
    final controller = TextEditingController(text: _htmlToPlainText(initialHtml));
    await showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setLocal) {
            final preview = _plainTextToHtml(controller.text);
            return AlertDialog(
              title: Text(title),
              content: SizedBox(
                width: 720,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Edit in simple English. Preview updates below.',
                        style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _knownLetterPlaceholders.map((p) {
                          return ActionChip(
                            label: Text('{{$p}}'),
                            onPressed: () {
                              controller.text = '${controller.text}{{$p}}';
                              setLocal(() {});
                            },
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: controller,
                        minLines: 8,
                        maxLines: 14,
                        keyboardType: TextInputType.multiline,
                        onChanged: (_) => setLocal(() {}),
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          hintText: 'Type the letter in plain English...',
                          labelText: 'Letter text',
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Live Preview',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Text(
                          _htmlToPlainText(preview),
                          style: const TextStyle(fontSize: 13, height: 1.45),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () async {
                    final html = _plainTextToHtml(controller.text);
                    await onGenerate(html);
                    if (ctx.mounted) Navigator.pop(ctx);
                  },
                  child: const Text('Generate Final'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _confirmDeleteLetter({
    required BuildContext context,
    required WidgetRef ref,
    required String documentId,
    required String name,
  }) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete letter'),
        content: Text('Delete $name? This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final repo = ref.read(lettersRepositoryProvider);
    try {
      await repo.deleteDocument(documentId: documentId);
      ref.invalidate(employeeLetterDocumentsProvider(profile.id));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Letter deleted')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Delete failed: $e')),
        );
      }
    }
  }

  Future<void> _createCustomLetter({
    required BuildContext context,
    required WidgetRef ref,
  }) async {
    final titleController = TextEditingController(text: 'Custom Letter');
    final title = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('New letter'),
        content: TextField(
          controller: titleController,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Letter title',
            hintText: 'e.g. Experience Certificate, NOC',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, titleController.text.trim()),
            child: const Text('Create'),
          ),
        ],
      ),
    );
    if (title == null) return;
    final repo = ref.read(lettersRepositoryProvider);
    try {
      final draft = await repo.createCustomDraft(
        employeeId: profile.id,
        title: title.isEmpty ? 'Custom Letter' : title,
      );
      if (!context.mounted) return;
      await _showLetterEditDialog(
        context: context,
        ref: ref,
        title: 'Draft — ${draft.template?.name ?? title}',
        initialHtml: draft.contentHtml,
        onGenerate: (html) async {
          await repo.updateDraftContent(documentId: draft.id, contentHtml: html);
          await repo.finalizeDraft(draftId: draft.id);
          ref.invalidate(employeeLetterDocumentsProvider(profile.id));
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Letter generated')),
            );
          }
        },
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to create letter: $e')),
        );
      }
    }
  }

  static const _knownLetterPlaceholders = <String>[
    'fullName',
    'employeeCode',
    'designation',
    'department',
    'organization',
    'instituteName',
    'joiningDate',
    'birthDate',
    'aadhaarNo',
    'panNo',
    'passportNo',
    'passportIssueDate',
    'passportExpiryDate',
    'todayDate',
  ];

  String _qualTitle(AcademicQualification q) {
    final degreeName = (q.degreeName ?? '').trim();
    final degreeType = q.degreeType.trim();
    final base = degreeName.isNotEmpty ? degreeName : degreeType;
    return '$base (${q.passingYear})';
  }

  List<Widget> _academicDocs(BuildContext context) {
    final items = <Widget>[];
    for (final q in profile.academicQuals) {
      if (q.certificateUrl != null && q.certificateUrl!.isNotEmpty) {
        items.add(_buildDocItem(context, '${_qualTitle(q)} Certificate', q.certificateUrl));
      }
      final semDocs = <String?>[
        q.sem1MarksheetUrl,
        q.sem2MarksheetUrl,
        q.sem3MarksheetUrl,
        q.sem4MarksheetUrl,
        q.sem5MarksheetUrl,
        q.sem6MarksheetUrl,
        q.sem7MarksheetUrl,
        q.sem8MarksheetUrl,
      ];
      for (var i = 0; i < semDocs.length; i += 1) {
        final url = semDocs[i];
        if (url != null && url.isNotEmpty) {
          items.add(_buildDocItem(context, '${_qualTitle(q)} Marksheet', url));
        }
      }
    }
    if (items.isEmpty) {
      items.add(_buildDocItem(context, 'Academic Documents', null));
    }
    return items;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final personal = profile.personalInfo;
    final other = profile.otherInfo;
    final bank = profile.bankInfo;

    final templatesAsync = ref.watch(letterTemplatesProvider);
    final documentsAsync = ref.watch(employeeLetterDocumentsProvider(profile.id));
    final repo = ref.read(lettersRepositoryProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildSectionCard(
            context: context,
            title: 'Identity & Media',
            icon: Icons.perm_media_outlined,
            children: [
              _buildDocItem(context, 'Profile Photo', profile.photoUrl),
              _buildDocItem(context, 'Digital Signature', profile.signatureUrl),
            ],
          ),
          const SizedBox(height: 16),
          _buildSectionCard(
            context: context,
            title: 'KYC & Passport',
            icon: Icons.badge_outlined,
            children: [
              _buildDocItem(context, 'Aadhaar Card', personal?.aadhaarCardUrl),
              _buildDocItem(context, 'PAN Card', personal?.panCardUrl),
              _buildDocItem(context, 'Passport Document', other?.passportUrl),
              _buildDocItem(context, 'Other Personal Document', personal?.otherDocumentUrl),
            ],
          ),
          const SizedBox(height: 16),
          _buildSectionCard(
            context: context,
            title: 'Academic Records',
            icon: Icons.school_outlined,
            children: _academicDocs(context),
          ),
          const SizedBox(height: 16),
          _buildSectionCard(
            context: context,
            title: 'Bank Documents',
            icon: Icons.account_balance_wallet_outlined,
            children: [
              _buildDocItem(context, 'Cancelled Cheque', bank?.cancelledChequeUrl),
              _buildDocItem(context, 'Passbook', bank?.passbookUrl),
            ],
          ),
          const SizedBox(height: 16),
          _buildSectionCard(
            context: context,
            title: 'Letters',
            icon: Icons.description_outlined,
            children: [
              Builder(
                builder: (context) {
                  if (templatesAsync.isLoading || documentsAsync.isLoading) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  if (templatesAsync.hasError || documentsAsync.hasError) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Text(
                        'Failed to load letters',
                        style: TextStyle(
                          color: AppColors.error,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    );
                  }

                  final templates = templatesAsync.asData?.value ?? const <LetterTemplate>[];
                  final docs = documentsAsync.asData?.value ?? const <LetterDocument>[];

                  // Backend already hides drafts from employees; keep UI defensive.
                  final draftDocs = canManageLetters
                      ? docs.where((d) => d.status == LetterDocumentStatus.DRAFT).toList()
                      : const <LetterDocument>[];
                  final finalDocs =
                      docs.where((d) => d.status == LetterDocumentStatus.FINAL).toList();

                  final children = <Widget>[];

                  if (canManageLetters) {
                    children.add(
                      Align(
                        alignment: Alignment.centerRight,
                        child: FilledButton.icon(
                          onPressed: () => _createCustomLetter(context: context, ref: ref),
                          icon: const Icon(Icons.add_rounded, size: 18),
                          label: const Text('New letter'),
                        ),
                      ),
                    );
                    children.add(const SizedBox(height: 10));
                    children.add(
                      Text(
                        'Employees only see letters after you click Generate Final.',
                        style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                      ),
                    );
                    children.add(const SizedBox(height: 10));
                  }

                  for (final doc in finalDocs) {
                    final tName = doc.template?.name ?? 'Letter';
                    final preview = _stripHtml(doc.contentHtml);
                    children.add(
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Theme.of(context).cardColor,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.border.withOpacity(0.6)),
                        ),
                        margin: const EdgeInsets.only(bottom: 10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.description_outlined, size: 18, color: AppColors.bronze),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    tName,
                                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              preview.length > 160 ? '${preview.substring(0, 160)}...' : preview,
                              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                            ),
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                OutlinedButton.icon(
                                  icon: const Icon(Icons.picture_as_pdf_outlined, size: 16),
                                  label: const Text('Download PDF'),
                                  onPressed: () {
                                    downloadLetterPdf(
                                      title: tName,
                                      html: doc.contentHtml,
                                      onMessage: (msg) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(content: Text(msg)),
                                        );
                                      },
                                    );
                                  },
                                ),
                                if (canManageLetters)
                                  OutlinedButton.icon(
                                    icon: const Icon(Icons.delete_outline, size: 16, color: Colors.red),
                                    label: const Text('Delete', style: TextStyle(color: Colors.red)),
                                    onPressed: () => _confirmDeleteLetter(
                                      context: context,
                                      ref: ref,
                                      documentId: doc.id,
                                      name: tName,
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  for (final doc in draftDocs) {
                    children.add(
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Theme.of(context).cardColor,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.amber.shade300),
                        ),
                        margin: const EdgeInsets.only(bottom: 10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${doc.template?.name ?? 'Letter'} (DRAFT — admin only)',
                              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              children: [
                                FilledButton(
                                  onPressed: () async {
                                    await _showLetterEditDialog(
                                      context: context,
                                      ref: ref,
                                      title: 'Edit Draft — ${doc.template?.name ?? 'Letter'}',
                                      initialHtml: doc.contentHtml,
                                      onGenerate: (html) async {
                                        await repo.updateDraftContent(
                                          documentId: doc.id,
                                          contentHtml: html,
                                        );
                                        await repo.finalizeDraft(draftId: doc.id);
                                        ref.invalidate(employeeLetterDocumentsProvider(profile.id));
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            const SnackBar(content: Text('Letter generated')),
                                          );
                                        }
                                      },
                                    );
                                  },
                                  child: const Text('Edit & Generate'),
                                ),
                                OutlinedButton(
                                  onPressed: () => _confirmDeleteLetter(
                                    context: context,
                                    ref: ref,
                                    documentId: doc.id,
                                    name: doc.template?.name ?? 'draft',
                                  ),
                                  child: const Text('Delete', style: TextStyle(color: Colors.red)),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  if (canManageLetters) {
                    children.add(const SizedBox(height: 8));
                    children.add(
                      Text(
                        'Generate letters:',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    );
                    children.add(const SizedBox(height: 10));

                    for (final t in templates) {
                      children.add(
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Theme.of(context).cardColor,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.border.withOpacity(0.6)),
                          ),
                          margin: const EdgeInsets.only(bottom: 10),
                          child: Row(
                            children: [
                              const Icon(Icons.edit_note_outlined, size: 18, color: AppColors.bronze),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  t.name,
                                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                                ),
                              ),
                              const SizedBox(width: 12),
                              OutlinedButton(
                                onPressed: () async {
                                  final draft = await repo.createOrUpdateDraft(
                                    employeeId: profile.id,
                                    templateId: t.id,
                                  );
                                  if (!context.mounted) return;
                                  await _showLetterEditDialog(
                                    context: context,
                                    ref: ref,
                                    title: 'Draft — ${t.name}',
                                    initialHtml: draft.contentHtml,
                                    onGenerate: (html) async {
                                      await repo.updateDraftContent(
                                        documentId: draft.id,
                                        contentHtml: html,
                                      );
                                      await repo.finalizeDraft(draftId: draft.id);
                                      ref.invalidate(employeeLetterDocumentsProvider(profile.id));
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(content: Text('Letter generated')),
                                        );
                                      }
                                    },
                                  );
                                },
                                child: const Text('Generate'),
                              ),
                            ],
                          ),
                        ),
                      );
                    }
                  }

                  if (children.isEmpty) {
                    children.add(
                      Text(
                        canManageLetters
                            ? 'No letters yet. Generate one above.'
                            : 'No letters available yet. They appear after HR finalizes them.',
                        style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w700),
                      ),
                    );
                  }

                  return Column(crossAxisAlignment: CrossAxisAlignment.start, children: children);
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class SalaryViewTab extends ConsumerWidget {
  final EmployeeProfile profile;

  const SalaryViewTab({super.key, required this.profile});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final previewAsync = ref.watch(employeeSalaryPreviewProvider(profile.id));

    return previewAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Could not load salary structure: $e'),
            const SizedBox(height: 16),
            EmployeeSalaryMonthlySection(employeeId: profile.id),
          ],
        ),
      ),
      data: (preview) {
        final computed = preview.computed;
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
                  _buildField(
                    context,
                    'Pay Commission',
                    preview.payCommission?.name ??
                        preview.payCommissionCode ??
                        info?.payCommission ??
                        '—',
                  ),
                  _buildField(
                    context,
                    'Designation',
                    preview.designation?.name ?? '—',
                  ),
                  if (computed != null) ...[
                    _buildField(context, 'Gross Pay', '₹${computed.grossPay}'),
                    _buildField(
                      context,
                      'Total Deductions',
                      '₹${computed.totalDeductions}',
                    ),
                    _buildField(context, 'Net Pay', '₹${computed.netPay}'),
                  ] else ...[
                    _buildField(
                      context,
                      'Basic Salary',
                      info?.basicSalary != null ? '₹${info!.basicSalary}' : '—',
                    ),
                    _buildField(
                      context,
                      'Gross Salary',
                      info?.grossSalary != null ? '₹${info!.grossSalary}' : '—',
                    ),
                    if (preview.reason != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          preview.reason == 'NO_TEMPLATE'
                              ? 'Salary structure not configured for this designation yet.'
                              : preview.reason == 'NO_COMMISSION'
                                  ? 'Pay commission not assigned.'
                                  : 'Salary preview unavailable (${preview.reason}).',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.orange.shade800,
                          ),
                        ),
                      ),
                  ],
                ],
              ),
              if (computed != null && preview.columnDefinitions.isNotEmpty) ...[
                const SizedBox(height: 16),
                _buildSectionCard(
                  context: context,
                  title: 'Columns',
                  icon: Icons.view_column_outlined,
                  children: [
                    for (final col in preview.columnDefinitions)
                      if (preview.columnVisibility[col.visibilityKey] != false)
                        _buildField(
                          context,
                          col.displayName,
                          () {
                            final row = computed.columns
                                .where((c) => c.key == col.visibilityKey)
                                .toList();
                            if (row.isEmpty) return '—';
                            return '₹${row.first.effectiveValue}';
                          }(),
                        ),
                  ],
                ),
              ],
              const SizedBox(height: 16),
              EmployeeSalaryMonthlySection(employeeId: profile.id),
            ],
          ),
        );
      },
    );
  }
}

/// Experience has no REST list API yet — still show the field labels from the web form.
class ExperienceViewTab extends StatelessWidget {
  const ExperienceViewTab({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1E1B18) : Colors.white;
    final cardBorder = isDark ? const Color(0xFFC5A059).withOpacity(0.15) : const Color(0xFFCFD8DC);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            elevation: 0,
            color: cardBg,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: cardBorder, width: 1.5),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.work_history_outlined, color: Color(0xFFC5A059), size: 22),
                      const SizedBox(width: 10),
                      Text(
                        'Work Experience',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : const Color(0xFF212F3D),
                        ),
                      ),
                    ],
                  ),
                  Divider(
                    height: 28,
                    thickness: 1.2,
                    color: isDark ? const Color(0xFFC5A059).withOpacity(0.12) : Colors.black.withOpacity(0.06),
                  ),
                  Text(
                    'REST API for experience is not available yet. Field layout matches the legacy form:',
                    style: TextStyle(
                      color: isDark ? Colors.white60 : const Color(0xFF607D8B), 
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Wrap(
                    spacing: 24,
                    runSpacing: 16,
                    children: [
                      _buildWrapField(context, 'Type', '—'),
                      _buildWrapField(context, 'Designation', '—'),
                      _buildWrapField(context, 'Organization', '—'),
                      _buildWrapField(context, 'From Date', '—'),
                      _buildWrapField(context, 'To Date', '—'),
                      _buildWrapField(context, 'Job Description', '—'),
                      _buildWrapField(context, 'Last Salary', '—'),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Document Upload Placeholders',
                    style: TextStyle(
                      fontWeight: FontWeight.w700, 
                      fontSize: 13,
                      color: isDark ? Colors.white70 : const Color(0xFF212F3D),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
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
  final isDark = Theme.of(context).brightness == Brightness.dark;
  return Card(
    elevation: 0,
    color: isDark ? const Color(0xFF1E1B18) : Colors.white,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
      side: BorderSide(
        color: isDark ? const Color(0xFFC5A059).withOpacity(0.15) : const Color(0xFFCFD8DC),
        width: 1.5,
      ),
    ),
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: const Color(0xFFC5A059), size: 22),
              const SizedBox(width: 10),
              Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : const Color(0xFF212F3D),
                ),
              ),
            ],
          ),
          Divider(
            height: 28, 
            thickness: 1.2,
            color: isDark ? const Color(0xFFC5A059).withOpacity(0.12) : Colors.black.withOpacity(0.06),
          ),
          Wrap(
            spacing: 24,
            runSpacing: 20,
            children: children,
          ),
        ],
      ),
    ),
  );
}

Widget _buildField(BuildContext context, String label, String value) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  return SizedBox(
    width: 250,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white60 : const Color(0xFF607D8B),
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.white : const Color(0xFF212F3D),
            fontSize: 14,
          ),
        ),
      ],
    ),
  );
}

Widget _buildEmailField(
  BuildContext context,
  String label,
  String? email, {
  required bool verified,
}) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  final display = (email == null || email.trim().isEmpty) ? '—' : email.trim();
  final hasEmail = display != '—';
  return SizedBox(
    width: 280,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white60 : const Color(0xFF607D8B),
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          display,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.white : const Color(0xFF212F3D),
            fontSize: 14,
          ),
        ),
        if (hasEmail) ...[
          const SizedBox(height: 6),
          emailVerificationStatusChip(context, verified: verified),
        ],
      ],
    ),
  );
}

/// Shared verified / unverified chip for email fields (view + edit).
Widget emailVerificationStatusChip(
  BuildContext context, {
  required bool verified,
  bool pendingChange = false,
}) {
  final label = pendingChange
      ? 'Will be Unverified'
      : (verified ? 'Verified' : 'Unverified');
  final color = pendingChange
      ? Colors.orange
      : (verified ? Colors.green : Colors.orange);
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(6),
      border: Border.all(color: color, width: 1),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          verified && !pendingChange
              ? Icons.verified_outlined
              : Icons.mark_email_unread_outlined,
          size: 14,
          color: color,
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w800,
            color: color,
            letterSpacing: 0.3,
          ),
        ),
      ],
    ),
  );
}

Widget _buildWrapField(BuildContext context, String label, String value) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: TextStyle(
          color: isDark ? Colors.white60 : const Color(0xFF607D8B),
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
      const SizedBox(height: 4),
      Text(
        value,
        style: TextStyle(
          color: isDark ? Colors.white : const Color(0xFF212F3D),
          fontSize: 13,
          fontWeight: FontWeight.w700,
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
  final isDark = Theme.of(context).brightness == Brightness.dark;
  final hasUrl = url != null && url.isNotEmpty;
  return SizedBox(
    width: 250,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white60 : const Color(0xFF607D8B),
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          height: 120,
          width: double.infinity,
          decoration: BoxDecoration(
            color: hasUrl 
                ? (isDark ? const Color(0xFF1A1816) : Colors.white) 
                : (isDark ? const Color(0xFF1E1B18) : const Color(0xFFECEFF1)),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: hasUrl 
                  ? (isDark ? const Color(0xFFC5A059).withOpacity(0.2) : const Color(0xFFCFD8DC)) 
                  : (isDark ? const Color(0xFFC5A059).withOpacity(0.1) : const Color(0xFFCFD8DC)),
              width: 1.5,
            ),
          ),
          child: hasUrl
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(10),
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
                      Icon(Icons.cloud_upload_outlined, color: isDark ? Colors.white38 : const Color(0xFF607D8B)),
                      const SizedBox(height: 6),
                      Text(
                        emptyHint,
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 11, color: isDark ? Colors.white30 : const Color(0xFF607D8B)),
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
  final isDark = Theme.of(context).brightness == Brightness.dark;
  final hasUrl = url != null && url.isNotEmpty;
  return SizedBox(
    width: 250,
    child: Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: hasUrl 
            ? (isDark ? const Color(0xFF1E1B18) : Colors.white) 
            : (isDark ? const Color(0xFF1A1816).withOpacity(0.4) : const Color(0xFFECEFF1).withOpacity(0.4)),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: hasUrl 
              ? (isDark ? const Color(0xFFC5A059).withOpacity(0.2) : const Color(0xFFCFD8DC)) 
              : (isDark ? const Color(0xFFC5A059).withOpacity(0.1) : const Color(0xFFCFD8DC)),
          width: 1.2,
        ),
      ),
      child: Row(
        children: [
          Icon(
            hasUrl ? Icons.attach_file_rounded : Icons.cloud_upload_outlined,
            size: 20,
            color: hasUrl ? const Color(0xFFC5A059) : (isDark ? Colors.white38 : const Color(0xFF607D8B)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(fontSize: 11, color: isDark ? Colors.white60 : const Color(0xFF607D8B), fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 4),
                InkWell(
                  onTap: hasUrl ? () => _handleDocClick(context, label, url) : null,
                  child: Text(
                    hasUrl ? 'View attachment' : 'Upload placeholder',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: hasUrl
                          ? (isDark ? const Color(0xFFE2D6BE) : const Color(0xFF263238))
                          : (isDark ? Colors.white30 : const Color(0xFF607D8B).withOpacity(0.7)),
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

Future<void> _handleDocClick(BuildContext context, String title, String url) async {
  // Same authenticated /upload/inline proxy as resumes — avoids Cloudinary 401
  // when opening restricted marksheets / certificates in a new tab.
  await openStoredDocument(
    context,
    url: url,
    title: title,
    fileName: url.split('/').last.split('?').first,
  );
}

String _formatDate(DateTime date) {
  return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
}
