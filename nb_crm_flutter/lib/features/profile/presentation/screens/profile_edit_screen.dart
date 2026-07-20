import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/platform_file_picker.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/name_utils.dart';
import '../../../admin/presentation/admin_notifier.dart';
import '../../../admin/domain/admin_models.dart';
import '../../../auth/presentation/auth_providers.dart';
import '../../../org/presentation/org_providers.dart';
import '../../../org/domain/org_models.dart';
import '../../../salary/domain/salary_models.dart';
import '../../../salary/presentation/salary_providers.dart';
import '../../../salary/presentation/widgets/salary_rule_editor_sheet.dart';
import '../../../auth/domain/permissions.dart';
import '../widgets/edit_attendance_settings_tab.dart';
import '../../../lookups/presentation/lookup_dropdown.dart';
import '../../../lookups/domain/lookup_models.dart';
import '../../domain/profile_models.dart';
import '../profile_notifier.dart';

class ProfileEditScreen extends ConsumerStatefulWidget {
  final int? employeeId;

  const ProfileEditScreen({super.key, this.employeeId});

  @override
  ConsumerState<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends ConsumerState<ProfileEditScreen> with SingleTickerProviderStateMixin {
  TabController? _tabController;
  int _tabCount = 0;

  List<String> _tabsFor(bool showAttendance) {
    final base = ['General', 'Personal', 'Address', 'Other', 'Family', 'Academic', 'Bank', 'Salary'];
    if (showAttendance) return [...base, 'Attendance'];
    return base;
  }

  void _syncTabController(int count) {
    if (_tabController != null && _tabCount == count) return;
    _tabController?.dispose();
    _tabController = TabController(length: count, vsync: this);
    _tabCount = count;
  }

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      final auth = ref.read(authNotifierProvider);
      final empId = widget.employeeId ?? auth.user?.employeeId;
      if (empId != null) {
        ref.read(activeProfileEmployeeIdProvider.notifier).set(empId);
      }
    });
  }

  @override
  void dispose() {
    _tabController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authNotifierProvider);
    final empId = widget.employeeId ?? authState.user?.employeeId;

    if (empId == null) {
      return const Scaffold(body: Center(child: Text('Required employee ID is missing.')));
    }

    final profileAsyncVal = ref.watch(profileProvider);

    // Privilege detection
    final roleName = authState.user?.role ?? '';
    final isPrivileged = ['ADMIN', 'HR', 'HR_MANAGER', 'HOI', 'REGISTRAR', 'VC']
        .contains(roleName.toUpperCase());
    final sessionEmployeeId = authState.user?.employeeId;
    final targetEmployeeId = widget.employeeId ?? empId;
    final isAdminEditingEmployee = widget.employeeId != null &&
        Permissions.canManageEmployeeAttendance(
          authState.permissions,
          authState.user?.role,
        ) &&
        (sessionEmployeeId == null || widget.employeeId != sessionEmployeeId);
    final showAttendanceTab = isAdminEditingEmployee;
    final tabs = _tabsFor(showAttendanceTab);
    _syncTabController(tabs.length);
    final tabController = _tabController!;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text('Edit Profile'),
        bottom: TabBar(
          controller: tabController,
          isScrollable: true,
          indicatorColor: Theme.of(context).colorScheme.primary,
          labelColor: Theme.of(context).colorScheme.primary,
          unselectedLabelColor: Colors.white70,
          tabs: tabs.map((tab) => Tab(text: tab)).toList(),
        ),
      ),
      body: profileAsyncVal.when(
        data: (profile) => TabBarView(
          controller: tabController,
          children: [
            EditGeneralTab(profile: profile, isPrivileged: isPrivileged),
            EditPersonalTab(profile: profile, isPrivileged: isPrivileged),
            EditAddressTab(
              key: ValueKey('edit-address-${profile.id}'),
              profile: profile,
              isPrivileged: isPrivileged,
            ),
            EditOtherTab(profile: profile, isPrivileged: isPrivileged),
            EditFamilyTab(profile: profile),
            EditAcademicTab(profile: profile),
            EditBankTab(profile: profile, isPrivileged: isPrivileged),
            EditSalaryTab(profile: profile, isPrivileged: isPrivileged),
            if (showAttendanceTab)
              EditAttendanceSettingsTab(employeeId: targetEmployeeId),
          ],
        ),
        loading: () => Center(child: CircularProgressIndicator(color: Theme.of(context).colorScheme.primary)),
        error: (err, stack) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, size: 48, color: AppColors.error),
              SizedBox(height: 12),
              Text('Failed to load profile for editing\n$err', textAlign: TextAlign.center),
              SizedBox(height: 12),
              FilledButton(
                onPressed: () => ref.read(profileProvider.notifier).refresh(),
                child: Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// EDIT SUB-TABS
// =============================================================================

class EditGeneralTab extends ConsumerStatefulWidget {
  final EmployeeProfile profile;
  final bool isPrivileged;

  const EditGeneralTab({super.key, required this.profile, required this.isPrivileged});

  @override
  ConsumerState<EditGeneralTab> createState() => _EditGeneralTabState();
}

class _EditGeneralTabState extends ConsumerState<EditGeneralTab> {
  static const _categories = ['TEACHING', 'NON_TEACHING', 'CONTRACT', 'VISITING'];
  static const _appointmentTypes = [
    'FULL_TIME_REGULAR',
    'FULL_TIME_CONTRACT',
    'PART_TIME',
    'VISITING',
    'DEPUTATION',
  ];

  final _formKey = GlobalKey<FormState>();
  late TextEditingController _fullNameCtrl;
  late TextEditingController _abbreviationCtrl;
  late TextEditingController _empCodeCtrl;
  late TextEditingController _departmentCtrl;
  late TextEditingController _functionalDeptCtrl;
  late TextEditingController _designationCtrl;
  DateTime? _incrementMonth;
  late DateTime _joiningDate;
  late DateTime _originalJoiningDate;
  String _organization = 'Gandhinagar University';
  String? _shift;
  String _employeeCategory = 'NON_TEACHING';
  String? _appointmentType;
  String? _firstApproverUserId;
  String? _secondApproverUserId;
  String? _thirdApproverUserId;

  @override
  void initState() {
    super.initState();
    final info = widget.profile.generalInfo;
    _fullNameCtrl = TextEditingController(text: info?.fullName ?? '');
    _abbreviationCtrl = TextEditingController(
      text: widget.profile.abbreviation ?? generateAbbreviation(info?.fullName ?? ''),
    );
    _fullNameCtrl.addListener(_syncAbbreviationFromName);
    _empCodeCtrl = TextEditingController(text: info?.employeeCode ?? '');
    final org = info?.organization?.trim();
    _organization = (org != null && org.isNotEmpty) ? org : 'Gandhinagar University';
    _departmentCtrl = TextEditingController(text: info?.department ?? '');
    _functionalDeptCtrl = TextEditingController(text: info?.functionalDepartment ?? '');
    _designationCtrl = TextEditingController(text: info?.designation ?? '');
    _shift = info?.shift;
    _incrementMonth = parseIncrementMonth(info?.incrementMonth);
    _joiningDate = info?.joiningDate ?? DateTime.now();
    _originalJoiningDate = info?.originalJoiningDate ?? _joiningDate;
    _employeeCategory = info?.employeeCategory ?? 'NON_TEACHING';
    _appointmentType = info?.appointmentType;
    _firstApproverUserId = info?.firstApproverUserId;
    _secondApproverUserId = info?.secondApproverUserId;
    _thirdApproverUserId = info?.thirdApproverUserId;
  }

  void _syncAbbreviationFromName() {
    final next = generateAbbreviation(_fullNameCtrl.text);
    if (_abbreviationCtrl.text == next) return;
    // Defer so TextFormField rebuilds never nest markNeedsBuild during build.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_abbreviationCtrl.text != next) {
        _abbreviationCtrl.text = next;
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _fullNameCtrl.removeListener(_syncAbbreviationFromName);
    _fullNameCtrl.dispose();
    _abbreviationCtrl.dispose();
    _empCodeCtrl.dispose();
    _departmentCtrl.dispose();
    _functionalDeptCtrl.dispose();
    _designationCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickIncrementMonth() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _incrementMonth ?? DateTime.now(),
      firstDate: DateTime(1980),
      lastDate: DateTime(2100),
      initialDatePickerMode: DatePickerMode.year,
    );
    if (picked != null) {
      setState(() => _incrementMonth = DateTime(picked.year, picked.month));
    }
  }

  String _instituteLabel(List<Institute> institutes) {
    final info = widget.profile.generalInfo;
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

  Future<void> _pickDate({required bool original}) async {
    final initial = original ? _originalJoiningDate : _joiningDate;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(1980),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        if (original) {
          _originalJoiningDate = picked;
        } else {
          _joiningDate = picked;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final institutesAsync = ref.watch(institutesListProvider);
    final namesAsync = ref.watch(employeeNamesProvider);
    final institutes = institutesAsync.asData?.value ?? const <Institute>[];
    final allNames = namesAsync.asData?.value ?? const <EmployeeNameOption>[];
    // Exclude the employee whose profile is being edited (cannot be own reporting manager)
    final names = allNames
        .where((n) => n.employeeId == null || n.employeeId != widget.profile.id)
        .toList();

    if (!widget.isPrivileged) {
      return ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Icon(Icons.lock_outline, size: 48, color: AppColors.textSecondary),
          const SizedBox(height: 12),
          const Text(
            'Employment details are read-only.',
            textAlign: TextAlign.center,
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          const Text(
            'Please contact HR to update employment fields. You can still upload your photo and signature below.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 24),
          BonusUploadZone(
            employeeId: widget.profile.id,
            photoUrl: widget.profile.photoUrl,
            signatureUrl: widget.profile.signatureUrl,
          ),
        ],
      );
    }

    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          BonusUploadZone(
            employeeId: widget.profile.id,
            photoUrl: widget.profile.photoUrl,
            signatureUrl: widget.profile.signatureUrl,
          ),
          const SizedBox(height: 16),
          _buildInfoBanner(context),
          const SizedBox(height: 16),
          _buildTextField('Full Name', _fullNameCtrl, required: true),
          _buildReadOnlyField('Abbreviation', _abbreviationCtrl.text.isEmpty ? '—' : _abbreviationCtrl.text),
          _buildTextField('Employee Code', _empCodeCtrl),
          _buildTextField('Designation', _designationCtrl, required: true, readOnly: true),
          _buildHelperChip('Managed via Designation Upgrade'),
          _buildTextField('Department', _departmentCtrl, required: true),
          _buildTextField('Functional Department', _functionalDeptCtrl),
          lookupLabelDropdown(
            ref: ref,
            category: 'ORGANIZATION',
            label: 'Organization',
            value: _organization,
            required: true,
            fallbackLabels: const ['Gandhinagar University', 'Platinum Foundation'],
            onChanged: (v) => setState(() => _organization = v),
          ),
          _buildReadOnlyField('Institute', _instituteLabel(institutes)),
          _buildHelperChip('Managed via Institute Transfer'),
          lookupDropdown(
            ref: ref,
            category: 'EMPLOYEE_CATEGORY',
            label: 'Employee Category',
            value: _employeeCategory,
            required: true,
            fallback: [
              for (final c in _categories)
                LookupOption(
                  id: c,
                  category: 'EMPLOYEE_CATEGORY',
                  code: c,
                  label: c.replaceAll('_', ' '),
                ),
            ],
            onChanged: (v) => setState(() => _employeeCategory = v),
          ),
          lookupNullableDropdown(
            ref: ref,
            category: 'APPOINTMENT_TYPE',
            label: 'Appointment Type',
            value: _appointmentType,
            fallback: [
              for (final c in _appointmentTypes)
                LookupOption(
                  id: c,
                  category: 'APPOINTMENT_TYPE',
                  code: c,
                  label: c.replaceAll('_', ' '),
                ),
            ],
            onChanged: (v) => setState(() => _appointmentType = v),
          ),
          lookupNullableLabelDropdown(
            ref: ref,
            category: 'SHIFT',
            label: 'Shift',
            value: _shift,
            fallbackLabels: const ['General', 'Morning', 'Evening'],
            onChanged: (v) => setState(() => _shift = v),
          ),
          _buildDateRow('Joining Date *', _joiningDate, () => _pickDate(original: false)),
          _buildDateRow('Original Joining Date *', _originalJoiningDate, () => _pickDate(original: true)),
          _buildDateRow(
            'Increment Month',
            _incrementMonth ?? DateTime.now(),
            _pickIncrementMonth,
            placeholder: _incrementMonth == null,
            display: _incrementMonth == null
                ? 'Not set — tap Select'
                : formatIncrementMonth(_incrementMonth!),
          ),
          const SizedBox(height: 8),
          Text(
            'Reporting managers can be regular employees or position accounts. Leave approvals are routed to the selected user account.',
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 12),
          _buildApproverDropdown('First Reporting Manager', _firstApproverUserId, names, (v) {
            setState(() => _firstApproverUserId = v);
          }),
          _buildApproverDropdown('Second Reporting Manager', _secondApproverUserId, names, (v) {
            setState(() => _secondApproverUserId = v);
          }),
          _buildApproverDropdown('Third Reporting Manager', _thirdApproverUserId, names, (v) {
            setState(() => _thirdApproverUserId = v);
          }),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _save,
            child: const Text('Save General Details'),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoBanner(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.amber.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.amber.shade200),
      ),
      child: const Text(
        'Institute transfer & promotion history\n'
        'Designation/Sub-Organization changes are tracked via Institute Transfer and Designation Upgrade (effective-dated). They are read-only here to preserve history.',
        style: TextStyle(fontSize: 12, color: Color(0xFF92400E)),
      ),
    );
  }

  Widget _buildHelperChip(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Chip(
          label: Text(text, style: const TextStyle(fontSize: 11)),
          visualDensity: VisualDensity.compact,
        ),
      ),
    );
  }

  Widget _buildReadOnlyField(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          filled: true,
          fillColor: Colors.grey.shade100,
          border: const OutlineInputBorder(),
        ),
        child: Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
      ),
    );
  }

  Widget _buildDateRow(
    String label,
    DateTime date,
    VoidCallback onTap, {
    bool placeholder = false,
    String? display,
  }) {
    final text = display ??
        '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Expanded(
            child: Text(
              placeholder ? '$label: $text' : '$label: $text',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: placeholder ? AppColors.textSecondary : null,
              ),
            ),
          ),
          TextButton.icon(
            onPressed: onTap,
            icon: const Icon(Icons.calendar_today_rounded, size: 16),
            label: const Text('Select'),
          ),
        ],
      ),
    );
  }

  Widget _buildApproverDropdown(
    String label,
    String? value,
    List<EmployeeNameOption> names,
    ValueChanged<String?> onChanged,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: DropdownButtonFormField<String?>(
        initialValue: value,
        decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
        items: [
          const DropdownMenuItem<String?>(
            value: null,
            child: Text('NULL (bypass this layer)'),
          ),
          ...names.map(
            (item) => DropdownMenuItem<String?>(
              value: item.userId,
              child: Text(item.displayLabel),
            ),
          ),
        ],
        onChanged: (v) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) onChanged(v);
          });
        },
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    try {
      final notifier = ref.read(profileProvider.notifier);
      final empCode = _empCodeCtrl.text.trim();
      await notifier.updateGeneralInfoDirect({
        'fullName': _fullNameCtrl.text.trim(),
        if (empCode.isNotEmpty) 'employeeCode': empCode,
        'organization': _organization.trim(),
        'department': _departmentCtrl.text.trim(),
        'functionalDepartment': _functionalDeptCtrl.text.trim().isEmpty
            ? null
            : _functionalDeptCtrl.text.trim(),
        'designation': _designationCtrl.text.trim(),
        'employeeCategory': _employeeCategory,
        'appointmentType': _appointmentType,
        'shift': _shift?.trim().isEmpty ?? true ? null : _shift!.trim(),
        'joiningDate': _joiningDate.toIso8601String(),
        'originalJoiningDate': _originalJoiningDate.toIso8601String(),
        'incrementMonth': _incrementMonth == null ? null : formatIncrementMonth(_incrementMonth!),
        'firstApproverUserId': _firstApproverUserId,
        'secondApproverUserId': _secondApproverUserId,
        'thirdApproverUserId': _thirdApproverUserId,
      });
      final abbr = generateAbbreviation(_fullNameCtrl.text.trim());
      if (abbr.isNotEmpty && abbr != (widget.profile.abbreviation ?? '')) {
        await notifier.updateEmployeeAbbreviation(abbr);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('General Info updated successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }
}

class EditPersonalTab extends ConsumerStatefulWidget {
  final EmployeeProfile profile;
  final bool isPrivileged;

  const EditPersonalTab({super.key, required this.profile, required this.isPrivileged});

  @override
  ConsumerState<EditPersonalTab> createState() => _EditPersonalTabState();
}

class _EditPersonalTabState extends ConsumerState<EditPersonalTab> {
  static const _bloodGroups = [
    'A_POS',
    'A_NEG',
    'B_POS',
    'B_NEG',
    'O_POS',
    'O_NEG',
    'AB_POS',
    'AB_NEG',
  ];

  final _formKey = GlobalKey<FormState>();
  final _birthPlaceCtrl = TextEditingController();
  final _homeTownCtrl = TextEditingController();
  final _subCasteCtrl = TextEditingController();
  final _nomineeNameCtrl = TextEditingController();
  final _aadhaarNoCtrl = TextEditingController();
  final _panNoCtrl = TextEditingController();
  final _passportNoCtrl = TextEditingController();
  final _passportIssuePlaceCtrl = TextEditingController();
  DateTime _birthDate = DateTime(1970, 1, 1);
  DateTime? _passportIssueDate;
  DateTime? _passportExpiryDate;
  String _gender = 'MALE';
  String _maritalStatus = 'SINGLE';
  String _nationality = 'INDIAN';
  String? _motherTongue;
  String? _castCategory;
  String? _nomineeRelation;
  String? _bloodGroup;

  @override
  void initState() {
    super.initState();
    final info = widget.profile.personalInfo;
    _birthPlaceCtrl.text = info?.birthPlace ?? '';
    _homeTownCtrl.text = info?.homeTown ?? '';
    _nationality = info?.nationality ?? 'INDIAN';
    _motherTongue = info?.motherTongue;
    _castCategory = info?.castCategory;
    _subCasteCtrl.text = info?.subCaste ?? '';
    _nomineeNameCtrl.text = info?.nomineeName ?? '';
    _nomineeRelation = info?.nomineeRelation;
    _aadhaarNoCtrl.text = info?.aadhaarNo ?? '';
    _panNoCtrl.text = info?.panNo ?? '';
    _passportNoCtrl.text = info?.passportNo ?? '';
    _passportIssuePlaceCtrl.text = info?.passportIssuePlace ?? '';
    _birthDate = info?.birthDate ?? DateTime(1970, 1, 1);
    _passportIssueDate = info?.passportIssueDate;
    _passportExpiryDate = info?.passportExpiryDate;
    _gender = info?.gender ?? 'MALE';
    _maritalStatus = info?.maritalStatus ?? 'SINGLE';
    _bloodGroup = info?.bloodGroup;
  }

  String _formatBloodGroup(String value) =>
      value.replaceAll('_POS', '+').replaceAll('_NEG', '-');

  String? _optionalText(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  String? _optionalNullable(String? value) {
    if (value == null) return null;
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  @override
  void dispose() {
    _birthPlaceCtrl.dispose();
    _homeTownCtrl.dispose();
    _subCasteCtrl.dispose();
    _nomineeNameCtrl.dispose();
    _aadhaarNoCtrl.dispose();
    _panNoCtrl.dispose();
    _passportNoCtrl.dispose();
    _passportIssuePlaceCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickBirthDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _birthDate,
      firstDate: DateTime(1940),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _birthDate = picked);
  }

  Future<void> _pickPassportIssueDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _passportIssueDate ?? DateTime.now(),
      firstDate: DateTime(1980),
      lastDate: DateTime.now().add(const Duration(days: 365 * 20)),
    );
    if (picked != null) setState(() => _passportIssueDate = picked);
  }

  Future<void> _pickPassportExpiryDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _passportExpiryDate ?? DateTime.now().add(const Duration(days: 365 * 5)),
      firstDate: DateTime(1980),
      lastDate: DateTime.now().add(const Duration(days: 365 * 30)),
    );
    if (picked != null) setState(() => _passportExpiryDate = picked);
  }

  Widget _buildOptionalDateRow(String label, DateTime? date, VoidCallback onTap) {
    final text = date == null
        ? 'dd-mm-yyyy'
        : '${date.day.toString().padLeft(2, '0')}-${date.month.toString().padLeft(2, '0')}-${date.year}';
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: label,
            border: const OutlineInputBorder(),
            suffixIcon: const Icon(Icons.calendar_today_outlined, size: 18),
          ),
          child: Text(
            text,
            style: TextStyle(
              color: date == null ? AppColors.textSecondary : null,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pendingRequest = !widget.isPrivileged
        ? ref.watch(pendingRequestProvider('PERSONAL'))
        : const AsyncValue<Map<String, dynamic>?>.data(null);
    final personal = widget.profile.personalInfo;

    return pendingRequest.when(
      data: (req) => Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (req != null)
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.errorSoft,
                  border: Border.all(color: AppColors.error),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.warning, color: AppColors.error),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'You currently have a change request pending review. Saving now will overwrite it.',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.error),
                      ),
                    ),
                  ],
                ),
              ),
            Text('Personal Details', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 12),
            _buildOptionalDateRow('Date of Birth *', _birthDate, _pickBirthDate),
            _buildTextField('Birth Place', _birthPlaceCtrl),
            _buildTextField('Home Town', _homeTownCtrl),
            lookupDropdown(
              ref: ref,
              category: 'GENDER',
              label: 'Gender',
              value: _gender,
              required: true,
              fallback: const [
                LookupOption(id: '1', category: 'GENDER', code: 'MALE', label: 'Male'),
                LookupOption(id: '2', category: 'GENDER', code: 'FEMALE', label: 'Female'),
                LookupOption(id: '3', category: 'GENDER', code: 'OTHER', label: 'Other'),
              ],
              onChanged: (v) => setState(() => _gender = v),
            ),
            lookupDropdown(
              ref: ref,
              category: 'MARITAL_STATUS',
              label: 'Marital Status',
              value: _maritalStatus,
              required: true,
              fallback: const [
                LookupOption(id: '1', category: 'MARITAL_STATUS', code: 'SINGLE', label: 'Single'),
                LookupOption(id: '2', category: 'MARITAL_STATUS', code: 'MARRIED', label: 'Married'),
                LookupOption(id: '3', category: 'MARITAL_STATUS', code: 'DIVORCED', label: 'Divorced'),
                LookupOption(id: '4', category: 'MARITAL_STATUS', code: 'WIDOWED', label: 'Widowed'),
              ],
              onChanged: (v) => setState(() => _maritalStatus = v),
            ),
            lookupDropdown(
              ref: ref,
              category: 'NATIONALITY',
              label: 'Nationality',
              value: _nationality,
              required: true,
              fallback: const [
                LookupOption(id: '1', category: 'NATIONALITY', code: 'INDIAN', label: 'Indian'),
              ],
              onChanged: (v) => setState(() => _nationality = v),
            ),
            lookupNullableDropdown(
              ref: ref,
              category: 'MOTHER_TONGUE',
              label: 'Mother Tongue',
              value: _motherTongue,
              fallback: const [
                LookupOption(id: '1', category: 'MOTHER_TONGUE', code: 'GUJARATI', label: 'Gujarati'),
                LookupOption(id: '2', category: 'MOTHER_TONGUE', code: 'HINDI', label: 'Hindi'),
                LookupOption(id: '3', category: 'MOTHER_TONGUE', code: 'ENGLISH', label: 'English'),
              ],
              onChanged: (v) => setState(() => _motherTongue = v),
            ),
            lookupNullableDropdown(
              ref: ref,
              category: 'BLOOD_GROUP',
              label: 'Blood Group',
              value: _bloodGroup,
              fallback: [
                for (final c in _bloodGroups)
                  LookupOption(
                    id: c,
                    category: 'BLOOD_GROUP',
                    code: c,
                    label: _formatBloodGroup(c),
                  ),
              ],
              onChanged: (v) => setState(() => _bloodGroup = v),
            ),
            lookupNullableDropdown(
              ref: ref,
              category: 'CASTE_CATEGORY',
              label: 'Cast Category',
              value: _castCategory,
              fallback: const [
                LookupOption(id: '1', category: 'CASTE_CATEGORY', code: 'OPEN', label: 'Open / General'),
                LookupOption(id: '2', category: 'CASTE_CATEGORY', code: 'OBC', label: 'OBC'),
                LookupOption(id: '3', category: 'CASTE_CATEGORY', code: 'SC', label: 'SC'),
                LookupOption(id: '4', category: 'CASTE_CATEGORY', code: 'ST', label: 'ST'),
                LookupOption(id: '5', category: 'CASTE_CATEGORY', code: 'EWS', label: 'EWS'),
              ],
              onChanged: (v) => setState(() => _castCategory = v),
            ),
            _buildTextField('Sub Caste', _subCasteCtrl),
            _buildTextField('Nominee Name', _nomineeNameCtrl),
            lookupNullableDropdown(
              ref: ref,
              category: 'FAMILY_RELATION',
              label: 'Nominee Relation',
              value: _nomineeRelation,
              fallback: const [
                LookupOption(id: '1', category: 'FAMILY_RELATION', code: 'SPOUSE', label: 'Spouse'),
                LookupOption(id: '2', category: 'FAMILY_RELATION', code: 'FATHER', label: 'Father'),
                LookupOption(id: '3', category: 'FAMILY_RELATION', code: 'MOTHER', label: 'Mother'),
                LookupOption(id: '4', category: 'FAMILY_RELATION', code: 'SON', label: 'Son'),
                LookupOption(id: '5', category: 'FAMILY_RELATION', code: 'DAUGHTER', label: 'Daughter'),
                LookupOption(id: '6', category: 'FAMILY_RELATION', code: 'OTHER', label: 'Other'),
              ],
              onChanged: (v) => setState(() => _nomineeRelation = v),
            ),
            _buildTextField('Aadhaar Number', _aadhaarNoCtrl),
            _buildTextField('PAN Number', _panNoCtrl),
            _buildTextField('Passport No', _passportNoCtrl),
            _buildTextField('Passport Issue Place', _passportIssuePlaceCtrl),
            _buildOptionalDateRow('Passport Issue Date', _passportIssueDate, _pickPassportIssueDate),
            _buildOptionalDateRow('Passport Expiry Date', _passportExpiryDate, _pickPassportExpiryDate),
            const Divider(height: 32),
            Text('Identity Documents', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 8),
            Text(
              'Upload Aadhaar, PAN, passport scan, or any other supporting document.',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 12),
            _DocumentUploadTile(
              label: 'Upload Aadhaar Card',
              kebabType: 'aadhaar-card',
              employeeId: widget.profile.id,
              currentUrl: personal?.aadhaarCardUrl,
            ),
            const SizedBox(height: 12),
            _DocumentUploadTile(
              label: 'Upload PAN Card',
              kebabType: 'pan-card',
              employeeId: widget.profile.id,
              currentUrl: personal?.panCardUrl,
            ),
            const SizedBox(height: 12),
            _DocumentUploadTile(
              label: 'Upload Passport Document',
              kebabType: 'passport',
              employeeId: widget.profile.id,
              currentUrl: widget.profile.otherInfo?.passportUrl,
            ),
            const SizedBox(height: 12),
            _DocumentUploadTile(
              label: 'Upload Other Document',
              kebabType: 'other-document',
              employeeId: widget.profile.id,
              currentUrl: personal?.otherDocumentUrl,
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _save,
              child: Text(widget.isPrivileged ? 'Save Personal Info Direct' : 'Submit Personal Change Request'),
            ),
          ],
        ),
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => const Center(child: Text('Error loading pending request status')),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final payload = {
      'birthDate': _birthDate.toUtc().toIso8601String(),
      'birthPlace': _optionalText(_birthPlaceCtrl.text),
      'homeTown': _optionalText(_homeTownCtrl.text),
      'gender': _gender,
      'maritalStatus': _maritalStatus,
      'nationality': _nationality.trim(),
      'motherTongue': _optionalNullable(_motherTongue),
      'bloodGroup': _bloodGroup,
      'castCategory': _optionalNullable(_castCategory),
      'subCaste': _optionalText(_subCasteCtrl.text),
      'nomineeName': _optionalText(_nomineeNameCtrl.text),
      'nomineeRelation': _optionalNullable(_nomineeRelation),
      'aadhaarNo': _optionalText(_aadhaarNoCtrl.text),
      'panNo': _optionalText(_panNoCtrl.text),
      'passportNo': _optionalText(_passportNoCtrl.text),
      'passportIssuePlace': _optionalText(_passportIssuePlaceCtrl.text),
      'passportIssueDate': _passportIssueDate?.toUtc().toIso8601String(),
      'passportExpiryDate': _passportExpiryDate?.toUtc().toIso8601String(),
    };

    try {
      final notifier = ref.read(profileProvider.notifier);
      if (widget.isPrivileged) {
        await notifier.updatePersonalInfoDirect(payload);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Personal Info updated directly')),
          );
        }
      } else {
        await notifier.submitPersonalChangeRequest(payload);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Personal change request submitted for HR approval. Changes apply only after approval.',
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }
}

