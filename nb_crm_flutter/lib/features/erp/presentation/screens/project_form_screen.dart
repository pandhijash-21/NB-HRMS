import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_back_button.dart';
import '../../../../core/utils/platform_file_picker.dart';
import '../../../lookups/presentation/lookup_dropdown.dart';
import '../../../org/presentation/org_providers.dart';
import '../../domain/project_models.dart';
import '../project_providers.dart';

class _DocDraft {
  _DocDraft({
    this.id,
    this.typeCode,
    this.name = '',
    this.remarks = '',
    this.fileUrl,
    this.fileName,
    this.mimeType,
    this.fileSize,
  });

  String? id;
  String? typeCode;
  String name;
  String remarks;
  String? fileUrl;
  String? fileName;
  String? mimeType;
  int? fileSize;
  bool uploading = false;
}

class ProjectFormScreen extends ConsumerStatefulWidget {
  const ProjectFormScreen({super.key, this.projectId});

  final String? projectId;

  @override
  ConsumerState<ProjectFormScreen> createState() => _ProjectFormScreenState();
}

class _ProjectFormScreenState extends ConsumerState<ProjectFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _projectId = TextEditingController();
  final _name = TextEditingController();
  final _rera = TextEditingController();
  final _notes = TextEditingController();
  final _projectArea = TextEditingController(text: '0.00');
  final _cost = TextEditingController(text: '0');
  final _address = TextEditingController();
  final _landmark = TextEditingController();
  final _pincode = TextEditingController(text: '0');
  final _plotArea = TextEditingController(text: '0.00');
  final _specNotes = TextEditingController();

  String? _organizationId;
  String? _instituteId;
  String? _categoryCode;
  String? _subCategoryCode;
  String? _structureCode;
  String? _segmentCode;
  DateTime? _completion;
  String? _statusCode = 'ACTIVE';
  int? _ownerEmployeeId;
  String? _areaUnitCode;
  String? _imageUrl;
  bool _imageUploading = false;

  String? _countryCode;
  String? _stateCode;
  String? _cityCode;
  String? _areaCode;

  final _amenitiesCodes = <String>{};
  String? _livabilityCode;
  String? _bankTieUpCode;
  String? _devAuthorityCode;
  String? _elecProviderCode;

  final _docs = <_DocDraft>[];
  bool _saving = false;
  bool _hydrated = false;

  bool get _isEdit => widget.projectId != null;

  @override
  void dispose() {
    _projectId.dispose();
    _name.dispose();
    _rera.dispose();
    _notes.dispose();
    _projectArea.dispose();
    _cost.dispose();
    _address.dispose();
    _landmark.dispose();
    _pincode.dispose();
    _plotArea.dispose();
    _specNotes.dispose();
    super.dispose();
  }

  void _hydrate(ErpProject p) {
    if (_hydrated) return;
    _hydrated = true;
    _projectId.text = p.displayId;
    _name.text = p.name;
    _organizationId = p.organizationId;
    _instituteId = p.instituteId;
    _categoryCode = p.categoryCode;
    _subCategoryCode = p.subCategoryCode;
    _structureCode = p.structureCode;
    _segmentCode = p.segmentCode;
    _rera.text = p.reraNo ?? '';
    _completion = p.expectedCompletionDate;
    _notes.text = p.notes ?? '';
    _statusCode = p.statusCode ?? 'ACTIVE';
    _ownerEmployeeId = p.ownerEmployeeId;
    _projectArea.text = (p.totalProjectArea ?? 0).toStringAsFixed(2);
    _areaUnitCode = p.areaUnitCode;
    _cost.text = (p.estimatedCost ?? 0).toStringAsFixed(0);
    _imageUrl = p.imageUrl;
    _address.text = p.address ?? '';
    _landmark.text = p.landmark ?? '';
    _countryCode = p.countryCode;
    _stateCode = p.stateCode;
    _cityCode = p.cityCode;
    _areaCode = p.areaCode;
    _pincode.text = p.pincode ?? '0';
    _plotArea.text = (p.totalPlotArea ?? 0).toStringAsFixed(2);
    _amenitiesCodes
      ..clear()
      ..addAll(p.amenitiesCodes);
    _livabilityCode = p.livabilityCode;
    _bankTieUpCode = p.bankTieUpCode;
    _devAuthorityCode = p.developmentAuthorityCode;
    _elecProviderCode = p.electricityProviderCode;
    _specNotes.text = p.specNotes ?? '';
    _docs
      ..clear()
      ..addAll(
        p.documents.map(
          (d) => _DocDraft(
            id: d.id,
            typeCode: d.typeCode,
            name: d.name,
            remarks: d.remarks ?? '',
            fileUrl: d.fileUrl,
            fileName: d.fileName,
            mimeType: d.mimeType,
            fileSize: d.fileSize,
          ),
        ),
      );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _completion ?? DateTime.now().add(const Duration(days: 365)),
      firstDate: DateTime(DateTime.now().year - 1),
      lastDate: DateTime(DateTime.now().year + 20),
    );
    if (picked != null) setState(() => _completion = picked);
  }

  Future<void> _uploadImage() async {
    final picked = await pickFileFromDevice(imagesOnly: true);
    if (picked == null) return;
    setState(() => _imageUploading = true);
    try {
      final uploaded = await ref.read(projectRepositoryProvider).uploadFile(
            bytes: picked.bytes,
            filename: picked.name,
            folder: 'erp/projects/images',
          );
      if (!mounted) return;
      setState(() {
        _imageUrl = uploaded.url;
        _imageUploading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _imageUploading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _uploadDoc(_DocDraft row) async {
    final picked = await pickFileFromDevice(
      imagesOnly: false,
      extensions: const ['pdf', 'png', 'jpg', 'jpeg', 'doc', 'docx'],
    );
    if (picked == null) return;
    setState(() => row.uploading = true);
    try {
      final uploaded = await ref.read(projectRepositoryProvider).uploadFile(
            bytes: picked.bytes,
            filename: picked.name,
            folder: 'erp/projects/docs',
          );
      if (!mounted) return;
      setState(() {
        row.fileUrl = uploaded.url;
        row.fileName = uploaded.fileName ?? picked.name;
        row.mimeType = uploaded.mimeType;
        row.fileSize = uploaded.fileSize;
        if (row.name.trim().isEmpty) row.name = picked.name;
        row.uploading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => row.uploading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_isEdit) {
      final projectNo = int.tryParse(_projectId.text.trim());
      if (projectNo == null || projectNo < 1) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Enter a valid Project ID')),
        );
        return;
      }
    }
    if (_completion == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Expected completion date is required')),
      );
      return;
    }
    setState(() => _saving = true);
    final projectNo = int.tryParse(_projectId.text.trim());
    final body = {
      if (!_isEdit && projectNo != null) 'projectNo': projectNo,
      'name': _name.text.trim(),
      'organizationId': _organizationId,
      'instituteId': _instituteId,
      'categoryCode': _categoryCode,
      'subCategoryCode': _subCategoryCode,
      'structureCode': _structureCode,
      'segmentCode': _segmentCode,
      'reraNo': _rera.text.trim(),
      'expectedCompletionDate':
          '${_completion!.year.toString().padLeft(4, '0')}-${_completion!.month.toString().padLeft(2, '0')}-${_completion!.day.toString().padLeft(2, '0')}',
      'notes': _notes.text.trim(),
      'statusCode': _statusCode,
      'ownerEmployeeId': _ownerEmployeeId,
      'totalProjectArea': double.tryParse(_projectArea.text) ?? 0,
      'areaUnitCode': _areaUnitCode,
      'estimatedCost': double.tryParse(_cost.text) ?? 0,
      'imageUrl': _imageUrl,
      'address': _address.text.trim(),
      'landmark': _landmark.text.trim(),
      'countryCode': _countryCode,
      'stateCode': _stateCode,
      'cityCode': _cityCode,
      'areaCode': _areaCode,
      'pincode': _pincode.text.trim(),
      'totalPlotArea': double.tryParse(_plotArea.text) ?? 0,
      'amenitiesCodes': _amenitiesCodes.toList(),
      'livabilityCode': _livabilityCode,
      'bankTieUpCode': _bankTieUpCode,
      'developmentAuthorityCode': _devAuthorityCode,
      'electricityProviderCode': _elecProviderCode,
      'specNotes': _specNotes.text.trim(),
      'documents': _docs
          .where((d) => d.fileUrl != null && d.fileUrl!.isNotEmpty)
          .map(
            (d) => {
              if (d.id != null) 'id': d.id,
              'typeCode': d.typeCode,
              'name': d.name.trim().isEmpty ? (d.fileName ?? 'Document') : d.name.trim(),
              'remarks': d.remarks.trim(),
              'fileUrl': d.fileUrl,
              'fileName': d.fileName,
              'mimeType': d.mimeType,
              'fileSize': d.fileSize,
            },
          )
          .toList(),
    };
    try {
      final repo = ref.read(projectRepositoryProvider);
      if (_isEdit) {
        await repo.update(widget.projectId!, body);
      } else {
        await repo.create(body);
      }
      ref.invalidate(projectsListProvider);
      if (!mounted) return;
      context.go('/erp/projects');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  InputDecoration _dec(String label, {bool required = false, String? hint}) {
    return InputDecoration(
      labelText: required ? '$label *' : label,
      hintText: hint,
      border: const OutlineInputBorder(),
      isDense: true,
    );
  }

  Widget _fieldGrid(List<Widget> fields) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxW = constraints.maxWidth;
        final cols = maxW >= 1100 ? 4 : maxW >= 820 ? 3 : maxW >= 520 ? 2 : 1;
        const gap = 12.0;
        final cellW = (maxW - gap * (cols - 1)) / cols;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: fields.map((f) => SizedBox(width: cellW, child: f)).toList(),
        );
      },
    );
  }

  Widget _stringDropdown({
    required String label,
    required String? value,
    required List<DropdownMenuItem<String>> items,
    required ValueChanged<String?> onChanged,
    bool required = false,
    String? hint,
  }) {
    final valid = items.any((i) => i.value == value);
    return DropdownButtonFormField<String>(
      key: ValueKey('$label-$value-${items.length}'),
      isExpanded: true,
      initialValue: valid ? value : null,
      decoration: _dec(label, required: required, hint: hint),
      hint: hint != null ? Text(hint, overflow: TextOverflow.ellipsis) : null,
      items: items,
      onChanged: onChanged,
      validator: required ? (v) => v == null ? 'Required' : null : null,
    );
  }

  Widget _card(String title, List<Widget> children, {Widget? fullWidth}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1B18) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark
              ? const Color(0xFFC5A059).withValues(alpha: 0.15)
              : const Color(0xFFCFD8DC),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
          const SizedBox(height: 14),
          _fieldGrid(children),
          if (fullWidth != null) ...[
            const SizedBox(height: 12),
            fullWidth,
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (_isEdit) {
      ref.listen(projectDetailProvider(widget.projectId!), (prev, next) {
        next.whenData((p) {
          if (!_hydrated) setState(() => _hydrate(p));
        });
      });
    }

    final orgs = ref.watch(activeOrganizationsProvider).asData?.value ?? const [];
    final institutes = ref.watch(pickerInstitutesProvider).asData?.value ?? const [];
    final owners = ref.watch(projectEmployeesProvider).asData?.value ?? const [];
    final filteredInstitutes = _organizationId == null
        ? institutes
        : institutes
            .where(
              (i) =>
                  i.parentOrganizationId == _organizationId ||
                  i.parentOrganizationId == null,
            )
            .toList();

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF1A1816) : Colors.white,
        elevation: 0,
        title: Text(_isEdit ? 'Edit Project' : 'Add Projects'),
        leading: const AppBackButton(fallbackLocation: '/erp/projects'),
        actions: [
          if (_isEdit)
            IconButton(
              tooltip: 'Manage structure',
              onPressed: () => context.go('/erp/structure/${widget.projectId}'),
              icon: const Icon(Icons.account_tree_outlined),
            ),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: FilledButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Save'),
            ),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
          children: [
            _card(
              'Project Basic Details',
              [
                TextFormField(
                  controller: _projectId,
                  readOnly: _isEdit,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: _dec('Project ID', required: !_isEdit, hint: 'e.g. 0008'),
                  validator: (v) {
                    if (_isEdit) return null;
                    if (v == null || v.trim().isEmpty) return 'Required';
                    if (int.tryParse(v.trim()) == null || int.parse(v.trim()) < 1) {
                      return 'Enter a valid number';
                    }
                    return null;
                  },
                ),
                TextFormField(
                  controller: _name,
                  decoration: _dec('Project Name', required: true),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                _stringDropdown(
                  label: 'Organization',
                  value: orgs.any((o) => o.id == _organizationId) ? _organizationId : null,
                  hint: 'Select Organization',
                  required: true,
                  items: orgs
                      .map(
                        (o) => DropdownMenuItem(
                          value: o.id,
                          child: Text(o.name, overflow: TextOverflow.ellipsis),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => setState(() {
                    _organizationId = v;
                    _instituteId = null;
                  }),
                ),
                _stringDropdown(
                  label: 'Sub Organization',
                  value: filteredInstitutes.any((i) => i.id == _instituteId)
                      ? _instituteId
                      : null,
                  hint: 'Select Sub Organization',
                  required: true,
                  items: filteredInstitutes
                      .map(
                        (i) => DropdownMenuItem(
                          value: i.id,
                          child: Text(i.name, overflow: TextOverflow.ellipsis),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => setState(() => _instituteId = v),
                ),
                lookupDropdown(
                  ref: ref,
                  category: 'PROJECT_CATEGORY',
                  label: 'Project Category',
                  value: _categoryCode,
                  required: true,
                  onChanged: (v) => setState(() => _categoryCode = v),
                ),
                lookupDropdown(
                  ref: ref,
                  category: 'PROJECT_SUB_CATEGORY',
                  label: 'Project Sub Category',
                  value: _subCategoryCode,
                  required: true,
                  onChanged: (v) => setState(() => _subCategoryCode = v),
                ),
                lookupDropdown(
                  ref: ref,
                  category: 'PROJECT_STRUCTURE',
                  label: 'Project Structure',
                  value: _structureCode,
                  required: true,
                  onChanged: (v) => setState(() => _structureCode = v),
                ),
                lookupNullableDropdown(
                  ref: ref,
                  category: 'PROJECT_SEGMENT',
                  label: 'Project Segment',
                  value: _segmentCode,
                  onChanged: (v) => setState(() => _segmentCode = v),
                ),
                TextFormField(
                  controller: _rera,
                  decoration: _dec('RERA No.', required: true),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                InkWell(
                  onTap: _pickDate,
                  borderRadius: BorderRadius.circular(4),
                  child: InputDecorator(
                    decoration: _dec('Expected Completion Date', required: true),
                    child: Text(
                      _completion == null
                          ? 'Select date'
                          : '${_completion!.day.toString().padLeft(2, '0')} / ${_completion!.month.toString().padLeft(2, '0')} / ${_completion!.year}',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                lookupDropdown(
                  ref: ref,
                  category: 'PROJECT_STATUS',
                  label: 'Status',
                  value: _statusCode,
                  required: true,
                  onChanged: (v) => setState(() => _statusCode = v),
                ),
                DropdownButtonFormField<int>(
                  key: ValueKey('owner-$_ownerEmployeeId-${owners.length}'),
                  isExpanded: true,
                  initialValue:
                      owners.any((o) => o.id == _ownerEmployeeId) ? _ownerEmployeeId : null,
                  decoration: _dec('Project Owner', required: true),
                  hint: const Text('Select Owner', overflow: TextOverflow.ellipsis),
                  items: owners
                      .map(
                        (o) => DropdownMenuItem(
                          value: o.id,
                          child: Text(
                            '#${o.id} ${o.fullName}',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => setState(() => _ownerEmployeeId = v),
                  validator: (v) => v == null ? 'Required' : null,
                ),
                TextFormField(
                  controller: _projectArea,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
                  decoration: _dec('Total Project Area'),
                ),
                lookupNullableDropdown(
                  ref: ref,
                  category: 'PROJECT_AREA_UNIT',
                  label: 'Area Unit',
                  value: _areaUnitCode,
                  onChanged: (v) => setState(() => _areaUnitCode = v),
                ),
                TextFormField(
                  controller: _cost,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: _dec('Estimated Project Cost'),
                ),
              ],
              fullWidth: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    controller: _notes,
                    maxLines: 3,
                    decoration: _dec('Notes', hint: 'Enter Notes'),
                  ),
                  const SizedBox(height: 12),
                  _imageBox(),
                ],
              ),
            ),
            _card('Location', [
              TextFormField(
                controller: _address,
                maxLines: 3,
                decoration: _dec('Address', required: true, hint: 'Enter Address'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              TextFormField(
                controller: _landmark,
                decoration: _dec('Landmark', hint: 'Enter Landmark'),
              ),
              lookupDropdown(
                ref: ref,
                category: 'PROJECT_COUNTRY',
                label: 'Country',
                value: _countryCode,
                required: true,
                onChanged: (v) => setState(() => _countryCode = v),
              ),
              lookupDropdown(
                ref: ref,
                category: 'PROJECT_STATE',
                label: 'State',
                value: _stateCode,
                required: true,
                onChanged: (v) => setState(() => _stateCode = v),
              ),
              lookupDropdown(
                ref: ref,
                category: 'PROJECT_CITY',
                label: 'City',
                value: _cityCode,
                required: true,
                onChanged: (v) => setState(() => _cityCode = v),
              ),
              lookupDropdown(
                ref: ref,
                category: 'PROJECT_LOCATION_AREA',
                label: 'Area',
                value: _areaCode,
                required: true,
                onChanged: (v) => setState(() => _areaCode = v),
              ),
              TextFormField(
                controller: _pincode,
                keyboardType: TextInputType.number,
                decoration: _dec('Pincode', required: true),
                validator: (v) => (v == null || v.trim().isEmpty || v.trim() == '0')
                    ? 'Required'
                    : null,
              ),
            ]),
            _card(
              'Specification',
              [
                TextFormField(
                  controller: _plotArea,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
                  decoration: _dec('Total Plot Area'),
                ),
                lookupNullableDropdown(
                  ref: ref,
                  category: 'PROJECT_AREA_UNIT',
                  label: 'Plot Area Unit',
                  value: _areaUnitCode,
                  onChanged: (v) => setState(() => _areaUnitCode = v),
                ),
                lookupNullableDropdown(
                  ref: ref,
                  category: 'PROJECT_LIVABILITY',
                  label: 'Livability',
                  value: _livabilityCode,
                  onChanged: (v) => setState(() => _livabilityCode = v),
                ),
                lookupNullableDropdown(
                  ref: ref,
                  category: 'PROJECT_BANK_TIE_UP',
                  label: 'Bank Tie-Ups for Customer Loan',
                  value: _bankTieUpCode,
                  onChanged: (v) => setState(() => _bankTieUpCode = v),
                ),
                lookupDropdown(
                  ref: ref,
                  category: 'PROJECT_DEV_AUTHORITY',
                  label: 'Development Authority',
                  value: _devAuthorityCode,
                  required: true,
                  onChanged: (v) => setState(() => _devAuthorityCode = v),
                ),
                lookupDropdown(
                  ref: ref,
                  category: 'PROJECT_ELEC_PROVIDER',
                  label: 'Electricity Provider',
                  value: _elecProviderCode,
                  required: true,
                  onChanged: (v) => setState(() => _elecProviderCode = v),
                ),
              ],
              fullWidth: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  lookupMultiCheckbox(
                    ref: ref,
                    category: 'PROJECT_AMENITY',
                    label: 'Amenities',
                    selected: _amenitiesCodes,
                    onChanged: (v) => setState(() {
                      _amenitiesCodes
                        ..clear()
                        ..addAll(v);
                    }),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _specNotes,
                    maxLines: 3,
                    decoration: _dec('Notes', hint: 'Enter Notes'),
                  ),
                ],
              ),
            ),
            _documentsCard(),
          ],
        ),
      ),
    );
  }

  Widget _imageBox() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Upload Image', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          InkWell(
            onTap: _imageUploading ? null : _uploadImage,
            child: Container(
              width: double.infinity,
              height: 140,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFF90CAF9), style: BorderStyle.solid),
                color: const Color(0xFFF5F9FF),
              ),
              child: _imageUploading
                  ? const CircularProgressIndicator()
                  : _imageUrl != null
                      ? Text(_imageUrl!, maxLines: 2, overflow: TextOverflow.ellipsis)
                      : const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.cloud_upload_outlined, color: Color(0xFF42A5F5)),
                            SizedBox(height: 6),
                            Text('Drag and drop a file here or click'),
                          ],
                        ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _documentsCard() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1B18) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark
              ? const Color(0xFFC5A059).withValues(alpha: 0.15)
              : const Color(0xFFCFD8DC),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text('Document Detail', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
              ),
              FilledButton.icon(
                onPressed: () => setState(() => _docs.add(_DocDraft())),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add Row'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_docs.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: Text('No data available in table')),
            )
          else
            Column(
              children: [
                for (var i = 0; i < _docs.length; i++) _docRow(i),
              ],
            ),
        ],
      ),
    );
  }

  Widget _docRow(int index) {
    final row = _docs[index];
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final maxW = constraints.maxWidth;
          final cols = maxW >= 900 ? 5 : maxW >= 600 ? 3 : 1;
          const gap = 8.0;
          final cellW = (maxW - 36 - gap * (cols - 1)) / cols;
          return Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: gap,
            runSpacing: gap,
            children: [
              SizedBox(
                width: 28,
                child: Text('${index + 1}', style: const TextStyle(fontWeight: FontWeight.w700)),
              ),
              SizedBox(
                width: cellW,
                child: InkWell(
                  onTap: row.uploading ? null : () => _uploadDoc(row),
                  child: InputDecorator(
                    decoration: _dec('Upload'),
                    child: row.uploading
                        ? const LinearProgressIndicator()
                        : Text(
                            row.fileName ?? row.fileUrl ?? 'Drag and drop a file here or click',
                            overflow: TextOverflow.ellipsis,
                          ),
                  ),
                ),
              ),
              SizedBox(
                width: cellW,
                child: lookupNullableDropdown(
                  ref: ref,
                  category: 'PROJECT_DOCUMENT_TYPE',
                  label: 'Type',
                  value: row.typeCode,
                  onChanged: (v) => setState(() => row.typeCode = v),
                ),
              ),
              SizedBox(
                width: cellW,
                child: TextFormField(
                  initialValue: row.name,
                  decoration: _dec('Name').copyWith(hintText: 'Document Name'),
                  onChanged: (v) => row.name = v,
                ),
              ),
              SizedBox(
                width: cellW,
                child: TextFormField(
                  initialValue: row.remarks,
                  decoration: _dec('Remarks').copyWith(hintText: 'Document Remarks'),
                  onChanged: (v) => row.remarks = v,
                ),
              ),
              IconButton(
                tooltip: 'Delete',
                onPressed: () => setState(() => _docs.removeAt(index)),
                icon: const Icon(Icons.delete_outline, color: Color(0xFFEF4444)),
              ),
            ],
          );
        },
      ),
    );
  }
}
