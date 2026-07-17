import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../auth/presentation/auth_providers.dart';
import '../../domain/profile_models.dart';
import '../profile_notifier.dart';

class ProfileEditScreen extends ConsumerStatefulWidget {
  final int? employeeId;

  const ProfileEditScreen({super.key, this.employeeId});

  @override
  ConsumerState<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends ConsumerState<ProfileEditScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _tabs = ['General', 'Personal', 'Address', 'Other', 'Family', 'Academic', 'Bank'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
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
    _tabController.dispose();
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
    final isPrivileged = ['ADMIN', 'HR', 'HOI', 'REGISTRAR', 'VC'].contains(roleName.toUpperCase());

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text('Edit Profile'),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          indicatorColor: Theme.of(context).colorScheme.primary,
          labelColor: Theme.of(context).colorScheme.primary,
          unselectedLabelColor: Colors.white70,
          tabs: _tabs.map((tab) => Tab(text: tab)).toList(),
        ),
      ),
      body: profileAsyncVal.when(
        data: (profile) => TabBarView(
          controller: _tabController,
          children: [
            EditGeneralTab(profile: profile, isPrivileged: isPrivileged),
            EditPersonalTab(profile: profile, isPrivileged: isPrivileged),
            EditAddressTab(profile: profile, isPrivileged: isPrivileged),
            EditOtherTab(profile: profile),
            EditFamilyTab(profile: profile),
            EditAcademicTab(profile: profile),
            EditBankTab(profile: profile),
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
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _fullNameCtrl;
  late TextEditingController _empCodeCtrl;
  late TextEditingController _departmentCtrl;
  late TextEditingController _designationCtrl;
  late TextEditingController _shiftCtrl;
  late TextEditingController _appointmentCtrl;

  @override
  void initState() {
    super.initState();
    final info = widget.profile.generalInfo;
    _fullNameCtrl = TextEditingController(text: info?.fullName ?? '');
    _empCodeCtrl = TextEditingController(text: info?.employeeCode ?? '');
    _departmentCtrl = TextEditingController(text: info?.department ?? '');
    _designationCtrl = TextEditingController(text: info?.designation ?? '');
    _shiftCtrl = TextEditingController(text: info?.shift ?? '');
    _appointmentCtrl = TextEditingController(text: info?.appointmentType ?? '');
  }

  @override
  void dispose() {
    _fullNameCtrl.dispose();
    _empCodeCtrl.dispose();
    _departmentCtrl.dispose();
    _designationCtrl.dispose();
    _shiftCtrl.dispose();
    _appointmentCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isPrivileged) {
      return ListView(
        padding: EdgeInsets.all(24),
        children: [
          Icon(Icons.lock_outline, size: 48, color: AppColors.textSecondary),
          SizedBox(height: 12),
          Text(
            'Employment details are read-only.',
            textAlign: TextAlign.center,
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 4),
          Text(
            'Please contact HR to update employment fields. You can still upload your photo and signature below.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textSecondary),
          ),
          SizedBox(height: 24),
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
        padding: EdgeInsets.all(16),
        children: [
          BonusUploadZone(
            employeeId: widget.profile.id,
            photoUrl: widget.profile.photoUrl,
            signatureUrl: widget.profile.signatureUrl,
          ),
          SizedBox(height: 16),
          _buildTextField('Full Name', _fullNameCtrl, required: true),
          _buildTextField('Employee Code', _empCodeCtrl),
          _buildTextField('Department', _departmentCtrl, required: true),
          _buildTextField('Designation', _designationCtrl, required: true),
          _buildTextField('Shift', _shiftCtrl),
          _buildTextField('Appointment Type', _appointmentCtrl),
          SizedBox(height: 24),
          FilledButton(
            onPressed: _save,
            child: Text('Save General Details'),
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    try {
      final notifier = ref.read(profileProvider.notifier);
      await notifier.updateGeneralInfoDirect({
        'fullName': _fullNameCtrl.text.trim(),
        'employeeCode': _empCodeCtrl.text.trim(),
        'department': _departmentCtrl.text.trim(),
        'designation': _designationCtrl.text.trim(),
        'shift': _shiftCtrl.text.trim(),
        'appointmentType': _appointmentCtrl.text.trim(),
      });
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
  late TextEditingController _nationalityCtrl;
  late TextEditingController _homeTownCtrl;
  late TextEditingController _nomineeNameCtrl;
  late TextEditingController _nomineeRelationCtrl;
  late TextEditingController _panNoCtrl;
  late TextEditingController _aadhaarNoCtrl;
  String _gender = 'MALE';
  String _maritalStatus = 'SINGLE';
  String? _bloodGroup;

  @override
  void initState() {
    super.initState();
    final info = widget.profile.personalInfo;
    _nationalityCtrl = TextEditingController(text: info?.nationality ?? 'INDIAN');
    _homeTownCtrl = TextEditingController(text: info?.homeTown ?? '');
    _nomineeNameCtrl = TextEditingController(text: info?.nomineeName ?? '');
    _nomineeRelationCtrl = TextEditingController(text: info?.nomineeRelation ?? '');
    _panNoCtrl = TextEditingController(text: info?.panNo ?? '');
    _aadhaarNoCtrl = TextEditingController(text: info?.aadhaarNo ?? '');
    _gender = info?.gender ?? 'MALE';
    _maritalStatus = info?.maritalStatus ?? 'SINGLE';
    _bloodGroup = info?.bloodGroup;
  }

  String _formatBloodGroup(String value) => value.replaceAll('_', ' ');

  @override
  void dispose() {
    _nationalityCtrl.dispose();
    _homeTownCtrl.dispose();
    _nomineeNameCtrl.dispose();
    _nomineeRelationCtrl.dispose();
    _panNoCtrl.dispose();
    _aadhaarNoCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Check pending request (for self-service)
    final pendingRequest = !widget.isPrivileged
        ? ref.watch(pendingRequestProvider('PERSONAL'))
        : const AsyncValue<Map<String, dynamic>?>.data(null);

    return pendingRequest.when(
      data: (req) => Form(
        key: _formKey,
        child: ListView(
          padding: EdgeInsets.all(16),
          children: [
            if (req != null)
              Container(
                margin: EdgeInsets.only(bottom: 16),
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.errorSoft,
                  border: Border.all(color: AppColors.error),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
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
            DropdownButtonFormField<String>(
              initialValue: _gender,
              decoration: const InputDecoration(labelText: 'Gender'),
              items: [
                DropdownMenuItem(value: 'MALE', child: Text('Male')),
                DropdownMenuItem(value: 'FEMALE', child: Text('Female')),
                DropdownMenuItem(value: 'OTHER', child: Text('Other')),
              ],
              onChanged: (v) {
                if (v != null) setState(() => _gender = v);
              },
            ),
            SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _maritalStatus,
              decoration: const InputDecoration(labelText: 'Marital Status'),
              items: [
                DropdownMenuItem(value: 'SINGLE', child: Text('Single')),
                DropdownMenuItem(value: 'MARRIED', child: Text('Married')),
                DropdownMenuItem(value: 'DIVORCED', child: Text('Divorced')),
                DropdownMenuItem(value: 'WIDOWED', child: Text('Widowed')),
              ],
              onChanged: (v) {
                if (v != null) setState(() => _maritalStatus = v);
              },
            ),
            SizedBox(height: 16),
            DropdownButtonFormField<String?>(
              initialValue: _bloodGroup,
              decoration: const InputDecoration(labelText: 'Blood Group'),
              items: [
                const DropdownMenuItem<String?>(value: null, child: Text('Not set')),
                ..._bloodGroups.map(
                  (bg) => DropdownMenuItem<String?>(
                    value: bg,
                    child: Text(_formatBloodGroup(bg)),
                  ),
                ),
              ],
              onChanged: (v) => setState(() => _bloodGroup = v),
            ),
            SizedBox(height: 16),
            _buildTextField('Nationality', _nationalityCtrl, required: true),
            _buildTextField('Home Town', _homeTownCtrl),
            _buildTextField('Aadhaar Number', _aadhaarNoCtrl),
            _buildTextField('PAN Number', _panNoCtrl),
            _buildTextField('Nominee Name', _nomineeNameCtrl),
            _buildTextField('Nominee Relation', _nomineeRelationCtrl),
            const Divider(height: 32),
            Text('Photo & Signature', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            SizedBox(height: 12),
            BonusUploadZone(
              employeeId: widget.profile.id,
              photoUrl: widget.profile.photoUrl,
              signatureUrl: widget.profile.signatureUrl,
            ),
            SizedBox(height: 16),
            Text('Identity Documents', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            SizedBox(height: 12),
            _DocumentUploadTile(
              label: 'Upload Aadhaar Card',
              kebabType: 'aadhaar-card',
              employeeId: widget.profile.id,
              currentUrl: widget.profile.personalInfo?.aadhaarCardUrl,
            ),
            SizedBox(height: 12),
            _DocumentUploadTile(
              label: 'Upload PAN Card',
              kebabType: 'pan-card',
              employeeId: widget.profile.id,
              currentUrl: widget.profile.personalInfo?.panCardUrl,
            ),
            SizedBox(height: 24),
            FilledButton(
              onPressed: _save,
              child: Text(widget.isPrivileged ? 'Save Personal Info Direct' : 'Submit Personal Change Request'),
            ),
          ],
        ),
      ),
      loading: () => Center(child: CircularProgressIndicator()),
      error: (_, __) => Center(child: Text('Error loading pending request status')),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final payload = {
      'gender': _gender,
      'maritalStatus': _maritalStatus,
      'bloodGroup': _bloodGroup,
      'nationality': _nationalityCtrl.text.trim(),
      'homeTown': _homeTownCtrl.text.trim(),
      'aadhaarNo': _aadhaarNoCtrl.text.trim(),
      'panNo': _panNoCtrl.text.trim(),
      'nomineeName': _nomineeNameCtrl.text.trim(),
      'nomineeRelation': _nomineeRelationCtrl.text.trim(),
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
            const SnackBar(content: Text('Change request submitted for approval')),
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
  late TextEditingController _localCityCtrl;
  late TextEditingController _localStateCtrl;
  late TextEditingController _localZipCtrl;
  late TextEditingController _localMobileCtrl;
  late TextEditingController _localInstEmailCtrl;

  late TextEditingController _permCityCtrl;
  late TextEditingController _permStateCtrl;
  late TextEditingController _permZipCtrl;
  late TextEditingController _permMobileCtrl;

  @override
  void initState() {
    super.initState();
    final local = widget.profile.addresses.where((a) => a.addressType == 'LOCAL').firstOrNull;
    final perm = widget.profile.addresses.where((a) => a.addressType == 'PERMANENT').firstOrNull;

    _localCityCtrl = TextEditingController(text: local?.city ?? '');
    _localStateCtrl = TextEditingController(text: local?.state ?? '');
    _localZipCtrl = TextEditingController(text: local?.zipPostalCode ?? '');
    _localMobileCtrl = TextEditingController(text: local?.mobileNo ?? '');
    _localInstEmailCtrl = TextEditingController(text: local?.instituteEmail ?? '');

    _permCityCtrl = TextEditingController(text: perm?.city ?? '');
    _permStateCtrl = TextEditingController(text: perm?.state ?? '');
    _permZipCtrl = TextEditingController(text: perm?.zipPostalCode ?? '');
    _permMobileCtrl = TextEditingController(text: perm?.mobileNo ?? '');
  }

  @override
  void dispose() {
    _localCityCtrl.dispose();
    _localStateCtrl.dispose();
    _localZipCtrl.dispose();
    _localMobileCtrl.dispose();
    _localInstEmailCtrl.dispose();
    _permCityCtrl.dispose();
    _permStateCtrl.dispose();
    _permZipCtrl.dispose();
    _permMobileCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pendingRequest = !widget.isPrivileged
        ? ref.watch(pendingRequestProvider('ADDRESS'))
        : const AsyncValue<Map<String, dynamic>?>.data(null);

    return pendingRequest.when(
      data: (req) => Form(
        key: _formKey,
        child: ListView(
          padding: EdgeInsets.all(16),
          children: [
            if (req != null)
              Container(
                margin: EdgeInsets.only(bottom: 16),
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.errorSoft,
                  border: Border.all(color: AppColors.error),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning, color: AppColors.error),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'You currently have a address change request pending review. Saving now will overwrite it.',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.error),
                      ),
                    ),
                  ],
                ),
              ),
            Text('Local Address', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const Divider(),
            _buildTextField('City', _localCityCtrl),
            _buildTextField('State', _localStateCtrl),
            _buildTextField('Zip Code', _localZipCtrl),
            _buildTextField('Mobile Number', _localMobileCtrl),
            _buildTextField('Institute Email', _localInstEmailCtrl),
            SizedBox(height: 24),
            Text('Permanent Address', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const Divider(),
            _buildTextField('City', _permCityCtrl),
            _buildTextField('State', _permStateCtrl),
            _buildTextField('Zip Code', _permZipCtrl),
            _buildTextField('Mobile Number', _permMobileCtrl),
            SizedBox(height: 24),
            FilledButton(
              onPressed: _save,
              child: Text(widget.isPrivileged ? 'Save Address Direct' : 'Submit Address Change Request'),
            ),
          ],
        ),
      ),
      loading: () => Center(child: CircularProgressIndicator()),
      error: (_, __) => Center(child: Text('Error loading pending request status')),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final payload = {
      'local': {
        'city': _localCityCtrl.text.trim(),
        'state': _localStateCtrl.text.trim(),
        'zipPostalCode': _localZipCtrl.text.trim(),
        'mobileNo': _localMobileCtrl.text.trim(),
        'instituteEmail': _localInstEmailCtrl.text.trim(),
      },
      'permanent': {
        'city': _permCityCtrl.text.trim(),
        'state': _permStateCtrl.text.trim(),
        'zipPostalCode': _permZipCtrl.text.trim(),
        'mobileNo': _permMobileCtrl.text.trim(),
      }
    };

    try {
      final notifier = ref.read(profileProvider.notifier);
      if (widget.isPrivileged) {
        await notifier.updateAddressInfoDirect('LOCAL', payload['local']!);
        await notifier.updateAddressInfoDirect('PERMANENT', payload['permanent']!);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Address details updated directly')),
          );
        }
      } else {
        await notifier.submitAddressChangeRequest(payload);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Address change request submitted')),
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

  const EditOtherTab({super.key, required this.profile});

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
          const Divider(height: 32),
          Text('Passport Document', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          SizedBox(height: 12),
          _DocumentUploadTile(
            label: 'Upload Passport',
            kebabType: 'passport',
            employeeId: widget.profile.id,
            currentUrl: widget.profile.otherInfo?.passportUrl,
          ),
          SizedBox(height: 24),
          FilledButton(
            onPressed: _save,
            child: Text('Save Traits & Other Info'),
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    try {
      final notifier = ref.read(profileProvider.notifier);
      await notifier.updateOtherInfo({
        'skillSet': _skillSetCtrl.text.trim(),
        'hobbies': _hobbiesCtrl.text.trim(),
        'strength': _strengthCtrl.text.trim(),
        'weakness': _weaknessCtrl.text.trim(),
        'isHandicapped': _isHandicapped,
        'handicapDetails': _isHandicapped ? _handicapDetailsCtrl.text.trim() : null,
        'heightInFeet': double.tryParse(_heightCtrl.text),
        'weightInKg': double.tryParse(_weightCtrl.text),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Traits updated successfully')),
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
        onSave: () {
          ref.read(profileProvider.notifier).refresh();
        },
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
        onSave: () {
          ref.read(profileProvider.notifier).refresh();
        },
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

  const EditBankTab({super.key, required this.profile});

  @override
  ConsumerState<EditBankTab> createState() => _EditBankTabState();
}

class _EditBankTabState extends ConsumerState<EditBankTab> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _bankNameCtrl;
  late TextEditingController _accountNoCtrl;
  late TextEditingController _branchCodeCtrl;
  late TextEditingController _ifscCtrl;

  @override
  void initState() {
    super.initState();
    final bank = widget.profile.bankInfo;
    _bankNameCtrl = TextEditingController(text: bank?.bankName ?? '');
    _accountNoCtrl = TextEditingController(text: bank?.bankAccountNo ?? '');
    _branchCodeCtrl = TextEditingController(text: bank?.bankBranchCode ?? '');
    _ifscCtrl = TextEditingController(text: bank?.ifscCode ?? '');
  }

  @override
  void dispose() {
    _bankNameCtrl.dispose();
    _accountNoCtrl.dispose();
    _branchCodeCtrl.dispose();
    _ifscCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: ListView(
        padding: EdgeInsets.all(16),
        children: [
          _buildTextField('Bank Name', _bankNameCtrl, required: true),
          _buildTextField('Account Number', _accountNoCtrl, required: true),
          _buildTextField('Branch Code', _branchCodeCtrl),
          _buildTextField('IFSC Code', _ifscCtrl, required: true),
          SizedBox(height: 24),
          BonusUploadZone(
            employeeId: widget.profile.id,
            photoUrl: widget.profile.photoUrl,
            signatureUrl: widget.profile.signatureUrl,
          ),
          SizedBox(height: 24),
          FilledButton(
            onPressed: _save,
            child: Text('Save Bank Info'),
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    try {
      final notifier = ref.read(profileProvider.notifier);
      await notifier.updateBankInfo({
        'bankName': _bankNameCtrl.text.trim(),
        'bankAccountNo': _accountNoCtrl.text.trim(),
        'bankBranchCode': _branchCodeCtrl.text.trim(),
        'ifscCode': _ifscCtrl.text.trim(),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Bank Info saved directly')),
        );
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

// =============================================================================
// HELPER DIALOGS & UPLOAD WIDGETS
// =============================================================================

class FamilyMemberDialog extends ConsumerStatefulWidget {
  final int employeeId;
  final FamilyMember? member;
  final VoidCallback onSave;

  const FamilyMemberDialog({
    super.key,
    required this.employeeId,
    this.member,
    required this.onSave,
  });

  @override
  ConsumerState<FamilyMemberDialog> createState() => _FamilyMemberDialogState();
}

class _FamilyMemberDialogState extends ConsumerState<FamilyMemberDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameCtrl;
  late TextEditingController _mobileCtrl;
  late TextEditingController _emailCtrl;
  late TextEditingController _cityCtrl;
  late TextEditingController _aadhaarNoCtrl;
  String _relation = 'OTHER';
  bool _isNominee = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.member?.name ?? '');
    _mobileCtrl = TextEditingController(text: widget.member?.mobileNo ?? '');
    _emailCtrl = TextEditingController(text: widget.member?.personalEmail ?? '');
    _cityCtrl = TextEditingController(text: widget.member?.city ?? '');
    _aadhaarNoCtrl = TextEditingController(text: widget.member?.aadhaarNo ?? '');
    _relation = widget.member?.relation ?? 'OTHER';
    _isNominee = widget.member?.isNominee ?? false;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _mobileCtrl.dispose();
    _emailCtrl.dispose();
    _cityCtrl.dispose();
    _aadhaarNoCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final modeText = widget.member == null ? 'Add' : 'Edit';
    return AlertDialog(
      title: Text('$modeText Family Member'),
      scrollable: true,
      content: Form(
        key: _formKey,
        child: Column(
          children: [
            _buildTextField('Full Name', _nameCtrl, required: true),
            DropdownButtonFormField<String>(
              initialValue: _relation,
              decoration: const InputDecoration(labelText: 'Relationship'),
              items: [
                DropdownMenuItem(value: 'FATHER', child: Text('Father')),
                DropdownMenuItem(value: 'MOTHER', child: Text('Mother')),
                DropdownMenuItem(value: 'SPOUSE', child: Text('Spouse')),
                DropdownMenuItem(value: 'SON', child: Text('Son')),
                DropdownMenuItem(value: 'DAUGHTER', child: Text('Daughter')),
                DropdownMenuItem(value: 'SIBLING', child: Text('Sibling')),
                DropdownMenuItem(value: 'OTHER', child: Text('Other')),
              ],
              onChanged: (v) {
                if (v != null) setState(() => _relation = v);
              },
            ),
            SizedBox(height: 12),
            _buildTextField('Mobile No', _mobileCtrl),
            _buildTextField('Personal Email', _emailCtrl),
            _buildTextField('City', _cityCtrl),
            _buildTextField('Aadhaar No', _aadhaarNoCtrl),
            SwitchListTile(
              title: Text('Is Nominee?'),
              value: _isNominee,
              activeThumbColor: Theme.of(context).colorScheme.primary,
              onChanged: (v) => setState(() => _isNominee = v),
            ),
            if (widget.member != null) ...[
              const Divider(),
              _DocumentUploadTile(
                label: 'Upload Family Aadhaar',
                kebabType: 'aadhaar-family',
                employeeId: widget.employeeId,
                memberId: widget.member!.id,
                currentUrl: widget.member!.aadhaarUrl,
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text('Cancel')),
        FilledButton(onPressed: _save, child: Text('Save')),
      ],
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final payload = {
      'relation': _relation,
      'name': _nameCtrl.text.trim(),
      'mobileNo': _mobileCtrl.text.trim(),
      'personalEmail': _emailCtrl.text.trim(),
      'city': _cityCtrl.text.trim(),
      'aadhaarNo': _aadhaarNoCtrl.text.trim(),
      'isNominee': _isNominee,
    };

    try {
      final notifier = ref.read(profileProvider.notifier);
      if (widget.member == null) {
        await notifier.addFamilyMember(payload);
      } else {
        await notifier.updateFamilyMember(widget.member!.id, payload);
      }
      widget.onSave();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }
}

class AcademicQualDialog extends ConsumerStatefulWidget {
  final int employeeId;
  final AcademicQualification? qual;
  final VoidCallback onSave;

  const AcademicQualDialog({
    super.key,
    required this.employeeId,
    this.qual,
    required this.onSave,
  });

  @override
  ConsumerState<AcademicQualDialog> createState() => _AcademicQualDialogState();
}

class _AcademicQualDialogState extends ConsumerState<AcademicQualDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _degreeNameCtrl;
  late TextEditingController _universityCtrl;
  late TextEditingController _collegeCtrl;
  late TextEditingController _percentCtrl;
  late TextEditingController _passingYearCtrl;
  String _degreeType = 'SSC';
  String _medium = 'ENGLISH';
  String? _certificateUrl;
  final List<String?> _semUrls = List<String?>.filled(8, null);

  @override
  void initState() {
    super.initState();
    _degreeNameCtrl = TextEditingController(text: widget.qual?.degreeName ?? '');
    _universityCtrl = TextEditingController(text: widget.qual?.boardUniversity ?? '');
    _collegeCtrl = TextEditingController(text: widget.qual?.schoolCollege ?? '');
    _percentCtrl = TextEditingController(text: widget.qual?.percentage?.toString() ?? '');
    _passingYearCtrl = TextEditingController(text: widget.qual?.passingYear.toString() ?? '2020');
    _degreeType = _normalizeDegreeType(widget.qual?.degreeType ?? 'SSC');
    _medium = widget.qual?.medium ?? 'ENGLISH';
    _certificateUrl = widget.qual?.certificateUrl;
    _semUrls[0] = widget.qual?.sem1MarksheetUrl;
    _semUrls[1] = widget.qual?.sem2MarksheetUrl;
    _semUrls[2] = widget.qual?.sem3MarksheetUrl;
    _semUrls[3] = widget.qual?.sem4MarksheetUrl;
    _semUrls[4] = widget.qual?.sem5MarksheetUrl;
    _semUrls[5] = widget.qual?.sem6MarksheetUrl;
    _semUrls[6] = widget.qual?.sem7MarksheetUrl;
    _semUrls[7] = widget.qual?.sem8MarksheetUrl;
  }

  String _normalizeDegreeType(String raw) {
    switch (raw.toUpperCase()) {
      case 'UG':
      case 'BACHELOR':
        return 'BACHELOR';
      case 'PG':
      case 'MASTER':
        return 'MASTER';
      case 'OTHER':
        return 'BACHELOR';
      default:
        return raw.toUpperCase();
    }
  }

  int get _semCount {
    switch (_degreeType) {
      case 'DIPLOMA':
        return 6;
      case 'MASTER':
        return 4;
      case 'BACHELOR':
        return 8;
      case 'PHD':
        return 0;
      default:
        // SSC / HSC — single marksheet slot (stored as sem1)
        return 1;
    }
  }

  bool get _showCertificate {
    switch (_degreeType) {
      case 'SSC':
      case 'HSC':
        return false;
      default:
        return true;
    }
  }

  @override
  void dispose() {
    _degreeNameCtrl.dispose();
    _universityCtrl.dispose();
    _collegeCtrl.dispose();
    _percentCtrl.dispose();
    _passingYearCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final modeText = widget.qual == null ? 'Add' : 'Edit';
    final semCount = _semCount;
    return AlertDialog(
      title: Text('$modeText Qualification'),
      scrollable: true,
      content: SizedBox(
        width: 440,
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DropdownButtonFormField<String>(
                initialValue: _degreeType,
                decoration: const InputDecoration(labelText: 'Degree Type'),
                items: [
                  DropdownMenuItem(value: 'SSC', child: Text('SSC / 10th')),
                  DropdownMenuItem(value: 'HSC', child: Text('HSC / 12th')),
                  DropdownMenuItem(value: 'DIPLOMA', child: Text('Diploma')),
                  DropdownMenuItem(value: 'BACHELOR', child: Text('Undergraduate (Bachelor)')),
                  DropdownMenuItem(value: 'MASTER', child: Text('Postgraduate (Master)')),
                  DropdownMenuItem(value: 'PHD', child: Text('Ph.D / Doctorate')),
                ],
                onChanged: (v) {
                  if (v != null) setState(() => _degreeType = v);
                },
              ),
              SizedBox(height: 12),
              _buildTextField('Degree/Course Name', _degreeNameCtrl, required: true),
              _buildTextField('Board / University', _universityCtrl, required: true),
              _buildTextField('School / College', _collegeCtrl, required: true),
              _buildTextField('Passing Year', _passingYearCtrl, required: true, isNumber: true),
              _buildTextField('Percentage Marks', _percentCtrl, isNumber: true),
              DropdownButtonFormField<String>(
                initialValue: _medium,
                decoration: const InputDecoration(labelText: 'Instruction Medium'),
                items: [
                  DropdownMenuItem(value: 'ENGLISH', child: Text('English')),
                  DropdownMenuItem(value: 'GUJARATI', child: Text('Gujarati')),
                  DropdownMenuItem(value: 'HINDI', child: Text('Hindi')),
                  DropdownMenuItem(value: 'MARATHI', child: Text('Marathi')),
                  DropdownMenuItem(value: 'OTHER', child: Text('Other')),
                ],
                onChanged: (v) {
                  if (v != null) setState(() => _medium = v);
                },
              ),
              const Divider(height: 24),
              Text(
                'Documents (PDF / Image)',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              if (semCount > 0) ...[
                Text(
                  semCount == 1
                      ? 'Marksheet Upload'
                      : 'Semester Marksheets ($semCount)',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).textTheme.bodySmall?.color,
                  ),
                ),
                SizedBox(height: 8),
                ...List.generate(semCount, (i) {
                  final sem = i + 1;
                  return Padding(
                    padding: EdgeInsets.only(bottom: 10),
                    child: _DocumentUploadTile(
                      label: semCount == 1 ? 'Marksheet' : 'SEM $sem Marksheet',
                      kebabType: 'marksheet',
                      employeeId: widget.employeeId,
                      qualId: widget.qual?.id,
                      sem: sem,
                      currentUrl: _semUrls[i],
                      onUploaded: (url) => setState(() => _semUrls[i] = url),
                    ),
                  );
                }),
              ],
              if (_showCertificate) ...[
                if (semCount > 0) SizedBox(height: 4),
                _DocumentUploadTile(
                  label: _degreeType == 'DIPLOMA'
                      ? 'Diploma Certificate'
                      : _degreeType == 'PHD'
                          ? 'PhD Certificate'
                          : 'Degree Certificate',
                  kebabType: 'certificate',
                  employeeId: widget.employeeId,
                  qualId: widget.qual?.id,
                  currentUrl: _certificateUrl,
                  onUploaded: (url) => setState(() => _certificateUrl = url),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text('Cancel')),
        FilledButton(onPressed: _save, child: Text('Save')),
      ],
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final payload = <String, dynamic>{
      'degreeType': _degreeType,
      'degreeName': _degreeNameCtrl.text.trim(),
      'boardUniversity': _universityCtrl.text.trim(),
      'schoolCollege': _collegeCtrl.text.trim(),
      'passingYear': int.parse(_passingYearCtrl.text.trim()),
      'percentage': double.tryParse(_percentCtrl.text.trim()),
      'medium': _medium,
      if (_certificateUrl != null && _certificateUrl!.isNotEmpty)
        'certificateUrl': _certificateUrl,
      for (var i = 0; i < 8; i++)
        if (_semUrls[i] != null && _semUrls[i]!.isNotEmpty)
          'sem${i + 1}MarksheetUrl': _semUrls[i],
    };

    try {
      final notifier = ref.read(profileProvider.notifier);
      if (widget.qual == null) {
        await notifier.addAcademicQualification(payload);
      } else {
        await notifier.updateAcademicQualification(widget.qual!.id, payload);
      }
      widget.onSave();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }
}

// =============================================================================
// PLATFORM INDEPENDENT DOCUMENT UPLOADER (No picker depend: inputs path or dummy)
// =============================================================================

class _DocumentUploadTile extends ConsumerStatefulWidget {
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
  ConsumerState<_DocumentUploadTile> createState() => _DocumentUploadTileState();
}

class _DocumentUploadTileState extends ConsumerState<_DocumentUploadTile> {
  final _pathController = TextEditingController();
  bool _uploading = false;
  String? _localUrl;

  @override
  void initState() {
    super.initState();
    _localUrl = widget.currentUrl;
  }

  @override
  void didUpdateWidget(covariant _DocumentUploadTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentUrl != widget.currentUrl) {
      _localUrl = widget.currentUrl;
    }
  }

  @override
  void dispose() {
    _pathController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isUploaded = _localUrl != null && _localUrl!.isNotEmpty;

    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isUploaded ? Colors.white : AppColors.mist.withValues(alpha: 0.35),
        border: Border.all(
          color: isUploaded ? AppColors.border : Theme.of(context).colorScheme.primary.withValues(alpha: 0.55),
        ),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  widget.label,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                ),
              ),
              if (isUploaded)
                Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.green, size: 16),
                    SizedBox(width: 4),
                    Text(
                      'Uploaded',
                      style: TextStyle(color: Colors.green, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ],
                )
              else
                Text(
                  'Placeholder — upload file',
                  style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.primary),
                ),
            ],
          ),
          if (!isUploaded) ...[
            SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(vertical: 18),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Theme.of(context).colorScheme.outlineVariant, style: BorderStyle.solid),
              ),
              child: Column(
                children: [
                  Icon(Icons.cloud_upload_outlined, color: Theme.of(context).textTheme.bodySmall?.color, size: 28),
                  SizedBox(height: 6),
                  Text(
                    'No file yet — enter a path below or use dummy upload',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
          ],
          SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _pathController,
                  decoration: const InputDecoration(
                    hintText: 'Enter absolute local file path to upload',
                    contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  ),
                  style: const TextStyle(fontSize: 12),
                ),
              ),
              SizedBox(width: 8),
              _uploading
                  ? SizedBox(width: 32, height: 32, child: CircularProgressIndicator(strokeWidth: 2))
                  : ElevatedButton(
                      onPressed: _startUpload,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.midnight,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: Text('Upload', style: TextStyle(fontSize: 12)),
                    ),
            ],
          ),
          SizedBox(height: 6),
          TextButton(
            onPressed: _uploadDummyFile,
            style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: Size.zero),
            child: Text('Or generate & upload dummy pdf file', style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.primary)),
          ),
        ],
      ),
    );
  }

  Future<void> _doUpload(File file) async {
    setState(() => _uploading = true);
    try {
      final notifier = ref.read(profileProvider.notifier);
      final url = await notifier.uploadFile(
        kebabType: widget.kebabType,
        file: file,
        qualId: widget.qualId,
        sem: widget.sem,
        memberId: widget.memberId,
      );
      if (!mounted) return;
      setState(() {
        _localUrl = url;
        _pathController.clear();
      });
      widget.onUploaded?.call(url);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('File uploaded successfully')),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload failed: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _startUpload() async {
    final path = _pathController.text.trim();
    if (path.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a file path first')),
      );
      return;
    }
    final file = File(path);
    if (!file.existsSync()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('File at entered path does not exist on disk')),
      );
      return;
    }
    await _doUpload(file);
  }

  Future<void> _uploadDummyFile() async {
    final dir = Directory.systemTemp;
    final file = File('${dir.path}/dummy_attachment_${widget.kebabType}_${widget.sem ?? 0}.pdf');
    await file.writeAsString('Dummy file contents for Cloudinary test upload.');
    await _doUpload(file);
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
  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.border),
      ),
      child: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.photo_camera_back, color: Theme.of(context).colorScheme.primary),
                SizedBox(width: 8),
                Text(
                  'Profile Photo & Signature',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ],
            ),
            const Divider(height: 20),
            _MediaPreviewRow(
              photoUrl: widget.photoUrl,
              signatureUrl: widget.signatureUrl,
            ),
            SizedBox(height: 12),
            _DocumentUploadTile(
              label: 'Upload Profile Photo',
              kebabType: 'photo',
              employeeId: widget.employeeId,
              currentUrl: widget.photoUrl,
            ),
            SizedBox(height: 12),
            _DocumentUploadTile(
              label: 'Upload Digital Signature',
              kebabType: 'signature',
              employeeId: widget.employeeId,
              currentUrl: widget.signatureUrl,
            ),
          ],
        ),
      ),
    );
  }
}

