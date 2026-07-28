import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../domain/company_profile.dart';
import '../../domain/org_models.dart';

/// Owns its [TextEditingController]s and disposes them safely on unmount.
class CompanyProfileFormController {
  CompanyProfileFormController({CompanyProfileFields? initial}) {
    registrationNo = _c(initial?.registrationNo);
    establishmentYear = _c(initial?.establishmentYear?.toString());
    contactPerson = _c(initial?.contactPerson);
    mobileNo = _c(initial?.mobileNo);
    contactNo = _c(initial?.contactNo);
    email = _c(initial?.email);
    webAddress = _c(initial?.webAddress);
    panNo = _c(initial?.panNo);
    gstNo = _c(initial?.gstNo);
    cinNo = _c(initial?.cinNo);
    country = _c(initial?.country ?? 'India');
    state = _c(initial?.state);
    city = _c(initial?.city);
    address1 = _c(initial?.address1);
    address2 = _c(initial?.address2);
    pinCode = _c(initial?.pinCode);
    tagLine = _c(initial?.tagLine);
    hostingUrl = _c(initial?.hostingUrl);
    pageSize = _c(initial?.pageSize);
    dateFormat = _c(initial?.dateFormat);
    timeZone = _c(initial?.timeZone ?? 'Asia/Kolkata');
    socialPostUrl = _c(initial?.socialPostUrl);
    bankName = _c(initial?.bankName);
    accountHolderName = _c(initial?.accountHolderName);
    bankAccountNo = _c(initial?.bankAccountNo);
    ifscCode = _c(initial?.ifscCode);
    bankBranch = _c(initial?.bankBranch);
  }

  final List<TextEditingController> _all = [];

  TextEditingController _c([String? text]) {
    final c = TextEditingController(text: text ?? '');
    _all.add(c);
    return c;
  }

  late final TextEditingController registrationNo;
  late final TextEditingController establishmentYear;
  late final TextEditingController contactPerson;
  late final TextEditingController mobileNo;
  late final TextEditingController contactNo;
  late final TextEditingController email;
  late final TextEditingController webAddress;
  late final TextEditingController panNo;
  late final TextEditingController gstNo;
  late final TextEditingController cinNo;
  late final TextEditingController country;
  late final TextEditingController state;
  late final TextEditingController city;
  late final TextEditingController address1;
  late final TextEditingController address2;
  late final TextEditingController pinCode;
  late final TextEditingController tagLine;
  late final TextEditingController hostingUrl;
  late final TextEditingController pageSize;
  late final TextEditingController dateFormat;
  late final TextEditingController timeZone;
  late final TextEditingController socialPostUrl;
  late final TextEditingController bankName;
  late final TextEditingController accountHolderName;
  late final TextEditingController bankAccountNo;
  late final TextEditingController ifscCode;
  late final TextEditingController bankBranch;

  bool _disposed = false;

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    for (final c in _all) {
      c.dispose();
    }
    _all.clear();
  }

  String? validateRequired() {
    final missing = <String>[];
    void req(TextEditingController c, String label) {
      if (c.text.trim().isEmpty) missing.add(label);
    }

    req(contactPerson, 'Contact Person');
    req(mobileNo, 'Mobile No.');
    req(panNo, 'PAN No.');
    req(gstNo, 'GST No.');
    req(email, 'Email');
    req(country, 'Country');
    req(state, 'State');
    req(city, 'City');
    req(address1, 'Address 1');
    req(pinCode, 'Pin Code');
    if (missing.isEmpty) return null;
    return 'Missing required fields: ${missing.join(', ')}';
  }

  Map<String, dynamic> toPayload() {
    int? year;
    final y = establishmentYear.text.trim();
    if (y.isNotEmpty) year = int.tryParse(y);

    String? n(TextEditingController c) {
      final t = c.text.trim();
      return t.isEmpty ? null : t;
    }

    return {
      'registrationNo': n(registrationNo),
      'establishmentYear': year,
      'contactPerson': n(contactPerson),
      'mobileNo': n(mobileNo),
      'contactNo': n(contactNo),
      'email': n(email),
      'webAddress': n(webAddress),
      'panNo': n(panNo),
      'gstNo': n(gstNo),
      'cinNo': n(cinNo),
      'country': n(country),
      'state': n(state),
      'city': n(city),
      'address1': n(address1),
      'address2': n(address2),
      'pinCode': n(pinCode),
      'tagLine': n(tagLine),
      'hostingUrl': n(hostingUrl),
      'pageSize': n(pageSize),
      'dateFormat': n(dateFormat),
      'timeZone': n(timeZone),
      'socialPostUrl': n(socialPostUrl),
      'bankName': n(bankName),
      'accountHolderName': n(accountHolderName),
      'bankAccountNo': n(bankAccountNo),
      'ifscCode': n(ifscCode),
      'bankBranch': n(bankBranch),
    };
  }
}

