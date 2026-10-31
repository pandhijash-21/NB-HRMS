import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_colors.dart';
import '../../data/crm_repository.dart';
import '../../domain/hub_partner_model.dart';

class CrmPartnersScreen extends StatefulWidget {
  const CrmPartnersScreen({super.key});

  @override
  State<CrmPartnersScreen> createState() => _CrmPartnersScreenState();
}

class _CrmPartnersScreenState extends State<CrmPartnersScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  List<HubPartner> _partners = [];
  String _selectedRoleFilter = 'ALL';
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadPartners();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadPartners() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final repo = context.read<CrmRepository>();
      final list = await repo.getHubPartners();
      if (!mounted) return;
      setState(() {
        _partners = list;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception:', '').trim();
        _isLoading = false;
      });
    }
  }

  List<HubPartner> get _filteredPartners {
    return _partners.where((p) {
      final matchesRole = _selectedRoleFilter == 'ALL' ||
          (_selectedRoleFilter == 'CP' && p.role == 'CP') ||
          (_selectedRoleFilter == 'AP' && p.role == 'AP') ||
          (_selectedRoleFilter == 'ACTIVE' && p.isActive) ||
          (_selectedRoleFilter == 'INACTIVE' && !p.isActive);

      if (!matchesRole) return false;

      if (_searchQuery.isEmpty) return true;

      final q = _searchQuery.toLowerCase();
      final name = p.displayName.toLowerCase();
      final contact = (p.contactPersonName ?? '').toLowerCase();
      final email = p.email.toLowerCase();
      final phone = (p.phone ?? '').toLowerCase();
      final city = (p.city ?? '').toLowerCase();
      final pan = (p.pan ?? '').toLowerCase();
      final rera = (p.reraNo ?? '').toLowerCase();
      final gst = (p.gstin ?? '').toLowerCase();

      return name.contains(q) ||
          contact.contains(q) ||
          email.contains(q) ||
          phone.contains(q) ||
          city.contains(q) ||
          pan.contains(q) ||
          rera.contains(q) ||
          gst.contains(q);
    }).toList();
  }

  int get _countTotal => _partners.length;
  int get _countCP => _partners.where((p) => p.role == 'CP').length;
  int get _countAP => _partners.where((p) => p.role == 'AP' || p.role == 'CA').length;
  int get _countActive => _partners.where((p) => p.isActive).length;

  Future<void> _openAddEditPartnerDialog([HubPartner? partner]) async {
    final isEdit = partner != null;
    HubPartner? seed = partner;

    // Prefer full Hub profile so edit form is not missing fields from list payloads.
    if (partner != null) {
      try {
        final id = partner.email.isNotEmpty ? partner.email : partner.username;
        final full = await context.read<CrmRepository>().getHubPartnerProfile(id);
        if (full != null) seed = full;
      } catch (_) {}
    }

    if (!mounted) return;

    final formKey = GlobalKey<FormState>();
    String role = seed?.role ?? 'CP';
    String status = seed?.status ?? 'ACTIVE';
    const permissionOptions = ['READ_ONLY', 'L1', 'L2', 'FULL'];
    String permissionLevel = seed?.permissionLevel.isNotEmpty == true ? seed!.permissionLevel : 'READ_ONLY';
    if (!permissionOptions.contains(permissionLevel)) {
      permissionLevel = 'READ_ONLY';
    }
    bool declarationAccepted = seed?.declarationAccepted ?? true;
    bool obscurePassword = true;
    List<String> natureOfBusiness = List<String>.from(seed?.natureOfBusiness ?? const []);
    List<String> areasOfPractice = List<String>.from(seed?.areasOfPractice ?? const []);
    String? companyLogo = seed?.companyLogo;

    final emailCtrl = TextEditingController(text: seed?.email ?? '');
    final usernameCtrl = TextEditingController(text: seed?.username ?? '');
    final passwordCtrl = TextEditingController();
    final phoneCtrl = TextEditingController(text: seed?.phone ?? '');
    final companyCtrl = TextEditingController(text: seed?.companyOrFirmName ?? '');
    final contactCtrl = TextEditingController(text: seed?.contactPersonName ?? '');
    final streamCtrl = TextEditingController(text: seed?.professionalStream ?? '');
    final constitutionCtrl = TextEditingController(text: seed?.constitution ?? '');
    final panCtrl = TextEditingController(text: seed?.pan ?? '');
    final gstinCtrl = TextEditingController(text: seed?.gstin ?? '');
    final reraCtrl = TextEditingController(text: seed?.reraNo ?? '');
    final icaiCtrl = TextEditingController(text: seed?.icaiMembershipNo ?? '');
    final copCtrl = TextEditingController(text: seed?.copNo ?? '');
    final doiCtrl = TextEditingController(text: seed?.dateOfIncorporation ?? '');
    final cityCtrl = TextEditingController(text: seed?.city ?? '');
    final addressCtrl = TextEditingController(text: seed?.address ?? '');
    final pincodeCtrl = TextEditingController(text: seed?.pincode ?? '');
    final websiteCtrl = TextEditingController(text: seed?.website ?? '');
    final logoUrlCtrl = TextEditingController(text: seed?.companyLogo ?? '');
    final natureChipCtrl = TextEditingController();
    final areasChipCtrl = TextEditingController();

    InputDecoration dense(String label, {IconData? icon, String? hint}) => InputDecoration(
          labelText: label,
          hintText: hint,
          border: const OutlineInputBorder(),
          isDense: true,
          prefixIcon: icon != null ? Icon(icon, size: 18) : null,
        );

    Widget sectionTitle(String title) => Padding(
          padding: const EdgeInsets.only(top: 4, bottom: 10),
          child: Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.primaryBlue),
          ),
        );

    Widget chipEditor({
      required String label,
      required List<String> values,
      required TextEditingController controller,
      required void Function(List<String>) onChanged,
    }) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              ...values.map(
                (v) => InputChip(
                  label: Text(v, style: const TextStyle(fontSize: 12)),
                  onDeleted: () => onChanged([...values]..remove(v)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  decoration: dense('Add item', hint: 'Type and press Add'),
                  onSubmitted: (raw) {
                    final t = raw.trim();
                    if (t.isEmpty) return;
                    if (!values.contains(t)) onChanged([...values, t]);
                    controller.clear();
                  },
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed: () {
                  final t = controller.text.trim();
                  if (t.isEmpty) return;
                  if (!values.contains(t)) onChanged([...values, t]);
                  controller.clear();
                },
                child: const Text('Add'),
              ),
            ],
          ),
        ],
      );
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        bool isSaving = false;
        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            Future<void> pickLogo() async {
              final result = await FilePicker.pickFiles(
                type: FileType.image,
                withData: true,
              );
              if (result == null || result.files.isEmpty) return;
              final file = result.files.first;
              final bytes = file.bytes;
              if (bytes == null || bytes.isEmpty) return;
              final mime = (file.extension ?? 'png').toLowerCase();
              final b64 = base64Encode(bytes);
              final dataUrl = 'data:image/$mime;base64,$b64';
              setDialogState(() {
                companyLogo = dataUrl;
                logoUrlCtrl.text = dataUrl;
              });
            }

            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primaryBlue.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      isEdit ? Icons.edit_note : Icons.person_add_alt_1,
                      color: AppColors.primaryBlue,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      isEdit ? 'Edit Partner: ${seed?.displayName ?? ''}' : 'Add New Partner',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: isSaving ? null : () => Navigator.pop(dialogCtx),
                  ),
                ],
              ),
              content: SizedBox(
                width: 720,
                child: Form(
                  key: formKey,
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        sectionTitle('Partner Role & Credentials'),
                        Row(
                          children: [
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                initialValue: role,
                                decoration: dense('Partner Role *'),
                                items: const [
                                  DropdownMenuItem(value: 'CP', child: Text('Channel Partner (CP)')),
                                  DropdownMenuItem(value: 'AP', child: Text('Associate Partner (AP)')),
                                  DropdownMenuItem(value: 'CA', child: Text('Chartered Accountant (CA)')),
                                ],
                                onChanged: (v) {
                                  if (v != null) setDialogState(() => role = v);
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                initialValue: status,
                                decoration: dense('Status'),
                                items: const [
                                  DropdownMenuItem(value: 'ACTIVE', child: Text('ACTIVE')),
                                  DropdownMenuItem(value: 'INACTIVE', child: Text('INACTIVE')),
                                ],
                                onChanged: (v) {
                                  if (v != null) setDialogState(() => status = v);
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: usernameCtrl,
                                decoration: dense('Username *', icon: Icons.alternate_email),
                                validator: (v) =>
                                    (v == null || v.trim().isEmpty) ? 'Username is required' : null,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextFormField(
                                controller: emailCtrl,
                                decoration: dense('Email Address *', icon: Icons.email_outlined),
                                validator: (v) {
                                  if (v == null || v.trim().isEmpty) return 'Email is required';
                                  if (!v.contains('@')) return 'Enter a valid email';
                                  return null;
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: passwordCtrl,
                                obscureText: obscurePassword,
                                decoration: dense(
                                  isEdit ? 'Password (leave blank to keep)' : 'Password *',
                                  icon: Icons.lock_outline,
                                ).copyWith(
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                                      size: 18,
                                    ),
                                    onPressed: () =>
                                        setDialogState(() => obscurePassword = !obscurePassword),
                                  ),
                                ),
                                validator: (v) {
                                  if (!isEdit && (v == null || v.trim().length < 4)) {
                                    return 'Password required (min 4 chars)';
                                  }
                                  if (v != null && v.isNotEmpty && v.trim().length < 4) {
                                    return 'Min 4 characters';
                                  }
                                  return null;
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                initialValue: permissionLevel,
                                decoration: dense('Permission Level'),
                                items: const [
                                  DropdownMenuItem(value: 'READ_ONLY', child: Text('READ_ONLY')),
                                  DropdownMenuItem(value: 'L1', child: Text('L1')),
                                  DropdownMenuItem(value: 'L2', child: Text('L2')),
                                  DropdownMenuItem(value: 'FULL', child: Text('FULL')),
                                ],
                                onChanged: (v) {
                                  if (v != null) setDialogState(() => permissionLevel = v);
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        SwitchListTile.adaptive(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Declaration accepted', style: TextStyle(fontSize: 13)),
                          value: declarationAccepted,
                          onChanged: (v) => setDialogState(() => declarationAccepted = v),
                        ),
                        const Divider(height: 24),
                        sectionTitle('Company & Contact'),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: companyCtrl,
                                decoration: dense('Company / Firm Name', icon: Icons.business_outlined),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextFormField(
                                controller: contactCtrl,
                                decoration: dense('Contact Person Name', icon: Icons.person_outline),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: phoneCtrl,
                                decoration: dense('Phone / Mobile Number', icon: Icons.phone_outlined),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextFormField(
                                controller: streamCtrl,
                                decoration: dense(
                                  'Professional Stream',
                                  hint: 'e.g. Real Estate, Finance, Legal',
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: constitutionCtrl,
                          decoration: dense('Constitution', hint: 'e.g. Proprietorship, LLP, Pvt Ltd'),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: logoUrlCtrl,
                                decoration: dense('Company Logo URL / Data', icon: Icons.image_outlined),
                                onChanged: (v) => companyLogo = v.trim().isEmpty ? null : v.trim(),
                              ),
                            ),
                            const SizedBox(width: 8),
                            OutlinedButton.icon(
                              onPressed: pickLogo,
                              icon: const Icon(Icons.upload_file_rounded, size: 16),
                              label: const Text('Upload'),
                            ),
                          ],
                        ),
                        if (companyLogo != null && companyLogo!.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: companyLogo!.startsWith('data:')
                                ? Image.memory(
                                    base64Decode(companyLogo!.split(',').last),
                                    height: 56,
                                    fit: BoxFit.contain,
                                    errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                                  )
                                : Image.network(
                                    companyLogo!,
                                    height: 56,
                                    fit: BoxFit.contain,
                                    errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                                  ),
                          ),
                        ],
                        const Divider(height: 28),
                        sectionTitle('Statutory & Registration'),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: panCtrl,
                                decoration: dense('PAN Number'),
                                textCapitalization: TextCapitalization.characters,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextFormField(
                                controller: gstinCtrl,
                                decoration: dense('GSTIN'),
                                textCapitalization: TextCapitalization.characters,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: reraCtrl,
                                decoration: dense('RERA Registration No'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextFormField(
                                controller: icaiCtrl,
                                decoration: dense('ICAI Membership No'),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: copCtrl,
                                decoration: dense('COP No'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextFormField(
                                controller: doiCtrl,
                                decoration: dense(
                                  'Date of Incorporation',
                                  hint: 'YYYY-MM-DD',
                                  icon: Icons.calendar_today_outlined,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const Divider(height: 28),
                        sectionTitle('Practice Focus'),
                        chipEditor(
                          label: 'Nature of Business',
                          values: natureOfBusiness,
                          controller: natureChipCtrl,
                          onChanged: (v) => setDialogState(() => natureOfBusiness = v),
                        ),
                        const SizedBox(height: 12),
                        chipEditor(
                          label: 'Areas of Practice',
                          values: areasOfPractice,
                          controller: areasChipCtrl,
                          onChanged: (v) => setDialogState(() => areasOfPractice = v),
                        ),
                        const Divider(height: 28),
                        sectionTitle('Address & Location'),
                        TextFormField(
                          controller: addressCtrl,
                          decoration: dense('Office Address', icon: Icons.location_on_outlined),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: cityCtrl,
                                decoration: dense('City'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextFormField(
                                controller: pincodeCtrl,
                                decoration: dense('Pincode'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextFormField(
                                controller: websiteCtrl,
                                decoration: dense('Website', icon: Icons.language_outlined),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSaving ? null : () => Navigator.pop(dialogCtx),
                  child: const Text('Cancel'),
                ),
                FilledButton.icon(
                  icon: isSaving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.check, size: 18),
                  label: Text(isEdit ? 'Save Changes' : 'Create Partner'),
                  onPressed: isSaving
                      ? null
                      : () async {
                          if (!formKey.currentState!.validate()) return;
                          setDialogState(() => isSaving = true);
                          final firm = companyCtrl.text.trim();
                          final contact = contactCtrl.text.trim();
                          final cleanEmail = emailCtrl.text.trim().toLowerCase();
                          final cleanUsername = usernameCtrl.text.trim();
                          final pwd = passwordCtrl.text.trim();
                          final logo = (companyLogo ?? logoUrlCtrl.text).trim();

                          final payload = <String, dynamic>{
                            'role': role,
                            'status': status,
                            'username': cleanUsername,
                            'email': cleanEmail,
                            'phone': phoneCtrl.text.trim(),
                            'company_or_firm_name': firm,
                            'companyOrFirmName': firm,
                            'contact_person_name': contact,
                            'contactPersonName': contact,
                            'name': contact.isNotEmpty ? contact : firm,
                            'professional_stream': streamCtrl.text.trim(),
                            'professionalStream': streamCtrl.text.trim(),
                            'constitution': constitutionCtrl.text.trim(),
                            'pan': panCtrl.text.trim().toUpperCase(),
                            'gstin': gstinCtrl.text.trim().toUpperCase(),
                            'rera_no': reraCtrl.text.trim(),
                            'reraNo': reraCtrl.text.trim(),
                            'icai_membership_no': icaiCtrl.text.trim(),
                            'icaiMembershipNo': icaiCtrl.text.trim(),
                            'cop_no': copCtrl.text.trim(),
                            'copNo': copCtrl.text.trim(),
                            'date_of_incorporation': doiCtrl.text.trim(),
                            'dateOfIncorporation': doiCtrl.text.trim(),
                            'address': addressCtrl.text.trim(),
                            'city': cityCtrl.text.trim(),
                            'pincode': pincodeCtrl.text.trim(),
                            'website': websiteCtrl.text.trim(),
                            'nature_of_business': natureOfBusiness,
                            'natureOfBusiness': natureOfBusiness,
                            'areas_of_practice': areasOfPractice,
                            'areasOfPractice': areasOfPractice,
                            'declaration_accepted': declarationAccepted,
                            'declarationAccepted': declarationAccepted,
                            'permission_level': permissionLevel,
                            'permissionLevel': permissionLevel,
                            if (logo.isNotEmpty) ...{
                              'company_logo': logo,
                              'companyLogo': logo,
                            },
                            if (pwd.isNotEmpty) 'password': pwd,
                          };

                          try {
                            final repo = context.read<CrmRepository>();
                            if (isEdit && seed != null) {
                              await repo.updateHubPartner(seed.id, payload);
                            } else {
                              await repo.createHubPartner(payload);
                            }

                            if (!dialogCtx.mounted) return;
                            Navigator.pop(dialogCtx);
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    isEdit
                                        ? 'Partner updated successfully in NB Hub!'
                                        : 'New partner created successfully in NB Hub!',
                                  ),
                                  backgroundColor: Colors.green.shade700,
                                ),
                              );
                              _loadPartners();
                            }
                          } catch (err) {
                            setDialogState(() => isSaving = false);
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Error: ${err.toString().replaceAll('Exception:', '').trim()}',
                                  ),
                                  backgroundColor: Colors.red.shade700,
                                ),
                              );
                            }
                          }
                        },
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _confirmDeletePartner(HubPartner partner) {
    showDialog(
      context: context,
      builder: (ctx) {
        bool isDeleting = false;
        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Row(
                children: [
                  Icon(Icons.delete_outline, color: Colors.red),
                  SizedBox(width: 8),
                  Text('Move to Trash?'),
                ],
              ),
              content: Text(
                'Are you sure you want to move partner "${partner.displayName}" to trash in NB Hub?\n\n'
                'The record will be archived in NB Hub trash records.',
              ),
              actions: [
                TextButton(
                  onPressed: isDeleting ? null : () => Navigator.pop(dialogCtx),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
                  onPressed: isDeleting
                      ? null
                      : () async {
                          setDialogState(() => isDeleting = true);
                          try {
                            final repo = context.read<CrmRepository>();
                            await repo.deleteHubPartner(partner.id);
                            if (!dialogCtx.mounted) return;
                            Navigator.pop(dialogCtx);
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Partner moved to trash in NB Hub.'),
                                  backgroundColor: Colors.green,
                                ),
                              );
                              _loadPartners();
                            }
                          } catch (e) {
                            setDialogState(() => isDeleting = false);
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Delete failed: $e'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          }
                        },
                  child: isDeleting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Move to Trash'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showPartnerProfile(HubPartner partner) {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          titlePadding: const EdgeInsets.fromLTRB(24, 20, 16, 0),
          contentPadding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          title: Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: AppColors.primaryBlue.withValues(alpha: 0.15),
                child: Text(
                  partner.displayName.isNotEmpty ? partner.displayName[0].toUpperCase() : 'P',
                  style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primaryBlue, fontSize: 18),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(partner.displayName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    Text(
                      '${partner.roleDisplay} • ${partner.status}',
                      style: TextStyle(
                        fontSize: 12,
                        color: partner.isActive ? Colors.green.shade700 : Colors.grey.shade600,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
            ],
          ),
          content: SizedBox(
            width: 580,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Divider(height: 24),
                  _buildProfileSection(
                    'Contact & Identity',
                    [
                      _ProfileRow('Username', partner.username),
                      _ProfileRow('Email', partner.email, canCopy: true),
                      if (partner.phone != null && partner.phone!.isNotEmpty)
                        _ProfileRow('Phone', partner.phone!, canCopy: true),
                      if (partner.contactPersonName != null && partner.contactPersonName!.isNotEmpty)
                        _ProfileRow('Contact Person', partner.contactPersonName!),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildProfileSection(
                    'Company & Stream',
                    [
                      if (partner.companyOrFirmName != null)
                        _ProfileRow('Firm Name', partner.companyOrFirmName!),
                      if (partner.professionalStream != null)
                        _ProfileRow('Professional Stream', partner.professionalStream!),
                      if (partner.constitution != null)
                        _ProfileRow('Constitution', partner.constitution!),
                      if (partner.website != null && partner.website!.isNotEmpty)
                        _ProfileRow('Website', partner.website!),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildProfileSection(
                    'Registrations & Taxes',
                    [
                      if (partner.reraNo != null && partner.reraNo!.isNotEmpty)
                        _ProfileRow('RERA No', partner.reraNo!, canCopy: true),
                      if (partner.pan != null && partner.pan!.isNotEmpty)
                        _ProfileRow('PAN', partner.pan!, canCopy: true),
                      if (partner.gstin != null && partner.gstin!.isNotEmpty)
                        _ProfileRow('GSTIN', partner.gstin!, canCopy: true),
                      if (partner.icaiMembershipNo != null && partner.icaiMembershipNo!.isNotEmpty)
                        _ProfileRow('ICAI Membership', partner.icaiMembershipNo!, canCopy: true),
                      if (partner.copNo != null && partner.copNo!.isNotEmpty)
                        _ProfileRow('COP No', partner.copNo!),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildProfileSection(
                    'Address',
                    [
                      _ProfileRow(
                        'Location',
                        partner.formattedAddress.isNotEmpty ? partner.formattedAddress : 'Not specified',
                      ),
                    ],
                  ),
                  if (partner.natureOfBusiness.isNotEmpty || partner.areasOfPractice.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    const Text('Practice & Business Areas', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        ...partner.natureOfBusiness.map((b) => Chip(
                              label: Text(b, style: const TextStyle(fontSize: 11)),
                              backgroundColor: Colors.blue.shade50,
                              padding: EdgeInsets.zero,
                            )),
                        ...partner.areasOfPractice.map((a) => Chip(
                              label: Text(a, style: const TextStyle(fontSize: 11)),
                              backgroundColor: Colors.purple.shade50,
                              padding: EdgeInsets.zero,
                            )),
                      ],
                    ),
                  ],
                  const SizedBox(height: 16),
                  Text(
                    'Record ID: ${partner.id}',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
            FilledButton.icon(
              icon: const Icon(Icons.edit, size: 16),
              label: const Text('Edit Partner'),
              onPressed: () {
                Navigator.pop(ctx);
                _openAddEditPartnerDialog(partner);
              },
            ),
          ],
        );
      },
    );
  }

  void _openTrashDialog() async {
    showDialog(
      context: context,
      builder: (ctx) {
        return FutureBuilder<List<Map<String, dynamic>>>(
          future: context.read<CrmRepository>().getHubTrash(),
          builder: (context, snapshot) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Row(
                children: [
                  Icon(Icons.archive_outlined, color: Colors.brown),
                  SizedBox(width: 8),
                  Text('NB Hub Trash Archive'),
                ],
              ),
              content: SizedBox(
                width: 600,
                height: 350,
                child: snapshot.connectionState == ConnectionState.waiting
                    ? const Center(child: CircularProgressIndicator())
                    : (snapshot.hasError
                        ? Center(child: Text('Failed to load trash: ${snapshot.error}'))
                        : (snapshot.data == null || snapshot.data!.isEmpty)
                            ? const Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.delete_sweep_outlined, size: 48, color: Colors.grey),
                                    SizedBox(height: 8),
                                    Text('Trash is empty', style: TextStyle(color: Colors.grey)),
                                  ],
                                ),
                              )
                            : ListView.separated(
                                itemCount: snapshot.data!.length,
                                separatorBuilder: (_, __) => const Divider(),
                                itemBuilder: (c, idx) {
                                  final item = snapshot.data![idx];
                                  final title = item['company_or_firm_name'] ??
                                      item['name'] ??
                                      item['username'] ??
                                      'Archived Item #${idx + 1}';
                                  final deletedAt = item['deleted_at'] ?? item['created_at'] ?? '';
                                  return ListTile(
                                    leading: const CircleAvatar(
                                      child: Icon(Icons.restore_from_trash, size: 18),
                                    ),
                                    title: Text(title.toString()),
                                    subtitle: Text('Archived: $deletedAt'),
                                  );
                                },
                              )),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Close'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildProfileSection(String title, List<_ProfileRow> rows) {
    if (rows.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.primaryBlue)),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(
            children: rows.map((r) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(
                  children: [
                    SizedBox(
                      width: 130,
                      child: Text(
                        r.label,
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        r.value,
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                      ),
                    ),
                    if (r.canCopy)
                      IconButton(
                        icon: const Icon(Icons.copy, size: 14),
                        tooltip: 'Copy',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: r.value));
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Copied ${r.label} to clipboard'),
                              duration: const Duration(seconds: 1),
                            ),
                          );
                        },
                      ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            _buildStatKpiStrip(),
            _buildFilterBar(),
            Expanded(child: _buildMainContent()),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF3B82F6), Color(0xFF1D4ED8)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.blue.withValues(alpha: 0.25),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: const Icon(Icons.handshake_outlined, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 16),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'NB Hub Partners',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.3,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Channel Partners, Onboarding Members & Profiles via NB Hub REST API',
                  style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                ),
              ],
            ),
          ),
          OutlinedButton.icon(
            icon: const Icon(Icons.archive_outlined, size: 16),
            label: const Text('Trash Archive'),
            onPressed: _openTrashDialog,
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
          const SizedBox(width: 10),
          IconButton.filledTonal(
            tooltip: 'Refresh Partners',
            icon: const Icon(Icons.refresh, size: 18),
            onPressed: _loadPartners,
          ),
          const SizedBox(width: 10),
          FilledButton.icon(
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Add Partner'),
            onPressed: () => _openAddEditPartnerDialog(),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatKpiStrip() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      child: Row(
        children: [
          _buildKpiCard('Total Partners', '$_countTotal', Icons.people_alt_outlined, const Color(0xFF2563EB)),
          const SizedBox(width: 14),
          _buildKpiCard('Channel Partners (CP)', '$_countCP', Icons.storefront_outlined, const Color(0xFF0D9488)),
          const SizedBox(width: 14),
          _buildKpiCard('Associate Partners (AP)', '$_countAP', Icons.badge_outlined, const Color(0xFF7C3AED)),
          const SizedBox(width: 14),
          _buildKpiCard('Active Onboarded', '$_countActive', Icons.verified_outlined, const Color(0xFF16A34A)),
        ],
      ),
    );
  }

  Widget _buildKpiCard(String title, String count, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600, fontWeight: FontWeight.w500),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    count,
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
      color: Colors.white,
      child: Row(
        children: [
          // Filter Tabs
          Wrap(
            spacing: 8,
            children: [
              _buildFilterChip('ALL', 'All Partners'),
              _buildFilterChip('CP', 'Channel Partners'),
              _buildFilterChip('AP', 'Associate Partners'),
              _buildFilterChip('ACTIVE', 'Active'),
              _buildFilterChip('INACTIVE', 'Inactive'),
            ],
          ),
          const Spacer(),
          // Search box
          SizedBox(
            width: 320,
            height: 38,
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search firm, person, email, city, RERA...',
                hintStyle: TextStyle(fontSize: 12, color: Colors.grey.shade400),
                prefixIcon: const Icon(Icons.search, size: 18),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 16),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppColors.primaryBlue),
                ),
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
              ),
              onChanged: (val) {
                setState(() => _searchQuery = val.trim());
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String key, String label) {
    final isSelected = _selectedRoleFilter == key;
    return ChoiceChip(
      label: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          color: isSelected ? Colors.white : Colors.grey.shade700,
        ),
      ),
      selected: isSelected,
      selectedColor: AppColors.primaryBlue,
      backgroundColor: Colors.grey.shade100,
      showCheckmark: false,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: isSelected ? AppColors.primaryBlue : Colors.grey.shade300),
      ),
      onSelected: (selected) {
        if (selected) {
          setState(() => _selectedRoleFilter = key);
        }
      },
    );
  }

  Widget _buildMainContent() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 14),
            Text('Loading NB Hub partners via REST API...', style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 480),
          padding: const EdgeInsets.all(24),

          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.red.shade200),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, size: 48, color: Colors.red.shade600),
              const SizedBox(height: 12),
              const Text(
                'Could not load NB Hub Partners',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('Try Again'),
                onPressed: _loadPartners,
              ),
            ],
          ),
        ),
      );
    }

    final filtered = _filteredPartners;

    if (filtered.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.handshake_outlined, size: 48, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            const Text(
              'No Partners Found',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              _searchQuery.isNotEmpty
                  ? 'No partners match "$_searchQuery"'
                  : 'No partner records are registered in NB Hub onboarding.',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Add First Partner'),
              onPressed: () => _openAddEditPartnerDialog(),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        // Table Header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 10),
          margin: const EdgeInsets.only(top: 12),
          child: const Row(
            children: [
              SizedBox(width: 48), // Avatar space
              Expanded(
                flex: 3,
                child: Text(
                  'PARTNER & FIRM',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B), letterSpacing: 0.5),
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: Text(
                  'ROLE & STATUS',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B), letterSpacing: 0.5),
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                flex: 3,
                child: Text(
                  'CONTACT INFO',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B), letterSpacing: 0.5),
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: Text(
                  'LOCATION & PAN',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B), letterSpacing: 0.5),
                ),
              ),
              SizedBox(width: 8),
              SizedBox(
                width: 110,
                child: Text(
                  'ACTIONS',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B), letterSpacing: 0.5),
                ),
              ),
            ],
          ),
        ),
        // List of compact single-line partner rows
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            itemCount: filtered.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final partner = filtered[index];
              return _buildPartnerSingleLineRow(partner);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildPartnerSingleLineRow(HubPartner partner) {
    final roleColor = partner.role == 'CP'
        ? const Color(0xFF0D9488)
        : (partner.role == 'AP' ? const Color(0xFF7C3AED) : const Color(0xFF2563EB));

    final firm = (partner.companyOrFirmName ?? '').trim();
    final contact = (partner.contactPersonName ?? '').trim();
    final primaryTitle = firm.isNotEmpty ? firm : (contact.isNotEmpty ? contact : partner.username);
    final secondaryTitle = firm.isNotEmpty && contact.isNotEmpty ? contact : (firm.isEmpty ? partner.username : '');

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () => _showPartnerProfile(partner),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                // 1. Avatar
                CircleAvatar(
                  radius: 17,
                  backgroundColor: roleColor.withValues(alpha: 0.12),
                  child: Text(
                    primaryTitle.isNotEmpty ? primaryTitle[0].toUpperCase() : 'P',
                    style: TextStyle(fontWeight: FontWeight.bold, color: roleColor, fontSize: 14),
                  ),
                ),
                const SizedBox(width: 14),

                // 2. Partner / Firm & Contact Person
                Expanded(
                  flex: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        primaryTitle,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (secondaryTitle.isNotEmpty)
                        Text(
                          secondaryTitle,
                          style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),

                const SizedBox(width: 12),

                // 3. Role & Status Badges
                Expanded(
                  flex: 2,
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: roleColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          partner.role,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: roleColor,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: partner.isActive ? Colors.green.shade50 : Colors.red.shade50,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: partner.isActive ? Colors.green.shade600 : Colors.red.shade600,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              partner.status,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: partner.isActive ? Colors.green.shade700 : Colors.red.shade700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 12),

                // 4. Contact (Email & Phone)
                Expanded(
                  flex: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.email_outlined, size: 13, color: Colors.grey.shade500),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              partner.email,
                              style: TextStyle(fontSize: 12, color: Colors.grey.shade800),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      if (partner.phone != null && partner.phone!.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Icon(Icons.phone_outlined, size: 13, color: Colors.grey.shade500),
                            const SizedBox(width: 6),
                            Text(
                              partner.phone!,
                              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),

                const SizedBox(width: 12),

                // 5. City & PAN
                Expanded(
                  flex: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (partner.city != null && partner.city!.isNotEmpty)
                        Row(
                          children: [
                            Icon(Icons.location_on_outlined, size: 13, color: Colors.grey.shade500),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                partner.city!,
                                style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        )
                      else
                        Text('—', style: TextStyle(fontSize: 12, color: Colors.grey.shade400)),
                      if (partner.pan != null && partner.pan!.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: Colors.blue.shade200),
                          ),
                          child: Text(
                            'PAN: ${partner.pan}',
                            style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: Colors.blue.shade900),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                const SizedBox(width: 8),

                // 6. Action buttons
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.visibility_outlined, size: 18),
                      tooltip: 'View Profile',
                      onPressed: () => _showPartnerProfile(partner),
                      visualDensity: VisualDensity.compact,
                    ),
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, size: 18),
                      tooltip: 'Edit Partner',
                      onPressed: () => _openAddEditPartnerDialog(partner),
                      visualDensity: VisualDensity.compact,
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                      tooltip: 'Move to Trash',
                      onPressed: () => _confirmDeletePartner(partner),
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ProfileRow {
  final String label;
  final String value;
  final bool canCopy;

  _ProfileRow(this.label, this.value, {this.canCopy = false});
}
