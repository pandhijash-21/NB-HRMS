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

  static bool isAdmin(String? role) {
    final r = (role ?? '').toUpperCase().replaceAll(RegExp(r'\s+'), '');
    return r == 'ADMIN' || r == 'SUPERADMIN' || r == 'SYSTEMADMIN';
  }

  static bool canReadProjects(PermissionMap? perms, [String? role]) {
    if (isAdmin(role)) return true;
    return hasPermission(perms, 'PROJECTS', 'READ');
  }

  static bool canWriteProjects(PermissionMap? perms, [String? role]) {
    if (isAdmin(role)) return true;
    return hasPermission(perms, 'PROJECTS', 'WRITE');
  }

  static bool canReadWorkOrders(PermissionMap? perms, [String? role]) {
    if (isAdmin(role)) return true;
    return hasPermission(perms, 'WORK_ORDERS', 'READ');
  }

  static bool canWriteWorkOrders(PermissionMap? perms, [String? role]) {
    if (isAdmin(role)) return true;
    return hasPermission(perms, 'WORK_ORDERS', 'WRITE');
  }

  static bool canApproveWorkOrders(PermissionMap? perms, [String? role]) {
    if (isAdmin(role)) return true;
    return hasPermission(perms, 'WORK_ORDERS', 'APPROVE');
  }

  static bool canReadBank(PermissionMap? perms, [String? role]) {
    if (isAdmin(role)) return true;
    return hasPermission(perms, 'BANK_DETAILS', 'READ');
  }

  static bool canWriteBank(PermissionMap? perms, [String? role]) {
    if (isAdmin(role)) return true;
    return hasPermission(perms, 'BANK_DETAILS', 'WRITE');
  }

  static bool canReadEducation(PermissionMap? perms, [String? role]) {
    if (isAdmin(role)) return true;
    return hasPermission(perms, 'EDUCATION', 'READ');
  }

  static bool canWriteEducation(PermissionMap? perms, [String? role]) {
    if (isAdmin(role)) return true;
    return hasPermission(perms, 'EDUCATION', 'WRITE');
  }

  static bool canReadExperience(PermissionMap? perms, [String? role]) {
    if (isAdmin(role)) return true;
    return hasPermission(perms, 'EXPERIENCE', 'READ');
  }

  static bool canWriteExperience(PermissionMap? perms, [String? role]) {
    if (isAdmin(role)) return true;
    return hasPermission(perms, 'EXPERIENCE', 'WRITE');
  }

  static bool canReadDpr(PermissionMap? perms, [String? role]) {
    if (isAdmin(role)) return true;
    if (perms?.containsKey('DPR') == true) return hasPermission(perms, 'DPR', 'READ');
    return hasPermission(perms, 'WORK_ORDERS', 'READ');
  }

  static bool canWriteDpr(PermissionMap? perms, [String? role]) {
    if (isAdmin(role)) return true;
    if (perms?.containsKey('DPR') == true) return hasPermission(perms, 'DPR', 'WRITE');
    return hasPermission(perms, 'WORK_ORDERS', 'WRITE');
  }

  static bool canReadStore(PermissionMap? perms, [String? role]) {
    if (isAdmin(role)) return true;
    if (perms?.containsKey('STORE') == true) return hasPermission(perms, 'STORE', 'READ');
    return hasPermission(perms, 'WORK_ORDERS', 'READ');
  }

  static bool canWriteStore(PermissionMap? perms, [String? role]) {
    if (isAdmin(role)) return true;
    if (perms?.containsKey('STORE') == true) return hasPermission(perms, 'STORE', 'WRITE');
    return hasPermission(perms, 'WORK_ORDERS', 'WRITE');
  }

  static bool canReadBoq(PermissionMap? perms, [String? role]) {
    if (isAdmin(role)) return true;
    if (perms?.containsKey('BOQ') == true) return hasPermission(perms, 'BOQ', 'READ');
    return hasPermission(perms, 'WORK_ORDERS', 'READ');
  }

  static bool canWriteBoq(PermissionMap? perms, [String? role]) {
    if (isAdmin(role)) return true;
    if (perms?.containsKey('BOQ') == true) return hasPermission(perms, 'BOQ', 'WRITE');
    return hasPermission(perms, 'WORK_ORDERS', 'WRITE');
  }

  static bool canReadTenders(PermissionMap? perms, [String? role]) {
    if (isAdmin(role)) return true;
    if (perms?.containsKey('TENDERS') == true) return hasPermission(perms, 'TENDERS', 'READ');
    return hasPermission(perms, 'WORK_ORDERS', 'READ');
  }

  static bool canWriteTenders(PermissionMap? perms, [String? role]) {
    if (isAdmin(role)) return true;
    if (perms?.containsKey('TENDERS') == true) return hasPermission(perms, 'TENDERS', 'WRITE');
    return hasPermission(perms, 'WORK_ORDERS', 'WRITE');
  }

  static bool canReadContractors(PermissionMap? perms, [String? role]) {
    if (isAdmin(role)) return true;
    if (perms?.containsKey('CONTRACTORS') == true) return hasPermission(perms, 'CONTRACTORS', 'READ');
    return hasPermission(perms, 'WORK_ORDERS', 'READ');
  }

  static bool canWriteContractors(PermissionMap? perms, [String? role]) {
    if (isAdmin(role)) return true;
    if (perms?.containsKey('CONTRACTORS') == true) return hasPermission(perms, 'CONTRACTORS', 'WRITE');
    return hasPermission(perms, 'WORK_ORDERS', 'WRITE');
  }

  static bool canReadCrm(PermissionMap? perms, [String? role]) {
    if (isAdmin(role)) return true;
    return hasPermission(perms, 'CRM', 'READ');
  }

  static bool canWriteCrm(PermissionMap? perms, [String? role]) {
    if (isAdmin(role)) return true;
    return hasPermission(perms, 'CRM', 'WRITE');
  }

  static bool canReadCrmDashboard(PermissionMap? perms, [String? role]) {
    if (isAdmin(role)) return true;
    if (perms?.containsKey('CRM_DASHBOARD') == true) return hasPermission(perms, 'CRM_DASHBOARD', 'READ');
    return hasPermission(perms, 'CRM', 'READ');
  }

  static bool canReadCrmHeaders(PermissionMap? perms, [String? role]) {
    if (isAdmin(role)) return true;
    if (perms?.containsKey('CRM_HEADERS') == true) return hasPermission(perms, 'CRM_HEADERS', 'READ');
    return hasPermission(perms, 'CRM', 'READ');
  }

  static bool canReadCrmSettings(PermissionMap? perms, [String? role]) {
    if (isAdmin(role)) return true;
    if (perms?.containsKey('CRM_SETTINGS') == true) return hasPermission(perms, 'CRM_SETTINGS', 'READ');
    return hasPermission(perms, 'CRM', 'READ');
  }

  static bool canReadCrmBin(PermissionMap? perms, [String? role]) {
    if (isAdmin(role)) return true;
    if (perms?.containsKey('CRM_BIN') == true) return hasPermission(perms, 'CRM_BIN', 'READ');
    return hasPermission(perms, 'CRM', 'READ');
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

  /// Admin/HR can set per-employee punch windows (matches backend PATCH guard).
  static bool canManageEmployeeAttendance(PermissionMap? perms, String? role) {
    final r = (role ?? '').toUpperCase();
    if (const ['ADMIN', 'HR', 'HR_MANAGER'].contains(r)) return true;
    return canWriteAttendance(perms);
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

  static bool canReadDocuments(PermissionMap? perms) {
    return hasPermission(perms, 'DOCUMENTS', 'READ');
  }

  static bool canWriteDocuments(PermissionMap? perms) {
    return hasPermission(perms, 'DOCUMENTS', 'WRITE');
  }

  static bool canManageLetters(PermissionMap? perms, String? role) {
    final r = (role ?? '').toUpperCase();
    if (const ['ADMIN', 'HR', 'HR_MANAGER'].contains(r)) return true;
    return canWriteDocuments(perms);
  }

  static bool canReadReimbursements(PermissionMap? perms) {
    return hasPermission(perms, 'REIMBURSEMENTS', 'READ') ||
        hasPermission(perms, 'REIMBURSEMENTS', 'WRITE');
  }

  static bool canWriteReimbursements(PermissionMap? perms) {
    return hasPermission(perms, 'REIMBURSEMENTS', 'WRITE');
  }

  static bool canAdminReimbursements(PermissionMap? perms, String role) {
    final r = role.toUpperCase();
    if (const ['ADMIN', 'HR', 'HR_MANAGER'].contains(r)) return true;
    return hasPermission(perms, 'REIMBURSEMENTS', 'APPROVE') ||
        hasPermission(perms, 'REIMBURSEMENTS', 'WRITE');
  }

  static bool canReadRecruitment(PermissionMap? perms) {
    return hasPermission(perms, 'RECRUITMENT', 'READ') ||
        hasPermission(perms, 'RECRUITMENT', 'WRITE');
  }

  static bool canWriteRecruitment(PermissionMap? perms, [String? role]) {
    final r = (role ?? '').toUpperCase();
    if (const ['ADMIN', 'HR', 'HR_MANAGER'].contains(r)) return true;
    return hasPermission(perms, 'RECRUITMENT', 'WRITE');
  }

  /// Company repository: Admin/HR can upload & remove; everyone can view.
  static bool canManageRepository(PermissionMap? perms, [String? role]) {
    final r = (role ?? '').toUpperCase();
    if (const ['ADMIN', 'HR', 'HR_MANAGER', 'SUPER_ADMIN'].contains(r)) return true;
    return canWriteDocuments(perms);
  }

  static String resolvePostLoginPath(
    PermissionMap? perms,
    String role,
    String? employeeViewScope,
  ) {
    if (canAccessAdminPortal(perms, employeeViewScope)) return '/admin/dashboard';
    if (canApproveLeave(perms)) return '/leave';
    if (canViewOwnWorkforce(perms, employeeViewScope)) return '/profile';

    if (const ['HOD', 'HOI', 'REGISTRAR', 'VC', 'HR', 'HR_MANAGER'].contains(role)) {
      return '/leave';
    }
    return '/home'; // Flutter fallback instead of /dashboard since dashboard links here/home.
  }

  static PermissionMap mapFromJson(Object? raw) {
    final map = <String, List<String>>{};
    if (raw is Map) {
      raw.forEach((key, value) {
        if (value is List) {
          map[key.toString()] = value.map((e) => e.toString()).toList();
        }
      });
    }
    return map;
  }

  static bool mapsEqual(PermissionMap a, PermissionMap b) {
    if (a.length != b.length) return false;
    for (final key in a.keys) {
      final left = List<String>.from(a[key] ?? const [])..sort();
      final right = List<String>.from(b[key] ?? const [])..sort();
      if (left.length != right.length) return false;
      for (var i = 0; i < left.length; i++) {
        if (left[i] != right[i]) return false;
      }
    }
    return true;
  }
}
