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
    String? employeeViewScope, [
    String? role,
  ]) {
    // Company Admin / Superadmin always administer workforce. Org-matrix
    // PERSONAL_INFO can lag behind a fresh login JWT and must not 403 them.
    if (isAdmin(role)) return true;

    return employeeViewScope == 'INSTITUTE' ||
        employeeViewScope == 'UNIVERSITY';
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
    String? employeeViewScope, [
    String? role,
  ]) {
    if (isSuperAdmin(role)) return true;
    if (perms == null || perms.isEmpty) {
      if (isSystemAdmin(role)) return false;
    }

    final hasManagementModule = hasPermission(perms, 'USER_MGMT', 'READ') ||
        hasPermission(perms, 'ROLE_MGMT', 'READ') ||
        hasPermission(perms, 'SALARY', 'READ') ||
        hasPermission(perms, 'PAYROLL', 'READ') ||
        hasPermission(perms, 'REPORTS', 'READ') ||
        hasPermission(perms, 'FIELD_MGMT', 'READ') ||
        hasPermission(perms, 'LEAVE', 'APPROVE') ||
        hasPermission(perms, 'GOOGLE_EARTH', 'READ');

    // Tenant System Admin: portal only when Superadmin granted a management module
    if (isSystemAdmin(role)) return hasManagementModule;

    if (canViewWorkforce(perms, employeeViewScope, role)) return true;
    if (perms == null || perms.isEmpty) return false;

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

  static bool isSuperAdmin(String? role) {
    final r = (role ?? '').toUpperCase().replaceAll(RegExp(r'[\s_-]+'), '');
    return r == 'SUPERADMIN';
  }

  static bool isSystemAdmin(String? role) {
    final r = (role ?? '').toUpperCase().replaceAll(RegExp(r'[\s_-]+'), '');
    return r == 'SYSTEMADMIN' || r == 'SYSTEMADMINISTRATOR' || r == 'ADMIN';
  }

  static bool isAdmin(String? role) {
    return isSuperAdmin(role) || isSystemAdmin(role);
  }

  static bool canCreateAdmins(String? role) {
    return isSuperAdmin(role);
  }

  /// Suite category for a module key (HRMS / CRM / ERP / COLLABORATION).
  static String suiteForModuleKey(String moduleKey) {
    final k = moduleKey.trim().toUpperCase();
    if (k.startsWith('COLLAB_') ||
        const ['CHAT', 'MEETINGS', 'TASKS', 'ORG_TREE', 'COLLABORATION'].contains(k)) {
      return 'COLLABORATION';
    }
    if (k.startsWith('ERP_') ||
        const [
          'PROJECTS',
          'WORK_ORDERS',
          'BOQ',
          'STORE',
          'PURCHASE',
          'DPR',
          'TENDERS',
          'TENDER_APPLICATIONS',
          'CONTRACTORS',
          'ERP_CONFIGURATIONS',
        ].contains(k)) {
      return 'ERP';
    }
    if (k.startsWith('CRM_') ||
        const [
          'CRM',
          'CRM_PRE_SALES',
          'CRM_POST_SALES',
          'CRM_HEADERS',
          'CRM_BIN',
          'CRM_SETTINGS',
          'CRM_DASHBOARD',
        ].contains(k)) {
      return 'CRM';
    }
    return 'HRMS';
  }

  /// True when the user may open the HRMS / CRM / ERP suite switcher entry.
  /// Requires at least one READ (or elevated) action on a module in that suite.
  static bool canAccessSuite(
    PermissionMap? perms,
    String suite, [
    String? role,
  ]) {
    if (isSuperAdmin(role)) return true;
    if (perms == null || perms.isEmpty) return false;
    final target = suite.trim().toUpperCase();
    for (final entry in perms.entries) {
      if (suiteForModuleKey(entry.key) != target) continue;
      final actions = entry.value;
      if (actions.any((a) =>
          a == 'READ' ||
          a == 'WRITE' ||
          a == 'APPROVE' ||
          a == 'DELETE' ||
          a == 'EXPORT')) {
        return true;
      }
    }
    return false;
  }

  /// Suites the user can actually open (license ∩ permission matrix).
  static List<String> accessibleSuites(
    PermissionMap? perms,
    List<String> enabledModules, [
    String? role,
  ]) {
    final out = <String>[];
    for (final suite in const ['HRMS', 'CRM', 'ERP']) {
      if (!enabledModules.map((e) => e.toUpperCase()).contains(suite)) continue;
      if (!canAccessSuite(perms, suite, role)) continue;
      out.add(suite);
    }
    return out;
  }

  static bool canReadProjects(PermissionMap? perms, [String? role]) {
    if (isSuperAdmin(role)) return true;
    return hasPermission(perms, 'PROJECTS', 'READ');
  }

  static bool canReadGoogleEarth(PermissionMap? perms, [String? role]) {
    if (isSuperAdmin(role)) return true;
    return hasPermission(perms, 'GOOGLE_EARTH', 'READ');
  }

  static bool canWriteGoogleEarth(PermissionMap? perms, [String? role]) {
    if (isSuperAdmin(role)) return true;
    return hasPermission(perms, 'GOOGLE_EARTH', 'WRITE');
  }

  static bool canWriteProjects(PermissionMap? perms, [String? role]) {
    if (isSuperAdmin(role)) return true;
    return hasPermission(perms, 'PROJECTS', 'WRITE');
  }

  static bool canReadWorkOrders(PermissionMap? perms, [String? role]) {
    if (isSuperAdmin(role)) return true;
    return hasPermission(perms, 'WORK_ORDERS', 'READ');
  }

  static bool canWriteWorkOrders(PermissionMap? perms, [String? role]) {
    if (isSuperAdmin(role)) return true;
    return hasPermission(perms, 'WORK_ORDERS', 'WRITE');
  }

  static bool canApproveWorkOrders(PermissionMap? perms, [String? role]) {
    if (isSuperAdmin(role)) return true;
    return hasPermission(perms, 'WORK_ORDERS', 'APPROVE');
  }

  static bool canReadBank(PermissionMap? perms, [String? role]) {
    if (isSuperAdmin(role)) return true;
    return hasPermission(perms, 'BANK_DETAILS', 'READ');
  }

  static bool canWriteBank(PermissionMap? perms, [String? role]) {
    if (isSuperAdmin(role)) return true;
    return hasPermission(perms, 'BANK_DETAILS', 'WRITE');
  }

  static bool canReadEducation(PermissionMap? perms, [String? role]) {
    if (isSuperAdmin(role)) return true;
    return hasPermission(perms, 'EDUCATION', 'READ');
  }

  static bool canWriteEducation(PermissionMap? perms, [String? role]) {
    if (isSuperAdmin(role)) return true;
    return hasPermission(perms, 'EDUCATION', 'WRITE');
  }

  static bool canReadExperience(PermissionMap? perms, [String? role]) {
    if (isSuperAdmin(role)) return true;
    return hasPermission(perms, 'EXPERIENCE', 'READ');
  }

  static bool canWriteExperience(PermissionMap? perms, [String? role]) {
    if (isSuperAdmin(role)) return true;
    return hasPermission(perms, 'EXPERIENCE', 'WRITE');
  }

  static bool canReadDpr(PermissionMap? perms, [String? role]) {
    if (isSuperAdmin(role)) return true;
    return hasPermission(perms, 'DPR', 'READ');
  }

  static bool canWriteDpr(PermissionMap? perms, [String? role]) {
    if (isSuperAdmin(role)) return true;
    return hasPermission(perms, 'DPR', 'WRITE');
  }

  static bool canReadStore(PermissionMap? perms, [String? role]) {
    if (isSuperAdmin(role)) return true;
    return hasPermission(perms, 'STORE', 'READ');
  }

  static bool canWriteStore(PermissionMap? perms, [String? role]) {
    if (isSuperAdmin(role)) return true;
    return hasPermission(perms, 'STORE', 'WRITE');
  }

  static bool canReadPurchase(PermissionMap? perms, [String? role]) {
    if (isSuperAdmin(role)) return true;
    return hasPermission(perms, 'PURCHASE', 'READ');
  }

  static bool canWritePurchase(PermissionMap? perms, [String? role]) {
    if (isSuperAdmin(role)) return true;
    return hasPermission(perms, 'PURCHASE', 'WRITE');
  }

  static bool canReadBoq(PermissionMap? perms, [String? role]) {
    if (isSuperAdmin(role)) return true;
    return hasPermission(perms, 'BOQ', 'READ');
  }

  static bool canWriteBoq(PermissionMap? perms, [String? role]) {
    if (isSuperAdmin(role)) return true;
    return hasPermission(perms, 'BOQ', 'WRITE');
  }

  static bool canReadTenders(PermissionMap? perms, [String? role]) {
    if (isSuperAdmin(role)) return true;
    return hasPermission(perms, 'TENDERS', 'READ');
  }

  static bool canWriteTenders(PermissionMap? perms, [String? role]) {
    if (isSuperAdmin(role)) return true;
    return hasPermission(perms, 'TENDERS', 'WRITE');
  }

  static bool canReadContractors(PermissionMap? perms, [String? role]) {
    if (isSuperAdmin(role)) return true;
    return hasPermission(perms, 'CONTRACTORS', 'READ');
  }

  static bool canWriteContractors(PermissionMap? perms, [String? role]) {
    if (isSuperAdmin(role)) return true;
    return hasPermission(perms, 'CONTRACTORS', 'WRITE');
  }

  static bool canReadCrm(PermissionMap? perms, [String? role]) {
    if (isSuperAdmin(role)) return true;
    return hasPermission(perms, 'CRM', 'READ');
  }

  static bool canWriteCrm(PermissionMap? perms, [String? role]) {
    if (isSuperAdmin(role)) return true;
    return hasPermission(perms, 'CRM', 'WRITE');
  }

  static bool canReadCrmDashboard(PermissionMap? perms, [String? role]) {
    if (isSuperAdmin(role)) return true;
    return hasPermission(perms, 'CRM_DASHBOARD', 'READ');
  }

  static bool canReadCrmHeaders(PermissionMap? perms, [String? role]) {
    if (isSuperAdmin(role)) return true;
    return hasPermission(perms, 'CRM_HEADERS', 'READ');
  }

  static bool canReadCrmSettings(PermissionMap? perms, [String? role]) {
    if (isSuperAdmin(role)) return true;
    return hasPermission(perms, 'CRM_SETTINGS', 'READ');
  }

  static bool canReadCrmBin(PermissionMap? perms, [String? role]) {
    if (isSuperAdmin(role)) return true;
    return hasPermission(perms, 'CRM_BIN', 'READ');
  }

  static bool canManageUsers(PermissionMap? perms, [String? role]) {
    if (isSuperAdmin(role)) return true;
    return hasPermission(perms, 'USER_MGMT', 'READ');
  }

  static bool canManageRoles(PermissionMap? perms, [String? role]) {
    if (isSuperAdmin(role)) return true;
    return hasPermission(perms, 'ROLE_MGMT', 'READ');
  }

  static bool canManageInstitutes(PermissionMap? perms, [String? role]) {
    if (isSuperAdmin(role)) return true;
    return hasPermission(perms, 'FIELD_MGMT', 'READ');
  }

  static bool canReadLeave(PermissionMap? perms, [String? role]) {
    if (isSuperAdmin(role)) return true;
    return hasPermission(perms, 'LEAVE', 'READ');
  }

  static bool canWriteLeave(PermissionMap? perms, [String? role]) {
    if (isSuperAdmin(role)) return true;
    return hasPermission(perms, 'LEAVE', 'WRITE');
  }

  static bool canAdminLeave(
    PermissionMap? perms,
    String role,
    String? employeeViewScope,
  ) {
    if (isSuperAdmin(role)) return true;
    if (!hasPermission(perms, 'LEAVE', 'WRITE')) return false;
    final adminRole =
        const ['ADMIN', 'HR', 'HR_MANAGER'].contains(role.toUpperCase());
    if (adminRole) return true;
    return canAccessAdminPortal(perms, employeeViewScope, role) &&
        hasPermission(perms, 'LEAVE', 'WRITE');
  }

  static bool canReadAttendance(PermissionMap? perms, [String? role]) {
    if (isSuperAdmin(role)) return true;
    return hasPermission(perms, 'ATTENDANCE', 'READ');
  }

  static bool canWriteAttendance(PermissionMap? perms, [String? role]) {
    if (isSuperAdmin(role)) return true;
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

  static bool canReadSalary(PermissionMap? perms, [String? role]) {
    if (isSuperAdmin(role)) return true;
    return hasPermission(perms, 'SALARY', 'READ') ||
        hasPermission(perms, 'PAYROLL', 'READ');
  }

  static bool canWriteSalary(PermissionMap? perms, [String? role]) {
    if (isSuperAdmin(role)) return true;
    return hasPermission(perms, 'SALARY', 'WRITE') ||
        hasPermission(perms, 'PAYROLL', 'WRITE');
  }

  static bool canReadDocuments(PermissionMap? perms, [String? role]) {
    if (isSuperAdmin(role)) return true;
    return hasPermission(perms, 'DOCUMENTS', 'READ');
  }

  static bool canWriteDocuments(PermissionMap? perms, [String? role]) {
    if (isSuperAdmin(role)) return true;
    return hasPermission(perms, 'DOCUMENTS', 'WRITE');
  }

  static bool canManageLetters(PermissionMap? perms, String? role) {
    final r = (role ?? '').toUpperCase();
    if (const ['ADMIN', 'HR', 'HR_MANAGER'].contains(r)) return true;
    return canWriteDocuments(perms);
  }

  static bool canReadReimbursements(PermissionMap? perms, [String? role]) {
    if (isSuperAdmin(role)) return true;
    return hasPermission(perms, 'REIMBURSEMENTS', 'READ') ||
        hasPermission(perms, 'REIMBURSEMENTS', 'WRITE');
  }

  static bool canWriteReimbursements(PermissionMap? perms, [String? role]) {
    if (isSuperAdmin(role)) return true;
    return hasPermission(perms, 'REIMBURSEMENTS', 'WRITE');
  }

  static bool canAdminReimbursements(PermissionMap? perms, String role) {
    if (isSuperAdmin(role) || isSystemAdmin(role)) return true;
    final r = role.toUpperCase().replaceAll(RegExp(r'[\s_-]+'), '');
    if (const ['ADMIN', 'HR', 'HRMANAGER'].contains(r)) return true;
    return hasPermission(perms, 'REIMBURSEMENTS', 'APPROVE') ||
        hasPermission(perms, 'REIMBURSEMENTS', 'WRITE');
  }

  static bool canReadRecruitment(PermissionMap? perms, [String? role]) {
    if (isSuperAdmin(role)) return true;
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

  static bool canReadRepository(PermissionMap? perms, [String? role]) {
    if (isSuperAdmin(role)) return true;
    return hasPermission(perms, 'REPOSITORY', 'READ');
  }

  // ── COLLABORATION ────────────────────────────────────────────────────────
  static bool canReadChat(PermissionMap? perms, [String? role]) {
    if (isSuperAdmin(role)) return true;
    return hasPermission(perms, 'CHAT', 'READ');
  }

  static bool canWriteChat(PermissionMap? perms, [String? role]) {
    if (isSuperAdmin(role)) return true;
    return hasPermission(perms, 'CHAT', 'WRITE');
  }

  static bool canReadMeetings(PermissionMap? perms, [String? role]) {
    if (isSuperAdmin(role)) return true;
    return hasPermission(perms, 'MEETINGS', 'READ');
  }

  static bool canWriteMeetings(PermissionMap? perms, [String? role]) {
    if (isSuperAdmin(role)) return true;
    return hasPermission(perms, 'MEETINGS', 'WRITE');
  }

  static bool canReadTasks(PermissionMap? perms, [String? role]) {
    if (isSuperAdmin(role)) return true;
    return hasPermission(perms, 'TASKS', 'READ');
  }

  static bool canWriteTasks(PermissionMap? perms, [String? role]) {
    if (isSuperAdmin(role)) return true;
    return hasPermission(perms, 'TASKS', 'WRITE');
  }

  static bool canReadSupport(PermissionMap? perms, [String? role]) {
    if (isSuperAdmin(role) || isSystemAdmin(role)) return true;
    return hasPermission(perms, 'SUPPORT', 'READ');
  }

  static bool canWriteSupport(PermissionMap? perms, [String? role]) {
    if (isSuperAdmin(role) || isSystemAdmin(role)) return true;
    return hasPermission(perms, 'SUPPORT', 'WRITE');
  }

  /// IT queue / resolve / force-close (role-based; also check API capabilities for assignees)
  static bool canAdminSupport(PermissionMap? perms, [String? role]) {
    if (isSuperAdmin(role) || isSystemAdmin(role)) return true;
    final r = (role ?? '').toUpperCase().replaceAll(RegExp(r'[\s_-]+'), '');
    if (const ['ADMIN', 'HR', 'HRMANAGER'].contains(r)) return true;
    return hasPermission(perms, 'SUPPORT', 'APPROVE');
  }

  /// Admin configures which employees receive IT Support tickets.
  static bool canManageSupportHandlers(String? role, {bool companyAdminGranted = false}) {
    if (companyAdminGranted) return true;
    if (isSuperAdmin(role) || isSystemAdmin(role)) return true;
    final r = (role ?? '').toUpperCase().replaceAll(RegExp(r'[\s_-]+'), '');
    return r == 'ADMIN';
  }

  static bool canReadOrgTree(PermissionMap? perms, [String? role]) {
    if (isSuperAdmin(role)) return true;
    return hasPermission(perms, 'ORG_TREE', 'READ');
  }

  // ── CRM EXTENSIONS ─────────────────────────────────────────────────────────
  /// Pre-sales nav uses CRM_PRE_SALES; DB module key is historically `CRM`.
  static bool canReadCrmPreSales(PermissionMap? perms, [String? role]) {
    if (isSuperAdmin(role)) return true;
    return hasPermission(perms, 'CRM_PRE_SALES', 'READ') ||
        hasPermission(perms, 'CRM', 'READ');
  }

  static bool canReadCrmPostSales(PermissionMap? perms, [String? role]) {
    if (isSuperAdmin(role)) return true;
    return hasPermission(perms, 'CRM_POST_SALES', 'READ');
  }

  static bool canWriteCrmPreSales(PermissionMap? perms, [String? role]) {
    if (isSuperAdmin(role)) return true;
    return hasPermission(perms, 'CRM_PRE_SALES', 'WRITE') ||
        hasPermission(perms, 'CRM', 'WRITE');
  }

  static bool canWriteCrmPostSales(PermissionMap? perms, [String? role]) {
    if (isSuperAdmin(role)) return true;
    return hasPermission(perms, 'CRM_POST_SALES', 'WRITE');
  }

  // Profile tab-level access (HRMS › Profile dropdown in RBAC)
  static bool canReadProfileGeneral(PermissionMap? perms, [String? role]) {
    if (isSuperAdmin(role) || isAdmin(role)) return true;
    return hasPermission(perms, 'PERSONAL_INFO', 'READ') ||
        hasPermission(perms, 'PROFILE_GENERAL', 'READ');
  }

  static bool canWriteProfileGeneral(PermissionMap? perms, [String? role]) {
    if (isSuperAdmin(role) || isAdmin(role)) return true;
    return hasPermission(perms, 'PERSONAL_INFO', 'WRITE') ||
        hasPermission(perms, 'PROFILE_GENERAL', 'WRITE');
  }

  static bool canReadProfilePersonal(PermissionMap? perms, [String? role]) {
    if (isSuperAdmin(role) || isAdmin(role)) return true;
    return hasPermission(perms, 'PROFILE_PERSONAL', 'READ') ||
        hasPermission(perms, 'PERSONAL_INFO', 'READ');
  }

  static bool canWriteProfilePersonal(PermissionMap? perms, [String? role]) {
    if (isSuperAdmin(role) || isAdmin(role)) return true;
    return hasPermission(perms, 'PROFILE_PERSONAL', 'WRITE') ||
        hasPermission(perms, 'PERSONAL_INFO', 'WRITE');
  }

  static bool canReadProfileAddress(PermissionMap? perms, [String? role]) {
    if (isSuperAdmin(role) || isAdmin(role)) return true;
    return hasPermission(perms, 'PROFILE_ADDRESS', 'READ') ||
        hasPermission(perms, 'PERSONAL_INFO', 'READ');
  }

  static bool canWriteProfileAddress(PermissionMap? perms, [String? role]) {
    if (isSuperAdmin(role) || isAdmin(role)) return true;
    return hasPermission(perms, 'PROFILE_ADDRESS', 'WRITE') ||
        hasPermission(perms, 'PERSONAL_INFO', 'WRITE');
  }

  static bool canReadProfileOther(PermissionMap? perms, [String? role]) {
    if (isSuperAdmin(role) || isAdmin(role)) return true;
    return hasPermission(perms, 'PROFILE_OTHER', 'READ') ||
        hasPermission(perms, 'PERSONAL_INFO', 'READ');
  }

  static bool canWriteProfileOther(PermissionMap? perms, [String? role]) {
    if (isSuperAdmin(role) || isAdmin(role)) return true;
    return hasPermission(perms, 'PROFILE_OTHER', 'WRITE') ||
        hasPermission(perms, 'PERSONAL_INFO', 'WRITE');
  }

  static bool canReadProfileFamily(PermissionMap? perms, [String? role]) {
    if (isSuperAdmin(role) || isAdmin(role)) return true;
    return hasPermission(perms, 'PROFILE_FAMILY', 'READ') ||
        hasPermission(perms, 'PERSONAL_INFO', 'READ');
  }

  static bool canWriteProfileFamily(PermissionMap? perms, [String? role]) {
    if (isSuperAdmin(role) || isAdmin(role)) return true;
    return hasPermission(perms, 'PROFILE_FAMILY', 'WRITE') ||
        hasPermission(perms, 'PERSONAL_INFO', 'WRITE');
  }

  static bool canReadProfileAttendance(PermissionMap? perms, [String? role]) {
    if (isSuperAdmin(role) || isAdmin(role)) return true;
    return hasPermission(perms, 'ATTENDANCE', 'READ') ||
        hasPermission(perms, 'PROFILE_ATTENDANCE', 'READ');
  }

  /// True if the user may open the Profile sidebar at all.
  static bool canOpenProfile(PermissionMap? perms, [String? role]) {
    if (isSuperAdmin(role) || isAdmin(role)) return true;
    return canReadProfileGeneral(perms, role) ||
        canReadProfilePersonal(perms, role) ||
        canReadProfileAddress(perms, role) ||
        canReadProfileOther(perms, role) ||
        canReadProfileFamily(perms, role) ||
        canReadEducation(perms, role) ||
        canReadExperience(perms, role) ||
        canReadDocuments(perms, role) ||
        canReadBank(perms, role) ||
        canReadSalary(perms, role) ||
        canReadProfileAttendance(perms, role);
  }

  // ── ERP EXTENSIONS ─────────────────────────────────────────────────────────
  static bool canReadTenderApplications(PermissionMap? perms, [String? role]) {
    if (isSuperAdmin(role)) return true;
    return hasPermission(perms, 'TENDER_APPLICATIONS', 'READ');
  }

  static bool canWriteTenderApplications(PermissionMap? perms, [String? role]) {
    if (isSuperAdmin(role)) return true;
    return hasPermission(perms, 'TENDER_APPLICATIONS', 'WRITE');
  }

  static bool canReadErpConfig(PermissionMap? perms, [String? role]) {
    if (isSuperAdmin(role)) return true;
    return hasPermission(perms, 'ERP_CONFIGURATIONS', 'READ');
  }

  static bool canReadPayroll(PermissionMap? perms, [String? role]) {
    if (isSuperAdmin(role)) return true;
    return hasPermission(perms, 'PAYROLL', 'READ') || hasPermission(perms, 'SALARY', 'READ');
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
