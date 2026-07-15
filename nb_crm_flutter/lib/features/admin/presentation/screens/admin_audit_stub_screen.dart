import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';

/// Audit logs were GraphQL-only in the Next.js app; `/admin/audit` was a nav orphan.
class AdminAuditStubScreen extends StatelessWidget {
  const AdminAuditStubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.sand,
      appBar: AppBar(
        title: const Text('Audit log'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/home'),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: const Card(
            margin: EdgeInsets.all(24),
            child: Padding(
              padding: EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.history_edu_outlined, size: 48, color: AppColors.bronze),
                  SizedBox(height: 16),
                  Text(
                    'Audit API unavailable',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.midnight,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'The legacy audit drawer used GraphQL only. '
                    'There is no REST audit page on the web app either. '
                    'This stub keeps the destination discoverable until a REST endpoint ships.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
