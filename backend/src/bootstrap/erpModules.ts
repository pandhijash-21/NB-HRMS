import bcrypt from 'bcryptjs';
import { prisma } from '../config/prisma';

export interface SystemSubmoduleDef {
  key: string;
  name: string;
  description: string;
  category: 'HRMS' | 'CRM' | 'ERP';
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
    name: 'Contractors & Vendors',
    description: 'Approved contractor profiles, contact info, banking details, and documents',
    category: 'ERP',
    sortOrder: 8,
  },
  {
    key: 'ERP_CONFIGURATIONS',
    name: 'ERP Configurations',
    description: 'Work activities catalog, machinery master, and standard labour wage rates',
    category: 'ERP',
    sortOrder: 9,
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
    name: 'Personal Info & Workforce',
    description: 'Employee directory, profile master data, and workforce visibility scope',
    category: 'HRMS',
    sortOrder: 1,
  },
  {
    key: 'EDUCATION',
    name: 'Education & Qualifications',
    description: 'Academic records, qualifications, degrees, and certificates',
    category: 'HRMS',
    sortOrder: 2,
  },
  {
    key: 'EXPERIENCE',
    name: 'Work Experience',
    description: 'Previous employers, designations, and professional employment history',
    category: 'HRMS',
    sortOrder: 3,
  },
  {
    key: 'LEAVE',
    name: 'Leave Management',
    description: 'Leave balances, applications, multi-level approvals, policies, and holiday calendar',
    category: 'HRMS',
    sortOrder: 4,
  },
  {
    key: 'ATTENDANCE',
    name: 'Attendance Management',
    description: 'Daily check-in punches, live tracking, biometric sync, and attendance regularization',
    category: 'HRMS',
    sortOrder: 5,
  },
  {
    key: 'PAYROLL',
    name: 'Payroll Processing',
    description: 'Monthly payroll generation, allowances, deductions, and salary disbursement',
    category: 'HRMS',
    sortOrder: 6,
  },
  {
    key: 'SALARY',
    name: 'Salary Management',
    description: 'Salary structures, 5th/6th pay commission templates, and payslips',
    category: 'HRMS',
    sortOrder: 7,
  },
  {
    key: 'BANK_DETAILS',
    name: 'Bank Details',
    description: 'Employee banking info, account verification, and payment details',
    category: 'HRMS',
    sortOrder: 8,
  },
  {
    key: 'DOCUMENTS',
    name: 'Documents & Letters',
    description: 'Document archive, appointment letters, experience certificates, and NDAs',
    category: 'HRMS',
    sortOrder: 9,
  },
  {
    key: 'REIMBURSEMENTS',
    name: 'Reimbursements',
    description: 'Employee expense claims, receipt attachments, approval workflow, and settlement',
    category: 'HRMS',
    sortOrder: 10,
  },
  {
    key: 'RECRUITMENT',
    name: 'Recruitment & ATS',
    description: 'Job openings, applicant pipeline, candidate interview ratings, and offers',
    category: 'HRMS',
    sortOrder: 11,
  },
  {
    key: 'REPORTS',
    name: 'Reports & Analytics',
    description: 'HR analytics, headcounts, and workforce reports',
    category: 'HRMS',
    sortOrder: 12,
  },
  {
    key: 'USER_MGMT',
    name: 'User Management',
    description: 'System logins, credentials, and password resets',
    category: 'HRMS',
    sortOrder: 13,
  },
  {
    key: 'ROLE_MGMT',
    name: 'Roles & Permission Matrix',
    description: 'Designation roles, permission matrix configuration, and access control levels',
    category: 'HRMS',
    sortOrder: 14,
  },
  {
    key: 'FIELD_MGMT',
    name: 'Configurations & Lookups',
    description: 'Institutes, departments, designations, and dynamic dropdown options',
    category: 'HRMS',
    sortOrder: 15,
  },
  {
    key: 'REPOSITORY',
    name: 'Company Repository',
    description: 'Shared company handbook, HR policies, code of conduct, and downloadable assets',
    category: 'HRMS',
    sortOrder: 16,
  },
  {
    key: 'TASKS',
    name: 'Tasks & Projects Hub',
    description: 'Employee task assignments, subtasks, deadlines, and interactive Gantt charts',
    category: 'HRMS',
    sortOrder: 17,
  },
  {
    key: 'CHAT',
    name: 'Chat & Collaboration',
    description: '1:1 direct messages, group channels, document sharing, and presence',
    category: 'HRMS',
    sortOrder: 18,
  },
  {
    key: 'MEETINGS',
    name: 'Meetings & Video Calls',
    description: 'Real-time audio/video calls, screen sharing, meeting schedules, and recordings',
    category: 'HRMS',
    sortOrder: 19,
  },
  {
    key: 'ORG_TREE',
    name: 'Org Chart & Tree',
    description: 'Organizational hierarchy, reporting leads, and employee reporting trees',
    category: 'HRMS',
    sortOrder: 20,
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
        update: { name: mod.name, description: mod.description },
        create: { key: mod.key, name: mod.name, description: mod.description },
      });
    }
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

  const systemAdminRole = await prisma.role.upsert({
    where: { name: 'SYSTEM_ADMIN' },
    update: { isSystem: true, isActive: true },
    create: {
      name: 'SYSTEM_ADMIN',
      description: 'System Administrator with full freedom to manage RBAC, users, permissions, and all system modules',
      isSystem: true,
      isActive: true,
    },
  });

  const adminRole = await prisma.role.upsert({
    where: { name: 'ADMIN' },
    update: { isSystem: true, isActive: true },
    create: {
      name: 'ADMIN',
      description: 'Administrator role (alias for System Admin)',
      isSystem: true,
      isActive: true,
    },
  });

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

  // Grant full permissions across all submodules to SUPERADMIN, SYSTEM_ADMIN, ADMIN & elevated roles
  for (const role of [superAdminRole, systemAdminRole, adminRole, ...elevated]) {
    for (const moduleKey of allKeys) {
      await prisma.rolePermission.upsert({
        where: { roleId_moduleKey: { roleId: role.id, moduleKey } },
        update: FULL,
        create: { roleId: role.id, moduleKey, ...FULL },
      });
    }
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
          roleId: systemAdminRole.id,
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
        update: {},
        create: { roleId: emp.id, moduleKey, ...perms },
      });
    }
  }
}
