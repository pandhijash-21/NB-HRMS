import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/widgets/header_action_button.dart';
import '../../domain/salary_models.dart';
import '../salary_providers.dart';
import '../widgets/salary_shared_widgets.dart';

class AdminSalaryRecordsScreen extends ConsumerWidget {
  const AdminSalaryRecordsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filters = ref.watch(salaryRecordsFilterProvider);
    final recordsAsync = ref.watch(salaryRecordsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF1A1816) : Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          'Payroll Records',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 20,
            color: isDark ? Colors.white : const Color(0xFF212F3D),
            letterSpacing: -0.5,
          ),
        ),
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_rounded,
            color: isDark ? Colors.white.withOpacity(0.8) : const Color(0xFF212F3D),
          ),
          onPressed: () => context.go('/home'),
        ),
        actions: [
          HeaderActionButton(
            tooltip: 'Salary Entry',
            label: 'Salary Entry',
            icon: Icon(
              Icons.edit_document,
              size: 18,
              color: isDark ? const Color(0xFFC5A059) : const Color(0xFF263238),
            ),
            onPressed: () => context.go('/admin/salary/entry'),
          ),
          HeaderActionButton(
            tooltip: 'Salary Structures',
            label: 'Structures',
            icon: Icon(
              Icons.account_tree_outlined,
              size: 18,
              color: isDark ? const Color(0xFFC5A059) : const Color(0xFF263238),
            ),
            onPressed: () => context.go('/admin/salary/structures'),
          ),
          HeaderActionButton(
            tooltip: 'Commissions Config',
            label: 'Commissions',
            icon: Icon(
              Icons.layers_outlined,
              size: 18,
              color: isDark ? const Color(0xFFC5A059) : const Color(0xFF263238),
            ),
            onPressed: () => context.go('/admin/salary/commissions'),
          ),
          const SizedBox(width: 8),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.5),
          child: Container(
            color: isDark ? const Color(0xFFC5A059).withOpacity(0.15) : const Color(0xFFCFD8DC),
            height: 1.5,
          ),
        ),
      ),
      body: TweenAnimationBuilder<double>(
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeOutCubic,
        tween: Tween(begin: 0.0, end: 1.0),
        builder: (context, value, child) {
          return Transform.translate(
            offset: Offset(0.0, 30.0 * (1.0 - value)),
            child: Opacity(
              opacity: value,
              child: child,
            ),
          );
        },
        child: Column(
          children: [
            _buildFilterBar(context, ref, filters),
            Expanded(
              child: SalaryAsyncBody<List<SalaryRecord>>(
                value: recordsAsync,
                emptyMessage: 'No salary records found.',
                onRetry: () => ref.invalidate(salaryRecordsProvider),
                builder: (records) => ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                  itemCount: records.length,
                  itemBuilder: (ctx, i) {
                    final r = records[i];
                    return _buildRecordCard(context, r);
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterBar(
    BuildContext context, 
    WidgetRef ref, 
    SalaryRecordsFilter filters
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1B18) : Colors.white,
        border: Border(
          bottom: BorderSide(
            color: isDark ? const Color(0xFFC5A059).withOpacity(0.12) : const Color(0xFFCFD8DC),
            width: 1.5,
          ),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Row(
          children: [
            SizedBox(
              width: 130,
              height: 44,
              child: TextField(
                decoration: InputDecoration(
                  labelText: 'Employee ID',
                  labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  prefixIcon: const Icon(Icons.person_search_rounded, size: 16, color: Color(0xFFC5A059)),
                  filled: true,
                  fillColor: isDark ? const Color(0xFF121212) : const Color(0xFFF8FAFC),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(
                      color: isDark ? const Color(0xFFC5A059).withOpacity(0.2) : const Color(0xFFCFD8DC),
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(
                      color: isDark ? const Color(0xFFC5A059).withOpacity(0.15) : const Color(0xFFCFD8DC),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xFFC5A059), width: 1.5),
                  ),
                  contentPadding: EdgeInsets.zero,
                ),
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                keyboardType: TextInputType.number,
                onChanged: (v) => ref
                    .read(salaryRecordsFilterProvider.notifier)
                    .setEmployeeId(int.tryParse(v)),
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: 100,
              height: 44,
              child: TextField(
                decoration: InputDecoration(
                  labelText: 'Month',
                  labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  prefixIcon: const Icon(Icons.calendar_month_rounded, size: 16, color: Color(0xFFC5A059)),
                  filled: true,
                  fillColor: isDark ? const Color(0xFF121212) : const Color(0xFFF8FAFC),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(
                      color: isDark ? const Color(0xFFC5A059).withOpacity(0.2) : const Color(0xFFCFD8DC),
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(
                      color: isDark ? const Color(0xFFC5A059).withOpacity(0.15) : const Color(0xFFCFD8DC),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xFFC5A059), width: 1.5),
                  ),
                  contentPadding: EdgeInsets.zero,
                ),
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                keyboardType: TextInputType.number,
                onChanged: (v) => ref
                    .read(salaryRecordsFilterProvider.notifier)
                    .setMonth(int.tryParse(v)),
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: 110,
              height: 44,
              child: TextField(
                decoration: InputDecoration(
                  labelText: 'Year',
                  labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  prefixIcon: const Icon(Icons.date_range_rounded, size: 16, color: Color(0xFFC5A059)),
                  filled: true,
                  fillColor: isDark ? const Color(0xFF121212) : const Color(0xFFF8FAFC),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(
                      color: isDark ? const Color(0xFFC5A059).withOpacity(0.2) : const Color(0xFFCFD8DC),
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(
                      color: isDark ? const Color(0xFFC5A059).withOpacity(0.15) : const Color(0xFFCFD8DC),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xFFC5A059), width: 1.5),
                  ),
                  contentPadding: EdgeInsets.zero,
                ),
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                keyboardType: TextInputType.number,
                onChanged: (v) => ref
                    .read(salaryRecordsFilterProvider.notifier)
                    .setYear(int.tryParse(v)),
              ),
            ),
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 1),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF121212) : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isDark ? const Color(0xFFC5A059).withOpacity(0.15) : const Color(0xFFCFD8DC),
                  width: 1.2,
                ),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: filters.status.isEmpty ? '' : filters.status,
                  dropdownColor: isDark ? const Color(0xFF1E1B18) : Colors.white,
                  style: TextStyle(
                    color: isDark ? Colors.white : const Color(0xFF212F3D), 
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                  icon: const Icon(Icons.arrow_drop_down_rounded, color: Color(0xFFC5A059)),
                  items: const [
                    DropdownMenuItem(value: '', child: Text('All statuses')),
                    DropdownMenuItem(value: 'DRAFT', child: Text('Draft')),
                    DropdownMenuItem(value: 'FINALIZED', child: Text('Finalized')),
                  ],
                  onChanged: (v) => ref
                      .read(salaryRecordsFilterProvider.notifier)
                      .setStatus(v ?? ''),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecordCard(BuildContext context, SalaryRecord r) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fullName = r.employee?.fullName ?? 'Employee';
    final initials = fullName.split(' ').map((e) => e.isNotEmpty ? e[0] : '').join('');
    final displayInitials = initials.isNotEmpty ? initials : '?';
    final designation = r.template?.designation?.name ?? 'No Designation';

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      color: isDark ? const Color(0xFF1E1B18) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isDark ? const Color(0xFFC5A059).withOpacity(0.15) : const Color(0xFFCFD8DC),
          width: 1.5,
        ),
      ),
      child: InkWell(
        onTap: () => context.go('/admin/salary/records/${r.id}/slip'),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isDark ? const Color(0xFFC5A059).withOpacity(0.2) : const Color(0xFF263238).withOpacity(0.15),
                    width: 1.5,
                  ),
                ),
                child: CircleAvatar(
                  radius: 24,
                  backgroundColor: isDark ? const Color(0xFF2B2722) : const Color(0xFFECEFF1),
                  child: Text(
                    displayInitials.length > 2 ? displayInitials.substring(0, 2).toUpperCase() : displayInitials.toUpperCase(),
                    style: TextStyle(
                      color: isDark ? const Color(0xFFE2D6BE) : const Color(0xFF263238), 
                      fontWeight: FontWeight.bold, 
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      r.employee?.fullName ?? 'Employee #${r.employeeId}',
                      style: TextStyle(
                        fontWeight: FontWeight.w800, 
                        fontSize: 15, 
                        color: isDark ? Colors.white : const Color(0xFF212F3D),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$designation  ·  ${r.payCommissionCode}  ·  Month: ${r.salaryMonth}/${r.salaryYear}',
                      style: TextStyle(
                        fontSize: 11, 
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white54 : const Color(0xFF607D8B),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.blue.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: Colors.blue.withOpacity(0.2)),
                          ),
                          child: Text(
                            'Gross: ${formatInr(r.grossPay)}',
                            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.blue),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF2B2722) : const Color(0xFFF0F4F8),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: isDark ? const Color(0xFFC5A059).withOpacity(0.2) : const Color(0xFF263238).withOpacity(0.15),
                            ),
                          ),
                          child: Text(
                            'Net Pay: ${formatInr(r.netPay)}',
                            style: TextStyle(
                              fontSize: 10, 
                              fontWeight: FontWeight.w800, 
                              color: isDark ? const Color(0xFFE2D6BE) : const Color(0xFF263238),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  salaryStatusChip(context, salaryRecordStatusApi(r.status)),
                  const SizedBox(height: 12),
                  const Icon(Icons.chevron_right_rounded, color: Colors.grey, size: 20),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
