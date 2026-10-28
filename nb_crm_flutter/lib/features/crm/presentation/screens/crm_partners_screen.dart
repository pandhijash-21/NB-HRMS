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

  void _openAddEditPartnerDialog([HubPartner? partner]) {
    final isEdit = partner != null;
    final formKey = GlobalKey<FormState>();

    String role = partner?.role ?? 'CP';
    final emailCtrl = TextEditingController(text: partner?.email ?? '');
    final usernameCtrl = TextEditingController(text: partner?.username ?? '');
    final phoneCtrl = TextEditingController(text: partner?.phone ?? '');
    final companyCtrl = TextEditingController(text: partner?.companyOrFirmName ?? '');
    final contactCtrl = TextEditingController(text: partner?.contactPersonName ?? '');
    final streamCtrl = TextEditingController(text: partner?.professionalStream ?? '');
    final panCtrl = TextEditingController(text: partner?.pan ?? '');
    final gstinCtrl = TextEditingController(text: partner?.gstin ?? '');
    final reraCtrl = TextEditingController(text: partner?.reraNo ?? '');
    final icaiCtrl = TextEditingController(text: partner?.icaiMembershipNo ?? '');
    final cityCtrl = TextEditingController(text: partner?.city ?? '');
    final addressCtrl = TextEditingController(text: partner?.address ?? '');
    final pincodeCtrl = TextEditingController(text: partner?.pincode ?? '');
    final websiteCtrl = TextEditingController(text: partner?.website ?? '');
    String status = partner?.status ?? 'ACTIVE';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        bool isSaving = false;
        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
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
                      isEdit ? 'Edit Partner: ${partner.displayName}' : 'Add New Partner',
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
                width: 680,
                child: Form(
                  key: formKey,
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Partner Role & Credentials',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.primaryBlue),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                initialValue: role,
                                decoration: const InputDecoration(
                                  labelText: 'Partner Role *',
                                  border: OutlineInputBorder(),
                                  isDense: true,
                                ),
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
                                decoration: const InputDecoration(
                                  labelText: 'Status',
                                  border: OutlineInputBorder(),
                                  isDense: true,
                                ),
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
                                decoration: const InputDecoration(
                                  labelText: 'Username *',
                                  border: OutlineInputBorder(),
                                  isDense: true,
                                  prefixIcon: Icon(Icons.alternate_email, size: 18),
                                ),
                                validator: (v) => (v == null || v.trim().isEmpty) ? 'Username is required' : null,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextFormField(
                                controller: emailCtrl,
                                decoration: const InputDecoration(
                                  labelText: 'Email Address *',
                                  border: OutlineInputBorder(),
                                  isDense: true,
                                  prefixIcon: Icon(Icons.email_outlined, size: 18),
                                ),
                                validator: (v) {
                                  if (v == null || v.trim().isEmpty) return 'Email is required';
                                  if (!v.contains('@')) return 'Enter a valid email';
                                  return null;
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        const Divider(),
                        const Text(
                          'Company & Contact Information',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.primaryBlue),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: companyCtrl,
                                decoration: const InputDecoration(
                                  labelText: 'Company / Firm Name',
                                  border: OutlineInputBorder(),
                                  isDense: true,
                                  prefixIcon: Icon(Icons.business_outlined, size: 18),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextFormField(
                                controller: contactCtrl,
                                decoration: const InputDecoration(
                                  labelText: 'Contact Person Name',
                                  border: OutlineInputBorder(),
                                  isDense: true,
                                  prefixIcon: Icon(Icons.person_outline, size: 18),
                                ),
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
                                decoration: const InputDecoration(
                                  labelText: 'Phone / Mobile Number',
                                  border: OutlineInputBorder(),
                                  isDense: true,
                                  prefixIcon: Icon(Icons.phone_outlined, size: 18),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextFormField(
                                controller: streamCtrl,
                                decoration: const InputDecoration(
                                  labelText: 'Professional Stream',
                                  hintText: 'e.g. Real Estate, Finance, Legal',
                                  border: OutlineInputBorder(),
                                  isDense: true,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        const Divider(),
                        const Text(
                          'Statutory & Registration Numbers',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.primaryBlue),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: panCtrl,
                                decoration: const InputDecoration(
                                  labelText: 'PAN Number',
                                  border: OutlineInputBorder(),
                                  isDense: true,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextFormField(
                                controller: gstinCtrl,
                                decoration: const InputDecoration(
                                  labelText: 'GSTIN',
                                  border: OutlineInputBorder(),
                                  isDense: true,
                                ),
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
                                decoration: const InputDecoration(
                                  labelText: 'RERA Registration No',
                                  border: OutlineInputBorder(),
                                  isDense: true,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextFormField(
                                controller: icaiCtrl,
                                decoration: const InputDecoration(
                                  labelText: 'ICAI Membership No (if CA)',
                                  border: OutlineInputBorder(),
                                  isDense: true,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        const Divider(),
                        const Text(
                          'Address & Location',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.primaryBlue),
                        ),
                        const SizedBox(height: 10),
                        TextFormField(
                          controller: addressCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Office Address',
                            border: OutlineInputBorder(),
                            isDense: true,
                            prefixIcon: Icon(Icons.location_on_outlined, size: 18),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: cityCtrl,
                                decoration: const InputDecoration(
                                  labelText: 'City',
                                  border: OutlineInputBorder(),
                                  isDense: true,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextFormField(
                                controller: pincodeCtrl,
                                decoration: const InputDecoration(
                                  labelText: 'Pincode',
                                  border: OutlineInputBorder(),
                                  isDense: true,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextFormField(
                                controller: websiteCtrl,
                                decoration: const InputDecoration(
                                  labelText: 'Website',
                                  border: OutlineInputBorder(),
                                  isDense: true,
                                  prefixIcon: Icon(Icons.language_outlined, size: 18),
                                ),
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

                          final payload = {
                            'role': role,
                            'status': status,
                            'username': usernameCtrl.text.trim(),
                            'email': emailCtrl.text.trim(),
                            'phone': phoneCtrl.text.trim(),
                            'company_or_firm_name': companyCtrl.text.trim(),
                            'contact_person_name': contactCtrl.text.trim(),
                            'professional_stream': streamCtrl.text.trim(),
                            'pan': panCtrl.text.trim().toUpperCase(),
                            'gstin': gstinCtrl.text.trim().toUpperCase(),
                            'rera_no': reraCtrl.text.trim(),
                            'icai_membership_no': icaiCtrl.text.trim(),
                            'address': addressCtrl.text.trim(),
                            'city': cityCtrl.text.trim(),
                            'pincode': pincodeCtrl.text.trim(),
                            'website': websiteCtrl.text.trim(),
                          };

                          try {
                            final repo = context.read<CrmRepository>();
                            if (isEdit) {
                              await repo.updateHubPartner(partner.id, payload);
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
                                  content: Text('Error: ${err.toString().replaceAll('Exception:', '').trim()}'),
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

    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth > 1400
            ? 3
            : (constraints.maxWidth > 900 ? 2 : 1);

        return GridView.builder(
          padding: const EdgeInsets.all(24),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            childAspectRatio: 1.65,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
          ),
          itemCount: filtered.length,
          itemBuilder: (context, index) {
            final partner = filtered[index];
            return _buildPartnerCard(partner);
          },
        );
      },
    );
  }

  Widget _buildPartnerCard(HubPartner partner) {
    final roleColor = partner.role == 'CP'
        ? const Color(0xFF0D9488)
        : (partner.role == 'AP' ? const Color(0xFF7C3AED) : const Color(0xFF2563EB));

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      color: Colors.white,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _showPartnerProfile(partner),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top row: Avatar + Name + Badges
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: roleColor.withValues(alpha: 0.12),
                    child: Text(
                      partner.displayName.isNotEmpty ? partner.displayName[0].toUpperCase() : 'P',
                      style: TextStyle(fontWeight: FontWeight.bold, color: roleColor, fontSize: 16),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          partner.displayName,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (partner.contactPersonName != null && partner.contactPersonName!.isNotEmpty)
                          Text(
                            partner.contactPersonName!,
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: roleColor.withValues(alpha: 0.1),
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
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: partner.isActive ? Colors.green.shade50 : Colors.red.shade50,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      partner.status,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: partner.isActive ? Colors.green.shade700 : Colors.red.shade700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 10),
              // Contact details
              Row(
                children: [
                  Icon(Icons.email_outlined, size: 14, color: Colors.grey.shade500),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      partner.email,
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              if (partner.phone != null && partner.phone!.isNotEmpty) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.phone_outlined, size: 14, color: Colors.grey.shade500),
                    const SizedBox(width: 6),
                    Text(
                      partner.phone!,
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                    ),
                  ],
                ),
              ],
              if (partner.city != null && partner.city!.isNotEmpty) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.location_on_outlined, size: 14, color: Colors.grey.shade500),
                    const SizedBox(width: 6),
                    Text(
                      partner.city!,
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                    ),
                  ],
                ),
              ],
              const Spacer(),
              // Tags / Reg row
              Row(
                children: [
                  if (partner.reraNo != null && partner.reraNo!.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.only(right: 6),
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade50,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: Colors.amber.shade200),
                      ),
                      child: Text(
                        'RERA: ${partner.reraNo}',
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.amber.shade900),
                      ),
                    ),
                  if (partner.pan != null && partner.pan!.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.only(right: 6),
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: Colors.blue.shade200),
                      ),
                      child: Text(
                        'PAN: ${partner.pan}',
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.blue.shade900),
                      ),
                    ),
                  const Spacer(),
                  // Action buttons
                  IconButton(
                    icon: const Icon(Icons.visibility_outlined, size: 18),
                    tooltip: 'View Profile',
                    constraints: const BoxConstraints(),
                    padding: const EdgeInsets.all(6),
                    onPressed: () => _showPartnerProfile(partner),
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    tooltip: 'Edit Partner',
                    constraints: const BoxConstraints(),
                    padding: const EdgeInsets.all(6),
                    onPressed: () => _openAddEditPartnerDialog(partner),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                    tooltip: 'Move to Trash',
                    constraints: const BoxConstraints(),
                    padding: const EdgeInsets.all(6),
                    onPressed: () => _confirmDeletePartner(partner),
                  ),
                ],
              ),
            ],
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
