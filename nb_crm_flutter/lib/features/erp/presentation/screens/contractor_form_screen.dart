import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_back_button.dart';
import '../../../../core/utils/platform_file_picker.dart';
import '../../../lookups/presentation/lookup_dropdown.dart';
import '../../domain/contractor_lookup_keys.dart';
import '../../domain/work_order_models.dart';
import '../work_order_providers.dart';

class ContractorFormScreen extends ConsumerStatefulWidget {
  const ContractorFormScreen({super.key, this.id});

  final String? id;
  bool get isEdit => id != null && id!.isNotEmpty;

  @override
  ConsumerState<ContractorFormScreen> createState() => _ContractorFormScreenState();
}

class _ContractorFormScreenState extends ConsumerState<ContractorFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _mobileCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _altMobileCtrl = TextEditingController();
  final _bankCtrl = TextEditingController();
  final _branchCtrl = TextEditingController();
  final _ifscCtrl = TextEditingController();
  final _accountCtrl = TextEditingController();
  final _paymentCtrl = TextEditingController();

  // Draft location fields before Add
  final _locNameCtrl = TextEditingController();
  final _addr1Ctrl = TextEditingController();
  final _addr2Ctrl = TextEditingController();
  final _postCtrl = TextEditingController();
  final _panCtrl = TextEditingController();
  final _gstCtrl = TextEditingController();

  String? _tdsCode;
  String? _contractorTypeCode;
  bool _isActive = true;

  String? _draftAddressType;
  String? _draftCountry = 'INDIA';
  String? _draftState;
  String? _draftCity;

  List<ErpContractorLocation> _locations = [];
  List<ErpContractorContact> _contacts = [const ErpContractorContact(name: '')];
  List<ErpContractorDocument> _documents = [];

  bool _hydrated = false;
  bool _saving = false;

  @override
  void dispose() {
    for (final c in [
      _nameCtrl,
      _mobileCtrl,
      _emailCtrl,
      _altMobileCtrl,
      _bankCtrl,
      _branchCtrl,
      _ifscCtrl,
      _accountCtrl,
      _paymentCtrl,
      _locNameCtrl,
      _addr1Ctrl,
      _addr2Ctrl,
      _postCtrl,
      _panCtrl,
      _gstCtrl,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  InputDecoration _dec(String label, {bool required = false, String? hint, Widget? prefix}) {
    return InputDecoration(
      labelText: required ? '$label *' : label,
      hintText: hint,
      prefixIcon: prefix,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      filled: true,
      fillColor: Colors.white,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    );
  }

  void _hydrate(ErpContractor c) {
    _nameCtrl.text = c.name;
    _mobileCtrl.text = c.mobileNo ?? c.phone ?? '';
    _emailCtrl.text = c.email ?? '';
    _altMobileCtrl.text = c.alternateMobileNo ?? '';
    _bankCtrl.text = c.bankName ?? '';
    _branchCtrl.text = c.branchName ?? '';
    _ifscCtrl.text = c.ifscCode ?? '';
    _accountCtrl.text = c.accountNo ?? '';
    _paymentCtrl.text = c.paymentTerms ?? '';
    _tdsCode = c.tdsCode;
    _contractorTypeCode = c.contractorTypeCode;
    _isActive = c.isActive;
    _locations = List.of(c.locations);
    _contacts = c.contacts.isEmpty ? [const ErpContractorContact(name: '')] : List.of(c.contacts);
    _documents = List.of(c.documents);
    _hydrated = true;
  }

  void _addLocation() {
    if ((_draftAddressType == null || _draftAddressType!.isEmpty) ||
        (_draftCountry == null || _draftCountry!.isEmpty) ||
        (_draftState == null || _draftState!.isEmpty) ||
        (_draftCity == null || _draftCity!.isEmpty) ||
        _addr1Ctrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Address Type, Country, State, City and Address1 are required')),
      );
      return;
    }
    setState(() {
      _locations = [
        ..._locations,
        ErpContractorLocation(
          locationName: _locNameCtrl.text.trim().isEmpty ? null : _locNameCtrl.text.trim(),
          addressTypeCode: _draftAddressType,
          countryCode: _draftCountry,
          stateCode: _draftState,
          cityCode: _draftCity,
          address1: _addr1Ctrl.text.trim(),
          address2: _addr2Ctrl.text.trim().isEmpty ? null : _addr2Ctrl.text.trim(),
          postCode: _postCtrl.text.trim().isEmpty ? null : _postCtrl.text.trim(),
          panNo: _panCtrl.text.trim().isEmpty ? null : _panCtrl.text.trim(),
          gstNo: _gstCtrl.text.trim().isEmpty ? null : _gstCtrl.text.trim(),
          sortOrder: _locations.length,
        ),
      ];
      _locNameCtrl.clear();
      _addr1Ctrl.clear();
      _addr2Ctrl.clear();
      _postCtrl.clear();
      _panCtrl.clear();
      _gstCtrl.clear();
    });
  }

  Future<void> _uploadDoc(int index) async {
    final picked = await pickFileFromDevice(imagesOnly: false, extensions: ['pdf', 'png', 'jpg', 'jpeg', 'doc', 'docx']);
    if (picked == null) return;
    try {
      final uploaded = await ref.read(workOrderRepositoryProvider).uploadContractorFile(
            bytes: picked.bytes,
            filename: picked.name,
          );
      setState(() {
        _documents[index] = _documents[index].copyWith(
          fileUrl: uploaded['url']?.toString(),
          fileName: uploaded['fileName']?.toString() ?? picked.name,
          mimeType: uploaded['mimeType']?.toString(),
          fileSize: int.tryParse('${uploaded['fileSize']}'),
          name: _documents[index].name?.isNotEmpty == true ? _documents[index].name : picked.name,
        );
      });
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _save({bool andNew = false}) async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final contacts = _contacts.where((c) => c.name.trim().isNotEmpty).toList();
      final body = {
        'name': _nameCtrl.text.trim(),
        'mobileNo': _mobileCtrl.text.trim(),
        'email': _emailCtrl.text.trim(),
        'alternateMobileNo': _altMobileCtrl.text.trim().isEmpty ? null : _altMobileCtrl.text.trim(),
        'tdsCode': _tdsCode,
        'bankName': _bankCtrl.text.trim().isEmpty ? null : _bankCtrl.text.trim(),
        'branchName': _branchCtrl.text.trim().isEmpty ? null : _branchCtrl.text.trim(),
        'ifscCode': _ifscCtrl.text.trim().isEmpty ? null : _ifscCtrl.text.trim(),
        'accountNo': _accountCtrl.text.trim().isEmpty ? null : _accountCtrl.text.trim(),
        'paymentTerms': _paymentCtrl.text.trim().isEmpty ? null : _paymentCtrl.text.trim(),
        'contractorTypeCode': _contractorTypeCode,
        'isActive': _isActive,
        'locations': _locations.asMap().entries.map((e) {
          final m = e.value.toJson();
          m['sortOrder'] = e.key;
          return m;
        }).toList(),
        'contacts': contacts.asMap().entries.map((e) {
          final m = e.value.toJson();
          m['sortOrder'] = e.key;
          return m;
        }).toList(),
        'documents': _documents.asMap().entries.map((e) {
          final m = e.value.toJson();
          m['sortOrder'] = e.key;
          return m;
        }).toList(),
      };

      final repo = ref.read(workOrderRepositoryProvider);
      if (widget.isEdit) {
        await repo.updateContractor(widget.id!, body);
      } else {
        await repo.createContractor(body);
      }
      ref.invalidate(erpContractorsAdminProvider);
      ref.invalidate(erpContractorsProvider);
      if (!mounted) return;
      if (andNew) {
        context.go('/erp/configurations/contractors/new');
        // Reset local state for new form if same route reused
        setState(() {
          _nameCtrl.clear();
          _mobileCtrl.clear();
          _emailCtrl.clear();
          _altMobileCtrl.clear();
          _bankCtrl.clear();
          _branchCtrl.clear();
          _ifscCtrl.clear();
          _accountCtrl.clear();
          _paymentCtrl.clear();
          _tdsCode = null;
          _contractorTypeCode = null;
          _isActive = true;
          _locations = [];
          _contacts = [const ErpContractorContact(name: '')];
          _documents = [];
          _hydrated = false;
        });
      } else {
        context.go('/erp/configurations/contractors');
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _section({required String title, required Widget child, Widget? trailing}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1B18) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isDark ? const Color(0xFF3D3834) : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Row(
              children: [
                Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15))),
                if (trailing != null) trailing,
              ],
            ),
          ),
          Divider(height: 1, color: isDark ? const Color(0xFF3D3834) : const Color(0xFFE2E8F0)),
          Padding(padding: const EdgeInsets.all(16), child: child),
        ],
      ),
    );
  }

  Widget _grid(List<Widget> children, {int cols = 4}) {
    return LayoutBuilder(
      builder: (context, c) {
        final wide = c.maxWidth >= 900;
        if (!wide) {
          return Column(
            children: [
              for (final w in children) ...[w, const SizedBox(height: 10)],
            ],
          );
        }
        final rows = <Widget>[];
        for (var i = 0; i < children.length; i += cols) {
          final slice = children.sublist(i, i + cols > children.length ? children.length : i + cols);
          while (slice.length < cols) {
            slice.add(const SizedBox.shrink());
          }
          rows.add(
            Padding(
              padding: EdgeInsets.only(bottom: i + cols < children.length ? 12 : 0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var j = 0; j < slice.length; j++) ...[
                    if (j > 0) const SizedBox(width: 12),
                    Expanded(child: slice[j]),
                  ],
                ],
              ),
            ),
          );
        }
        return Column(children: rows);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isEdit) {
      ref.listen(erpContractorDetailProvider(widget.id!), (prev, next) {
        next.whenData((c) {
          if (_hydrated || !mounted) return;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted || _hydrated) return;
            setState(() => _hydrate(c));
          });
        });
      });
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF1F5F9),
      appBar: AppBar(
        title: Text(widget.isEdit ? 'Edit Contractor' : 'Add Contractor'),
        leading: const AppBackButton(fallbackLocation: '/erp/configurations/contractors'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
          children: [
            _section(
              title: 'Contractors Details',
              child: Column(
                children: [
                  _grid([
                    TextFormField(
                      controller: _nameCtrl,
                      decoration: _dec('Company Name', required: true, hint: 'Enter Company Name'),
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                    ),
                    TextFormField(
                      controller: _mobileCtrl,
                      keyboardType: TextInputType.phone,
                      decoration: _dec(
                        'Mobile No',
                        required: true,
                        hint: 'Enter Mobile No',
                        prefix: const Padding(
                          padding: EdgeInsets.only(left: 12, top: 12),
                          child: Text('+91', style: TextStyle(fontWeight: FontWeight.w600)),
                        ),
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                    ),
                    TextFormField(
                      controller: _emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      decoration: _dec('Email', required: true, hint: 'Enter Email'),
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                    ),
                    TextFormField(
                      controller: _altMobileCtrl,
                      keyboardType: TextInputType.phone,
                      decoration: _dec(
                        'Alternate Mobile No',
                        hint: 'Alternate Mobile No',
                        prefix: const Padding(
                          padding: EdgeInsets.only(left: 12, top: 12),
                          child: Text('+91', style: TextStyle(fontWeight: FontWeight.w600)),
                        ),
                      ),
                    ),
                    lookupNullableDropdown(
                      ref: ref,
                      category: kContractorTds,
                      label: 'TDS',
                      value: _tdsCode,
                      onChanged: (v) => setState(() => _tdsCode = v),
                    ),
                    TextFormField(
                      controller: _bankCtrl,
                      decoration: _dec('Bank Name', hint: 'Enter Bank Name'),
                    ),
                    TextFormField(
                      controller: _branchCtrl,
                      decoration: _dec('Branch Name', hint: 'Enter Branch Name'),
                    ),
                    TextFormField(
                      controller: _ifscCtrl,
                      decoration: _dec('IFSC code', hint: 'Enter IFSC code'),
                    ),
                    TextFormField(
                      controller: _accountCtrl,
                      decoration: _dec('Account No', hint: 'Enter Account No'),
                    ),
                    TextFormField(
                      controller: _paymentCtrl,
                      maxLines: 2,
                      decoration: _dec('Payment Terms', hint: 'Enter Payment Terms'),
                    ),
                    lookupNullableDropdown(
                      ref: ref,
                      category: kContractorType,
                      label: 'Contractor Type',
                      value: _contractorTypeCode,
                      onChanged: (v) => setState(() => _contractorTypeCode = v),
                    ),
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Active'),
                      value: _isActive,
                      onChanged: (v) => setState(() => _isActive = v ?? true),
                      controlAffinity: ListTileControlAffinity.leading,
                    ),
                  ]),
                ],
              ),
            ),
            _section(
              title: 'Location Details',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _grid([
                    TextFormField(
                      controller: _locNameCtrl,
                      decoration: _dec('Location Name', hint: 'Enter Location Name'),
                    ),
                    lookupDropdown(
                      ref: ref,
                      category: kContractorAddressType,
                      label: 'Address Type',
                      value: _draftAddressType,
                      required: true,
                      onChanged: (v) => setState(() => _draftAddressType = v),
                    ),
                    lookupDropdown(
                      ref: ref,
                      category: kContractorCountry,
                      label: 'Country',
                      value: _draftCountry,
                      required: true,
                      onChanged: (v) => setState(() => _draftCountry = v),
                    ),
                    lookupDropdown(
                      ref: ref,
                      category: kContractorState,
                      label: 'State',
                      value: _draftState,
                      required: true,
                      onChanged: (v) => setState(() => _draftState = v),
                    ),
                    lookupDropdown(
                      ref: ref,
                      category: kContractorCity,
                      label: 'City',
                      value: _draftCity,
                      required: true,
                      onChanged: (v) => setState(() => _draftCity = v),
                    ),
                    TextFormField(
                      controller: _addr1Ctrl,
                      maxLines: 2,
                      decoration: _dec('Address1', required: true, hint: 'Address'),
                    ),
                    TextFormField(
                      controller: _addr2Ctrl,
                      maxLines: 2,
                      decoration: _dec('Address2', hint: 'Address'),
                    ),
                    TextFormField(
                      controller: _postCtrl,
                      decoration: _dec('PostCode', hint: 'Enter Post Code'),
                    ),
                    TextFormField(
                      controller: _panCtrl,
                      decoration: _dec('PAN No', hint: 'Enter PAN No'),
                    ),
                    TextFormField(
                      controller: _gstCtrl,
                      decoration: _dec('GST No', hint: 'Enter GST No'),
                    ),
                  ]),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: _addLocation,
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Add'),
                    style: FilledButton.styleFrom(backgroundColor: const Color(0xFF1e3a5f)),
                  ),
                  if (_locations.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                        headingRowHeight: 40,
                        columns: const [
                          DataColumn(label: Text('#')),
                          DataColumn(label: Text('Location')),
                          DataColumn(label: Text('Address Type')),
                          DataColumn(label: Text('State')),
                          DataColumn(label: Text('City')),
                          DataColumn(label: Text('Address1')),
                          DataColumn(label: Text('PAN')),
                          DataColumn(label: Text('GST')),
                          DataColumn(label: Text('')),
                        ],
                        rows: [
                          for (var i = 0; i < _locations.length; i++)
                            DataRow(
                              cells: [
                                DataCell(Text('${i + 1}')),
                                DataCell(Text(_locations[i].locationName ?? '—')),
                                DataCell(Text(_locations[i].addressTypeCode ?? '—')),
                                DataCell(Text(_locations[i].stateCode ?? '—')),
                                DataCell(Text(_locations[i].cityCode ?? '—')),
                                DataCell(SizedBox(
                                  width: 160,
                                  child: Text(_locations[i].address1 ?? '—', maxLines: 2, overflow: TextOverflow.ellipsis),
                                )),
                                DataCell(Text(_locations[i].panNo ?? '—')),
                                DataCell(Text(_locations[i].gstNo ?? '—')),
                                DataCell(IconButton(
                                  icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                                  onPressed: () => setState(() => _locations.removeAt(i)),
                                )),
                              ],
                            ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            _section(
              title: 'Contact Person Details',
              trailing: TextButton.icon(
                onPressed: () => setState(() => _contacts = [..._contacts, const ErpContractorContact(name: '')]),
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Add Row'),
              ),
              child: Column(
                children: [
                  for (var i = 0; i < _contacts.length; i++)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _grid([
                        TextFormField(
                          key: ValueKey('cname-$i'),
                          initialValue: _contacts[i].name,
                          decoration: _dec('Name', hint: 'Enter Contact Person'),
                          onChanged: (v) => _contacts[i] = _contacts[i].copyWith(name: v),
                        ),
                        TextFormField(
                          key: ValueKey('cemail-$i'),
                          initialValue: _contacts[i].email ?? '',
                          decoration: _dec('Email', hint: 'Enter Email'),
                          onChanged: (v) => _contacts[i] = _contacts[i].copyWith(email: v),
                        ),
                        TextFormField(
                          key: ValueKey('cmobile-$i'),
                          initialValue: _contacts[i].mobileNo ?? '',
                          decoration: _dec('Mobile No', hint: 'Enter Mobile No', prefix: const Padding(
                            padding: EdgeInsets.only(left: 12, top: 12),
                            child: Text('+91', style: TextStyle(fontWeight: FontWeight.w600)),
                          )),
                          onChanged: (v) => _contacts[i] = _contacts[i].copyWith(mobileNo: v),
                        ),
                        TextFormField(
                          key: ValueKey('calt-$i'),
                          initialValue: _contacts[i].alternateMobileNo ?? '',
                          decoration: _dec('Alternate Mobile', hint: 'Enter Alternate Mobile'),
                          onChanged: (v) => _contacts[i] = _contacts[i].copyWith(alternateMobileNo: v),
                        ),
                        TextFormField(
                          key: ValueKey('cdesig-$i'),
                          initialValue: _contacts[i].designation ?? '',
                          decoration: _dec('Designation', hint: 'Enter Designation Name'),
                          onChanged: (v) => _contacts[i] = _contacts[i].copyWith(designation: v),
                        ),
                        TextFormField(
                          key: ValueKey('cloc-$i'),
                          initialValue: _contacts[i].locationName ?? '',
                          decoration: _dec('Location', hint: 'Enter Location Name'),
                          onChanged: (v) => _contacts[i] = _contacts[i].copyWith(locationName: v),
                        ),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: IconButton(
                            tooltip: 'Remove',
                            onPressed: _contacts.length <= 1
                                ? null
                                : () => setState(() => _contacts.removeAt(i)),
                            icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                          ),
                        ),
                      ], cols: 4),
                    ),
                ],
              ),
            ),
            _section(
              title: 'Document Detail',
              trailing: TextButton.icon(
                onPressed: () => setState(() => _documents = [..._documents, const ErpContractorDocument()]),
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Add Row'),
              ),
              child: _documents.isEmpty
                  ? Text('No documents yet.', style: TextStyle(color: Theme.of(context).hintColor))
                  : Column(
                      children: [
                        for (var i = 0; i < _documents.length; i++)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _grid([
                              OutlinedButton.icon(
                                onPressed: () => _uploadDoc(i),
                                icon: const Icon(Icons.upload_file, size: 16),
                                label: Text(_documents[i].fileName ?? 'Upload'),
                              ),
                              lookupNullableDropdown(
                                ref: ref,
                                category: kContractorDocumentType,
                                label: 'Type',
                                value: _documents[i].typeCode,
                                onChanged: (v) => setState(() => _documents[i] = _documents[i].copyWith(typeCode: v)),
                              ),
                              TextFormField(
                                key: ValueKey('dname-$i'),
                                initialValue: _documents[i].name ?? '',
                                decoration: _dec('Name'),
                                onChanged: (v) => _documents[i] = _documents[i].copyWith(name: v),
                              ),
                              TextFormField(
                                key: ValueKey('drem-$i'),
                                initialValue: _documents[i].remarks ?? '',
                                decoration: _dec('Remarks'),
                                onChanged: (v) => _documents[i] = _documents[i].copyWith(remarks: v),
                              ),
                              IconButton(
                                onPressed: () => setState(() => _documents.removeAt(i)),
                                icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                              ),
                            ]),
                          ),
                      ],
                    ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E1B18) : Colors.white,
            border: Border(top: BorderSide(color: isDark ? const Color(0xFF3D3834) : const Color(0xFFE2E8F0))),
          ),
          child: Row(
            children: [
              FilledButton(
                onPressed: _saving ? null : () => _save(),
                style: FilledButton.styleFrom(backgroundColor: const Color(0xFF1e3a5f)),
                child: Text(_saving ? 'Saving…' : 'Submit'),
              ),
              const SizedBox(width: 8),
              FilledButton.tonal(
                onPressed: _saving ? null : () => _save(andNew: true),
                child: const Text('Submit & New'),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed: () => context.go('/erp/configurations/contractors'),
                child: const Text('Cancel'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
