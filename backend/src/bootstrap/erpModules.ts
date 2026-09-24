import bcrypt from 'bcryptjs';
import { prisma } from '../config/prisma';

export interface SystemSubmoduleDef {
  key: string;
  name: string;
  description: string;
  category: 'HRMS' | 'CRM' | 'ERP' | 'COLLABORATION';
  sortOrder: number;
}

export const SYSTEM_SUBMODULES: SystemSubmoduleDef[] = [
  // ── ERP MODULE ────────────────────────────────────────────────────────────
  {
    key: 'PROJECTS',
    name: 'Projects & Sites',
    description: 'Sites under development — add and manage project structures, towers, and units',
    category: 'ERP',
    sortOrder: 1,
  },
  {
    key: 'WORK_ORDERS',
    name: 'Work Orders',
    description: 'Create, issue, track, and complete contractor work orders',
    category: 'ERP',
    sortOrder: 2,
  },
  {
    key: 'DPR',
    name: 'Daily Progress Reports (DPR)',
    description: 'Daily progress tracking — tasks, consumed materials, labour count, and machinery hours',
    category: 'ERP',
    sortOrder: 3,
  },
  {
    key: 'STORE',
    name: 'Store & Inventory',
    description: 'Material inward/outward stock register, issue/return slips, and machine equipment logs',
    category: 'ERP',
    sortOrder: 4,
  },
  {
    key: 'BOQ',
    name: 'Bill of Quantities (BOQ)',
    description: 'Bill of quantities — line items, materials, machine rates, and labour estimations',
    category: 'ERP',
    sortOrder: 5,
  },
  {
    key: 'TENDERS',
    name: 'Tenders & Bidding',
    description: 'Draft, publish, and manage competitive tenders against project BOQ items',
    category: 'ERP',
    sortOrder: 6,
  },
  {
    key: 'TENDER_APPLICATIONS',
    name: 'Tender Applications',
    description: 'Review contractor proposals, bids, and award tender contracts',
    category: 'ERP',
    sortOrder: 7,
  },
  {
    key: 'CONTRACTORS',
    name: 'Vendors',
    description: 'Vendor profiles (Agency / Contractor / Supplier), contact info, banking, and documents',
    category: 'ERP',
    sortOrder: 8,
  },
  {
    key: 'PURCHASE',
    name: 'Purchase',
    description: 'Purchase request approvals and approved requests ready for purchasing',
    category: 'ERP',
    sortOrder: 9,
  },
  {
    key: 'ERP_CONFIGURATIONS',
    name: 'ERP Configurations',
    description: 'Work activities catalog, machinery master, and standard labour wage rates',
    category: 'ERP',
    sortOrder: 10,
  },

  // ── CRM MODULE ────────────────────────────────────────────────────────────
  {
    key: 'CRM',
    name: 'Pre-Sales & Leads',
    description: 'Lead management pipeline, calls, follow-ups, and lead conversion workflow',
    category: 'CRM',
    sortOrder: 1,
  },
  {
    key: 'CRM_PRE_SALES',
    name: 'CRM Pre-Sales (Nav)',
    description: 'Same as Pre-Sales & Leads — used by mobile/web CRM navigation',
    category: 'CRM',
    sortOrder: 1,
  },
  {
    key: 'CRM_DASHBOARD',
    name: 'CRM Analytics Dashboard',
    description: 'Sales conversion KPIs, agent call stats, and lead volume analytics',
    category: 'CRM',
    sortOrder: 2,
  },
  {
    key: 'CRM_HEADERS',
    name: 'Pipeline Stages & Headers',
    description: 'Customize dynamic pipeline stages, headers, and lead metadata columns',
    category: 'CRM',
    sortOrder: 3,
  },
  {
    key: 'CRM_POST_SALES',
    name: 'Post-Sales & Bookings',
    description: 'Customer bookings, unit allocations, payment milestones, and handover tracking',
    category: 'CRM',
    sortOrder: 4,
  },
  {
    key: 'CRM_SETTINGS',
    name: 'CRM Settings & Integrations',
    description: 'Telephony webhooks, campaign tokens, Excel import templates, and CRM configurations',
    category: 'CRM',
    sortOrder: 5,
  },
  {
    key: 'CRM_BIN',
    name: 'Recycle Bin',
    description: 'Archived and soft-deleted leads with restore or permanent deletion capability',
    category: 'CRM',
    sortOrder: 6,
  },

  // ── HRMS MODULE ───────────────────────────────────────────────────────────
  {
    key: 'PERSONAL_INFO',
    name: 'Profile › General & Workforce',
    description: 'Profile General tab + employee directory / workforce visibility scope',
    category: 'HRMS',
    sortOrder: 1,
  },
  {
    key: 'PROFILE_GENERAL',
    name: 'Profile › General',
    description: 'Profile General tab (identity, designation, org)',
    category: 'HRMS',
    sortOrder: 2,
  },
  {
    key: 'PROFILE_PERSONAL',
    name: 'Profile › Personal',
    description: 'Profile Personal tab (DOB, gender, contacts)',
    category: 'HRMS',
    sortOrder: 3,
  },
  {
    key: 'PROFILE_ADDRESS',
    name: 'Profile › Address',
    description: 'Profile Address tab (present / permanent address)',
    category: 'HRMS',
    sortOrder: 4,
  },
  {
    key: 'PROFILE_OTHER',
    name: 'Profile › Other',
    description: 'Profile Other tab (extra personal fields)',
    category: 'HRMS',
    sortOrder: 5,
  },
  {
    key: 'PROFILE_FAMILY',
    name: 'Profile › Family',
    description: 'Profile Family tab (dependents / emergency contacts)',
    category: 'HRMS',
    sortOrder: 6,
  },
  {
    key: 'EDUCATION',
    name: 'Profile › Academic',
    description: 'Academic records, qualifications, degrees, and certificates',
    category: 'HRMS',
    sortOrder: 7,
  },
  {
    key: 'EXPERIENCE',
    name: 'Profile › Experience',
    description: 'Previous employers, designations, and professional employment history',
    category: 'HRMS',
    sortOrder: 8,
  },
  {
    key: 'DOCUMENTS',
    name: 'Profile › Documents',
    description: 'Employee documents, letters, and file uploads',
    category: 'HRMS',
    sortOrder: 9,
  },
  {
    key: 'BANK_DETAILS',
    name: 'Profile › Bank',
    description: 'Bank account details for salary credit',
    category: 'HRMS',
    sortOrder: 10,
  },
  {
    key: 'SALARY',
    name: 'Profile › Salary',
    description: 'Employee profile salary tab (structures / payslips). Does not control Payroll nav — use PAYROLL for that.',
    category: 'HRMS',
    sortOrder: 11,
  },
  {
    key: 'PROFILE_ATTENDANCE',
    name: 'Profile › Attendance',
    description: 'Attendance tab inside employee profile',
    category: 'HRMS',
    sortOrder: 12,
  },
  {
    key: 'LEAVE',
    name: 'Leave Management',
    description: 'Leave balances, applications, multi-level approvals, policies, and holiday calendar',
    category: 'HRMS',
    sortOrder: 20,
  },
  {
    key: 'ATTENDANCE',
    name: 'Attendance Management',
    description: 'Daily check-in punches, live tracking, biometric sync, and attendance regularization',
    category: 'HRMS',
    sortOrder: 21,
  },
  {
    key: 'PAYROLL',
    name: 'Payroll Processing',
    description: 'Monthly payroll generation, allowances, deductions, and salary disbursement (HR Payroll menu)',
    category: 'HRMS',
    sortOrder: 22,
  },
  {
    key: 'REIMBURSEMENTS',
    name: 'Reimbursements',
    description: 'Employee expense claims, receipt attachments, approval workflow, and settlement',
    category: 'HRMS',
    sortOrder: 23,
  },
  {
    key: 'RECRUITMENT',
    name: 'Recruitment & ATS',
    description: 'Job openings, applicant pipeline, candidate interview ratings, and offers',
    category: 'HRMS',
    sortOrder: 24,
  },
  {
    key: 'REPORTS',
    name: 'Reports & Analytics',
    description: 'HR analytics, headcounts, and workforce reports',
    category: 'HRMS',
    sortOrder: 25,
  },
  {
    key: 'USER_MGMT',
    name: 'User Management',
    description: 'System logins, credentials, and password resets',
    category: 'HRMS',
    sortOrder: 26,
  },
  {
    key: 'ROLE_MGMT',
    name: 'Roles & Permission Matrix',
    description: 'Designation roles, permission matrix configuration, and access control levels',
    category: 'HRMS',
    sortOrder: 27,
  },
  {
    key: 'FIELD_MGMT',
    name: 'Configurations & Lookups',
    description: 'Institutes, departments, designations, and dynamic dropdown options',
    category: 'HRMS',
    sortOrder: 28,
  },
  {
    key: 'REPOSITORY',
    name: 'Company Repository',
    description: 'Shared company handbook, HR policies, code of conduct, and downloadable assets',
    category: 'HRMS',
    sortOrder: 29,
  },
  {
    key: 'GOOGLE_EARTH',
    name: 'NB Earth',
    description: '3D globe property inventory, satellite map, price history, and Earth dashboard trends',
    category: 'HRMS',
    sortOrder: 30,
  },
  {
    key: 'TASKS',
    name: 'Tasks & Projects Hub',
    description: 'Employee task assignments, subtasks, deadlines, and interactive Gantt charts',
    category: 'COLLABORATION',
    sortOrder: 1,
  },
  {
    key: 'CHAT',
    name: 'Chat & Collaboration',
    description: '1:1 direct messages, group channels, document sharing, and presence',
    category: 'COLLABORATION',
    sortOrder: 2,
  },
  {
    key: 'MEETINGS',
    name: 'Meetings & Video Calls',
    description: 'Real-time audio/video calls, screen sharing, meeting schedules, and recordings',
    category: 'COLLABORATION',
    sortOrder: 3,
  },
  {
    key: 'ORG_TREE',
    name: 'Org Chart & Tree',
    description: 'Organizational hierarchy, reporting leads, and employee reporting trees',
    category: 'COLLABORATION',
    sortOrder: 4,
  },
  {
    key: 'SUPPORT',
    name: 'IT Support Tickets',
    description: 'Employee IT helpdesk tickets, ETA tracking, resolve confirmation, and force-close',
    category: 'COLLABORATION',
    sortOrder: 5,
  },
];