class _MediaPreviewRow extends StatelessWidget {
  const _MediaPreviewRow({this.photoUrl, this.signatureUrl});

  final String? photoUrl;
  final String? signatureUrl;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: _previewBox(context, 'Photo', photoUrl, Icons.person_outline)),
        SizedBox(width: 12),
        Expanded(child: _previewBox(context, 'Signature', signatureUrl, Icons.draw_outlined)),
      ],
    );
  }

  Widget _previewBox(BuildContext context, String label, String? url, IconData icon) {
    final has = url != null && url.isNotEmpty;
    return Container(
      height: 110,
      decoration: BoxDecoration(
        color: AppColors.mist.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: has ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.outlineVariant,
          style: has ? BorderStyle.solid : BorderStyle.solid,
        ),
      ),
      child: has
          ? ClipRRect(
              borderRadius: BorderRadius.circular(9),
              child: Image.network(
                url,
                fit: BoxFit.cover,
                width: double.infinity,
                errorBuilder: (_, __, ___) => _empty(context, label, icon),
              ),
            )
          : _empty(context, label, icon),
    );
  }

  Widget _empty(BuildContext context, String label, IconData icon) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Theme.of(context).textTheme.bodySmall?.color, size: 28),
          SizedBox(height: 6),
          Text(
            'No $label uploaded',
            style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

// Helper components

Widget _buildTextField(String label, TextEditingController controller, {bool required = false, bool isNumber = false}) {
  return Padding(
    padding: EdgeInsets.only(bottom: 16.0),
    child: TextFormField(
      controller: controller,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      decoration: InputDecoration(
        labelText: required ? '$label *' : label,
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