class CompanyDetailsFormSections extends StatelessWidget {
  const CompanyDetailsFormSections({
    super.key,
    required this.controller,
    this.enabled = true,
  });

  final CompanyProfileFormController controller;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _sectionTitle('Identity', isDark),
        _field(controller.registrationNo, 'Registration No.'),
        _field(
          controller.establishmentYear,
          'Establishment Year',
          keyboard: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        ),
        const SizedBox(height: 12),
        _sectionTitle('Contact', isDark),
        _field(controller.contactPerson, 'Contact Person *'),
        _field(controller.mobileNo, 'Mobile No. *', keyboard: TextInputType.phone),
        _field(controller.contactNo, 'Contact No.', keyboard: TextInputType.phone),
        _field(controller.email, 'Email *', keyboard: TextInputType.emailAddress),
        _field(controller.webAddress, 'Web Address', keyboard: TextInputType.url),
        const SizedBox(height: 12),
        _sectionTitle('Tax IDs', isDark),
        _field(controller.panNo, 'PAN No. *'),
        _field(controller.gstNo, 'GST No. *'),
        _field(controller.cinNo, 'CIN No.'),
        const SizedBox(height: 12),
        _sectionTitle('Address', isDark),
        _field(controller.country, 'Country *'),
        _field(controller.state, 'State *'),
        _field(controller.city, 'City *'),
        _field(controller.address1, 'Address 1 *', maxLines: 2),
        _field(controller.address2, 'Address 2', maxLines: 2),
        _field(controller.pinCode, 'Pin Code *', keyboard: TextInputType.number),
        const SizedBox(height: 12),
        _sectionTitle('Branding & settings', isDark),
        _field(controller.tagLine, 'Tag Line'),
        _field(controller.hostingUrl, 'Hosting URL', keyboard: TextInputType.url),
        _field(controller.pageSize, 'Page Size'),
        _field(controller.dateFormat, 'Date Format'),
        _field(controller.timeZone, 'Time Zone'),
        _field(controller.socialPostUrl, 'Social Post URL', keyboard: TextInputType.url),
        const SizedBox(height: 12),
        _sectionTitle('Bank details', isDark),
        _field(controller.bankName, 'Bank Name'),
        _field(controller.accountHolderName, 'Account Holder Name'),
        _field(controller.bankAccountNo, 'Account No.'),
        _field(controller.ifscCode, 'IFSC Code'),
        _field(controller.bankBranch, 'Branch'),
      ],
    );
  }

  Widget _sectionTitle(String title, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, top: 4),
      child: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.w800,
          fontSize: 13,
          color: isDark ? const Color(0xFFC5A059) : const Color(0xFF0369a1),
          letterSpacing: 0.3,
        ),
      ),
    );
  }

  Widget _field(
    TextEditingController c,
    String label, {
    TextInputType? keyboard,
    int maxLines = 1,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: c,
        enabled: enabled,
        keyboardType: keyboard,
        maxLines: maxLines,
        inputFormatters: inputFormatters,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          isDense: true,
        ),
      ),
    );
  }
}

/// Result of org/institute editor dialog.
class CompanyEditorResult {
  const CompanyEditorResult(this.body);
  final Map<String, dynamic> body;
}

Future<CompanyEditorResult?> showOrganizationEditorDialog(
  BuildContext context, {
  Organization? existing,
}) {
  return showDialog<CompanyEditorResult>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => _OrganizationEditorDialog(existing: existing),
  );
}

Future<CompanyEditorResult?> showInstituteEditorDialog(
  BuildContext context, {
  Institute? existing,
  required List<Organization> organizations,
  String? organizationsError,
}) {
  return showDialog<CompanyEditorResult>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => _InstituteEditorDialog(
      existing: existing,
      organizations: organizations,
      organizationsError: organizationsError,
    ),
  );
}

class _OrganizationEditorDialog extends StatefulWidget {
  const _OrganizationEditorDialog({this.existing});
  final Organization? existing;

  @override
  State<_OrganizationEditorDialog> createState() => _OrganizationEditorDialogState();
}

class _OrganizationEditorDialogState extends State<_OrganizationEditorDialog> {
  late final TextEditingController _codeCtrl;
  late final TextEditingController _nameCtrl;
  late final CompanyProfileFormController _profile;
  var _saving = false;

  @override
  void initState() {
    super.initState();
    _codeCtrl = TextEditingController(text: widget.existing?.code ?? '');
    _nameCtrl = TextEditingController(text: widget.existing?.name ?? '');
    _profile = CompanyProfileFormController(initial: widget.existing?.profile);
  }

