// RBAC Permissions logic ported from Next.js `frontend/lib/auth/permissions.ts`.
typedef PermissionMap = Map<String, List<String>>;

class Permissions {
  Permissions._();

  static bool hasPermission(
    PermissionMap? perms,
    String module,
    String action,
  ) {
    if (perms == null) return false;
    return perms[module]?.contains(action) ?? false;
  }

  static bool canViewOwnWorkforce(
    PermissionMap? perms,
    String? employeeViewScope,
  ) {
    return employeeViewScope == 'SELF' && hasPermission(perms, 'PERSONAL_INFO', 'READ');
  }

  static bool canViewWorkforce(
    PermissionMap? perms,
    String? employeeViewScope,
  ) {
    return employeeViewScope == 'INSTITUTE' || employeeViewScope == 'UNIVERSITY';
  }

  static bool canEditOwnWorkforce(
    PermissionMap? perms,
    String? employeeViewScope,
  ) {
    return canViewOwnWorkforce(perms, employeeViewScope) &&
        hasPermission(perms, 'PERSONAL_INFO', 'WRITE');
  }

  static bool canEditWorkforce(
    PermissionMap? perms,
    String? employeeViewScope,
  ) {
    return canViewWorkforce(perms, employeeViewScope) &&
        hasPermission(perms, 'PERSONAL_INFO', 'WRITE');
  }

  /// Can open the admin portal (management modules - not employee self-service).
  static bool canAccessAdminPortal(
    PermissionMap? perms,
    String? employeeViewScope,
  ) {
    if (canViewWorkforce(perms, employeeViewScope)) return true;
    if (perms == null || perms.isEmpty) return false;

    final hasManagementModule = hasPermission(perms, 'USER_MGMT', 'READ') ||
        hasPermission(perms, 'ROLE_MGMT', 'READ') ||
        hasPermission(perms, 'SALARY', 'READ') ||
        hasPermission(perms, 'PAYROLL', 'READ') ||
        hasPermission(perms, 'REPORTS', 'READ') ||
        hasPermission(perms, 'FIELD_MGMT', 'READ') ||
        hasPermission(perms, 'LEAVE', 'APPROVE');

    if (hasManagementModule) return true;

    // Self-service employees (Staff): personal/leave/attendance access uses the employee portal
    if (employeeViewScope == 'SELF' || employeeViewScope == 'NONE') {
      return false;
    }

    return hasPermission(perms, 'ATTENDANCE', 'READ') ||
        hasPermission(perms, 'LEAVE', 'WRITE') ||
        hasPermission(perms, 'PERSONAL_INFO', 'WRITE');
  }

  static bool canApproveLeave(PermissionMap? perms) {
    return hasPermission(perms, 'LEAVE', 'APPROVE');
  }

  static bool canManageUsers(PermissionMap? perms, [String? role]) {
    if (role != null && role.toUpperCase() == 'ADMIN') return true;
    return hasPermission(perms, 'USER_MGMT', 'READ');
  }

  static bool canManageRoles(PermissionMap? perms, [String? role]) {
    if (role != null && role.toUpperCase() == 'ADMIN') return true;
    return hasPermission(perms, 'ROLE_MGMT', 'READ');
  }

  static bool canManageInstitutes(PermissionMap? perms, [String? role]) {
    if (role != null && role.toUpperCase() == 'ADMIN') return true;
    return hasPermission(perms, 'FIELD_MGMT', 'READ');
  }

  static bool canReadLeave(PermissionMap? perms) {
    return hasPermission(perms, 'LEAVE', 'READ');
  }

  static bool canWriteLeave(PermissionMap? perms) {
    return hasPermission(perms, 'LEAVE', 'WRITE');
  }

  static bool canAdminLeave(
    PermissionMap? perms,
    String role,
    String? employeeViewScope,
  ) {
    if (!hasPermission(perms, 'LEAVE', 'WRITE')) return false;
    final adminRole =
        const ['ADMIN', 'HR', 'HR_MANAGER'].contains(role.toUpperCase());
    if (adminRole) return true;
    return canAccessAdminPortal(perms, employeeViewScope) &&
        hasPermission(perms, 'LEAVE', 'WRITE');
  }

  static bool canReadAttendance(PermissionMap? perms) {
    return hasPermission(perms, 'ATTENDANCE', 'READ');
  }

  static bool canWriteAttendance(PermissionMap? perms) {
    return hasPermission(perms, 'ATTENDANCE', 'WRITE');
  }

  static bool canAdminAttendance(PermissionMap? perms, String role) {
    return canReadAttendance(perms) &&
        const ['ADMIN', 'HR', 'HR_MANAGER'].contains(role.toUpperCase());
  }

  static bool canReadSalary(PermissionMap? perms) {
    return hasPermission(perms, 'SALARY', 'READ') ||
        hasPermission(perms, 'PAYROLL', 'READ');
  }

  static bool canWriteSalary(PermissionMap? perms) {
    return hasPermission(perms, 'SALARY', 'WRITE') ||
        hasPermission(perms, 'PAYROLL', 'WRITE');
  }

  static String resolvePostLoginPath(
    PermissionMap? perms,
    String role,
    String? employeeViewScope,
  ) {
    if (canAccessAdminPortal(perms, employeeViewScope)) return '/admin/dashboard';
    if (canApproveLeave(perms)) return '/approvals';
    if (canViewOwnWorkforce(perms, employeeViewScope)) return '/profile';

    if (const ['HOD', 'HOI', 'REGISTRAR', 'VC', 'HR', 'HR_MANAGER'].contains(role)) {
      return '/approvals';
    }
    return '/home'; // Flutter fallback instead of /dashboard since dashboard links here/home.
  }
}
