import { Prisma } from '@prisma/client';
import { prisma } from '../../config/prisma';
import { isSuperAdminRole, isSystemAdminRole } from '../auth/permissions-map';
import type {
  AuditLogFilterInput,
  AuditLogEntryDTO,
  AuditEmployeeSummaryDTO,
  SuperadminTenantHierarchyDTO,
  AuditStatsDTO,
  TargetEmployeeSummary,
} from './audit.types';

const TABLE_LABELS: Record<string, string> = {
  employee_personal_info: 'Personal Information',
  employee_general_info: 'General Employment',
  employee_addresses: 'Addresses',
  employee_bank_info: 'Bank Details',
  employee_other_info: 'Other Profile Details',
  family_members: 'Family Members',
  employees: 'Employee Record / Documents',
  leave_records: 'Leave Balances & Credits',
  leave_audit_log: 'Leave Records',
};

function formatFieldLabel(field: string): string {
  if (!field) return '';
  return field
    .replace(/([A-Z])/g, ' $1')
    .replace(/[_-]+/g, ' ')
    .trim()
    .replace(/\b\w/g, (c) => c.toUpperCase());
}

export interface RequesterContext {
  id?: string;
  roleName?: string;
  role?: string;
  organizationId?: string | null;
  subOrganization?: string | null;
  employeeId?: number | null;
}

