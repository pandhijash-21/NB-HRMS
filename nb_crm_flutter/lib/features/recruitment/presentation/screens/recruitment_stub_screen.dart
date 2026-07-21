import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';

/// Stub — full Recruitment/Vacancy feature comes later.
/// Employees: read-only empty state. Admins: same stub for now (edit later).
class RecruitmentStubScreen extends StatelessWidget {
  const RecruitmentStubScreen({super.key, this.isAdmin = false});

  final bool isAdmin;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Recruitment / Vacancy'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/home'),
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.work_outline, size: 56, color: AppColors.bronze.withOpacity(0.7)),
              const SizedBox(height: 16),
              const Text(
                'No vacancies right now',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                isAdmin
                    ? 'Recruitment management will be available here soon. Employees will only see posted vacancies (read-only).'
                    : 'When openings are posted by HR, they will appear here.',
                style: TextStyle(color: AppColors.textSecondary),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
