import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../../core/router/app_back_button.dart';
import '../../../../core/widgets/mobile_input_formatter.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../data/crm_repository.dart';
import '../../domain/crm_models.dart';
import '../bloc/crm_leads_bloc.dart';

class CrmVisitorDeskScreen extends StatelessWidget {
  const CrmVisitorDeskScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<CrmLeadsBloc>(
      create: (ctx) => CrmLeadsBloc(
        crmRepository: ctx.read<CrmRepository>(),
      )..add(const CrmLeadsLoadRequested()),
      child: const _CrmVisitorDeskView(),
    );
  }
}

class _CrmVisitorDeskView extends StatefulWidget {
  const _CrmVisitorDeskView();

  @override
  State<_CrmVisitorDeskView> createState() => _CrmVisitorDeskViewState();
}

class _CrmVisitorDeskViewState extends State<_CrmVisitorDeskView> {
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _cpNameController = TextEditingController();
  final TextEditingController _refNameController = TextEditingController();
  final TextEditingController _remarksController = TextEditingController(text: 'Visitor checked in at site reception.');

  bool _isLookingUp = false;
  bool _hasLookedUp = false;
  Map<String, dynamic>? _lookupData;
  String? _lookupError;

  int? _selectedSalesId;
  String _selectedLeadSource = 'Walk IN';
  String _selectedRefType = 'B2B';

  @override
  void dispose() {
    _phoneController.dispose();
    _nameController.dispose();
    _cpNameController.dispose();
    _refNameController.dispose();
    _remarksController.dispose();
    super.dispose();
  }

