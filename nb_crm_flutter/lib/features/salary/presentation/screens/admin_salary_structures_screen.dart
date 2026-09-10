import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_back_button.dart';
import '../../../../core/widgets/bloc_async_body.dart';
import '../../data/salary_repository.dart';
import '../../domain/salary_models.dart';
import '../bloc/salary_bloc.dart';

class AdminSalaryStructuresScreen extends StatelessWidget {
  const AdminSalaryStructuresScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<SalaryBloc>(
      create: (ctx) => SalaryBloc(
        salaryRepository: ctx.read<SalaryRepository>(),
      )..add(const SalaryLoadRequested()),
      child: const _AdminSalaryStructuresView(),
    );
  }
}

class _AdminSalaryStructuresView extends StatelessWidget {
  const _AdminSalaryStructuresView();

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<SalaryBloc>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF1A1816) : Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          'Salary Structures',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 20,
            color: isDark ? Colors.white : const Color(0xFF212F3D),
            letterSpacing: -0.5,
          ),
        ),
        leading: const AppBackButton(fallbackLocation: '/admin/salary/records'),
        actions: [
          TextButton.icon(
            onPressed: () => context.go('/admin/salary/commissions'),
            style: TextButton.styleFrom(
              foregroundColor: isDark ? const Color(0xFFE2D6BE) : const Color(0xFF263238),
              textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
            ),
            icon: const Icon(Icons.layers_outlined, size: 14, color: Color(0xFFC5A059)),
            label: const Text('Commissions'),
          ),
          TextButton.icon(
            onPressed: () => context.go('/admin/salary/entry'),
            style: TextButton.styleFrom(
              foregroundColor: isDark ? const Color(0xFFE2D6BE) : const Color(0xFF263238),
              textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
            ),
            icon: const Icon(Icons.edit_document, size: 14, color: Color(0xFFC5A059)),
            label: const Text('Entry'),
          ),
          const SizedBox(width: 12),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.5),
          child: Container(
            color: isDark ? const Color(0xFFC5A059).withValues(alpha: 0.15) : const Color(0xFFCFD8DC),
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
        child: BlocBuilder<SalaryBloc, SalaryState>(
          builder: (context, state) {
            return BlocAsyncBody<List<SalaryStructureStatus>>(
              status: state.status,
              data: state.structureStatuses,
              emptyMessage: 'No designations found.',
              errorMessage: state.errorMessage,
              onRetry: () => bloc.add(const SalaryRefreshRequested()),
              builder: (rows) => ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                itemCount: rows.length,
                itemBuilder: (ctx, i) {
                  final row = rows[i];
                  return Card(
                    elevation: 0,
                    margin: const EdgeInsets.only(bottom: 16),
                    color: isDark ? const Color(0xFF1E1B18) : Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(
                        color: isDark ? const Color(0xFFC5A059).withValues(alpha: 0.15) : const Color(0xFFCFD8DC),
                        width: 1.5,
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            row.designation.name,
                            style: TextStyle(
                              fontWeight: FontWeight.w800, 
                              fontSize: 16,
                              color: isDark ? Colors.white : const Color(0xFF212F3D),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            children: row.commissions
                                .map((c) => _buildStatusChip(context, c))
                                .toList(),
                          ),
                          const SizedBox(height: 18),
                          Wrap(
                            spacing: 12,
                            runSpacing: 10,
                            children: row.commissions
                                .map(
                                  (c) => SizedBox(
                                    height: 36,
                                    child: OutlinedButton.icon(
                                      onPressed: () => _goConfigure(context, bloc, row, c),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: isDark ? const Color(0xFFE2D6BE) : const Color(0xFF263238),
                                        side: BorderSide(
                                          color: isDark ? const Color(0xFFC5A059).withValues(alpha: 0.4) : const Color(0xFFCFD8DC),
                                          width: 1.2,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        padding: const EdgeInsets.symmetric(horizontal: 14),
                                      ),
                                      icon: const Icon(Icons.settings_outlined, size: 14, color: Color(0xFFC5A059)),
                                      label: Text(
                                        'Configure ${c.payCommission.name}', 
                                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 11),
                                      ),
                                    ),
                                  ),
                                )
                                .toList(),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildStatusChip(BuildContext context, SalaryStructureCommissionStatus c) {
    final color = c.configured ? Colors.green : Colors.orange;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        border: Border.all(color: color, width: 1.2),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            c.configured ? Icons.check_circle_rounded : Icons.warning_amber_rounded,
            size: 12,
            color: color,
          ),
          const SizedBox(width: 6),
          Text(
            '${c.payCommission.name}: ${c.configured ? 'Configured' : 'Not Configured'}',
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _goConfigure(
    BuildContext context,
    SalaryBloc bloc,
    SalaryStructureStatus row,
    SalaryStructureCommissionStatus commission,
  ) async {
    var templateId = commission.templateId;
    if (templateId == null) {
      final repo = context.read<SalaryRepository>();
      final created = await repo.createTemplate(
        designationId: row.designation.id,
        payCommissionCode: commission.payCommission.code,
      );
      templateId = created.id;
      bloc.add(const SalaryRefreshRequested());
    }
    if (!context.mounted) return;
    context.go(
      '/admin/salary/structures/${row.designation.id}/${commission.payCommission.code.toLowerCase()}?templateId=$templateId',
    );
  }
}
