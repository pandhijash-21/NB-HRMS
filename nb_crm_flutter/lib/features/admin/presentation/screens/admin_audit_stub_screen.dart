import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/network/dio_client.dart';
import '../../../../core/router/app_back_button.dart';
import '../../../../core/tour/models/tour_models.dart';
import '../../../../core/tour/widgets/tour_target.dart';

class AdminAuditStubScreen extends StatefulWidget {
  const AdminAuditStubScreen({super.key});

  @override
  State<AdminAuditStubScreen> createState() => _AdminAuditStubScreenState();
}

class _AdminAuditStubScreenState extends State<AdminAuditStubScreen> {
  bool _loading = true;
  String? _error;

  List<Map<String, dynamic>> _employees = [];
  int? _selectedEmployeeId;

  List<Map<String, dynamic>> _logs = [];
  int _totalLogs = 0;
  String _searchQuery = '';
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    final dio = context.read<DioClient>();
    try {
      // Load employee list
      final empRes = await dio.getEnvelope<List<dynamic>>('admin/audit-logs/employees');
      final empList = (empRes ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList();

      // Load logs
      final queryParams = <String, dynamic>{
        'limit': 50,
        if (_selectedEmployeeId != null) 'employeeId': _selectedEmployeeId,
        if (_searchQuery.trim().isNotEmpty) 'search': _searchQuery.trim(),
      };

      final logsRes = await dio.getEnvelope<Map<String, dynamic>>('admin/audit-logs', queryParameters: queryParams);
      final logRows = (logsRes?['logs'] as List<dynamic>? ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      final pagination = logsRes?['pagination'] as Map<String, dynamic>?;

      if (mounted) {
        setState(() {
          _employees = empList;
          _logs = logRows;
          _totalLogs = (pagination?['total'] as num?)?.toInt() ?? logRows.length;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  Future<void> _fetchLogsOnly() async {
    setState(() => _loading = true);
    final dio = context.read<DioClient>();
    try {
      final queryParams = <String, dynamic>{
        'limit': 50,
        if (_selectedEmployeeId != null) 'employeeId': _selectedEmployeeId,
        if (_searchQuery.trim().isNotEmpty) 'search': _searchQuery.trim(),
      };

      final logsRes = await dio.getEnvelope<Map<String, dynamic>>('admin/audit-logs', queryParameters: queryParams);
      final logRows = (logsRes?['logs'] as List<dynamic>? ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      final pagination = logsRes?['pagination'] as Map<String, dynamic>?;

      if (mounted) {
        setState(() {
          _logs = logRows;
          _totalLogs = (pagination?['total'] as num?)?.toInt() ?? logRows.length;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  void _showLogDetails(Map<String, dynamic> log) {
    final target = log['targetEmployee'] as Map<String, dynamic>?;
    final theme = Theme.of(context);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: theme.scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.65,
        maxChildSize: 0.9,
        minChildSize: 0.4,
        expand: false,
        builder: (_, scrollController) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: ListView(
            controller: scrollController,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.bottom(16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade400,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Row(
                children: [
                  const Icon(Icons.shield_outlined, color: Colors.indigo, size: 22),
                  const SizedBox(width: 8),
                  Text(
                    'Audit Log Details',
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const Divider(height: 24),
              if (target != null) ...[
                Text(
                  'TARGET EMPLOYEE',
                  style: theme.textTheme.labelSmall?.copyWith(color: Colors.grey.shade600, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  target['fullName'] ?? 'Employee',
                  style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
                Text(
                  '${target['employeeCode'] ?? ''} • ${target['designation'] ?? 'Staff'}',
                  style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey.shade600),
                ),
                const SizedBox(height: 16),
              ],
              Text(
                'FIELD MODIFIED',
                style: theme.textTheme.labelSmall?.copyWith(color: Colors.grey.shade600, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                '${log['fieldLabel'] ?? log['fieldName']} (${log['tableLabel'] ?? log['tableName']})',
                style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        border: Border.all(color: Colors.red.shade200),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Previous', style: TextStyle(color: Colors.red.shade700, fontSize: 11, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Text(
                            log['oldValue']?.toString() ?? '(empty)',
                            style: TextStyle(color: Colors.red.shade900, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        border: Border.all(color: Colors.green.shade200),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Updated', style: TextStyle(color: Colors.green.shade700, fontSize: 11, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Text(
                            log['newValue']?.toString() ?? '(cleared)',
                            style: TextStyle(color: Colors.green.shade900, fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                'CHANGED BY',
                style: theme.textTheme.labelSmall?.copyWith(color: Colors.grey.shade600, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                '${log['changedByName'] ?? log['changedBy']} ${log['changedByRole'] != null ? '(${log['changedByRole']})' : ''}',
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 8),
              Text(
                'TIMESTAMP',
                style: theme.textTheme.labelSmall?.copyWith(color: Colors.grey.shade600, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                log['changedAt']?.toString() ?? '',
                style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey.shade700),
              ),
              if (log['changeReason'] != null) ...[
                const SizedBox(height: 8),
                Text(
                  'REASON',
                  style: theme.textTheme.labelSmall?.copyWith(color: Colors.grey.shade600, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  log['changeReason'].toString(),
                  style: theme.textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic),
                ),
              ],
              if (log['ipAddress'] != null) ...[
                const SizedBox(height: 8),
                Text(
                  'IP ADDRESS',
                  style: theme.textTheme.labelSmall?.copyWith(color: Colors.grey.shade600, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  log['ipAddress'].toString(),
                  style: theme.textTheme.bodySmall?.copyWith(fontFamily: 'monospace'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Workforce Audit Log'),
        leading: const AppBackButton(),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: TourTarget(
        id: TourIds.step('hrms.audit', 2),
        child: Column(
          children: [
            // Filter Header Container
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              color: theme.colorScheme.surface,
              child: Column(
                children: [
                  // Search Bar
                  TextField(
                    controller: _searchCtrl,
                    decoration: InputDecoration(
                      hintText: 'Search field, value, actor...',
                      prefixIcon: const Icon(Icons.search, size: 20),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 18),
                              onPressed: () {
                                _searchCtrl.clear();
                                setState(() => _searchQuery = '');
                                _fetchLogsOnly();
                              },
                            )
                          : null,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onSubmitted: (val) {
                      setState(() => _searchQuery = val);
                      _fetchLogsOnly();
                    },
                  ),
                  const SizedBox(height: 10),

                  // Employee Selector Horizontal Chips
                  SizedBox(
                    height: 36,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _employees.length + 1,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (ctx, index) {
                        if (index == 0) {
                          final isAll = _selectedEmployeeId == null;
                          return ChoiceChip(
                            label: Text('All Workforce ($_totalLogs)'),
                            selected: isAll,
                            onSelected: (_) {
                              setState(() => _selectedEmployeeId = null);
                              _fetchLogsOnly();
                            },
                          );
                        }
                        final emp = _employees[index - 1];
                        final empId = emp['employeeId'] as int;
                        final isSelected = _selectedEmployeeId == empId;
                        final changes = emp['totalChanges'] ?? 0;

                        return ChoiceChip(
                          label: Text('${emp['fullName'] ?? 'Emp #$empId'} ($changes)'),
                          selected: isSelected,
                          onSelected: (_) {
                            setState(() => _selectedEmployeeId = empId);
                            _fetchLogsOnly();
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),

            // Content List
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.error_outline, size: 48, color: Colors.red),
                                const SizedBox(height: 12),
                                Text(
                                  'Failed to load audit logs',
                                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 4),
                                Text(_error!, textAlign: TextAlign.center, style: theme.textTheme.bodySmall),
                                const SizedBox(height: 16),
                                ElevatedButton(onPressed: _loadData, child: const Text('Retry')),
                              ],
                            ),
                          ),
                        )
                      : _logs.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.history_edu_outlined, size: 48, color: Colors.grey.shade400),
                                  const SizedBox(height: 12),
                                  Text(
                                    'No audit entries found',
                                    style: theme.textTheme.titleMedium?.copyWith(color: Colors.grey.shade600),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Try selecting a different employee or clearing search.',
                                    style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey.shade500),
                                  ),
                                ],
                              ),
                            )
                          : RefreshIndicator(
                              onRefresh: _fetchLogsOnly,
                              child: ListView.separated(
                                padding: const EdgeInsets.all(12),
                                itemCount: _logs.length,
                                separatorBuilder: (_, __) => const SizedBox(height: 8),
                                itemBuilder: (ctx, idx) {
                                  final log = _logs[idx];
                                  final target = log['targetEmployee'] as Map<String, dynamic>?;
                                  final oldVal = log['oldValue']?.toString() ?? '';
                                  final newVal = log['newValue']?.toString() ?? '';

                                  return Card(
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      side: BorderSide(color: Colors.grey.shade300),
                                    ),
                                    child: InkWell(
                                      borderRadius: BorderRadius.circular(10),
                                      onTap: () => _showLogDetails(log),
                                      child: Padding(
                                        padding: const EdgeInsets.all(12),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Expanded(
                                                  child: Text(
                                                    target?['fullName'] ?? 'System / General',
                                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ),
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                  decoration: BoxDecoration(
                                                    color: Colors.indigo.shade50,
                                                    borderRadius: BorderRadius.circular(4),
                                                  ),
                                                  child: Text(
                                                    log['tableLabel'] ?? log['tableName'] ?? '',
                                                    style: TextStyle(color: Colors.indigo.shade700, fontSize: 10, fontWeight: FontWeight.bold),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              log['fieldLabel'] ?? log['fieldName'] ?? '',
                                              style: TextStyle(color: Colors.grey.shade800, fontSize: 12, fontWeight: FontWeight.w600),
                                            ),
                                            const SizedBox(height: 6),
                                            Row(
                                              children: [
                                                Expanded(
                                                  child: Text(
                                                    oldVal.isEmpty ? '(none)' : oldVal,
                                                    style: TextStyle(color: Colors.red.shade700, fontSize: 11, decoration: TextDecoration.lineThrough),
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ),
                                                const Icon(Icons.arrow_forward, size: 14, color: Colors.grey),
                                                const SizedBox(width: 4),
                                                Expanded(
                                                  child: Text(
                                                    newVal.isEmpty ? '(cleared)' : newVal,
                                                    style: TextStyle(color: Colors.green.shade800, fontSize: 11, fontWeight: FontWeight.bold),
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const Divider(height: 16),
                                            Row(
                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                              children: [
                                                Text(
                                                  'By: ${log['changedByName'] ?? log['changedBy']}',
                                                  style: TextStyle(color: Colors.grey.shade600, fontSize: 11),
                                                ),
                                                Text(
                                                  log['changedAt']?.toString().substring(0, 10) ?? '',
                                                  style: TextStyle(color: Colors.grey.shade500, fontSize: 10, fontFamily: 'monospace'),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
            ),
          ],
        ),
      ),
    );
  }
}