  void _resetLookup() {
    setState(() {
      _hasLookedUp = false;
      _lookupData = null;
      _lookupError = null;
      _selectedSalesId = null;
      _nameController.clear();
      _cpNameController.clear();
      _refNameController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1E1B18) : Colors.white;
    final borderColor = isDark ? const Color(0xFF3E3830) : const Color(0xFFE2E8F0);
    final textMuted = isDark ? const Color(0xFFB3ADA0) : const Color(0xFF64748B);
    const primaryColor = Color(0xFFD97706); // Warm Reception / Front Desk amber

    return BlocConsumer<CrmLeadsBloc, CrmLeadsState>(
      listener: (context, state) {
        if (state.actionSuccessMessage != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.actionSuccessMessage!),
              backgroundColor: const Color(0xFF16A34A),
            ),
          );
          _resetLookup();
          _phoneController.clear();
        } else if (state.errorMessage != null && state.errorMessage!.isNotEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.errorMessage!), backgroundColor: Colors.redAccent),
          );
        }
      },
      builder: (context, state) {
        final authState = context.watch<AuthBloc>().state;
        final currentUser = authState.user;
        final userRole = currentUser?.role.toUpperCase() ?? '';
        final userEmployeeId = currentUser?.employeeId;
        final isAdmin = ['ADMIN', 'SUPER_ADMIN', 'SYSTEM_ADMIN'].contains(userRole);
        final isDesignatedDeskEmployee = userEmployeeId != null &&
            state.settings?.siteVisitDeskEmployeeId != null &&
            userEmployeeId == state.settings!.siteVisitDeskEmployeeId;
        final hasAccess = isAdmin || isDesignatedDeskEmployee;

        // Today's Visited Leads
        final now = DateTime.now();
        final todayVisitedLeads = state.leads.where((l) {
          if (l.status != CrmStatus.siteVisitDone) return false;
          final visitDate = l.visitedAt ?? l.updatedAt;
          return visitDate.year == now.year && visitDate.month == now.month && visitDate.day == now.day;
        }).toList();

        return Scaffold(
          appBar: AppBar(
            leading: const AppBackButton(fallbackLocation: '/crm/pre-sales'),
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Site Reception & Visitor Desk',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
                Text(
                  'Verify scheduled appointments, register walk-ins, and assign Sales Representatives',
                  style: TextStyle(fontSize: 12, color: textMuted, fontWeight: FontWeight.normal),
                ),
              ],
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh_rounded),
                tooltip: 'Refresh Desk',
                onPressed: () => context.read<CrmLeadsBloc>().add(const CrmLeadsLoadRequested()),
              ),
              const SizedBox(width: 8),
            ],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Access Banner if not authorized
                if (!hasAccess) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.amber.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.amber.withValues(alpha: 0.35)),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.lock_rounded, color: Colors.amber, size: 20),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Notice: Only Admins or the Designated Site Visit Desk In-Charge can register visitors and assign sales reps.',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                // Desk In-Charge Info Card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: primaryColor.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: primaryColor.withValues(alpha: 0.25)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: primaryColor.withValues(alpha: 0.18),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.badge_rounded, color: primaryColor, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'DESIGNATED SITE VISIT DESK IN-CHARGE',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.6, color: primaryColor),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              state.settings?.siteVisitDeskEmployeeId != null
                                  ? 'Employee ID #${state.settings!.siteVisitDeskEmployeeId} (Configured in CRM Settings)'
                                  : 'Not specifically designated (System Administrators have full front-desk authority)',
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Main Visitor Check-In Interactive Card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: borderColor),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: const Color(0xFF2563EB).withValues(alpha: 0.12),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.person_search_rounded, color: Color(0xFF2563EB), size: 22),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Visitor Arrival Lookup',
                                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                                ),
                                Text(
                                  'Enter visitor mobile number to verify schedule and check in at site',
                                  style: TextStyle(fontSize: 12, color: Colors.grey),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),

                      // Mobile Lookup Row
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _phoneController,
                              keyboardType: TextInputType.phone,
                              inputFormatters: mobileInputFormatters,
                              decoration: InputDecoration(
                                hintText: '10-digit mobile number',
                                prefixIcon: buildMobilePrefix(isDark: isDark),
                                prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              onChanged: (_) {
                                if (_hasLookedUp) _resetLookup();
                              },
                              onSubmitted: (_) => _handleLookup(context),
                            ),
                          ),
                          const SizedBox(width: 12),
                          ElevatedButton.icon(
                            icon: _isLookingUp
                                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                : const Icon(Icons.search_rounded, size: 18),
                            label: const Text('Verify & Lookup'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF2563EB),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            onPressed: _isLookingUp ? null : () => _handleLookup(context),
                          ),
                        ],
                      ),
                      if (_lookupError != null) ...[
                        const SizedBox(height: 8),
                        Text(_lookupError!, style: const TextStyle(fontSize: 13, color: Colors.redAccent)),
                      ],

                      // Results & Check-in section
                      if (_hasLookedUp) ...[
                        const SizedBox(height: 24),
                        const Divider(),
                        const SizedBox(height: 16),
                        _buildLookupResultContent(context, state, isDark, primaryColor, textMuted),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 30),

                // Table of Today's Checked-In Visitors
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "Today's Visited Clients (${todayVisitedLeads.length})",
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      DateFormat('dd MMMM yyyy').format(now),
                      style: TextStyle(fontSize: 13, color: textMuted, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                if (todayVisitedLeads.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: borderColor),
                    ),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(Icons.event_available_outlined, size: 40, color: textMuted),
                          const SizedBox(height: 10),
                          const Text('No Visitors Checked-In Yet Today', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                          const SizedBox(height: 4),
                          Text('Use the lookup box above when a visitor arrives at the reception.', style: TextStyle(color: textMuted, fontSize: 13)),
                        ],
                      ),
                    ),
                  )
                else
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: borderColor),
                    ),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                        headingRowColor: WidgetStateProperty.all(
                          isDark ? Colors.white.withValues(alpha: 0.04) : const Color(0xFFF1F5F9),
                        ),
                        columns: const [
                          DataColumn(label: Text('#', style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('Visitor Name', style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('Mobile', style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('Assigned Sales Rep', style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('Visit Time', style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('Lead Source', style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('Status', style: TextStyle(fontWeight: FontWeight.bold))),
                        ],
                        rows: List.generate(todayVisitedLeads.length, (i) {
                          final lead = todayVisitedLeads[i];
                          final visitTime = lead.visitedAt ?? lead.updatedAt;

                          return DataRow(
                            cells: [
                              DataCell(Text('${i + 1}')),
                              DataCell(Text(lead.name.isNotEmpty ? lead.name : 'Client', style: const TextStyle(fontWeight: FontWeight.w600))),
                              DataCell(Text(lead.phone.isNotEmpty ? '+91 ${lead.phone}' : '-')),
                              DataCell(
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.badge_outlined, size: 14, color: Color(0xFF2563EB)),
                                    const SizedBox(width: 6),
                                    Text(lead.assignedToName ?? 'Assigned Rep', style: const TextStyle(fontWeight: FontWeight.w600)),
                                  ],
                                ),
                              ),
                              DataCell(Text(DateFormat('hh:mm a').format(visitTime))),
                              DataCell(Text(lead.leadSource ?? 'Walk IN')),
                              DataCell(
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF10B981).withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.4)),
                                  ),
                                  child: const Text('Site Done', style: TextStyle(color: Color(0xFF047857), fontWeight: FontWeight.bold, fontSize: 12)),
                                ),
                              ),
                            ],
                          );
                        }),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _handleLookup(BuildContext context) async {
    final digits = cleanMobile10(_phoneController.text);
    if (digits.length != 10) {
      setState(() => _lookupError = 'Please enter a valid 10-digit mobile number.');
      return;
    }

    setState(() {
      _isLookingUp = true;
      _lookupError = null;
    });

    try {
      final repo = context.read<CrmRepository>();
      final res = await repo.visitorLookup(digits);
      setState(() {
        _isLookingUp = false;
        _hasLookedUp = true;
        _lookupData = res;
        if (res['exists'] == true && res['lead'] != null) {
          final l = res['lead'] as Map<String, dynamic>;
          _nameController.text = l['name']?.toString() ?? '';
          if (l['assignedToId'] != null) {
            _selectedSalesId = l['assignedToId'] as int?;
          }
        }
      });
    } catch (err) {
      setState(() {
        _isLookingUp = false;
        _lookupError = 'Lookup failed: $err';
      });
    }
  }

  Widget _buildLookupResultContent(
    BuildContext context,
    CrmLeadsState state,
    bool isDark,
    Color primaryColor,
    Color textMuted,
  ) {
    final exists = _lookupData?['exists'] == true;
    final isScheduledToday = _lookupData?['isScheduledToday'] == true;
    final lead = _lookupData?['lead'] as Map<String, dynamic>?;
    final salesUsers = state.salesUsers;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (exists && lead != null) ...[
          // BRANCH A: EXISTING LEAD FOUND
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isScheduledToday
                  ? const Color(0xFF16A34A).withValues(alpha: 0.1)
                  : const Color(0xFF2563EB).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isScheduledToday
                    ? const Color(0xFF16A34A).withValues(alpha: 0.35)
                    : const Color(0xFF2563EB).withValues(alpha: 0.35),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      isScheduledToday ? Icons.check_circle_rounded : Icons.info_outline_rounded,
                      size: 20,
                      color: isScheduledToday ? const Color(0xFF16A34A) : const Color(0xFF2563EB),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        isScheduledToday
                            ? 'Scheduled Site Visit Confirmed for Today!'
                            : 'No visit was scheduled for today. Check-in will automatically allocate a visit for today at the current time.',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: isScheduledToday ? const Color(0xFF15803D) : const Color(0xFF1D4ED8),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  'Visitor: ${lead['name'] ?? 'Unnamed'} • ${lead['phone'] ?? _phoneController.text}',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                if (lead['campaign'] != null && lead['campaign']['name'] != null) ...[
                  const SizedBox(height: 4),
                  Text('Campaign: ${lead['campaign']['name']}', style: TextStyle(fontSize: 13, color: textMuted)),
                ],
              ],
            ),
          ),
        ] else ...[
          // BRANCH B: NEW VISITOR REGISTRATION
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFD97706).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFD97706).withValues(alpha: 0.3)),
            ),
            child: const Row(
              children: [
                Icon(Icons.person_add_rounded, size: 20, color: Color(0xFFD97706)),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'New Visitor Registration — No previous lead found for this number. Enter visitor details below.',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFFB45309)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          const Text('Visitor Full Name *', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          TextField(
            controller: _nameController,
            decoration: InputDecoration(
              hintText: 'Enter full name',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              isDense: true,
            ),
          ),
          const SizedBox(height: 14),

          // Lead Source
          const Text('Lead Source *', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          DropdownButtonFormField<String>(
            isExpanded: true,
            initialValue: _selectedLeadSource,
            decoration: InputDecoration(
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              isDense: true,
            ),
            items: (state.settings?.leadSources ?? ['Walk IN', 'Channel Partner', 'Reference'])
                .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                .toList(),
            onChanged: (val) {
              if (val != null) setState(() => _selectedLeadSource = val);
            },
          ),

          if (_selectedLeadSource == 'Channel Partner') ...[
            const SizedBox(height: 14),
            const Text('Channel Partner Name *', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            TextField(
              controller: _cpNameController,
              decoration: InputDecoration(
                hintText: 'Enter CP name or agency',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                isDense: true,
              ),
            ),
          ],

          if (_selectedLeadSource == 'Reference') ...[
            const SizedBox(height: 14),
            const Text('Reference Category *', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            DropdownButtonFormField<String>(
              isExpanded: true,
              initialValue: _selectedRefType,
              decoration: InputDecoration(
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                isDense: true,
              ),
              items: (state.settings?.referenceTypes ?? ['B2B', 'Employee', 'Other Client'])
                  .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                  .toList(),
              onChanged: (val) {
                if (val != null) setState(() => _selectedRefType = val);
              },
            ),
            const SizedBox(height: 14),
            const Text('Referrer Name *', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            TextField(
              controller: _refNameController,
              decoration: InputDecoration(
                hintText: 'Enter referrer name',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                isDense: true,
              ),
            ),
          ],
        ],

        const SizedBox(height: 18),

        // Assign Sales Representative (All HRMS employees)
        const Text(
          'Assign Sales Representative *',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFFD97706)),
        ),
        const SizedBox(height: 6),
        Text(
          'Select the Sales Manager / Representative who is attending this visitor at the site.',
          style: TextStyle(fontSize: 12, color: textMuted),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<int?>(
          isExpanded: true,
          initialValue: _selectedSalesId,
          hint: const Text('Select Sales Representative (from HRMS employees)'),
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.badge_outlined, size: 20),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            isDense: true,
          ),
          items: salesUsers.map((u) {
            final label = u.designation != null && u.designation!.isNotEmpty
                ? '${u.fullName} (${u.designation})'
                : u.fullName;
            return DropdownMenuItem<int?>(
              value: u.employeeId,
              child: Text(label, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13)),
            );
          }).toList(),
          onChanged: (val) => setState(() => _selectedSalesId = val),
        ),
        const SizedBox(height: 16),

        const Text('Reception Notes (Optional)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        TextField(
          controller: _remarksController,
          maxLines: 2,
          decoration: InputDecoration(
            hintText: 'Notes for the sales rep...',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            isDense: true,
          ),
        ),
        const SizedBox(height: 20),

        // Submit Button
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            icon: const Icon(Icons.how_to_reg_rounded, size: 20),
            label: Text(
              exists ? 'Confirm Check-In & Mark Site Done' : 'Register Visitor & Mark Site Done',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF16A34A),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              final digits = cleanMobile10(_phoneController.text);
              if (_selectedSalesId == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please select an Assigned Sales Representative.')),
                );
                return;
              }

              if (!exists) {
                final name = _nameController.text.trim();
                if (name.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please enter Visitor Full Name.')),
                  );
                  return;
                }
                if (_selectedLeadSource == 'Channel Partner' && _cpNameController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please enter Channel Partner Name.')),
                  );
                  return;
                }
                if (_selectedLeadSource == 'Reference' && _refNameController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please enter Referrer Name.')),
                  );
                  return;
                }

                context.read<CrmLeadsBloc>().add(
                      CrmLeadsVisitorCheckinSubmitted({
                        'phone': digits,
                        'name': name,
                        'leadSource': _selectedLeadSource,
                        'channelPartnerName': _cpNameController.text.trim(),
                        'referenceType': _selectedLeadSource == 'Reference' ? _selectedRefType : null,
                        'referenceName': _refNameController.text.trim(),
                        'assignedToId': _selectedSalesId,
                        'remarks': _remarksController.text.trim(),
                      }),
                    );
              } else {
                context.read<CrmLeadsBloc>().add(
                      CrmLeadsVisitorCheckinSubmitted({
                        'leadId': lead!['id'],
                        'phone': digits,
                        'assignedToId': _selectedSalesId,
                        'remarks': _remarksController.text.trim(),
                      }),
                    );
              }
            },
          ),
        ),
      ],
    );
  }
}
