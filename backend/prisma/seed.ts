import { PrismaClient } from '@prisma/client';
import bcrypt from 'bcryptjs';
import { seedSalaryCatalog } from './seeds/designationSalary.seed';
import { seedSystemLookups } from './seeds/lookups.seed';
import { seedInstitutes } from './seeds/institutes.seed';

const prisma = new PrismaClient();

// ---------------------------------------------------------------------------
// Module definitions
// ---------------------------------------------------------------------------
const MODULES = [
  { key: 'PERSONAL_INFO', name: 'Personal Information' },
  { key: 'EDUCATION',     name: 'Education & Qualifications' },
  { key: 'EXPERIENCE',    name: 'Work Experience' },
  { key: 'LEAVE',         name: 'Leave Management' },
  { key: 'PAYROLL',       name: 'Payroll' },
  { key: 'SALARY',        name: 'Salary Management' },
  { key: 'ATTENDANCE',    name: 'Attendance' },
  { key: 'BANK_DETAILS',  name: 'Bank Details' },
  { key: 'DOCUMENTS',     name: 'Document Management' },
  { key: 'REIMBURSEMENTS', name: 'Reimbursements' },
  { key: 'RECRUITMENT',   name: 'Recruitment' },
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

  EMPLOYEE: {
    PERSONAL_INFO: RW,
    EDUCATION:     RW,
    EXPERIENCE:    RW,
    LEAVE:         { canRead: true, canWrite: true, canApprove: false, canDelete: false, canExport: false },
    REIMBURSEMENTS:{ canRead: true, canWrite: true, canApprove: false, canDelete: false, canExport: false },
    RECRUITMENT:   RO,
    ATTENDANCE:    RO,
    BANK_DETAILS:  RW,
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

  // ── Roles (ADMIN + default EMPLOYEE; others come from designations) ─────
  console.log('⏳  Seeding roles…');
  const ROLES = [
    { name: 'ADMIN',    description: 'Full system access', isSystem: true },
    { name: 'EMPLOYEE', description: 'Default employee permissions', isSystem: true },
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

  const workforceScopeByRole: Record<string, 'UNIVERSITY' | 'INSTITUTE' | 'SELF' | 'NONE'> = {
    ADMIN: 'UNIVERSITY',
    EMPLOYEE: 'SELF',
  };
  for (const [roleName, employeeViewScope] of Object.entries(workforceScopeByRole)) {
    const roleId = roleIdMap[roleName];
    if (!roleId) continue;
    await prisma.rolePermission.updateMany({
      where: { roleId, moduleKey: 'PERSONAL_INFO' },
      data: { employeeViewScope },
    });
  }

  await seedSystemLookups(prisma);
  await seedInstitutes(prisma);
  // Pay commissions / salary column catalog only (no institutes, no designations)
  await seedSalaryCatalog(prisma);

  // ── Leave Settings (catalog empty — configure leave types in UI) ─────────
  console.log('⏳  Seeding leave settings…');
  const leaveSettings = [
    {
      key: 'absence_window_hours',
      value: '48',
      description: 'Hours employee has to apply after absence (null = infinite)',
    },
    {
      key: 'approver_window_hours',
      value: '48',
      description: 'Fallback window hours if role-specific window is not set',
    },
    {
      key: 'hod_window_hours',
      value: '48',
      description: 'Hours HOD has to recommend/reject before timeout',
    },
    {
      key: 'hoi_window_hours',
      value: '48',
      description: 'Hours HOI has to recommend/reject before timeout',
    },
    {
      key: 'global_window_hours',
      value: '72',
      description: 'Hours Vice Chancellor/Registrar have to approve/reject before timeout',
    },
    {
      key: 'approver_timeout_action',
      value: 'escalate',
      description: 'On approver timeout: escalate or reject',
    },
    {
      key: 'yearend_processing_date',
      value: '12-31',
      description: 'Year-end processing date (MM-DD)',
    },
    {
      key: 'new_year_credit_date',
      value: '01-01',
      description: 'New year credit date (MM-DD)',
    },
    {
      key: 'mid_year_credit_date',
      value: '07-01',
      description: 'Mid year credit date (MM-DD)',
    },
    {
      key: 'lwp_auto_apply',
      value: 'true',
      description: 'Auto apply LWP after absence window expiry',
    },
  ] as const;

  for (const s of leaveSettings) {
    await prisma.leaveSetting.upsert({
      where: { key: s.key },
      update: { value: s.value, description: s.description, updatedBy: 'seed' },
      create: { ...s, updatedBy: 'seed' },
    });
  }
  console.log(`✅  ${leaveSettings.length} leave settings seeded (leave types: configure in app)`);

  // ── Attendance Policy (default punch timing rules) ─────────────────────────
  console.log('⏳  Seeding attendance policy…');
  await prisma.attendancePolicy.upsert({
    where: { id: 'default' },
    update: {},
    create: {
      id: 'default',
      defaultPunchInTime: '09:00',
      defaultPunchOutTime: '15:30',
      punchInBufferMinutes: 10,
      punchOutBufferMinutes: 10,
      updatedBy: 'seed',
    },
  });
  console.log('✅  Attendance policy seeded');

  // ── Letters templates ──────────────────────────────────────────────────
  console.log('⏳  Seeding letter templates…');
  const letterPlaceholders = [
    'fullName',
    'employeeCode',
    'designation',
    'department',
    'organization',
    'instituteName',
    'subOrganization',
    'joiningDate',
    'birthDate',
    'aadhaarNo',
    'panNo',
    'passportNo',
    'passportIssueDate',
    'passportExpiryDate',
    'todayDate',
  ];

  const letterTemplates = [
    {
      key: 'offer_letter',
      name: 'Offer Letter',
      description: 'Default offer letter template',
      templateHtml: `
<div>
  <div style="margin-bottom: 16px;">{{todayDate}}</div>
  <p>Dear <b>{{fullName}}</b>,</p>
  <p>
    We are pleased to offer you the position of <b>{{designation}}</b> in <b>{{department}}</b>,
    {{organization}}.
  </p>
  <p>
    Joining date: <b>{{joiningDate}}</b>
  </p>
  <p>Sincerely,</p>
  <p>HR Department</p>
</div>`.trim(),
    },
    {
      key: 'lor_recommendation_letter',
      name: 'LOR / Recommendation Letter',
      description: 'Default recommendation letter template',
      templateHtml: `
<div>
  <div style="margin-bottom: 16px;">{{todayDate}}</div>
  <p>To Whom It May Concern,</p>
  <p>
    This letter is to recommend <b>{{fullName}}</b> (Employee Code: <b>{{employeeCode}}</b>)
    for their professional contributions at {{organization}}.
  </p>
  <p>
    Designation: <b>{{designation}}</b> | Department: <b>{{department}}</b>
  </p>
  <p>Sincerely,</p>
  <p>Authorized Signatory</p>
</div>`.trim(),
    },
    {
      key: 'exit_letter',
      name: 'Exit Letter',
      description: 'Default exit letter template',
      templateHtml: `
<div>
  <div style="margin-bottom: 16px;">{{todayDate}}</div>
  <p>Dear <b>{{fullName}}</b>,</p>
  <p>
    This is to confirm your exit from {{organization}} as per the applicable terms.
  </p>
  <p>
    Employee Code: <b>{{employeeCode}}</b><br/>
    Designation: <b>{{designation}}</b>
  </p>
  <p>Sincerely,</p>
  <p>HR Department</p>
</div>`.trim(),
    },
  ];

  for (const t of letterTemplates) {
    await prisma.letterTemplate.upsert({
      where: { key: t.key },
      update: {
        name: t.name,
        description: t.description,
        templateHtml: t.templateHtml,
        placeholders: letterPlaceholders,
        updatedBy: 'seed',
      },
      create: {
        key: t.key,
        name: t.name,
        description: t.description,
        templateHtml: t.templateHtml,
        placeholders: letterPlaceholders,
        updatedBy: 'seed',
      },
    });
  }
  console.log(`✅  ${letterTemplates.length} letter templates seeded`);

  // ── Admin employee + user ──────────────────────────────────────────────
  console.log('⏳  Seeding admin employee & user…');

  await prisma.employee.upsert({
    where:  { id: 1 },
    update: {},
    create: {
      id:           1,
      abbreviation: 'ADM',
      userId:       'pending-admin',
      status:       'ACTIVE',
    },
  });

  await prisma.employeeGeneralInfo.upsert({
    where: { employeeId: 1 },
    update: {
      fullName: 'SYSTEM ADMIN',
      designation: 'SYSTEM ADMINISTRATOR',
      department: 'IT DEPARTMENT',
    },
    create: {
      employeeId: 1,
      fullName: 'SYSTEM ADMIN',
      organization: 'GANDHINAGAR UNIVERSITY',
      department: 'IT DEPARTMENT',
      employeeCategory: 'NON_TEACHING',
      designation: 'SYSTEM ADMINISTRATOR',
      joiningDate: new Date('2020-01-01'),
      originalJoiningDate: new Date('2020-01-01'),
    },
  });

  const adminRoleId = roleIdMap['ADMIN'];
  const defaultHash = await bcrypt.hash('01011998', 12);

  const adminUser = await prisma.user.upsert({
    where:  { employeeId: 1 },
    update: {
      passwordHash: defaultHash,
      roleId: adminRoleId,
      isActive: true,
      isFirstLogin: false,
    },
    create: {
      employeeId:   1,
      roleId:       adminRoleId,
      passwordHash: defaultHash,
      isFirstLogin: false,
    },
  });

  await prisma.employee.update({
    where: { id: 1 },
    data:  { userId: adminUser.id },
  });

  try {
    await prisma.$executeRawUnsafe(
      "SELECT setval('employees_id_seq', (SELECT MAX(id) FROM employees))",
    );
  } catch (err: unknown) {
    const msg = err instanceof Error ? err.message : String(err);
    console.warn('⚠️  Could not reset sequences (non-critical):', msg);
  }

  console.log('✅  Admin user seeded');
  console.log('');
  console.log('════════════════════════════════════════════════════════');
  console.log(' Clean slate seed (admin only — no demo data)');
  console.log(' Admin login : employeeId = 1');
  console.log(' Password    : 01011998');
  console.log(' Roles       : ADMIN + EMPLOYEE (add designations → roles in app)');
  console.log(' Configure   : institutes, designations, leave types,');
  console.log('               employees via the app');
  console.log('════════════════════════════════════════════════════════');
}

main()
  .catch((e) => { console.error(e); process.exit(1); })
  .finally(() => prisma.$disconnect());
