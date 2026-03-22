import { PrismaClient } from '@prisma/client';
import bcrypt from 'bcryptjs';

const prisma = new PrismaClient();

// ---------------------------------------------------------------------------
// Module definitions
// ---------------------------------------------------------------------------
const MODULES = [
  { key: 'PERSONAL_INFO', name: 'Personal Information' },
  { key: 'EDUCATION',     name: 'Education & Qualifications' },
  { key: 'LEAVE',         name: 'Leave Management' },
  { key: 'PAYROLL',       name: 'Payroll' },
  { key: 'SALARY',        name: 'Salary Management' },
  { key: 'ATTENDANCE',    name: 'Attendance' },
  { key: 'BANK_DETAILS',  name: 'Bank Details' },
  { key: 'DOCUMENTS',     name: 'Document Management' },
  { key: 'REPORTS',       name: 'Reports & Analytics' },
  { key: 'USER_MGMT',     name: 'User Management' },
  { key: 'ROLE_MGMT',     name: 'Role Management' },
  { key: 'FIELD_MGMT',    name: 'Dynamic Field Management' },
];

// ---------------------------------------------------------------------------
// Helper permission sets
// ---------------------------------------------------------------------------
const FULL    = { canRead: true,  canWrite: true,  canApprove: true,  canDelete: true,  canExport: true  };
const RO      = { canRead: true,  canWrite: false, canApprove: false, canDelete: false, canExport: false };
const RW      = { canRead: true,  canWrite: true,  canApprove: false, canDelete: false, canExport: false };
const RA      = { canRead: true,  canWrite: false, canApprove: true,  canDelete: false, canExport: false };
const RX      = { canRead: true,  canWrite: false, canApprove: false, canDelete: false, canExport: true  };
const RAX     = { canRead: true,  canWrite: false, canApprove: true,  canDelete: false, canExport: true  };
const RWAX    = { canRead: true,  canWrite: true,  canApprove: true,  canDelete: false, canExport: true  };

type PermSet = { canRead: boolean; canWrite: boolean; canApprove: boolean; canDelete: boolean; canExport: boolean };

const ALL_KEYS = MODULES.map((m) => m.key);

type PermissionMatrix = Record<string, Record<string, PermSet>>;

const PERMISSION_MATRIX: PermissionMatrix = {
  ADMIN: Object.fromEntries(ALL_KEYS.map((k) => [k, FULL])),

  HOI: Object.fromEntries(ALL_KEYS.map((k) => [k, { ...RO, canApprove: true, canExport: true }])),

  HR: {
    PERSONAL_INFO: RWAX,
    EDUCATION:     RWAX,
    LEAVE:         RWAX,
    ATTENDANCE:    RX,
    BANK_DETAILS:  RO,
    DOCUMENTS:     { canRead: true, canWrite: true, canApprove: true, canDelete: false, canExport: false },
    REPORTS:       RX,
    PAYROLL:       RO,
    SALARY:        RO,
    USER_MGMT:     RO,
    ROLE_MGMT:     RO,
    FIELD_MGMT:    RW,
  },

  HOD: {
    PERSONAL_INFO: RO,
    EDUCATION:     RO,
    LEAVE:         { canRead: true, canWrite: false, canApprove: true, canDelete: false, canExport: true },
    ATTENDANCE:    RO,
    REPORTS:       RO,
  },

  FINANCE: {
    PAYROLL:      FULL,
    SALARY:       FULL,
    BANK_DETAILS: RO,
    REPORTS:      RX,
  },

  EMPLOYEE: {
    PERSONAL_INFO: RW,
    EDUCATION:     RW,
    LEAVE:         { canRead: true, canWrite: true, canApprove: false, canDelete: false, canExport: false },
    ATTENDANCE:    RO,
    BANK_DETAILS:  RO,
    DOCUMENTS:     RW,
  },
};

// ---------------------------------------------------------------------------
// Main
// ---------------------------------------------------------------------------
async function main() {
  console.log('⏳  Seeding system modules…');
  for (const mod of MODULES) {
    await prisma.systemModule.upsert({
      where:  { key: mod.key },
      update: {},
      create: mod,
    });
  }
  console.log(`✅  ${MODULES.length} modules seeded`);

  // ── Roles ──────────────────────────────────────────────────────────────
  console.log('⏳  Seeding roles…');
  const ROLES = [
    { name: 'ADMIN',    description: 'Full system access',                    isSystem: true },
    { name: 'HOI',      description: 'Head of Institution — Principal level', isSystem: true },
    { name: 'HR',       description: 'HR department staff',                   isSystem: true },
    { name: 'HOD',      description: 'Head of Department',                    isSystem: true },
    { name: 'FINANCE',  description: 'Finance department staff',              isSystem: true },
    { name: 'EMPLOYEE', description: 'Regular employee',                      isSystem: true },
  ];

  const roleIdMap: Record<string, string> = {};
  for (const role of ROLES) {
    const r = await prisma.role.upsert({
      where:  { name: role.name },
      update: {},
      create: role,
    });
    roleIdMap[role.name] = r.id;
  }
  console.log(`✅  ${ROLES.length} roles seeded`);

  // ── Permissions ────────────────────────────────────────────────────────
  console.log('⏳  Seeding permissions…');
  let permCount = 0;
  for (const [roleName, modulePerms] of Object.entries(PERMISSION_MATRIX)) {
    const roleId = roleIdMap[roleName];
    for (const [moduleKey, perms] of Object.entries(modulePerms)) {
      await prisma.rolePermission.upsert({
        where:  { roleId_moduleKey: { roleId, moduleKey } },
        update: perms,
        create: { roleId, moduleKey, ...perms },
      });
      permCount++;
    }
  }
  console.log(`✅  ${permCount} permission entries seeded`);

  // ── Admin employee + user ──────────────────────────────────────────────
  console.log('⏳  Seeding admin employee & user…');

  // Create / ensure Employee id=1 exists (placeholder userId updated below)
  await prisma.employee.upsert({
    where:  { id: 1 },
    update: {},
    create: {
      id:           1,
      abbreviation: 'ADM',
      userId:       'pending-admin',   // updated after User is created
      status:       'ACTIVE',
    },
  });

  const adminRoleId = roleIdMap['ADMIN'];

  // Default password: 01011990  (admin should change on first login)
  const defaultHash = await bcrypt.hash('01011990', 12);

  const adminUser = await prisma.user.upsert({
    where:  { employeeId: 1 },
    update: {},
    create: {
      employeeId:   1,
      roleId:       adminRoleId,
      passwordHash: defaultHash,
      isFirstLogin: true,
    },
  });

  // Backfill Employee.userId with the real User UUID
  await prisma.employee.update({
    where: { id: 1 },
    data:  { userId: adminUser.id },
  });

  console.log('✅  Admin user seeded');
  console.log('');
  console.log('═══════════════════════════════════════');
  console.log(' Login with:  employeeId = 1');
  console.log(' Password  :  01011990  (change on first login)');
  console.log('═══════════════════════════════════════');
}

main()
  .catch((e) => { console.error(e); process.exit(1); })
  .finally(() => prisma.$disconnect());