const FULL = {
  canRead: true,
  canWrite: true,
  canApprove: true,
  canDelete: true,
  canExport: true,
};

const EMPLOYEE_RO = {
  canRead: true,
  canWrite: false,
  canApprove: false,
  canDelete: false,
  canExport: false,
};

/**
 * Idempotent: ensures all HRMS, CRM, and ERP system modules exist in DB
 * with their category, sort order, and administrator permissions.
 */
export async function ensureErpModulePermissions(): Promise<void> {
  // Ensure DB columns exist
  try {
    await prisma.$executeRawUnsafe(`
      ALTER TABLE "system_modules" ADD COLUMN IF NOT EXISTS "category" TEXT NOT NULL DEFAULT 'HRMS',
      ADD COLUMN IF NOT EXISTS "sort_order" INTEGER NOT NULL DEFAULT 0;
    `);
  } catch (err) {
    // Ignore if already present
  }

  // Seed / update all submodules
  for (const mod of SYSTEM_SUBMODULES) {
    try {
      await prisma.$executeRawUnsafe(
        `
        INSERT INTO "system_modules" ("id", "key", "name", "description", "category", "sort_order", "is_active", "created_at")
        VALUES (gen_random_uuid(), $1, $2, $3, $4, $5, true, NOW())
        ON CONFLICT ("key") DO UPDATE SET
          "name" = EXCLUDED."name",
          "description" = COALESCE(EXCLUDED."description", "system_modules"."description"),
          "category" = EXCLUDED."category",
          "sort_order" = EXCLUDED."sort_order",
          "is_active" = true;
      `,
        mod.key,
        mod.name,
        mod.description,
        mod.category,
        mod.sortOrder,
      );
    } catch {
      // Fallback to prisma upsert
      await prisma.systemModule.upsert({
        where: { key: mod.key },
        update: {
          name: mod.name,
          description: mod.description,
          category: mod.category,
          sortOrder: mod.sortOrder,
        },
        create: {
          key: mod.key,
          name: mod.name,
          description: mod.description,
          category: mod.category,
          sortOrder: mod.sortOrder,
        },
      });
    }
  }

  // Mirror CRM → CRM_PRE_SALES so CRM nav works for roles already granted CRM.
  try {
    const crmRows = await prisma.rolePermission.findMany({ where: { moduleKey: 'CRM' } });
    for (const row of crmRows) {
      await prisma.rolePermission.upsert({
        where: { roleId_moduleKey: { roleId: row.roleId, moduleKey: 'CRM_PRE_SALES' } },
        create: {
          roleId: row.roleId,
          moduleKey: 'CRM_PRE_SALES',
          canRead: row.canRead,
          canWrite: row.canWrite,
          canApprove: row.canApprove,
          canDelete: row.canDelete,
          canExport: row.canExport,
          employeeViewScope: row.employeeViewScope,
        },
        update: {
          canRead: row.canRead,
          canWrite: row.canWrite,
          canApprove: row.canApprove,
          canDelete: row.canDelete,
          canExport: row.canExport,
        },
      });
    }
  } catch {
    // ignore mirror failures on fresh DBs
  }

  // Seed Profile tab modules for roles that already have PERSONAL_INFO READ
  // so existing employees keep seeing their profile tabs until admins tighten RBAC.
  try {
    const profileTabKeys = [
      'PROFILE_GENERAL',
      'PROFILE_PERSONAL',
      'PROFILE_ADDRESS',
      'PROFILE_OTHER',
      'PROFILE_FAMILY',
      'PROFILE_ATTENDANCE',
    ] as const;
    const personalRows = await prisma.rolePermission.findMany({
      where: { moduleKey: 'PERSONAL_INFO', canRead: true },
    });
    for (const row of personalRows) {
      for (const key of profileTabKeys) {
        const existing = await prisma.rolePermission.findUnique({
          where: { roleId_moduleKey: { roleId: row.roleId, moduleKey: key } },
        });
        if (existing) continue;
        await prisma.rolePermission.create({
          data: {
            roleId: row.roleId,
            moduleKey: key,
            canRead: row.canRead,
            canWrite: row.canWrite,
            canApprove: false,
            canDelete: false,
            canExport: false,
          },
        });
      }
    }
  } catch {
    // ignore
  }

  // ── Core Administrative & System Roles ─────────────────────────────────
  const superAdminRole = await prisma.role.upsert({
    where: { name: 'SUPERADMIN' },
    update: { isSystem: true, isActive: true },
    create: {
      name: 'SUPERADMIN',
      description: 'Super Administrator with supreme authority over system administrators, administrative roles, and system configuration',
      isSystem: true,
      isActive: true,
    },
  });

  const adminRole = await prisma.role.upsert({
    where: { name: 'ADMIN' },
    update: { isSystem: true, isActive: true },
    create: {
      name: 'ADMIN',
      description: 'Company System Administrator — capabilities controlled per company by Superadmin',
      isSystem: true,
      isActive: true,
    },
  });

  // Migrate any users currently assigned to obsolete SYSTEM_ADMIN or SYSTEM_ADMINISTRATOR roles to ADMIN
  const obsoleteRoles = await prisma.role.findMany({
    where: { name: { in: ['SYSTEM_ADMIN', 'SYSTEM_ADMINISTRATOR', 'SYSTEMADMIN'] } },
    select: { id: true, name: true },
  });
  if (obsoleteRoles.length > 0) {
    const obsoleteIds = obsoleteRoles.map((r) => r.id);
    await prisma.user.updateMany({
      where: { roleId: { in: obsoleteIds } },
      data: { roleId: adminRole.id },
    });
    // Mark obsolete duplicate roles inactive so they never appear in admin > roles
    await prisma.role.updateMany({
      where: { id: { in: obsoleteIds } },
      data: { isActive: false, isSystem: false },
    });
  }

  const emp = await prisma.role.upsert({
    where: { name: 'EMPLOYEE' },
    update: { isSystem: true, isActive: true },
    create: {
      name: 'EMPLOYEE',
      description: 'Default employee permissions',
      isSystem: true,
      isActive: true,
    },
  });

  const elevated = await prisma.role.findMany({
    where: { name: { in: ['HR', 'HR_MANAGER'] } },
  });

  const allKeys = SYSTEM_SUBMODULES.map((m) => m.key);

  // Grant full permissions across all submodules to SUPERADMIN only.
  // Tenant ADMIN capabilities come from OrganizationAdminPermission (per company).
  for (const role of [superAdminRole, ...elevated]) {
    for (const moduleKey of allKeys) {
      await prisma.rolePermission.upsert({
        where: { roleId_moduleKey: { roleId: role.id, moduleKey } },
        update: FULL,
        create: { roleId: role.id, moduleKey, ...FULL },
      });
    }
  }

  // Backfill per-company admin matrices for orgs that have none yet
  try {
    const { orgAdminPermissionService } = await import('../modules/platform/org-admin-permission.service');
    const { parseModules } = await import('../modules/platform/platform.service');
    const orgs = await prisma.organization.findMany({
      where: { deletedAt: null },
      select: { id: true, tagLine: true },
    });
    for (const org of orgs) {
      const count = await prisma.organizationAdminPermission.count({
        where: { organizationId: org.id },
      });
      if (count === 0) {
        await orgAdminPermissionService.seedForOrganization(
          org.id,
          parseModules(org.tagLine),
        );
      } else {
        const enabled = parseModules(org.tagLine);
        if (enabled.map((e) => e.toUpperCase()).includes('HRMS')) {
          await prisma.organizationAdminPermission.upsert({
            where: {
              organizationId_moduleKey: {
                organizationId: org.id,
                moduleKey: 'GOOGLE_EARTH',
              },
            },
            update: {},
            create: {
              organizationId: org.id,
              moduleKey: 'GOOGLE_EARTH',
              canRead: true,
              canWrite: true,
              canApprove: true,
              canDelete: true,
              canExport: true,
            },
          });
        }
        // SUPPORT was added after many orgs already had a matrix — always ensure it exists
        // (Collaboration is licensed for every company).
        await prisma.organizationAdminPermission.upsert({
          where: {
            organizationId_moduleKey: {
              organizationId: org.id,
              moduleKey: 'SUPPORT',
            },
          },
          update: {
            canRead: true,
            canWrite: true,
            canApprove: true,
            canDelete: true,
            canExport: true,
          },
          create: {
            organizationId: org.id,
            moduleKey: 'SUPPORT',
            canRead: true,
            canWrite: true,
            canApprove: true,
            canDelete: true,
            canExport: true,
          },
        });
      }
    }
  } catch (err) {
    console.warn('Org admin permission backfill skipped:', err);
  }

  // 1. Ensure dedicated Platform SUPERADMIN user (The CRM Product Owner)
  try {
    const existingSuperadmin = await prisma.user.findUnique({
      where: { username: 'superadmin' },
      select: { id: true, passwordHash: true },
    });

    if (!existingSuperadmin) {
      const defaultHash = await bcrypt.hash('01011998', 12);
      await prisma.user.create({
        data: {
          username: 'superadmin',
          roleId: superAdminRole.id,
          passwordHash: defaultHash,
          isActive: true,
          isFirstLogin: false,
        },
      });
    } else {
      await prisma.user.update({
        where: { id: existingSuperadmin.id },
        data: {
          roleId: superAdminRole.id,
          isActive: true,
          // Never overwrite existing password! Only populate if missing
          ...(existingSuperadmin.passwordHash
            ? {}
            : { passwordHash: await bcrypt.hash('01011998', 12) }),
        },
      });
    }

    // 2. Ensure Client Company SYSTEM_ADMIN user (Initial company admin)
    const companyAdmin = await prisma.user.findFirst({
      where: {
        OR: [
          { employeeId: 1 },
          { username: 'admin' },
        ],
      },
      select: { id: true, username: true, subOrganization: true, passwordHash: true },
    });

    const existingOrg = await prisma.organization.findFirst();
    const org = existingOrg ?? await prisma.organization.create({
      data: {
        code: 'NB_CORP',
        name: 'NB Solutions Corp',
        contactPerson: 'Admin User',
        email: 'admin@nbsolutions.com',
        mobileNo: '9876543210',
        tagLine: JSON.stringify(['HRMS', 'CRM', 'ERP']),
        isActive: true,
      },
    });

    if (companyAdmin && companyAdmin.username !== 'superadmin') {
      await prisma.user.update({
        where: { id: companyAdmin.id },
        data: {
          roleId: adminRole.id,
          username: 'admin',
          subOrganization: companyAdmin.subOrganization || org.name,
          isActive: true,
          // Never overwrite existing password! Only populate if missing
          ...(companyAdmin.passwordHash
            ? {}
            : { passwordHash: await bcrypt.hash('01011998', 12) }),
        },
      });
    }
  } catch (err) {
    console.warn('Superadmin and System Admin user alignment notice:', err);
  }

  // Default permissions for EMPLOYEE role
  if (emp) {
    for (const moduleKey of allKeys) {
      const isInteractive = [
        'CHAT',
        'MEETINGS',
        'CRM',
        'LEAVE',
        'REIMBURSEMENTS',
        'PERSONAL_INFO',
        'EDUCATION',
        'EXPERIENCE',
        'BANK_DETAILS',
        'DOCUMENTS',
        'TASKS',
        'SUPPORT',
      ].includes(moduleKey);

      const perms = isInteractive
        ? {
            canRead: true,
            canWrite: true,
            canApprove: false,
            canDelete: false,
            canExport: false,
          }
        : EMPLOYEE_RO;

      await prisma.rolePermission.upsert({
        where: { roleId_moduleKey: { roleId: emp.id, moduleKey } },
        // Always refresh SUPPORT so existing EMPLOYEE rows pick up RW after the module was added.
        update: moduleKey === 'SUPPORT' ? perms : {},
        create: { roleId: emp.id, moduleKey, ...perms },
      });
    }
  }

  // Backfill SUPPORT RW onto every employee-facing / designation role that already
  // has Chat, Leave, Tasks, or Reimbursements — so all staff see IT Support.
  try {
    const employeeFacing = await prisma.rolePermission.findMany({
      where: {
        canRead: true,
        moduleKey: { in: ['CHAT', 'LEAVE', 'TASKS', 'REIMBURSEMENTS', 'MEETINGS'] },
      },
      select: { roleId: true },
      distinct: ['roleId'],
    });
    const supportRw = {
      canRead: true,
      canWrite: true,
      canApprove: false,
      canDelete: false,
      canExport: false,
    };
    for (const { roleId } of employeeFacing) {
      // Do not downgrade SUPERADMIN / HR full grants.
      const existing = await prisma.rolePermission.findUnique({
        where: { roleId_moduleKey: { roleId, moduleKey: 'SUPPORT' } },
      });
      if (existing?.canApprove || existing?.canDelete) continue;
      await prisma.rolePermission.upsert({
        where: { roleId_moduleKey: { roleId, moduleKey: 'SUPPORT' } },
        create: { roleId, moduleKey: 'SUPPORT', ...supportRw },
        update: {
          canRead: true,
          canWrite: true,
        },
      });
    }
  } catch (err) {
    console.warn('SUPPORT role backfill skipped:', err);
  }

  try {
    const { invalidateOrgAdminPermissionCache, invalidateRolePermissionCache } =
      await import('../modules/auth/permissions-map');
    invalidateOrgAdminPermissionCache();
    invalidateRolePermissionCache();
  } catch {
    // cache helpers optional
  }
}