export const auditService = {
  /**
   * Resolves the organization and employee IDs belonging to this tenant.
   */
  async resolveTenantScope(requester?: RequesterContext, explicitOrgId?: string) {
    const isSuper = isSuperAdminRole(requester?.roleName ?? requester?.role);

    // If explicit org ID requested (e.g. by Superadmin)
    let org = null;
    if (explicitOrgId) {
      org = await prisma.organization.findFirst({
        where: { id: explicitOrgId, deletedAt: null },
        select: { id: true, name: true, code: true },
      });
    } else if (requester?.organizationId) {
      org = await prisma.organization.findFirst({
        where: { id: requester.organizationId, deletedAt: null },
        select: { id: true, name: true, code: true },
      });
    } else if (requester?.subOrganization?.trim()) {
      const sub = requester.subOrganization.trim();
      org = await prisma.organization.findFirst({
        where: {
          deletedAt: null,
          OR: [
            { name: { equals: sub, mode: 'insensitive' } },
            { code: { equals: sub, mode: 'insensitive' } },
          ],
        },
        select: { id: true, name: true, code: true },
      });
    } else if (requester?.employeeId) {
      const emp = await prisma.employee.findUnique({
        where: { id: requester.employeeId },
        select: {
          generalInfo: {
            select: {
              organization: true,
              subOrganization: true,
              institute: { select: { parentOrganizationId: true } },
            },
          },
        },
      });
      const orgName = emp?.generalInfo?.organization;
      const parentOrgId = emp?.generalInfo?.institute?.parentOrganizationId;
      if (parentOrgId) {
        org = await prisma.organization.findFirst({
          where: { id: parentOrgId, deletedAt: null },
          select: { id: true, name: true, code: true },
        });
      } else if (orgName) {
        org = await prisma.organization.findFirst({
          where: { name: { equals: orgName, mode: 'insensitive' }, deletedAt: null },
          select: { id: true, name: true, code: true },
        });
      }
    }

    if (!org && !isSuper) {
      return { org: null, employeeIds: [], tenantUserIds: [] };
    }

    if (!org && isSuper) {
      return { org: null, employeeIds: null, tenantUserIds: null };
    }

    // Find all users belonging to this tenant/org
    const tenantUsers = await prisma.user.findMany({
      where: {
        deletedAt: null,
        OR: [
          { subOrganization: { equals: org!.name, mode: 'insensitive' } },
          { subOrganization: { equals: org!.code, mode: 'insensitive' } },
          {
            employee: {
              generalInfo: {
                OR: [
                  { organization: { equals: org!.name, mode: 'insensitive' } },
                  { subOrganization: { equals: org!.name, mode: 'insensitive' } },
                  { subOrganization: { equals: org!.code, mode: 'insensitive' } },
                  { institute: { parentOrganizationId: org!.id } },
                ],
              },
            },
          },
        ],
      },
      select: { id: true, employeeId: true },
    });

    const tenantUserIds = tenantUsers.map((u) => u.id);
    const tenantUserEmpIds = tenantUsers
      .map((u) => u.employeeId)
      .filter((id): id is number => typeof id === 'number' && id > 0);

    // Find all employees belonging to this tenant/org
    const tenantEmps = await prisma.employee.findMany({
      where: {
        OR: [
          { id: { in: tenantUserEmpIds } },
          { generalInfo: { organization: { equals: org!.name, mode: 'insensitive' } } },
          { generalInfo: { subOrganization: { equals: org!.name, mode: 'insensitive' } } },
          { generalInfo: { subOrganization: { equals: org!.code, mode: 'insensitive' } } },
          { generalInfo: { institute: { parentOrganizationId: org!.id } } },
          ...(tenantUserIds.length > 0 ? [{ createdBy: { in: tenantUserIds } }] : []),
        ],
      },
      select: { id: true },
    });

    const employeeIds = [...new Set([...tenantEmps.map((e) => e.id), ...tenantUserEmpIds])];

    return { org, employeeIds, tenantUserIds };
  },

  /**
   * List logs for Tenant Admin or Superadmin.
   */
  async listLogs(requester: RequesterContext, filters: AuditLogFilterInput) {
    const isSuper = isSuperAdminRole(requester.roleName ?? requester.role);
    const scope = await this.resolveTenantScope(requester, filters.organizationId);

    // Non-superadmin must be scoped to an organization
    if (!isSuper && !scope.org) {
      return {
        logs: [],
        pagination: { total: 0, page: 1, limit: filters.limit ?? 50, totalPages: 0 },
      };
    }

    const where: Prisma.AuditLogWhereInput = {};

    // Tenancy isolation filter
    if (scope.employeeIds !== null && scope.tenantUserIds !== null) {
      // Must belong to this tenant's employees or be changed by this tenant's users
      where.OR = [
        { employeeId: { in: scope.employeeIds } },
        { changedBy: { in: scope.tenantUserIds } },
      ];
    }

    // Specific employee filter
    if (filters.employeeId) {
      const empId = Number(filters.employeeId);
      if (Number.isFinite(empId)) {
        where.employeeId = empId;
      }
    }

    // Specific actor (changedBy) filter
    if (filters.actorId?.trim()) {
      where.changedBy = filters.actorId.trim();
    }

    // Table name filter
    if (filters.tableName?.trim()) {
      where.tableName = filters.tableName.trim();
    }

    // Date range filter
    if (filters.startDate || filters.endDate) {
      where.changedAt = {};
      if (filters.startDate) {
        where.changedAt.gte = new Date(filters.startDate);
      }
      if (filters.endDate) {
        where.changedAt.lte = new Date(filters.endDate);
      }
    }

    // Search filter across field name, values, reason
    if (filters.search?.trim()) {
      const q = filters.search.trim();
      const searchConditions: Prisma.AuditLogWhereInput[] = [
        { fieldName: { contains: q, mode: 'insensitive' } },
        { oldValue: { contains: q, mode: 'insensitive' } },
        { newValue: { contains: q, mode: 'insensitive' } },
        { changeReason: { contains: q, mode: 'insensitive' } },
      ];

      // Also allow searching by target employee name or changer username
      const matchingEmployees = await prisma.employee.findMany({
        where: {
          generalInfo: {
            OR: [
              { fullName: { contains: q, mode: 'insensitive' } },
              { employeeCode: { contains: q, mode: 'insensitive' } },
            ],
          },
          ...(scope.employeeIds ? { id: { in: scope.employeeIds } } : {}),
        },
        select: { id: true },
        take: 50,
      });

      if (matchingEmployees.length > 0) {
        searchConditions.push({ employeeId: { in: matchingEmployees.map((e) => e.id) } });
      }

      const matchingUsers = await prisma.user.findMany({
        where: {
          OR: [
            { username: { contains: q, mode: 'insensitive' } },
            { employee: { generalInfo: { fullName: { contains: q, mode: 'insensitive' } } } },
          ],
          ...(scope.tenantUserIds ? { id: { in: scope.tenantUserIds } } : {}),
        },
        select: { id: true },
        take: 50,
      });

      if (matchingUsers.length > 0) {
        searchConditions.push({ changedBy: { in: matchingUsers.map((u) => u.id) } });
      }

      if (where.OR) {
        where.AND = [{ OR: where.OR }, { OR: searchConditions }];
        delete where.OR;
      } else {
        where.OR = searchConditions;
      }
    }

    const page = Math.max(1, Number(filters.page) || 1);
    const limit = Math.min(200, Math.max(1, Number(filters.limit) || 50));
    const skip = (page - 1) * limit;

    const [total, rows] = await Promise.all([
      prisma.auditLog.count({ where }),
      prisma.auditLog.findMany({
        where,
        orderBy: { changedAt: 'desc' },
        skip,
        take: limit,
      }),
    ]);

    // Batch enrich target employees
    const targetEmpIds = [...new Set(rows.map((r) => r.employeeId).filter((id): id is number => typeof id === 'number' && id > 0))];
    const employees = targetEmpIds.length
      ? await prisma.employee.findMany({
          where: { id: { in: targetEmpIds } },
          select: {
            id: true,
            photoUrl: true,
            generalInfo: {
              select: {
                fullName: true,
                employeeCode: true,
                designation: true,
                department: true,
              },
            },
            user: { select: { id: true } },
          },
        })
      : [];

    const empMap = new Map<number, { summary: TargetEmployeeSummary; userId?: string }>();
    for (const emp of employees) {
      empMap.set(emp.id, {
        userId: emp.user?.id,
        summary: {
          id: emp.id,
          fullName: emp.generalInfo?.fullName?.trim() || `Employee #${emp.id}`,
          employeeCode: emp.generalInfo?.employeeCode ?? null,
          designation: emp.generalInfo?.designation ?? null,
          department: emp.generalInfo?.department ?? null,
          avatarUrl: emp.photoUrl ?? null,
        },
      });
    }

    // Batch enrich changers
    const changerIds = [...new Set(rows.map((r) => r.changedBy).filter(Boolean))];
    const users = changerIds.length
      ? await prisma.user.findMany({
          where: { id: { in: changerIds } },
          select: {
            id: true,
            username: true,
            role: { select: { name: true } },
            employee: { select: { generalInfo: { select: { fullName: true } } } },
          },
        })
      : [];

    const userMap = new Map<
      string,
      { fullName: string; roleName: string | null }
    >();
    for (const u of users) {
      userMap.set(u.id, {
        fullName: u.employee?.generalInfo?.fullName?.trim() || u.username || u.id,
        roleName: u.role?.name ?? null,
      });
    }

    const logs: AuditLogEntryDTO[] = rows.map((r) => {
      const empData = r.employeeId ? empMap.get(r.employeeId) : undefined;
      const userData = userMap.get(r.changedBy);
      const isSelf = Boolean(empData?.userId && empData.userId === r.changedBy);

      return {
        id: r.id,
        tableName: r.tableName,
        tableLabel: TABLE_LABELS[r.tableName] || formatFieldLabel(r.tableName),
        recordId: r.recordId,
        employeeId: r.employeeId,
        targetEmployee: empData?.summary ?? null,
        fieldName: r.fieldName,
        fieldLabel: formatFieldLabel(r.fieldName),
        oldValue: r.oldValue,
        newValue: r.newValue,
        changedBy: r.changedBy,
        changedByName: userData?.fullName || r.changedBy,
        changedByRole: userData?.roleName ?? null,
        isSelfChange: isSelf,
        changedAt: r.changedAt.toISOString(),
        changeReason: r.changeReason,
        ipAddress: r.ipAddress,
        userAgent: r.userAgent,
      };
    });

    return {
      logs,
      pagination: {
        total,
        page,
        limit,
        totalPages: Math.ceil(total / limit),
      },
    };
  },

  /**
   * Lists employees belonging to the tenant who have audit activity,
   * along with total changes and latest activity.
   */
  async listEmployeesWithLogs(requester: RequesterContext, options?: { organizationId?: string; search?: string }) {
    const isSuper = isSuperAdminRole(requester.roleName ?? requester.role);
    const scope = await this.resolveTenantScope(requester, options?.organizationId);

    if (!isSuper && !scope.org) {
      return [];
    }

    const employeeWhere: Prisma.EmployeeWhereInput = {};
    if (scope.employeeIds !== null) {
      employeeWhere.id = { in: scope.employeeIds };
    }

    if (options?.search?.trim()) {
      const q = options.search.trim();
      employeeWhere.OR = [
        { generalInfo: { fullName: { contains: q, mode: 'insensitive' } } },
        { generalInfo: { employeeCode: { contains: q, mode: 'insensitive' } } },
        { generalInfo: { designation: { contains: q, mode: 'insensitive' } } },
        { generalInfo: { department: { contains: q, mode: 'insensitive' } } },
      ];
    }

    const employees = await prisma.employee.findMany({
      where: employeeWhere,
      select: {
        id: true,
        photoUrl: true,
        generalInfo: {
          select: {
            fullName: true,
            employeeCode: true,
            designation: true,
            department: true,
          },
        },
      },
      orderBy: { id: 'asc' },
    });

    if (employees.length === 0) return [];

    const empIds = employees.map((e) => e.id);

    // Group logs by employeeId
    const groups = await prisma.auditLog.groupBy({
      by: ['employeeId'],
      where: { employeeId: { in: empIds } },
      _count: { id: true },
      _max: { changedAt: true },
    });

    const statMap = new Map<number, { count: number; lastAt: Date | null }>();
    for (const g of groups) {
      if (typeof g.employeeId === 'number') {
        statMap.set(g.employeeId, {
          count: g._count.id,
          lastAt: g._max.changedAt,
        });
      }
    }

    const result: AuditEmployeeSummaryDTO[] = employees.map((emp) => {
      const stats = statMap.get(emp.id);
      return {
        employeeId: emp.id,
        fullName: emp.generalInfo?.fullName?.trim() || `Employee #${emp.id}`,
        employeeCode: emp.generalInfo?.employeeCode ?? null,
        designation: emp.generalInfo?.designation ?? null,
        department: emp.generalInfo?.department ?? null,
        avatarUrl: emp.photoUrl ?? null,
        totalChanges: stats?.count ?? 0,
        lastChangedAt: stats?.lastAt ? stats.lastAt.toISOString() : null,
      };
    });

    // Sort: employees with activity first, then by last activity desc, then alphabetically
    return result.sort((a, b) => {
      if (b.totalChanges !== a.totalChanges) return b.totalChanges - a.totalChanges;
      if (a.lastChangedAt && b.lastChangedAt) {
        return new Date(b.lastChangedAt).getTime() - new Date(a.lastChangedAt).getTime();
      }
      return a.fullName.localeCompare(b.fullName);
    });
  },

  /**
   * Aggregated KPIs for audit dashboard.
   */
  async getAuditStats(requester: RequesterContext, organizationId?: string): Promise<AuditStatsDTO> {
    const isSuper = isSuperAdminRole(requester.roleName ?? requester.role);
    const scope = await this.resolveTenantScope(requester, organizationId);

    if (!isSuper && !scope.org) {
      return {
        totalLogs: 0,
        todayLogs: 0,
        activeEmployeesWithLogs: 0,
        topTables: [],
        topChangers: [],
      };
    }

    const where: Prisma.AuditLogWhereInput = {};
    if (scope.employeeIds !== null && scope.tenantUserIds !== null) {
      where.OR = [
        { employeeId: { in: scope.employeeIds } },
        { changedBy: { in: scope.tenantUserIds } },
      ];
    }

    const startOfToday = new Date();
    startOfToday.setHours(0, 0, 0, 0);

    const [totalLogs, todayLogs, tableGroups, userGroups, empGroups] = await Promise.all([
      prisma.auditLog.count({ where }),
      prisma.auditLog.count({
        where: {
          ...where,
          changedAt: { gte: startOfToday },
        },
      }),
      prisma.auditLog.groupBy({
        by: ['tableName'],
        where,
        _count: { id: true },
        orderBy: { _count: { id: 'desc' } },
        take: 5,
      }),
      prisma.auditLog.groupBy({
        by: ['changedBy'],
        where,
        _count: { id: true },
        orderBy: { _count: { id: 'desc' } },
        take: 5,
      }),
      prisma.auditLog.groupBy({
        by: ['employeeId'],
        where: {
          ...where,
          employeeId: { not: null },
        },
        _count: { id: true },
      }),
    ]);

    const userIds = userGroups.map((g) => g.changedBy).filter(Boolean);
    const users = userIds.length
      ? await prisma.user.findMany({
          where: { id: { in: userIds } },
          select: {
            id: true,
            username: true,
            employee: { select: { generalInfo: { select: { fullName: true } } } },
          },
        })
      : [];

    const userNameMap = new Map(
      users.map((u) => [u.id, u.employee?.generalInfo?.fullName?.trim() || u.username || u.id]),
    );

    return {
      totalLogs,
      todayLogs,
      activeEmployeesWithLogs: empGroups.length,
      topTables: tableGroups.map((t) => ({
        tableName: t.tableName,
        label: TABLE_LABELS[t.tableName] || formatFieldLabel(t.tableName),
        count: t._count.id,
      })),
      topChangers: userGroups.map((u) => ({
        userId: u.changedBy,
        name: userNameMap.get(u.changedBy) || u.changedBy,
        count: u._count.id,
      })),
    };
  },

  /**
   * Superadmin Tier 1: Lists all Organizations with Company Admins and log stats.
   * "Admin > Employee wise in superadmin"
   */
  async listSuperadminHierarchy(): Promise<SuperadminTenantHierarchyDTO[]> {
    const orgs = await prisma.organization.findMany({
      where: { deletedAt: null },
      select: {
        id: true,
        name: true,
        code: true,
      },
      orderBy: { sortOrder: 'asc' },
    });

    // Batch load admins across all orgs
    const admins = await prisma.user.findMany({
      where: {
        deletedAt: null,
        OR: [
          { role: { name: { in: ['SYSTEM_ADMIN', 'SYSTEM_ADMINISTRATOR', 'ADMIN', 'IT_ADMIN'] } } },
          { companyAdminGranted: true },
        ],
      },
      select: {
        id: true,
        username: true,
        subOrganization: true,
        lastLoginAt: true,
        role: { select: { name: true } },
        employee: {
          select: {
            generalInfo: {
              select: {
                fullName: true,
                designation: true,
                organization: true,
                subOrganization: true,
              },
            },
          },
        },
      },
    });

    const hierarchy: SuperadminTenantHierarchyDTO[] = [];

    for (const org of orgs) {
      // Match admins for this organization
      const orgAdmins = admins.filter((a) => {
        const sub = (a.subOrganization || '').toLowerCase().trim();
        const empOrg = (a.employee?.generalInfo?.organization || '').toLowerCase().trim();
        const empSub = (a.employee?.generalInfo?.subOrganization || '').toLowerCase().trim();
        const orgName = org.name.toLowerCase().trim();
        const orgCode = org.code.toLowerCase().trim();

        return (
          sub === orgName ||
          sub === orgCode ||
          empOrg === orgName ||
          empSub === orgName ||
          empSub === orgCode
        );
      });

      // Scope employees & logs for this org
      const scope = await this.resolveTenantScope(undefined, org.id);
      const empCount = scope.employeeIds?.length ?? 0;

      let logCount = 0;
      let lastActivityAt: string | null = null;

      if (scope.employeeIds && scope.employeeIds.length > 0) {
        const [cnt, latest] = await Promise.all([
          prisma.auditLog.count({
            where: {
              OR: [
                { employeeId: { in: scope.employeeIds } },
                ...(scope.tenantUserIds && scope.tenantUserIds.length > 0
                  ? [{ changedBy: { in: scope.tenantUserIds } }]
                  : []),
              ],
            },
          }),
          prisma.auditLog.findFirst({
            where: {
              OR: [
                { employeeId: { in: scope.employeeIds } },
                ...(scope.tenantUserIds && scope.tenantUserIds.length > 0
                  ? [{ changedBy: { in: scope.tenantUserIds } }]
                  : []),
              ],
            },
            orderBy: { changedAt: 'desc' },
            select: { changedAt: true },
          }),
        ]);

        logCount = cnt;
        lastActivityAt = latest?.changedAt?.toISOString() ?? null;
      }

      hierarchy.push({
        organizationId: org.id,
        organizationName: org.name,
        organizationCode: org.code,
        admins: orgAdmins.map((adm) => ({
          id: adm.id,
          username: adm.username ?? adm.id,
          fullName: adm.employee?.generalInfo?.fullName ?? adm.username ?? 'Admin',
          roleName: adm.role?.name ?? 'Admin',
          designation: adm.employee?.generalInfo?.designation ?? null,
          lastLoginAt: adm.lastLoginAt ? adm.lastLoginAt.toISOString() : null,
        })),
        totalEmployees: empCount,
        totalLogs: logCount,
        lastActivityAt,
      });
    }

    // Sort orgs by log count desc, then name
    return hierarchy.sort((a, b) => b.totalLogs - a.totalLogs || a.organizationName.localeCompare(b.organizationName));
  },
};