class EditAddressTab extends ConsumerStatefulWidget {
  final EmployeeProfile profile;
  final bool isPrivileged;

  const EditAddressTab({super.key, required this.profile, required this.isPrivileged});

  @override
  ConsumerState<EditAddressTab> createState() => _EditAddressTabState();
}

class _EditAddressTabState extends ConsumerState<EditAddressTab> {
  final _formKey = GlobalKey<FormState>();
  /// Controllers live in a map so hot-reload on web never leaves fields undefined.
  final Map<String, TextEditingController> _ctrls = {};
  bool _sameAsLocal = false;
  bool _seeded = false;
  bool _listenersAttached = false;

  static const _localKeys = [
    'l_flat',
    'l_building',
    'l_area',
    'l_city',
    'l_state',
    'l_pincode',
    'l_country',
    'l_phone',
    'l_mobile',
    'l_email',
  ];

  static const _permKeys = [
    'p_flat',
    'p_building',
    'p_area',
    'p_city',
    'p_state',
    'p_pincode',
    'p_country',
    'p_phone',
    'p_mobile',
  ];

  static const _copyPairs = [
    ('l_flat', 'p_flat'),
    ('l_building', 'p_building'),
    ('l_area', 'p_area'),
    ('l_city', 'p_city'),
    ('l_state', 'p_state'),
    ('l_pincode', 'p_pincode'),
    ('l_country', 'p_country'),
    ('l_phone', 'p_phone'),
    ('l_mobile', 'p_mobile'),
  ];