  @override
  void dispose() {
    _codeCtrl.dispose();
    _nameCtrl.dispose();
    _profile.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.existing == null ? 'Add organization' : 'Edit organization'),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _codeCtrl,
                enabled: widget.existing == null && !_saving,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(
                  labelText: 'Organization Code *',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                onChanged: (v) {
                  final upper = v.toUpperCase().replaceAll(' ', '_');
                  if (upper != v) {
                    _codeCtrl.value = _codeCtrl.value.copyWith(
                      text: upper,
                      selection: TextSelection.collapsed(offset: upper.length),
                    );
                  }
                },
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _nameCtrl,
                enabled: !_saving,
                decoration: const InputDecoration(
                  labelText: 'Name *',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 8),
              CompanyDetailsFormSections(controller: _profile, enabled: !_saving),
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
          onPressed: _saving ? null : _submit,
          child: _saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : Text(widget.existing == null ? 'Create' : 'Save'),
        ),
      ],
    );
  }

  void _submit() {
    final code = _codeCtrl.text.trim();
    final name = _nameCtrl.text.trim();
    if (code.isEmpty || name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Code and name are required')),
      );
      return;
    }
    final err = _profile.validateRequired();
    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
      return;
    }
    Navigator.pop(
      context,
      CompanyEditorResult({
        'code': code,
        'name': name,
        ..._profile.toPayload(),
      }),
    );
  }
}

class _InstituteEditorDialog extends StatefulWidget {
  const _InstituteEditorDialog({
    this.existing,
    required this.organizations,
    this.organizationsError,
  });

  final Institute? existing;
  final List<Organization> organizations;
  final String? organizationsError;

  @override
  State<_InstituteEditorDialog> createState() => _InstituteEditorDialogState();
}

class _InstituteEditorDialogState extends State<_InstituteEditorDialog> {
  late final TextEditingController _codeCtrl;
  late final TextEditingController _nameCtrl;
  late final CompanyProfileFormController _profile;
  late bool _isChild;
  String? _parentId;
  var _saving = false;

  @override
  void initState() {
    super.initState();
    _codeCtrl = TextEditingController(text: widget.existing?.code ?? '');
    _nameCtrl = TextEditingController(text: widget.existing?.name ?? '');
    _profile = CompanyProfileFormController(initial: widget.existing?.profile);
    _isChild = widget.existing?.isChildCompany ?? false;
    _parentId =
        widget.existing?.parentOrganizationId ?? widget.existing?.parentOrganization?.id;
  }

  @override
  void dispose() {
    _codeCtrl.dispose();
    _nameCtrl.dispose();
    _profile.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.existing == null ? 'Add institute' : 'Edit institute'),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _codeCtrl,
                enabled: widget.existing == null && !_saving,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(
                  labelText: 'Code *',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                onChanged: (v) {
                  final upper = v.toUpperCase().replaceAll(' ', '_');
                  if (upper != v) {
                    _codeCtrl.value = _codeCtrl.value.copyWith(
                      text: upper,
                      selection: TextSelection.collapsed(offset: upper.length),
                    );
                  }
                },
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _nameCtrl,
                enabled: !_saving,
                decoration: const InputDecoration(
                  labelText: 'Name *',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Is a child company?'),
                subtitle: const Text('Link this institute to a parent organization'),
                value: _isChild,
                onChanged: _saving
                    ? null
                    : (v) => setState(() {
                          _isChild = v;
                          if (!v) _parentId = null;
                        }),
              ),
              if (_isChild) ...[
                if (widget.organizationsError != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      'Could not load organizations: ${widget.organizationsError}',
                      style: const TextStyle(color: Colors.red, fontSize: 12),
                    ),
                  )
                else if (widget.organizations.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      'No organizations found. Create one under Configurations → Organizations first.',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  )
                else
                  DropdownButtonFormField<String>(
                    initialValue: _parentId != null &&
                            widget.organizations.any((o) => o.id == _parentId)
                        ? _parentId
                        : null,
                    decoration: const InputDecoration(
                      labelText: 'Parent organization *',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: [
                      for (final o in widget.organizations)
                        DropdownMenuItem(
                          value: o.id,
                          child: Text('${o.name} (${o.code})'),
                        ),
                    ],
                    onChanged: _saving ? null : (v) => setState(() => _parentId = v),
                  ),
                const SizedBox(height: 8),
              ],
              CompanyDetailsFormSections(controller: _profile, enabled: !_saving),
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
          onPressed: _saving ? null : _submit,
          child: _saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : Text(widget.existing == null ? 'Create' : 'Save'),
        ),
      ],
    );
  }

  void _submit() {
    final code = _codeCtrl.text.trim();
    final name = _nameCtrl.text.trim();
    if (code.isEmpty || name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Code and name are required')),
      );
      return;
    }
    if (_isChild && (_parentId == null || _parentId!.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select a parent organization')),
      );
      return;
    }
    final err = _profile.validateRequired();
    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
      return;
    }
    Navigator.pop(
      context,
      CompanyEditorResult({
        'code': code,
        'name': name,
        'isChildCompany': _isChild,
        'parentOrganizationId': _isChild ? _parentId : null,
        ..._profile.toPayload(),
      }),
    );
  }
}
