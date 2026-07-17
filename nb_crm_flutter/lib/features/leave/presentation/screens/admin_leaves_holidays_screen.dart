import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../domain/leave_models.dart';
import '../leave_providers.dart';
import '../widgets/leave_shared_widgets.dart';

class AdminLeavesHolidaysScreen extends ConsumerWidget {
  const AdminLeavesHolidaysScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final year = ref.watch(holidaysYearFilterProvider);
    final holidaysAsync = ref.watch(adminHolidaysProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF1A1816) : Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          'Public Holidays',
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
          onPressed: () => context.go('/admin/leaves'),
        ),
        actions: [
          IconButton(
            tooltip: 'Add holiday',
            icon: const Icon(Icons.add_rounded, color: Color(0xFFC5A059)),
            onPressed: () => _showAddDialog(context, ref, year, isDark),
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
            child: Opacity(opacity: value, child: child),
          );
        },
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E1B18) : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark ? const Color(0xFFC5A059).withOpacity(0.15) : const Color(0xFFCFD8DC),
                  width: 1.5,
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.calendar_month_rounded, color: const Color(0xFFC5A059), size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Year',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : const Color(0xFF212F3D),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<int>(
                        value: year,
                        dropdownColor: isDark ? const Color(0xFF2B2722) : Colors.white,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : const Color(0xFF212F3D),
                        ),
                        icon: const Icon(Icons.expand_more_rounded, color: Color(0xFFC5A059)),
                        isExpanded: true,
                        items: List.generate(5, (i) {
                          final y = DateTime.now().year - 1 + i;
                          return DropdownMenuItem(value: y, child: Text('$y'));
                        }),
                        onChanged: (v) {
                          if (v != null) {
                            ref.read(holidaysYearFilterProvider.notifier).set(v);
                          }
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: holidaysAsync.when(
                loading: () => const Center(
                  child: CircularProgressIndicator(color: Color(0xFFC5A059)),
                ),
                error: (e, _) => Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('$e', style: TextStyle(color: Colors.red)),
                      const SizedBox(height: 12),
                      FilledButton(
                        onPressed: () => ref.invalidate(adminHolidaysProvider),
                        style: FilledButton.styleFrom(
                          backgroundColor: isDark ? const Color(0xFFC5A059) : const Color(0xFF263238),
                        ),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
                data: (holidays) {
                  if (holidays.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(40),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.event_busy_rounded, size: 64, color: isDark ? Colors.white10 : Colors.black12),
                            const SizedBox(height: 16),
                            Text(
                              'No holidays for $year.',
                              style: TextStyle(
                                color: isDark ? Colors.white30 : const Color(0xFF607D8B).withOpacity(0.6),
                                fontWeight: FontWeight.w600,
                                fontSize: 15,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }
                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: holidays.length,
                    itemBuilder: (ctx, i) => _HolidayTile(holiday: holidays[i], isDark: isDark),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _styledInput(String label, bool isDark) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(fontWeight: FontWeight.w600),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
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
    );
  }

  Future<void> _showAddDialog(
    BuildContext context,
    WidgetRef ref,
    int year,
    bool isDark,
  ) async {
    final nameController = TextEditingController();
    DateTime? date;
    var isOptional = false;

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          backgroundColor: isDark ? const Color(0xFF1E1B18) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            'Add holiday',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white : const Color(0xFF212F3D),
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: _styledInput('Name', isDark),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    side: BorderSide(
                      color: isDark ? const Color(0xFFC5A059).withOpacity(0.15) : const Color(0xFFCFD8DC),
                    ),
                  ),
                  onPressed: () async {
                    final d = await showDatePicker(
                      context: ctx,
                      initialDate: DateTime(year, 1, 1),
                      firstDate: DateTime(year - 1),
                      lastDate: DateTime(year + 2),
                    );
                    if (d != null) setLocal(() => date = d);
                  },
                  child: Text(
                    date == null ? 'Pick date' : formatDateYmd(date!),
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : const Color(0xFF212F3D),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Container(
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF2B2722) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isDark ? const Color(0xFFC5A059).withOpacity(0.1) : const Color(0xFFCFD8DC),
                  ),
                ),
                child: SwitchListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                  title: Text(
                    'Optional holiday',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: isDark ? Colors.white : const Color(0xFF212F3D),
                    ),
                  ),
                  value: isOptional,
                  activeColor: const Color(0xFFC5A059),
                  onChanged: (v) => setLocal(() => isOptional = v),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Cancel', style: TextStyle(color: isDark ? Colors.white70 : const Color(0xFF607D8B))),
            ),
            FilledButton(
              onPressed: () async {
                if (nameController.text.trim().isEmpty || date == null) return;
                try {
                  await ref.read(leaveRepositoryProvider).addAdminHoliday({
                    'name': nameController.text.trim(),
                    'date': formatDateYmd(date!),
                    'year': date!.year,
                    'isOptional': isOptional,
                  });
                  invalidateLeaveAdminData(ref);
                  if (ctx.mounted) Navigator.pop(ctx);
                } catch (e) {
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('$e')));
                  }
                }
              },
              style: FilledButton.styleFrom(
                backgroundColor: isDark ? const Color(0xFFC5A059) : const Color(0xFF263238),
                foregroundColor: isDark ? const Color(0xFF1A1816) : Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('Add', style: TextStyle(fontWeight: FontWeight.w800)),
            ),
          ],
        ),
      ),
    );
    nameController.dispose();
  }
}

class _HolidayTile extends ConsumerWidget {
  const _HolidayTile({required this.holiday, required this.isDark});

  final PublicHoliday holiday;
  final bool isDark;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 10),
      color: isDark ? const Color(0xFF1E1B18) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: isDark ? const Color(0xFFC5A059).withOpacity(0.15) : const Color(0xFFCFD8DC),
          width: 1.5,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF2B2722) : const Color(0xFFF1F5F9),
                shape: BoxShape.circle,
                border: Border.all(
                  color: isDark ? const Color(0xFFC5A059).withOpacity(0.1) : const Color(0xFFCFD8DC),
                ),
              ),
              child: const Icon(Icons.event_available_rounded, color: Color(0xFFC5A059), size: 20),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    holiday.name,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: isDark ? Colors.white : const Color(0xFF212F3D),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        holiday.date,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white54 : const Color(0xFF607D8B),
                        ),
                      ),
                      if (holiday.isOptional) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.orange.withOpacity(0.1),
                            border: Border.all(color: Colors.orange, width: 1),
                            borderRadius: BorderRadius.circular(30),
                          ),
                          child: const Text(
                            'OPTIONAL',
                            style: TextStyle(
                              fontSize: 8,
                              fontWeight: FontWeight.w800,
                              color: Colors.orange,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded),
              color: isDark ? Colors.white38 : const Color(0xFF607D8B),
              onPressed: () async {
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    backgroundColor: isDark ? const Color(0xFF1E1B18) : Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    title: Text(
                      'Delete holiday?',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : const Color(0xFF212F3D),
                      ),
                    ),
                    content: Text(
                      'Remove ${holiday.name}?',
                      style: TextStyle(color: isDark ? Colors.white70 : const Color(0xFF607D8B)),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: Text('Cancel', style: TextStyle(color: isDark ? Colors.white70 : const Color(0xFF607D8B))),
                      ),
                      FilledButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        child: const Text('Delete', style: TextStyle(fontWeight: FontWeight.w800)),
                      ),
                    ],
                  ),
                );
                if (ok != true) return;
                try {
                  await ref.read(leaveRepositoryProvider).deleteAdminHoliday(holiday.id);
                  invalidateLeaveAdminData(ref);
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
                  }
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}