  TextEditingController _c(String key) =>
      _ctrls.putIfAbsent(key, TextEditingController.new);

  String _t(String key) => _c(key).text;

  @override
  void initState() {
    super.initState();
    _seedFromProfile();
  }

  void _seedFromProfile() {
    if (_seeded) return;
    final local = widget.profile.addresses.where((a) => a.addressType == 'LOCAL').firstOrNull;
    final perm = widget.profile.addresses.where((a) => a.addressType == 'PERMANENT').firstOrNull;

    _c('l_flat').text = local?.flatBlockNo ?? '';
    _c('l_building').text = local?.buildingSociety ?? '';
    _c('l_area').text = local?.area ?? '';
    _c('l_city').text = local?.city ?? '';
    _c('l_state').text = local?.state ?? '';
    _c('l_pincode').text = local?.zipPostalCode ?? '';
    _c('l_country').text =
        (local?.country != null && local!.country!.trim().isNotEmpty) ? local.country! : 'India';
    _c('l_phone').text = local?.phoneNo ?? '';
    _c('l_mobile').text = local?.mobileNo ?? '';
    _c('l_email').text = local?.personalEmail ?? '';

    _c('p_flat').text = perm?.flatBlockNo ?? '';
    _c('p_building').text = perm?.buildingSociety ?? '';
    _c('p_area').text = perm?.area ?? '';
    _c('p_city').text = perm?.city ?? '';
    _c('p_state').text = perm?.state ?? '';
    _c('p_pincode').text = perm?.zipPostalCode ?? '';
    _c('p_country').text =
        (perm?.country != null && perm!.country!.trim().isNotEmpty) ? perm.country! : 'India';
    _c('p_phone').text = perm?.phoneNo ?? '';
    _c('p_mobile').text = perm?.mobileNo ?? '';

    _sameAsLocal = _addressesMatch();
    if (_sameAsLocal) _copyLocalToPermanent();
    _attachLocalListeners();
    _seeded = true;
  }

  void _attachLocalListeners() {
    if (_listenersAttached) return;
    for (final key in _localKeys) {
      if (key == 'l_email') continue;
      _c(key).addListener(_onLocalChanged);
    }
    _listenersAttached = true;
  }

  bool _addressesMatch() {
    String n(String v) => v.trim().toLowerCase();
    for (final (l, p) in _copyPairs) {
      if (n(_t(l)) != n(_t(p))) return false;
    }
    return _t('l_city').trim().isNotEmpty;
  }

  void _copyLocalToPermanent() {
    for (final (from, to) in _copyPairs) {
      final next = _c(from).text;
      if (_c(to).text != next) {
        _c(to).text = next;
      }
    }
  }

  void _onLocalChanged() {
    if (!_sameAsLocal || !mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_sameAsLocal) return;
      _copyLocalToPermanent();
    });
  }

  void _toggleSameAsLocal(bool? value) {
    final checked = value == true;
    if (checked) {
      _copyLocalToPermanent();
    }
    setState(() => _sameAsLocal = checked);
  }

  String? _optional(String value) {
    final t = value.trim();
    return t.isEmpty ? null : t;
  }

  Map<String, dynamic> _localPayload() => {
        'flatBlockNo': _optional(_t('l_flat')),
        'buildingSociety': _optional(_t('l_building')),
        'area': _optional(_t('l_area')),
        'city': _t('l_city').trim(),
        'state': _t('l_state').trim(),
        'zipPostalCode': _optional(_t('l_pincode')),
        'country': _optional(_t('l_country')) ?? 'India',
        'phoneNo': _optional(_t('l_phone')),
        'mobileNo': _optional(_t('l_mobile')),
        'personalEmail': _optional(_t('l_email')),
      };

  Map<String, dynamic> _permanentPayload() {
    if (_sameAsLocal) _copyLocalToPermanent();
    return {
      'flatBlockNo': _optional(_t('p_flat')),
      'buildingSociety': _optional(_t('p_building')),
      'area': _optional(_t('p_area')),
      'city': _t('p_city').trim(),
      'state': _t('p_state').trim(),
      'zipPostalCode': _optional(_t('p_pincode')),
      'country': _optional(_t('p_country')) ?? 'India',
      'phoneNo': _optional(_t('p_phone')),
      'mobileNo': _optional(_t('p_mobile')),
    };
  }

  @override
  void dispose() {
    for (final c in _ctrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  Widget _sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, top: 4),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.1,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }

  String _permLabel(String key) {
    switch (key) {
      case 'p_flat':
        return 'Flat / Block No';
      case 'p_building':
        return 'Building / Society';
      case 'p_area':
        return 'Area / Street';
      case 'p_city':
        return 'City';
      case 'p_state':
        return 'State';
      case 'p_pincode':
        return 'Pincode';
      case 'p_country':
        return 'Country';
      case 'p_phone':
        return 'Phone';
      case 'p_mobile':
        return 'Mobile';
      default:
        return key;
    }
  }

  @override
  Widget build(BuildContext context) {
    final pendingLocal = !widget.isPrivileged
        ? ref.watch(pendingRequestProvider('ADDRESS_LOCAL'))
        : const AsyncValue<Map<String, dynamic>?>.data(null);
    final pendingPermanent = !widget.isPrivileged
        ? ref.watch(pendingRequestProvider('ADDRESS_PERMANENT'))
        : const AsyncValue<Map<String, dynamic>?>.data(null);

    final hasPending = (pendingLocal.asData?.value != null) ||
        (pendingPermanent.asData?.value != null);

    if (pendingLocal.isLoading || pendingPermanent.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (pendingLocal.hasError || pendingPermanent.hasError) {
      return const Center(child: Text('Error loading pending request status'));
    }

    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (hasPending)
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.errorSoft,
                border: Border.all(color: AppColors.error),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                children: [
                  Icon(Icons.warning, color: AppColors.error),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'You currently have an address change request pending review. Saving now will replace it.',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppColors.error,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            _sectionHeader('LOCAL / CURRENT ADDRESS'),
            _buildTextField('Flat / Block No', _c('l_flat')),
            _buildTextField('Building / Society', _c('l_building')),
            _buildTextField('Area / Street', _c('l_area')),
            _buildTextField('City', _c('l_city'), required: true),
            _buildTextField('State', _c('l_state'), required: true),
            _buildTextField('Pincode', _c('l_pincode')),
            _buildTextField('Country', _c('l_country')),
            _buildTextField('Phone', _c('l_phone')),
            _buildTextField('Mobile', _c('l_mobile')),
            _buildTextField('Personal Email', _c('l_email')),
            const Divider(height: 28),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              tristate: false,
              value: _sameAsLocal,
              onChanged: _toggleSameAsLocal,
              title: const Text(
                'Permanent address same as local address',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(height: 8),
            _sectionHeader('PERMANENT ADDRESS'),
            IgnorePointer(
              ignoring: _sameAsLocal,
              child: Opacity(
                opacity: _sameAsLocal ? 0.55 : 1,
                child: Column(
                  children: [
                    for (final key in _permKeys)
                      _buildTextField(
                        _permLabel(key),
                        _c(key),
                        required: key == 'p_city' || key == 'p_state',
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _save,
              child: Text(
                widget.isPrivileged ? 'Save Address Direct' : 'Submit Address Change Request',
              ),
            ),
          ],
        ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_sameAsLocal) _copyLocalToPermanent();

    final local = _localPayload();
    final permanent = _permanentPayload();

    try {
      final notifier = ref.read(profileProvider.notifier);
      if (widget.isPrivileged) {
        await notifier.updateAddressInfoDirect('LOCAL', local);
        await notifier.updateAddressInfoDirect('PERMANENT', permanent);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Address details updated directly')),
          );
        }
      } else {
        await notifier.submitAddressChangeRequest(
          local: local,
          permanent: permanent,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Address change request submitted for HR approval. Changes apply only after approval.',
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }
}

class EditOtherTab extends ConsumerStatefulWidget {
  final EmployeeProfile profile;
  final bool isPrivileged;

  const EditOtherTab({super.key, required this.profile, required this.isPrivileged});

  @override
  ConsumerState<EditOtherTab> createState() => _EditOtherTabState();
}

class _EditOtherTabState extends ConsumerState<EditOtherTab> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _skillSetCtrl;
  late TextEditingController _hobbiesCtrl;
  late TextEditingController _strengthCtrl;
  late TextEditingController _weaknessCtrl;
  late TextEditingController _handicapDetailsCtrl;
  late TextEditingController _heightCtrl;
  late TextEditingController _weightCtrl;
  bool _isHandicapped = false;

  @override
  void initState() {
    super.initState();
    final other = widget.profile.otherInfo;
    _skillSetCtrl = TextEditingController(text: other?.skillSet ?? '');
    _hobbiesCtrl = TextEditingController(text: other?.hobbies ?? '');
    _strengthCtrl = TextEditingController(text: other?.strength ?? '');
    _weaknessCtrl = TextEditingController(text: other?.weakness ?? '');
    _handicapDetailsCtrl = TextEditingController(text: other?.handicapDetails ?? '');
    _heightCtrl = TextEditingController(text: other?.heightInFeet?.toString() ?? '');
    _weightCtrl = TextEditingController(text: other?.weightInKg?.toString() ?? '');
    _isHandicapped = other?.isHandicapped ?? false;
  }

  @override
  void dispose() {
    _skillSetCtrl.dispose();
    _hobbiesCtrl.dispose();
    _strengthCtrl.dispose();
    _weaknessCtrl.dispose();
    _handicapDetailsCtrl.dispose();
    _heightCtrl.dispose();
    _weightCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: ListView(
        padding: EdgeInsets.all(16),
        children: [
          _buildTextField('Skill Set', _skillSetCtrl),
          _buildTextField('Hobbies', _hobbiesCtrl),
          _buildTextField('Strengths', _strengthCtrl),
          _buildTextField('Weaknesses', _weaknessCtrl),
          SwitchListTile(
            title: Text('Is Handicapped'),
            value: _isHandicapped,
            activeThumbColor: Theme.of(context).colorScheme.primary,
            onChanged: (v) => setState(() => _isHandicapped = v),
          ),
          if (_isHandicapped) _buildTextField('Handicap Details', _handicapDetailsCtrl),
          _buildTextField('Height (ft)', _heightCtrl, isNumber: true),
          _buildTextField('Weight (kg)', _weightCtrl, isNumber: true),
          SizedBox(height: 24),
          FilledButton(
            onPressed: _save,
            child: Text(
              widget.isPrivileged
                  ? 'Save Traits & Other Info'
                  : 'Submit Other Info for Approval',
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final payload = {
      'skillSet': _skillSetCtrl.text.trim(),
      'hobbies': _hobbiesCtrl.text.trim(),
      'strength': _strengthCtrl.text.trim(),
      'weakness': _weaknessCtrl.text.trim(),
      'isHandicapped': _isHandicapped,
      'handicapDetails': _isHandicapped ? _handicapDetailsCtrl.text.trim() : null,
      'heightInFeet': double.tryParse(_heightCtrl.text),
      'weightInKg': double.tryParse(_weightCtrl.text),
    };
    try {
      final notifier = ref.read(profileProvider.notifier);
      if (widget.isPrivileged) {
        await notifier.updateOtherInfo(payload);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Traits updated successfully')),
          );
        }
      } else {
        await notifier.submitOtherChangeRequest(payload);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Other info submitted for HR approval. Changes apply only after approval.',
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }
}

class EditFamilyTab extends ConsumerStatefulWidget {
  final EmployeeProfile profile;

  const EditFamilyTab({super.key, required this.profile});

  @override
  ConsumerState<EditFamilyTab> createState() => _EditFamilyTabState();
}

class _EditFamilyTabState extends ConsumerState<EditFamilyTab> {
  @override
  Widget build(BuildContext context) {
    final list = widget.profile.familyMembers;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: list.isEmpty
          ? Center(child: Text('No family members yet.'))
          : ListView.builder(
              padding: EdgeInsets.all(16),
              itemCount: list.length,
              itemBuilder: (context, i) {
                final member = list[i];
                return Card(
                  elevation: 1,
                  margin: EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    title: Text(member.name),
                    subtitle: Text('${member.relation}  |  ${member.mobileNo ?? "No Contact"}'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: Icon(Icons.edit_outlined, color: Theme.of(context).colorScheme.primary),
                          onPressed: () => _showDialog(member: member),
                        ),
                        IconButton(
                          icon: Icon(Icons.delete_outline, color: AppColors.error),
                          onPressed: () => _delete(member.id),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: AppColors.midnight,
        onPressed: () => _showDialog(),
        child: Icon(Icons.add),
      ),
    );
  }

  void _showDialog({FamilyMember? member}) {
    showDialog(
      context: context,
      builder: (_) => FamilyMemberDialog(
        employeeId: widget.profile.id,
        member: member,
      ),
    );
  }

  Future<void> _delete(String id) async {
    try {
      await ref.read(profileProvider.notifier).deleteFamilyMember(id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Family member deleted')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }
}

class EditAcademicTab extends ConsumerStatefulWidget {
  final EmployeeProfile profile;

  const EditAcademicTab({super.key, required this.profile});

  @override
  ConsumerState<EditAcademicTab> createState() => _EditAcademicTabState();
}

class _EditAcademicTabState extends ConsumerState<EditAcademicTab> {
  @override
  Widget build(BuildContext context) {
    final list = widget.profile.academicQuals;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: list.isEmpty
          ? Center(child: Text('No academic qualifications added yet.'))
          : ListView.builder(
              padding: EdgeInsets.all(16),
              itemCount: list.length,
              itemBuilder: (context, i) {
                final qual = list[i];
                return Card(
                  elevation: 1,
                  margin: EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    title: Text(qual.degreeName ?? qual.degreeType),
                    subtitle: Text('${qual.schoolCollege}  |  ${qual.passingYear}'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: Icon(Icons.edit_outlined, color: Theme.of(context).colorScheme.primary),
                          onPressed: () => _showDialog(qual: qual),
                        ),
                        IconButton(
                          icon: Icon(Icons.delete_outline, color: AppColors.error),
                          onPressed: () => _delete(qual.id),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: AppColors.midnight,
        onPressed: () => _showDialog(),
        child: Icon(Icons.add),
      ),
    );
  }

  void _showDialog({AcademicQualification? qual}) {
    showDialog(
      context: context,
      builder: (_) => AcademicQualDialog(
        employeeId: widget.profile.id,
        qual: qual,
      ),
    );
  }

  Future<void> _delete(String id) async {
    try {
      await ref.read(profileProvider.notifier).deleteAcademicQualification(id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Academic record removed')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }
}

class EditBankTab extends ConsumerStatefulWidget {
  final EmployeeProfile profile;
  final bool isPrivileged;

  const EditBankTab({super.key, required this.profile, required this.isPrivileged});

  @override
  ConsumerState<EditBankTab> createState() => _EditBankTabState();
}

class _EditBankTabState extends ConsumerState<EditBankTab> {
  final _formKey = GlobalKey<FormState>();
  late String _bankName;
  late TextEditingController _accountNoCtrl;
  late TextEditingController _branchCodeCtrl;
  late TextEditingController _ifscCtrl;

  @override
  void initState() {
    super.initState();
    final bank = widget.profile.bankInfo;
    _bankName = bank?.bankName ?? '';
    _accountNoCtrl = TextEditingController(text: bank?.bankAccountNo ?? '');
    _branchCodeCtrl = TextEditingController(text: bank?.bankBranchCode ?? '');
    _ifscCtrl = TextEditingController(text: bank?.ifscCode ?? '');
  }

  @override
  void dispose() {
    _accountNoCtrl.dispose();
    _branchCodeCtrl.dispose();
    _ifscCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bank = ref.watch(profileProvider).asData?.value.bankInfo ?? widget.profile.bankInfo;

    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          lookupLabelDropdown(
            ref: ref,
            category: 'BANK_NAME',
            label: 'Bank Name',
            value: _bankName.isEmpty ? null : _bankName,
            required: true,
            fallbackLabels: const [
              'State Bank of India',
              'HDFC Bank',
              'ICICI Bank',
              'Axis Bank',
              'Bank of Baroda',
            ],
            onChanged: (v) => setState(() => _bankName = v),
          ),
          _buildTextField('Account Number', _accountNoCtrl, required: true),
          _buildTextField('Branch Code', _branchCodeCtrl),
          _buildTextField('IFSC Code', _ifscCtrl, required: true),
          const SizedBox(height: 8),
          BankDocumentUploadZone(
            employeeId: widget.profile.id,
            cancelledChequeUrl: bank?.cancelledChequeUrl,
            passbookUrl: bank?.passbookUrl,
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _save,
            child: Text(
              widget.isPrivileged ? 'Save Bank Info' : 'Submit Bank Info for Approval',
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final payload = {
      'bankName': _bankName.trim(),
      'bankAccountNo': _accountNoCtrl.text.trim(),
      'bankBranchCode': _branchCodeCtrl.text.trim(),
      'ifscCode': _ifscCtrl.text.trim(),
    };
    try {
      final notifier = ref.read(profileProvider.notifier);
      if (widget.isPrivileged) {
        await notifier.updateBankInfo(payload);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Bank Info saved')),
          );
        }
      } else {
        await notifier.submitBankChangeRequest(payload);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Bank info submitted for HR approval. Changes apply only after approval.',
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving bank: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }
}

/// Salary tab for profile edit — loads designation structure when commission is set;
/// privileged users can assign commission, override amounts, and customize rules per employee.
class EditSalaryTab extends ConsumerStatefulWidget {
  final EmployeeProfile profile;
  final bool isPrivileged;

  const EditSalaryTab({
    super.key,
    required this.profile,
    required this.isPrivileged,
  });

  @override
  ConsumerState<EditSalaryTab> createState() => _EditSalaryTabState();
}

class _EditSalaryTabState extends ConsumerState<EditSalaryTab> {
  String? _selectedCommissionCode;
  Map<String, num> _overrides = {};
  Map<String, Map<String, dynamic>> _employeeRules = {};
  bool _dirty = false;
  bool _saving = false;
  ComputedSalaryResult? _liveComputed;

  static const _totalRows = {'gross_pay', 'total_deductions', 'net_pay'};

  @override
  Widget build(BuildContext context) {
    final commissionsAsync = ref.watch(payCommissionsProvider);
    final previewAsync = ref.watch(employeeSalaryPreviewProvider(widget.profile.id));
    final name = widget.profile.generalInfo?.fullName ?? 'Employee #${widget.profile.id}';

    return previewAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text('Could not load salary preview: $e'),
          TextButton(
            onPressed: () => ref.invalidate(employeeSalaryPreviewProvider(widget.profile.id)),
            child: const Text('Retry'),
          ),
        ],
      ),
      data: (preview) {
        final overrides = _dirty ? _overrides : preview.columnOverrides;
        final employeeRules = _dirty ? _employeeRules : preview.employeeColumnRules;
        final computed = _liveComputed ?? preview.computed;

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            _buildCommissionCard(context, commissionsAsync, preview),
            const SizedBox(height: 16),
            _buildStatusBanner(context, preview),
            if (computed != null) ...[
              const SizedBox(height: 16),
              _buildSummary(context, computed),
              const SizedBox(height: 16),
              _buildColumnsCard(
                context,
                preview,
                name,
                overrides: overrides,
                employeeRules: employeeRules,
                computed: computed,
              ),
            ],
            if (widget.isPrivileged && _dirty) ...[
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _saving ? null : () => _saveOverrides(),
                child: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Save employee salary changes'),
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _buildCommissionCard(
    BuildContext context,
    AsyncValue<List<PayCommission>> commissionsAsync,
    EmployeeSalaryPreview preview,
  ) {
    final currentCode = preview.payCommissionCode;
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
            Text(
              'Pay Commission',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              preview.designation != null
                  ? 'Designation: ${preview.designation!.name}'
                  : 'Designation not set on general info',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
            const Divider(height: 20),
            if (!widget.isPrivileged)
              Text(
                currentCode != null
                    ? '${preview.payCommission?.name ?? currentCode}'
                    : 'Not assigned',
                style: const TextStyle(fontWeight: FontWeight.w600),
              )
            else
              commissionsAsync.when(
                loading: () => const LinearProgressIndicator(),
                error: (e, _) => Text('$e'),
                data: (list) {
                  final active = list.where((c) => c.isActive).toList();
                  final value = _selectedCommissionCode ?? currentCode;
                  final safeValue = active.any((c) => c.code == value) ? value : null;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      DropdownButtonFormField<String>(
                        key: ValueKey('pay-commission-$safeValue'),
                        initialValue: safeValue,
                        decoration: const InputDecoration(
                          labelText: 'Select pay commission',
                          border: OutlineInputBorder(),
                        ),
                        items: active
                            .map(
                              (c) => DropdownMenuItem(
                                value: c.code,
                                child: Text('${c.code} — ${c.name}'),
                              ),
                            )
                            .toList(),
                        onChanged: (v) => setState(() => _selectedCommissionCode = v),
                      ),
                      const SizedBox(height: 10),
                      FilledButton(
                        onPressed: _saving || (_selectedCommissionCode ?? currentCode) == null
                            ? null
                            : () => _saveCommission(_selectedCommissionCode ?? currentCode!),
                        child: const Text('Apply commission & load structure'),
                      ),
                    ],
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBanner(BuildContext context, EmployeeSalaryPreview preview) {
    String? message;
    Color? bg;
    Color? fg;
    switch (preview.reason) {
      case 'NO_DESIGNATION':
        message = 'Set employee designation in General Info before assigning pay commission.';
        bg = Colors.amber.shade50;
        fg = Colors.amber.shade900;
      case 'NO_COMMISSION':
        message = widget.isPrivileged
            ? 'Select a pay commission above to load the salary structure.'
            : 'Pay commission not assigned yet. Contact HR.';
        bg = Colors.blue.shade50;
        fg = Colors.blue.shade900;
      case 'NO_TEMPLATE':
        message =
            'No salary structure for ${preview.designation?.name ?? 'this designation'} + ${preview.payCommissionCode ?? 'commission'}. Configure it under Payroll → Structures.';
        bg = Colors.orange.shade50;
        fg = Colors.orange.shade900;
      case 'NO_RULES':
        message =
            'Structure exists but no column rules yet. Open Payroll → Structures and configure rules.';
        bg = Colors.orange.shade50;
        fg = Colors.orange.shade900;
      default:
        if (preview.configured) {
          message = 'Salary structure loaded from designation template. Amounts can be edited per employee.';
          bg = Colors.green.shade50;
          fg = Colors.green.shade900;
        }
    }
    if (message == null) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: fg!.withOpacity(0.2)),
      ),
      child: Text(message, style: TextStyle(fontSize: 12, color: fg)),
    );
  }

  Widget _buildSummary(BuildContext context, ComputedSalaryResult computed) {
    Widget chip(String label, num value, Color color) {
      return Expanded(
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.08),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: color.withOpacity(0.25)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(fontSize: 11, color: color)),
              const SizedBox(height: 4),
              Text(
                '₹${value.toStringAsFixed(0)}',
                style: TextStyle(fontWeight: FontWeight.w800, color: color, fontSize: 16),
              ),
            ],
          ),
        ),
      );
    }

    return Row(
      children: [
        chip('Gross', computed.grossPay, Colors.green.shade800),
        const SizedBox(width: 8),
        chip('Deductions', computed.totalDeductions, Colors.red.shade800),
        const SizedBox(width: 8),
        chip('Net', computed.netPay, const Color(0xFF212F3D)),
      ],
    );
  }

  Widget _buildColumnsCard(
    BuildContext context,
    EmployeeSalaryPreview preview,
    String employeeName, {
    required Map<String, num> overrides,
    required Map<String, Map<String, dynamic>> employeeRules,
    required ComputedSalaryResult computed,
  }) {
    final computedByKey = {for (final c in computed.columns) c.key: c};
    final templateRuleMap = {for (final r in preview.templateRules) r.mapKey: r};

    final cols = preview.columnDefinitions.where((c) {
      if (widget.isPrivileged) return true;
      final vis = preview.columnVisibility[c.visibilityKey];
      return vis != false;
    }).toList();

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Salary columns', style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            for (final col in cols) ...[
              _buildColumnRow(
                context,
                col: col,
                computedByKey: computedByKey,
                templateRuleMap: templateRuleMap,
                preview: preview,
                employeeName: employeeName,
                overrides: overrides,
                employeeRules: employeeRules,
              ),
              const Divider(height: 1),
            ],
          ],
        ),
      ),
    );
  }

  void _ensureLocalEditState(EmployeeSalaryPreview preview) {
    if (_dirty) return;
    _overrides = Map.from(preview.columnOverrides);
    _employeeRules = {
      for (final e in preview.employeeColumnRules.entries)
        e.key: Map<String, dynamic>.from(e.value),
    };
  }

  Widget _buildColumnRow(
    BuildContext context, {
    required PayCommissionColumn col,
    required Map<String, ComputedSalaryColumn> computedByKey,
    required Map<String, SalaryRule> templateRuleMap,
    required EmployeeSalaryPreview preview,
    required String employeeName,
    required Map<String, num> overrides,
    required Map<String, Map<String, dynamic>> employeeRules,
  }) {
    final key = col.visibilityKey;
    final row = computedByKey[key];
    final isTotal = _totalRows.contains(col.columnIdentifier);
    final hasOverride = overrides.containsKey(key);
    final hasCustomRule = employeeRules.containsKey(key);
    final displayAmount = hasOverride ? overrides[key]! : (row?.effectiveValue ?? 0);
    final formula = hasCustomRule
        ? 'Custom for this employee'
        : (row?.formulaPreview.isNotEmpty == true
            ? row!.formulaPreview
            : (templateRuleMap[key]?.formulaPreview ?? ''));

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  col.displayName,
                  style: TextStyle(
                    fontWeight: isTotal ? FontWeight.w800 : FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                if (formula.isNotEmpty)
                  Text(
                    formula,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 10, color: AppColors.textSecondary),
                  ),
                if (hasCustomRule)
                  Text(
                    'Employee rule',
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.blue.shade700,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
              ],
            ),
          ),
          if (widget.isPrivileged && !isTotal)
            SizedBox(
              width: 110,
              child: TextFormField(
                key: ValueKey('ov-$key-$displayAmount'),
                initialValue: displayAmount.toString(),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  isDense: true,
                  prefixText: '₹ ',
                  border: const OutlineInputBorder(),
                  filled: hasOverride,
                  fillColor: hasOverride ? Colors.amber.shade50 : null,
                ),
                onChanged: (v) {
                  final n = num.tryParse(v);
                  if (n == null) return;
                  setState(() {
                    _ensureLocalEditState(preview);
                    _overrides[key] = n;
                    _dirty = true;
                  });
                  _recomputeLive(preview);
                },
              ),
            )
          else
            SizedBox(
              width: 90,
              child: Text(
                '₹${displayAmount.toStringAsFixed(0)}',
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontWeight: isTotal ? FontWeight.w800 : FontWeight.w600,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
          if (widget.isPrivileged) ...[
            if (hasOverride)
              IconButton(
                tooltip: 'Revert amount',
                icon: const Icon(Icons.restart_alt, size: 18),
                onPressed: () {
                  setState(() {
                    _ensureLocalEditState(preview);
                    _overrides.remove(key);
                    _dirty = true;
                  });
                  _recomputeLive(preview);
                },
              ),
            if (col.isRuleConfigurable && preview.ruleEditorEnabled)
              IconButton(
                tooltip: 'Edit rule for this employee',
                icon: const Icon(Icons.edit_outlined, size: 18),
                onPressed: () => _editEmployeeRule(
                  col,
                  templateRuleMap,
                  preview,
                  employeeName,
                  employeeRules,
                ),
              ),
            if (hasCustomRule)
              IconButton(
                tooltip: 'Use designation default rule',
                icon: const Icon(Icons.undo, size: 18),
                onPressed: () async {
                  setState(() {
                    _ensureLocalEditState(preview);
                    _employeeRules.remove(key);
                    _dirty = true;
                  });
                  await ref.read(salaryRepositoryProvider).updateEmployeeProfile(
                        widget.profile.id,
                        columnRules: _employeeRules.isEmpty ? null : _employeeRules,
                        clearRules: _employeeRules.isEmpty,
                      );
                  ref.invalidate(employeeSalaryPreviewProvider(widget.profile.id));
                  setState(() {
                    _dirty = false;
                    _liveComputed = null;
                  });
                },
              ),
          ],
        ],
      ),
    );
  }

  Future<void> _editEmployeeRule(
    PayCommissionColumn col,
    Map<String, SalaryRule> templateRuleMap,
    EmployeeSalaryPreview preview,
    String employeeName,
    Map<String, Map<String, dynamic>> employeeRules,
  ) async {
    final key = col.visibilityKey;
    final existingBody = employeeRules[key];
    final existing = existingBody != null
        ? employeeRuleBodyToColumnRule(key, existingBody)
        : templateRuleMap[key];

    await SalaryRuleEditorSheet.show(
      context,
      column: col,
      existingRule: existing,
      allColumns: preview.columnDefinitions,
      ruleEditorEnabled: preview.ruleEditorEnabled,
      employeeMode: true,
      employeeLabel: employeeName,
      onSave: (body) async {
        _ensureLocalEditState(preview);
        final next = Map<String, Map<String, dynamic>>.from(_employeeRules);
        next[key] = body;
        setState(() {
          _employeeRules = next;
          _dirty = true;
        });
        await ref.read(salaryRepositoryProvider).updateEmployeeProfile(
              widget.profile.id,
              columnRules: next,
            );
        ref.invalidate(employeeSalaryPreviewProvider(widget.profile.id));
        setState(() {
          _dirty = false;
          _liveComputed = null;
        });
      },
    );
  }

  Future<void> _recomputeLive(EmployeeSalaryPreview preview) async {
    final templateId = preview.templateId;
    if (templateId == null) return;
    try {
      final result = await ref.read(salaryRepositoryProvider).computeSalary(
            templateId: templateId,
            employeeId: widget.profile.id,
            overrides: _overrides,
            employeeRules: _employeeRules,
          );
      if (mounted) setState(() => _liveComputed = result);
    } catch (_) {
      // Keep last known computed
    }
  }

  Future<void> _saveCommission(String code) async {
    setState(() => _saving = true);
    try {
      await ref.read(salaryRepositoryProvider).updateEmployeeProfile(
            widget.profile.id,
            payCommissionCode: code,
            clearOverrides: true,
            clearRules: true,
          );
      setState(() {
        _overrides = {};
        _employeeRules = {};
        _dirty = false;
        _liveComputed = null;
        _selectedCommissionCode = code;
      });
      ref.invalidate(employeeSalaryPreviewProvider(widget.profile.id));
      ref.invalidate(employeeSalaryProfileProvider(widget.profile.id));
      await ref.read(profileProvider.notifier).refresh();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Pay commission applied — structure loaded')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _saveOverrides() async {
    setState(() => _saving = true);
    try {
      await ref.read(salaryRepositoryProvider).updateEmployeeProfile(
            widget.profile.id,
            columnOverrides: _overrides.isEmpty ? null : _overrides,
            columnRules: _employeeRules.isEmpty ? null : _employeeRules,
            clearOverrides: _overrides.isEmpty,
            clearRules: _employeeRules.isEmpty,
          );
      setState(() {
        _dirty = false;
        _liveComputed = null;
      });
      ref.invalidate(employeeSalaryPreviewProvider(widget.profile.id));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Employee salary changes saved')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

// =============================================================================
// HELPER DIALOGS & UPLOAD WIDGETS
// =============================================================================

class FamilyMemberDialog extends ConsumerStatefulWidget {
  final int employeeId;
  final FamilyMember? member;

  const FamilyMemberDialog({
    super.key,
    required this.employeeId,
    this.member,
  });

  @override
  ConsumerState<FamilyMemberDialog> createState() => _FamilyMemberDialogState();
}

class _FamilyMemberDialogState extends ConsumerState<FamilyMemberDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  final _mobileCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _aadhaarNoCtrl = TextEditingController();
  final _employerCtrl = TextEditingController();

  String _relation = 'SPOUSE';
  DateTime? _dateOfBirth;
  bool _isDependent = false;
  bool _isEmployed = false;
  bool _isNominee = false;
  String? _aadhaarUrl;
  PickedFileData? _pendingAadhaar;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final m = widget.member;
    _nameCtrl.text = m?.name ?? '';
    _cityCtrl.text = m?.city ?? '';
    _mobileCtrl.text = m?.mobileNo ?? '';
    _emailCtrl.text = m?.personalEmail ?? '';
    _aadhaarNoCtrl.text = m?.aadhaarNo ?? '';
    _employerCtrl.text = m?.employerName ?? '';
    _relation = m?.relation ?? 'SPOUSE';
    _dateOfBirth = m?.dateOfBirth;
    _isDependent = m?.isDependent ?? false;
    _isEmployed = m?.isEmployed ?? false;
    _isNominee = m?.isNominee ?? false;
    _aadhaarUrl = m?.aadhaarUrl;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _cityCtrl.dispose();
    _mobileCtrl.dispose();
    _emailCtrl.dispose();
    _aadhaarNoCtrl.dispose();
    _employerCtrl.dispose();
    super.dispose();
  }

  String? _optional(String value) {
    final t = value.trim();
    return t.isEmpty ? null : t;
  }

  Future<void> _pickDob() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dateOfBirth ?? DateTime(1990, 1, 1),
      firstDate: DateTime(1940),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _dateOfBirth = picked);
  }

  Future<void> _pickAadhaar() async {
    // Existing member: upload immediately. New member: keep pending until save.
    if (widget.member != null) {
      await _pickAndUploadFile(
        context: context,
        ref: ref,
        employeeId: widget.employeeId,
        kebabType: 'aadhaar-family',
        imagesOnly: false,
        allowedExtensions: const ['pdf', 'jpg', 'jpeg', 'png'],
        memberId: widget.member!.id,
        onUploaded: (url) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) setState(() => _aadhaarUrl = url);
          });
        },
      );
      return;
    }

    try {
      final picked = await pickFileFromDevice(
        imagesOnly: false,
        extensions: const ['pdf', 'jpg', 'jpeg', 'png'],
      );
      if (picked != null) {
        setState(() => _pendingAadhaar = picked);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open file picker: $e'), backgroundColor: AppColors.error),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final modeText = widget.member == null ? 'Add' : 'Edit';
    final dobText = _dateOfBirth == null
        ? 'dd-mm-yyyy'
        : '${_dateOfBirth!.day.toString().padLeft(2, '0')}-${_dateOfBirth!.month.toString().padLeft(2, '0')}-${_dateOfBirth!.year}';
    final aadhaarReady = (_aadhaarUrl != null && _aadhaarUrl!.isNotEmpty) || _pendingAadhaar != null;

    return AlertDialog(
      title: Row(
        children: [
          Expanded(child: Text('$modeText Family Member')),
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close),
          ),
        ],
      ),
      scrollable: true,
      content: SizedBox(
        width: 480,
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildTextField('Name', _nameCtrl, required: true),
              lookupDropdown(
                ref: ref,
                category: 'FAMILY_RELATION',
                label: 'Relation',
                value: _relation,
                required: true,
                fallback: const [
                  LookupOption(id: '1', category: 'FAMILY_RELATION', code: 'FATHER', label: 'Father'),
                  LookupOption(id: '2', category: 'FAMILY_RELATION', code: 'MOTHER', label: 'Mother'),
                  LookupOption(id: '3', category: 'FAMILY_RELATION', code: 'SPOUSE', label: 'Spouse'),
                  LookupOption(id: '4', category: 'FAMILY_RELATION', code: 'SON', label: 'Son'),
                  LookupOption(id: '5', category: 'FAMILY_RELATION', code: 'DAUGHTER', label: 'Daughter'),
                  LookupOption(id: '6', category: 'FAMILY_RELATION', code: 'BROTHER', label: 'Brother'),
                  LookupOption(id: '7', category: 'FAMILY_RELATION', code: 'SISTER', label: 'Sister'),
                  LookupOption(id: '8', category: 'FAMILY_RELATION', code: 'OTHER', label: 'Other'),
                ],
                onChanged: (v) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) setState(() => _relation = v);
                  });
                },
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: InkWell(
                  onTap: _pickDob,
                  borderRadius: BorderRadius.circular(8),
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Date of Birth',
                      border: OutlineInputBorder(),
                      suffixIcon: Icon(Icons.calendar_today_outlined, size: 18),
                    ),
                    child: Text(
                      dobText,
                      style: TextStyle(
                        color: _dateOfBirth == null ? AppColors.textSecondary : null,
                      ),
                    ),
                  ),
                ),
              ),
              _buildTextField('City', _cityCtrl, required: true, hint: 'e.g., Gandhinagar'),
              _buildTextField('Phone Number', _mobileCtrl, required: true, hint: '10-digit phone'),
              _buildTextField('Personal Email', _emailCtrl, required: true, hint: 'email@example.com'),
              _buildTextField('Aadhaar No', _aadhaarNoCtrl, required: true, hint: '12-digit'),
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: InkWell(
                  onTap: _pickAadhaar,
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                    decoration: BoxDecoration(
                      color: aadhaarReady ? Colors.white : AppColors.mist.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: aadhaarReady
                            ? AppColors.border
                            : Theme.of(context).colorScheme.primary.withValues(alpha: 0.55),
                        style: BorderStyle.solid,
                      ),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          aadhaarReady ? Icons.check_circle : Icons.upload_file_outlined,
                          color: aadhaarReady
                              ? Colors.green
                              : Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          aadhaarReady
                              ? (_pendingAadhaar?.name ?? 'Aadhaar uploaded — tap to replace')
                              : 'Click to upload Aadhaar (PDF/Image) *',
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Wrap(
                spacing: 8,
                children: [
                  FilterChip(
                    label: const Text('Dependent'),
                    selected: _isDependent,
                    onSelected: (v) => setState(() => _isDependent = v),
                  ),
                  FilterChip(
                    label: const Text('Employed'),
                    selected: _isEmployed,
                    onSelected: (v) => setState(() => _isEmployed = v),
                  ),
                  FilterChip(
                    label: const Text('Is Nominee'),
                    selected: _isNominee,
                    onSelected: (v) => setState(() => _isNominee = v),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (_isEmployed) _buildTextField('Employer Name', _employerCtrl),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Save'),
        ),
      ],
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if ((_aadhaarUrl == null || _aadhaarUrl!.isEmpty) && _pendingAadhaar == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please upload Aadhaar document')),
      );
      return;
    }

    final email = _emailCtrl.text.trim();
    final payload = <String, dynamic>{
      'relation': _relation,
      'name': _nameCtrl.text.trim(),
      'city': _cityCtrl.text.trim(),
      'mobileNo': _mobileCtrl.text.trim(),
      'personalEmail': email.isEmpty ? null : email,
      'aadhaarNo': _aadhaarNoCtrl.text.trim(),
      'dateOfBirth': _dateOfBirth?.toUtc().toIso8601String(),
      'isNominee': _isNominee,
      'isDependent': _isDependent,
      'isEmployed': _isEmployed,
      'employerName': _isEmployed ? _optional(_employerCtrl.text) : null,
    };

    setState(() => _saving = true);
    try {
      final notifier = ref.read(profileProvider.notifier);
      if (widget.member == null) {
        final createdId = await notifier.addFamilyMember(payload);
        if (createdId != null && _pendingAadhaar != null) {
          final pending = _pendingAadhaar!;
          await notifier.uploadFile(
            kebabType: 'aadhaar-family',
            bytes: pending.bytes,
            filename: pending.name,
            memberId: createdId,
          );
          // Upload skips profile state update; refresh list after dialog closes.
          if (mounted) Navigator.pop(context);
          await notifier.refresh();
          return;
        }
      } else {
        await notifier.updateFamilyMember(widget.member!.id, payload);
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

class AcademicQualDialog extends ConsumerStatefulWidget {
  final int employeeId;
  final AcademicQualification? qual;

  const AcademicQualDialog({
    super.key,
    required this.employeeId,
    this.qual,
  });

  @override
  ConsumerState<AcademicQualDialog> createState() => _AcademicQualDialogState();
}

class _AcademicQualDialogState extends ConsumerState<AcademicQualDialog> {
  static const _levels = ['SSC', 'HSC_DIPLOMA', 'UG', 'PG', 'PHD', 'OTHER'];
  static const _mediums = ['ENGLISH', 'GUJARATI', 'HINDI', 'MARATHI', 'OTHER'];
  static const _hscStreams = ['SCIENCE', 'COMMERCE', 'ARTS_HUMANITIES'];

  final _formKey = GlobalKey<FormState>();
  final _degreeNameCtrl = TextEditingController();
  final _institutionCtrl = TextEditingController();
  final _schoolCollegeCtrl = TextEditingController();
  final _boardCtrl = TextEditingController();
  final _passingYearCtrl = TextEditingController();
  final _percentCtrl = TextEditingController();
  final _cgpaCtrl = TextEditingController();

  // Plain strings (not enums) — safer on Flutter web / hot reload.
  String _uiLevel = 'SSC';
  String _program = 'HSC';
  String _medium = 'ENGLISH';
  String _hscStream = 'SCIENCE';
  String? _certificateUrl;
  final List<String?> _semUrls = List<String?>.filled(8, null);
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final q = widget.qual;
    _degreeNameCtrl.text = q?.degreeName ?? '';
    _institutionCtrl.text = q?.boardUniversity ?? '';
    _schoolCollegeCtrl.text = q?.schoolCollege ?? '';
    _passingYearCtrl.text = (q?.passingYear ?? DateTime.now().year).toString();
    _percentCtrl.text = q?.percentage?.toString() ?? '';
    _cgpaCtrl.text = q?.grade ?? '';
    _medium = q?.medium ?? 'ENGLISH';
    if (!_mediums.contains(_medium)) _medium = 'ENGLISH';
    _certificateUrl = q?.certificateUrl;
    _semUrls[0] = q?.sem1MarksheetUrl;
    _semUrls[1] = q?.sem2MarksheetUrl;
    _semUrls[2] = q?.sem3MarksheetUrl;
    _semUrls[3] = q?.sem4MarksheetUrl;
    _semUrls[4] = q?.sem5MarksheetUrl;
    _semUrls[5] = q?.sem6MarksheetUrl;
    _semUrls[6] = q?.sem7MarksheetUrl;
    _semUrls[7] = q?.sem8MarksheetUrl;
    _applyDegreeType(q?.degreeType ?? 'SSC', q?.specialization);
  }

  void _applyDegreeType(String raw, String? specialization) {
    switch (raw.toUpperCase()) {
      case 'SSC':
        _uiLevel = 'SSC';
        break;
      case 'HSC':
        _uiLevel = 'HSC_DIPLOMA';
        _program = 'HSC';
        if (specialization != null && _hscStreams.contains(specialization)) {
          _hscStream = specialization;
        }
        break;
      case 'DIPLOMA':
        _uiLevel = 'HSC_DIPLOMA';
        _program = 'DIPLOMA';
        break;
      case 'UG':
      case 'BACHELOR':
        _uiLevel = 'UG';
        break;
      case 'PG':
      case 'MASTER':
        _uiLevel = 'PG';
        break;
      case 'PHD':
        _uiLevel = 'PHD';
        break;
      case 'OTHER':
        _uiLevel = 'OTHER';
        break;
      default:
        _uiLevel = 'SSC';
    }
  }

  String get _effectiveLevel =>
      _uiLevel == 'HSC_DIPLOMA' ? _program : _uiLevel;

  String get _apiDegreeType {
    switch (_effectiveLevel) {
      case 'SSC':
        return 'SSC';
      case 'HSC':
        return 'HSC';
      case 'DIPLOMA':
        return 'DIPLOMA';
      case 'UG':
        return 'BACHELOR';
      case 'PG':
        return 'MASTER';
      case 'PHD':
        return 'PHD';
      case 'OTHER':
        return 'OTHER';
      default:
        return 'SSC';
    }
  }

  int get _semCount {
    switch (_effectiveLevel) {
      case 'DIPLOMA':
        return 6;
      case 'UG':
        return 8;
      case 'PG':
        return 4;
      case 'SSC':
      case 'HSC':
        return 1;
      default:
        return 0;
    }
  }

  bool get _showSingleMarksheet =>
      _effectiveLevel == 'SSC' || _effectiveLevel == 'HSC';

  bool get _showSemGrid =>
      _effectiveLevel == 'DIPLOMA' || _effectiveLevel == 'UG' || _effectiveLevel == 'PG';

  bool get _showCertificate =>
      const {'DIPLOMA', 'UG', 'PG', 'PHD', 'OTHER'}.contains(_effectiveLevel);

  bool get _showSchoolCollege => _effectiveLevel != 'SSC';

  bool get _showStream => _effectiveLevel == 'HSC';

  String get _certificateLabel {
    switch (_effectiveLevel) {
      case 'DIPLOMA':
        return 'Diploma Certificate';
      case 'PHD':
        return 'PhD Certificate';
      case 'OTHER':
        return 'Certificate';
      default:
        return 'Degree Certificate';
    }
  }

  String _levelLabel(String v) {
    switch (v) {
      case 'HSC_DIPLOMA':
        return 'HSC/Diploma';
      default:
        return v;
    }
  }

  /// Defer setState so dropdown close / upload completion never hits a locked tree.
  void _safeSetState(VoidCallback fn) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(fn);
    });
  }

  @override
  void dispose() {
    _degreeNameCtrl.dispose();
    _institutionCtrl.dispose();
    _schoolCollegeCtrl.dispose();
    _boardCtrl.dispose();
    _passingYearCtrl.dispose();
    _percentCtrl.dispose();
    _cgpaCtrl.dispose();
    super.dispose();
  }

  Future<void> _uploadMarksheet(int semIndex) async {
    await _pickAndUploadFile(
      context: context,
      ref: ref,
      employeeId: widget.employeeId,
      kebabType: 'marksheet',
      imagesOnly: false,
      allowedExtensions: const ['pdf', 'jpg', 'jpeg', 'png'],
      qualId: widget.qual?.id,
      sem: semIndex + 1,
      onUploaded: (url) => _safeSetState(() => _semUrls[semIndex] = url),
    );
  }

  Future<void> _uploadCertificate() async {
    await _pickAndUploadFile(
      context: context,
      ref: ref,
      employeeId: widget.employeeId,
      kebabType: 'certificate',
      imagesOnly: false,
      allowedExtensions: const ['pdf', 'jpg', 'jpeg', 'png'],
      qualId: widget.qual?.id,
      onUploaded: (url) => _safeSetState(() => _certificateUrl = url),
    );
  }

  Widget _dropdown({
    required String label,
    required String value,
    required List<String> options,
    required String Function(String) display,
    required ValueChanged<String> onChanged,
  }) {
    final safeValue = options.contains(value) ? value : options.first;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: DropdownButtonFormField<String>(
        key: ValueKey('$label-$safeValue-${options.join()}'),
        initialValue: safeValue,
        decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
        items: options
            .map((o) => DropdownMenuItem<String>(value: o, child: Text(display(o))))
            .toList(),
        onChanged: (v) {
          if (v == null) return;
          _safeSetState(() => onChanged(v));
        },
      ),
    );
  }

  Widget _uploadBox({
    required String label,
    required bool filled,
    required VoidCallback onTap,
    String? subtitle,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 12),
          decoration: BoxDecoration(
            color: filled ? Colors.white : AppColors.mist.withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: filled
                  ? AppColors.border
                  : Theme.of(context).colorScheme.primary.withValues(alpha: 0.5),
            ),
          ),
          child: Column(
            children: [
              Icon(
                filled ? Icons.check_circle : Icons.cloud_upload_outlined,
                color: filled ? Colors.green : Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 6),
              Text(label, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
              Text(
                filled ? (subtitle ?? 'Uploaded — tap to replace') : 'Click to upload (PDF/Image)',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _field(
    String label,
    TextEditingController controller, {
    bool required = false,
    bool isNumber = false,
    String? hint,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
        keyboardType: isNumber ? TextInputType.number : TextInputType.text,
        decoration: InputDecoration(
          labelText: required ? '$label *' : label,
          hintText: hint,
          border: const OutlineInputBorder(),
        ),
        validator: required
            ? (v) {
                if (v == null || v.trim().isEmpty) return '$label is required';
                return null;
              }
            : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final modeText = widget.qual == null ? 'Add' : 'Edit';
    final semCount = _semCount;

    return AlertDialog(
      title: Row(
        children: [
          Expanded(child: Text('$modeText Qualification')),
          IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
        ],
      ),
      scrollable: true,
      content: SizedBox(
        width: 520,
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _dropdown(
                label: 'Level *',
                value: _uiLevel,
                options: _levels,
                display: _levelLabel,
                onChanged: (v) {
                  _uiLevel = v;
                  if (v == 'HSC_DIPLOMA') {
                    if (_program != 'HSC' && _program != 'DIPLOMA') _program = 'HSC';
                  }
                },
              ),
              if (_uiLevel == 'HSC_DIPLOMA')
                _dropdown(
                  label: 'Program *',
                  value: _program,
                  options: const ['HSC', 'DIPLOMA'],
                  display: (v) => v == 'HSC' ? 'HSC (Higher Secondary)' : 'Diploma',
                  onChanged: (v) => _program = v,
                ),
              lookupDropdown(
                ref: ref,
                category: 'ACADEMIC_MEDIUM',
                label: 'Medium',
                value: _medium,
                required: true,
                fallback: [
                  for (final m in _mediums)
                    LookupOption(
                      id: m,
                      category: 'ACADEMIC_MEDIUM',
                      code: m,
                      label: m[0] + m.substring(1).toLowerCase(),
                    ),
                ],
                onChanged: (v) => _safeSetState(() => _medium = v),
              ),
              _field('Degree / Certificate Name', _degreeNameCtrl, required: true, hint: 'e.g., Bachelor of Science'),
              if (_showStream)
                lookupDropdown(
                  ref: ref,
                  category: 'HSC_STREAM',
                  label: 'Stream',
                  value: _hscStream,
                  required: true,
                  fallback: [
                    for (final s in _hscStreams)
                      LookupOption(
                        id: s,
                        category: 'HSC_STREAM',
                        code: s,
                        label: s.replaceAll('_', ' / '),
                      ),
                  ],
                  onChanged: (v) => _safeSetState(() => _hscStream = v),
                ),
              _field(
                'Institution / Board / University',
                _institutionCtrl,
                required: true,
                hint: 'e.g., Gujarat Secondary Board',
              ),
              if (_showSchoolCollege)
                _field('School / College Name', _schoolCollegeCtrl, hint: 'e.g., XYZ College'),
              _field('Board / University', _boardCtrl, hint: 'e.g., Gujarat University'),
              _field('Passing Year', _passingYearCtrl, required: true, isNumber: true, hint: '2026'),
              _field('Percentage', _percentCtrl, isNumber: true, hint: '0-100'),
              _field('CGPA', _cgpaCtrl, isNumber: true, hint: '0-10'),
              if (_showSingleMarksheet) ...[
                const SizedBox(height: 4),
                const Text('Marksheet Upload *', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                const SizedBox(height: 8),
                _uploadBox(
                  label: 'Click to upload marksheet (PDF/Image)',
                  filled: _semUrls[0] != null && _semUrls[0]!.isNotEmpty,
                  onTap: () => _uploadMarksheet(0),
                  subtitle: 'Marksheet uploaded — tap to replace',
                ),
              ],
              if (_showSemGrid) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Expanded(
                      child: Text('Semester Marksheets', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                    ),
                    Text('$semCount semesters', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: List.generate(semCount, (i) {
                    final filled = _semUrls[i] != null && _semUrls[i]!.isNotEmpty;
                    return SizedBox(
                      width: 150,
                      child: _uploadBox(
                        label: 'Sem ${i + 1}',
                        filled: filled,
                        onTap: () => _uploadMarksheet(i),
                      ),
                    );
                  }),
                ),
              ],
              if (_showCertificate) ...[
                const SizedBox(height: 12),
                Text('$_certificateLabel *', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                const SizedBox(height: 8),
                _uploadBox(
                  label: 'Click to upload certificate (PDF/Image)',
                  filled: _certificateUrl != null && _certificateUrl!.isNotEmpty,
                  onTap: _uploadCertificate,
                  subtitle: 'Certificate uploaded — tap to replace',
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Save'),
        ),
      ],
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    if (_showSingleMarksheet && (_semUrls[0] == null || _semUrls[0]!.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please upload marksheet')));
      return;
    }
    if (_showCertificate && (_certificateUrl == null || _certificateUrl!.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Please upload $_certificateLabel')));
      return;
    }

    final institution = _institutionCtrl.text.trim();
    final school = _schoolCollegeCtrl.text.trim();
    final board = _boardCtrl.text.trim();

    final payload = <String, dynamic>{
      'degreeType': _apiDegreeType,
      'degreeName': _degreeNameCtrl.text.trim(),
      'medium': _medium,
      'boardUniversity': board.isNotEmpty ? board : institution,
      'schoolCollege': school.isNotEmpty ? school : institution,
      'passingYear': int.parse(_passingYearCtrl.text.trim()),
      'percentage': double.tryParse(_percentCtrl.text.trim()),
      'grade': _cgpaCtrl.text.trim().isEmpty ? null : _cgpaCtrl.text.trim(),
      'specialization': _showStream ? _hscStream : null,
      'totalSemesters': _showSemGrid ? _semCount : (_showSingleMarksheet ? 1 : null),
      if (_certificateUrl != null && _certificateUrl!.isNotEmpty) 'certificateUrl': _certificateUrl,
      for (var i = 0; i < 8; i++)
        if (_semUrls[i] != null && _semUrls[i]!.isNotEmpty) 'sem${i + 1}MarksheetUrl': _semUrls[i],
    };

    setState(() => _saving = true);
    try {
      final notifier = ref.read(profileProvider.notifier);
      if (widget.qual == null) {
        await notifier.addAcademicQualification(payload);
      } else {
        await notifier.updateAcademicQualification(widget.qual!.id, payload);
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

// =============================================================================
// FILE UPLOAD HELPERS
// =============================================================================

Future<void> _pickAndUploadFile({
  required BuildContext context,
  required WidgetRef ref,
  required int employeeId,
  required String kebabType,
  bool imagesOnly = true,
  List<String>? allowedExtensions,
  String? qualId,
  int? sem,
  String? memberId,
  ValueChanged<String>? onUploaded,
  VoidCallback? onUploadStarted,
  VoidCallback? onUploadFinished,
}) async {
  PickedFileData? picked;
  try {
    picked = await pickFileFromDevice(
      imagesOnly: imagesOnly,
      extensions: allowedExtensions,
    );
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not open file picker: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
    return;
  }

  if (picked == null) return;
  if (!context.mounted) return;

  onUploadStarted?.call();
  final messenger = ScaffoldMessenger.of(context);
  try {
    final notifier = ref.read(profileProvider.notifier);
    final url = await notifier.uploadFile(
      kebabType: kebabType,
      bytes: picked.bytes,
      filename: picked.name,
      qualId: qualId,
      sem: sem,
      memberId: memberId,
    );
    onUploaded?.call(url);
    if (context.mounted) {
      messenger.showSnackBar(
        const SnackBar(content: Text('File uploaded successfully')),
      );
    }
  } catch (e) {
    if (context.mounted) {
      messenger.showSnackBar(
        SnackBar(content: Text('Upload failed: $e'), backgroundColor: AppColors.error),
      );
    }
  } finally {
    onUploadFinished?.call();
  }
}

class _DocumentUploadTile extends ConsumerWidget {
  final String label;
  final String kebabType;
  final int employeeId;
  final String? currentUrl;
  final String? qualId;
  final int? sem;
  final String? memberId;
  final ValueChanged<String>? onUploaded;

  const _DocumentUploadTile({
    required this.label,
    required this.kebabType,
    required this.employeeId,
    this.currentUrl,
    this.qualId,
    this.sem,
    this.memberId,
    this.onUploaded,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isUploaded = currentUrl != null && currentUrl!.isNotEmpty;

    return InkWell(
      onTap: () => _pickAndUploadFile(
        context: context,
        ref: ref,
        employeeId: employeeId,
        kebabType: kebabType,
        imagesOnly: false,
        allowedExtensions: const ['pdf', 'jpg', 'jpeg', 'png'],
        qualId: qualId,
        sem: sem,
        memberId: memberId,
        onUploaded: onUploaded,
      ),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isUploaded ? Colors.white : AppColors.mist.withValues(alpha: 0.35),
          border: Border.all(
            color: isUploaded
                ? AppColors.border
                : Theme.of(context).colorScheme.primary.withValues(alpha: 0.55),
          ),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Icon(
              isUploaded ? Icons.check_circle : Icons.upload_file,
              color: isUploaded ? Colors.green : Theme.of(context).colorScheme.primary,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  Text(
                    isUploaded ? 'Tap to replace file' : 'Tap to upload from device',
                    style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class BankDocumentUploadZone extends ConsumerStatefulWidget {
  final int employeeId;
  final String? cancelledChequeUrl;
  final String? passbookUrl;

  const BankDocumentUploadZone({
    super.key,
    required this.employeeId,
    this.cancelledChequeUrl,
    this.passbookUrl,
  });

  @override
  ConsumerState<BankDocumentUploadZone> createState() => _BankDocumentUploadZoneState();
}

class _BankDocumentUploadZoneState extends ConsumerState<BankDocumentUploadZone> {
  bool _uploadingCheque = false;
  bool _uploadingPassbook = false;
  String? _chequeUrl;
  String? _passbookUrl;

  @override
  void initState() {
    super.initState();
    _chequeUrl = widget.cancelledChequeUrl;
    _passbookUrl = widget.passbookUrl;
  }

  @override
  void didUpdateWidget(covariant BankDocumentUploadZone oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.cancelledChequeUrl != widget.cancelledChequeUrl) {
      _chequeUrl = widget.cancelledChequeUrl;
    }
    if (oldWidget.passbookUrl != widget.passbookUrl) {
      _passbookUrl = widget.passbookUrl;
    }
  }

  Future<void> _upload(String kebabType) async {
    await _pickAndUploadFile(
      context: context,
      ref: ref,
      employeeId: widget.employeeId,
      kebabType: kebabType,
      imagesOnly: false,
      allowedExtensions: const ['pdf', 'jpg', 'jpeg', 'png'],
      onUploadStarted: () {
        if (!mounted) return;
        setState(() {
          if (kebabType == 'cancelled-cheque') {
            _uploadingCheque = true;
          } else {
            _uploadingPassbook = true;
          }
        });
      },
      onUploaded: (url) {
        if (!mounted) return;
        setState(() {
          if (kebabType == 'cancelled-cheque') {
            _chequeUrl = url;
          } else {
            _passbookUrl = url;
          }
        });
      },
      onUploadFinished: () {
        if (!mounted) return;
        setState(() {
          _uploadingCheque = false;
          _uploadingPassbook = false;
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.account_balance_wallet_outlined, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Bank Documents',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ),
              ],
            ),
            const Divider(height: 20),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _MediaUploadBox(
                    label: 'Cancelled Cheque',
                    url: _chequeUrl,
                    icon: Icons.receipt_long_outlined,
                    uploading: _uploadingCheque,
                    onTap: () => _upload('cancelled-cheque'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _MediaUploadBox(
                    label: 'Passbook',
                    url: _passbookUrl,
                    icon: Icons.menu_book_outlined,
                    uploading: _uploadingPassbook,
                    onTap: () => _upload('passbook'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class BonusUploadZone extends ConsumerStatefulWidget {
  final int employeeId;
  final String? photoUrl;
  final String? signatureUrl;

  const BonusUploadZone({
    super.key,
    required this.employeeId,
    this.photoUrl,
    this.signatureUrl,
  });

  @override
  ConsumerState<BonusUploadZone> createState() => _BonusUploadZoneState();
}

class _BonusUploadZoneState extends ConsumerState<BonusUploadZone> {
  bool _uploadingPhoto = false;
  bool _uploadingSignature = false;
  String? _photoUrl;
  String? _signatureUrl;

  @override
  void initState() {
    super.initState();
    _uploadingPhoto = false;
    _uploadingSignature = false;
    _photoUrl = widget.photoUrl;
    _signatureUrl = widget.signatureUrl;
  }

  @override
  void didUpdateWidget(covariant BonusUploadZone oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.photoUrl != widget.photoUrl) _photoUrl = widget.photoUrl;
    if (oldWidget.signatureUrl != widget.signatureUrl) _signatureUrl = widget.signatureUrl;
  }

  Future<void> _upload(String kebabType) async {
    await _pickAndUploadFile(
      context: context,
      ref: ref,
      employeeId: widget.employeeId,
      kebabType: kebabType,
      imagesOnly: true,
      onUploadStarted: () {
        if (!mounted) return;
        setState(() {
          if (kebabType == 'photo') {
            _uploadingPhoto = true;
          } else {
            _uploadingSignature = true;
          }
        });
      },
      onUploaded: (url) {
        if (!mounted) return;
        setState(() {
          if (kebabType == 'photo') {
            _photoUrl = url;
          } else {
            _signatureUrl = url;
          }
        });
      },
      onUploadFinished: () {
        if (!mounted) return;
        setState(() {
          _uploadingPhoto = false;
          _uploadingSignature = false;
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.photo_camera_back, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                const Text(
                  'Profile Photo & Signature',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ],
            ),
            const Divider(height: 20),
            Row(
              children: [
                Expanded(
                  child: _MediaUploadBox(
                    label: 'Photo',
                    url: _photoUrl,
                    icon: Icons.person_outline,
                    uploading: _uploadingPhoto == true,
                    onTap: () => _upload('photo'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _MediaUploadBox(
                    label: 'Signature',
                    url: _signatureUrl,
                    icon: Icons.draw_outlined,
                    uploading: _uploadingSignature == true,
                    onTap: () => _upload('signature'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MediaUploadBox extends StatelessWidget {
  const _MediaUploadBox({
    required this.label,
    required this.url,
    required this.icon,
    this.uploading = false,
    required this.onTap,
  });

  final String label;
  final String? url;
  final IconData icon;
  final bool uploading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final has = url != null && url!.isNotEmpty;
    final isUploading = uploading;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: isUploading ? null : onTap,
      child: Material(
        color: AppColors.mist.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          height: 100,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: has
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.outlineVariant,
            ),
          ),
          child: isUploading
              ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
              : has
                  ? Stack(
                      fit: StackFit.expand,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(9),
                          child: Image.network(url!, fit: BoxFit.cover),
                        ),
                        Positioned(
                          right: 6,
                          bottom: 6,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.black54,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'Replace',
                              style: TextStyle(color: Colors.white, fontSize: 10),
                            ),
                          ),
                        ),
                      ],
                    )
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(icon, color: Theme.of(context).textTheme.bodySmall?.color, size: 28),
                        const SizedBox(height: 6),
                        Text(
                          'No $label uploaded',
                          style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Tap to upload',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
        ),
      ),
    );
  }
}

Widget _buildTextField(
  String label,
  TextEditingController controller, {
  bool required = false,
  bool isNumber = false,
  bool readOnly = false,
  String? hint,
}) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 16.0),
    child: TextFormField(
      controller: controller,
      readOnly: readOnly,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      decoration: InputDecoration(
        labelText: required ? '$label *' : label,
        hintText: hint,
        filled: readOnly,
        fillColor: readOnly ? Colors.grey.shade100 : null,
      ),
      validator: required
          ? (v) {
              if (v == null || v.trim().isEmpty) return '$label is required';
              return null;
            }
          : null,
    ),
  );
}
