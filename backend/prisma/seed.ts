import { PrismaClient } from '@prisma/client';
import bcrypt from 'bcryptjs';
import { seedDesignationsAndSalaryCatalog } from './seeds/designationSalary.seed';

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

  // Final approvers in Leave workflow (step 3)
  VC: Object.fromEntries(ALL_KEYS.map((k) => [k, { ...RO, canApprove: true, canExport: true }])),
  REGISTRAR: Object.fromEntries(ALL_KEYS.map((k) => [k, { ...RO, canApprove: true, canExport: true }])),

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
    BANK_DETAILS:  RW,
    DOCUMENTS:     RW,
  },

  // Optional role aligned to Hasura spec language
  HR_MANAGER: {
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
    { name: 'VC',       description: 'Vice Chancellor',                       isSystem: true },
    { name: 'REGISTRAR',description: 'Registrar',                             isSystem: true },
    { name: 'HR_MANAGER', description: 'HR manager (alias role)',             isSystem: true },
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

  await seedDesignationsAndSalaryCatalog(prisma, roleIdMap);

  // ── Leave Settings + Types ───────────────────────────────────────────────
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
  console.log(`✅  ${leaveSettings.length} leave settings seeded`);

  console.log('⏳  Seeding leave types…');
  const leaveTypes = [
    {
      code: 'CL',
      name: 'Casual Leave',
      applicableTo: 'BOTH' as const,
      defaultDaysPerYear: 12,
      isCarryForward: false,
      allowHalfDay: true,
      skipPublicHolidays: true,
      skipWeekends: true,
      requiresDocument: false,
      requiresReason: true,
      employeeCanApply: true,
      creditSchedule: { credits: [{ month: 1, day: 1, days: 12 }] },
    },
    {
      code: 'SL',
      name: 'Sick Leave',
      applicableTo: 'BOTH' as const,
      defaultDaysPerYear: 10,
      isCarryForward: true,
      allowHalfDay: true,
      skipPublicHolidays: true,
      skipWeekends: true,
      requiresDocument: false,
      requiresReason: true,
      employeeCanApply: false,   // HR applies on behalf
      creditSchedule: { credits: [{ month: 1, day: 1, days: 5 }, { month: 7, day: 1, days: 5 }] },
    },
    {
      code: 'EL',
      name: 'Earned Leave',
      applicableTo: 'NON_TEACHING' as const,
      defaultDaysPerYear: 21,
      isCarryForward: true,
      allowHalfDay: true,
      skipPublicHolidays: true,
      skipWeekends: true,
      requiresDocument: false,
      requiresReason: true,
      employeeCanApply: false,   // HR applies on behalf
      creditSchedule: { credits: [{ month: 1, day: 1, days: 10 }, { month: 7, day: 1, days: 11 }] },
    },
    {
      code: 'DL',
      name: 'Duty Leave',
      applicableTo: 'BOTH' as const,
      defaultDaysPerYear: null,
      isCarryForward: false,
      allowHalfDay: true,
      skipPublicHolidays: true,
      skipWeekends: true,
      requiresDocument: true,
      requiresReason: true,
      employeeCanApply: true,
      creditSchedule: null,
    },
    {
      code: 'AL',
      name: 'Academic Leave',
      applicableTo: 'TEACHING' as const,
      defaultDaysPerYear: null,
      isCarryForward: false,
      allowHalfDay: true,
      skipPublicHolidays: true,
      skipWeekends: true,
      requiresDocument: false,
      requiresReason: true,
      employeeCanApply: true,
      creditSchedule: null,
    },
    {
      code: 'VL',
      name: 'Vacation Leave',
      applicableTo: 'TEACHING' as const,
      defaultDaysPerYear: 21,
      isCarryForward: false,
      allowHalfDay: true,
      skipPublicHolidays: true,
      skipWeekends: true,
      requiresDocument: false,
      requiresReason: true,
      employeeCanApply: true,
      creditSchedule: { credits: [{ month: 1, day: 1, days: 21 }] },
    },
    {
      code: 'LWP',
      name: 'Leave Without Pay',
      applicableTo: 'BOTH' as const,
      defaultDaysPerYear: null,
      isCarryForward: false,
      allowHalfDay: true,
      skipPublicHolidays: true,
      skipWeekends: true,
      requiresDocument: false,
      requiresReason: true,
      employeeCanApply: false,   // System-applied only
      creditSchedule: null,
    },
    {
      code: 'OT',
      name: 'Other',
      applicableTo: 'BOTH' as const,
      defaultDaysPerYear: null,
      isCarryForward: false,
      allowHalfDay: true,
      skipPublicHolidays: true,
      skipWeekends: true,
      requiresDocument: true,
      requiresReason: true,
      employeeCanApply: true,
      creditSchedule: null,
    },
  ] as const;

  for (const lt of leaveTypes) {
    const common = {
      name:               lt.name,
      applicableTo:       lt.applicableTo,
      defaultDaysPerYear: lt.defaultDaysPerYear,
      isCarryForward:     lt.isCarryForward,
      allowHalfDay:       lt.allowHalfDay,
      skipPublicHolidays: lt.skipPublicHolidays,
      skipWeekends:       lt.skipWeekends,
      requiresDocument:   lt.requiresDocument,
      requiresReason:     lt.requiresReason,
      isActive:           true,
      employeeCanApply:   (lt as any).employeeCanApply ?? true,
      creditSchedule:     lt.creditSchedule as any,
    };
    await prisma.leaveType.upsert({
      where:  { code: lt.code },
      update: common,
      create: { code: lt.code, ...common },
    });
  }
  console.log(`✅  ${leaveTypes.length} leave types seeded`);

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

  // Default password: 01011998 (user-specified)
  const defaultHash = await bcrypt.hash('01011998', 12);

  const adminUser = await prisma.user.upsert({
    where:  { employeeId: 1 },
    update: {
      passwordHash: defaultHash,
      isFirstLogin: true,
    },
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

  // ── HR employee + user ──────────────────────────────────────────────
  console.log('⏳  Seeding HR employee & user…');
  const hrEmployee = await prisma.employee.upsert({
    where:  { id: 2 },
    update: {},
    create: {
      id:           2,
      abbreviation: 'HRM',
      userId:       'pending-hr',
      status:       'ACTIVE',
    },
  });

  const hrUser = await prisma.user.upsert({
    where:  { employeeId: 2 },
    update: { passwordHash: defaultHash },
    create: {
      employeeId:   2,
      roleId:       roleIdMap['HR'],
      passwordHash: defaultHash,
    },
  });

  await prisma.employee.update({
    where: { id: 2 },
    data:  { userId: hrUser.id },
  });

  await prisma.employeeGeneralInfo.upsert({
    where: { employeeId: 2 },
    update: {
      fullName: 'SNEHA TIWARI',
    },
    create: {
      employeeId: 2,
      fullName: 'SNEHA TIWARI',
      organization: 'GANDHINAGAR UNIVERSITY',
      department: 'HR DEPARTMENT',
      employeeCategory: 'NON_TEACHING',
      designation: 'HR MANAGER',
      joiningDate: new Date('2020-05-15'),
      originalJoiningDate: new Date('2020-05-15'),
    },
  });

  // ── Regular Employees ────────────────────────────────────────────────
  console.log('⏳  Seeding regular employees…');
  const employeesToSeed = [
    {
      id: 3,
      name: 'RAJESH KUMAR',
      designation: 'ASSISTANT PROFESSOR',
      dept: 'COMPUTER ENGINEERING',
      category: 'TEACHING' as const,
    },
    {
      id: 4,
      name: 'PRIYA SHARMA',
      designation: 'LECTURER',
      dept: 'INFORMATION TECHNOLOGY',
      category: 'TEACHING' as const,
    },
  ];

  for (const empData of employeesToSeed) {
    const emp = await prisma.employee.upsert({
      where:  { id: empData.id },
      update: {},
      create: {
        id:           empData.id,
        abbreviation: empData.name.split(' ').map(n => n[0]).join(''),
        userId:       `pending-emp-${empData.id}`,
        status:       'ACTIVE',
      },
    });

    const user = await prisma.user.upsert({
      where:  { employeeId: empData.id },
      update: { passwordHash: defaultHash },
      create: {
        employeeId:   empData.id,
        roleId:       roleIdMap['EMPLOYEE'],
        passwordHash: defaultHash,
        isFirstLogin: true,
      },
    });

    await prisma.employee.update({
      where: { id: empData.id },
      data:  { userId: user.id },
    });

    await prisma.employeeGeneralInfo.upsert({
      where: { employeeId: empData.id },
      update: {},
      create: {
        employeeId: empData.id,
        fullName: empData.name,
        organization: 'GANDHINAGAR UNIVERSITY',
        department: empData.dept,
        employeeCategory: empData.category,
        designation: empData.designation,
        joiningDate: new Date('2022-01-10'),
        originalJoiningDate: new Date('2022-01-10'),
      },
    });

    await prisma.employeePersonalInfo.upsert({
      where: { employeeId: empData.id },
      update: {},
      create: {
        employeeId: empData.id,
        birthDate: new Date('1990-01-01'),
        gender: empData.id % 2 === 0 ? 'FEMALE' : 'MALE',
        maritalStatus: 'SINGLE',
        nationality: 'INDIAN',
        bloodGroup: 'O_POS',
      },
    });
  }

  // ── Update Employee 3 — set subOrganization so leave routes to GIT HOD/HOI ───
  await prisma.employeeGeneralInfo.update({
    where: { employeeId: 3 },
    data: { subOrganization: 'GIT' },
  });
  await prisma.employeeGeneralInfo.update({
    where: { employeeId: 4 },
    data: { subOrganization: 'GIT' },
  });
  console.log('✅  Updated employees 3 & 4 — subOrganization = GIT');

  // ── Leave workflow test users (IDs 5–8) ─────────────────────────────────────
  console.log('⏳  Seeding leave workflow users (HOD, HOI, Registrar, VC)…');

  const leaveWorkflowUsers = [
    {
      id:           5,
      abbreviation: 'AP',
      name:         'DR. AMIT PATEL',
      designation:  'HEAD OF DEPARTMENT',
      dept:         'COMPUTER ENGINEERING',
      subOrg:       'GIT',
      org:          'GANDHINAGAR UNIVERSITY',
      category:     'TEACHING' as const,
      gender:       'MALE' as const,
      dob:          new Date('1975-04-10'),
      roleName:     'HOD',
    },
    {
      id:           6,
      abbreviation: 'RS',
      name:         'DR. REKHA SHAH',
      designation:  'PRINCIPAL',
      dept:         'PRINCIPAL OFFICE',
      subOrg:       'GIT',
      org:          'GANDHINAGAR UNIVERSITY',
      category:     'TEACHING' as const,
      gender:       'FEMALE' as const,
      dob:          new Date('1970-08-22'),
      roleName:     'HOI',
    },
    {
      id:           7,
      abbreviation: 'SM',
      name:         'MR. SURESH MEHTA',
      designation:  'REGISTRAR',
      dept:         'REGISTRAR OFFICE',
      subOrg:       null,
      org:          'GANDHINAGAR UNIVERSITY',
      category:     'NON_TEACHING' as const,
      gender:       'MALE' as const,
      dob:          new Date('1968-12-05'),
      roleName:     'REGISTRAR',
    },
    {
      id:           8,
      abbreviation: 'JD',
      name:         'PROF. JAYESH DESAI',
      designation:  'VICE CHANCELLOR',
      dept:         'VICE CHANCELLOR OFFICE',
      subOrg:       null,
      org:          'GANDHINAGAR UNIVERSITY',
      category:     'NON_TEACHING' as const,
      gender:       'MALE' as const,
      dob:          new Date('1962-03-17'),
      roleName:     'VC',
    },
  ];

  for (const u of leaveWorkflowUsers) {
    const emp = await prisma.employee.upsert({
      where:  { id: u.id },
      update: {},
      create: {
        id:           u.id,
        abbreviation: u.abbreviation,
        userId:       `pending-${u.roleName.toLowerCase()}-${u.id}`,
        status:       'ACTIVE',
      },
    });

    const user = await prisma.user.upsert({
      where:  { employeeId: u.id },
      update: { passwordHash: defaultHash },
      create: {
        employeeId:   u.id,
        roleId:       roleIdMap[u.roleName],
        passwordHash: defaultHash,
        isFirstLogin: true,
      },
    });

    await prisma.employee.update({
      where: { id: u.id },
      data:  { userId: user.id },
    });

    await prisma.employeeGeneralInfo.upsert({
      where: { employeeId: u.id },
      update: {},
      create: {
        employeeId:          u.id,
        fullName:            u.name,
        organization:        u.org,
        subOrganization:     u.subOrg ?? undefined,
        department:          u.dept,
        employeeCategory:    u.category,
        designation:         u.designation,
        joiningDate:         new Date('2015-06-01'),
        originalJoiningDate: new Date('2015-06-01'),
      },
    });

    await prisma.employeePersonalInfo.upsert({
      where:  { employeeId: u.id },
      update: {},
      create: {
        employeeId:    u.id,
        birthDate:     u.dob,
        gender:        u.gender,
        maritalStatus: 'MARRIED',
        nationality:   'INDIAN',
        bloodGroup:    'B_POS',
      },
    });

    console.log(`  ✓  ${u.roleName} (ID ${u.id}): ${u.name}`);
  }

  // ── Configure leave approval workflow ────────────────────────────────────────
  console.log('⏳  Configuring leave approval workflow…');

  // HOD for each department at GIT
  const deptHODs = [
    { department: 'COMPUTER ENGINEERING',   hodEmployeeId: 5 },
    { department: 'INFORMATION TECHNOLOGY', hodEmployeeId: 5 }, // same HOD covers IT for now
  ];
  for (const d of deptHODs) {
    const existing = await prisma.departmentApprover.findFirst({ where: { department: d.department } });
    if (existing) {
      await prisma.departmentApprover.update({
        where: { id: existing.id },
        data:  { hodEmployeeId: d.hodEmployeeId, isActive: true, updatedBy: 'seed' },
      });
    } else {
      await prisma.departmentApprover.create({
        data: { department: d.department, hodEmployeeId: d.hodEmployeeId, isActive: true, updatedBy: 'seed' },
      });
    }
    console.log(`  ✓  DepartmentApprover: ${d.department} → Employee #${d.hodEmployeeId}`);
  }

  // HOI for GIT institute
  const instituteHOIs = [
    { institute: 'GIT', hoiEmployeeId: 6 },
  ];
  for (const i of instituteHOIs) {
    const existing = await prisma.instituteApprover.findFirst({ where: { institute: i.institute } });
    if (existing) {
      await prisma.instituteApprover.update({
        where: { id: existing.id },
        data:  { hoiEmployeeId: i.hoiEmployeeId, isActive: true, updatedBy: 'seed' },
      });
    } else {
      await prisma.instituteApprover.create({
        data: { institute: i.institute, hoiEmployeeId: i.hoiEmployeeId, isActive: true, updatedBy: 'seed' },
      });
    }
    console.log(`  ✓  InstituteApprover: ${i.institute} → Employee #${i.hoiEmployeeId}`);
  }

  // Global approvers — VC (#8) + Registrar (#7), university-wide
  const existingGlobal = await prisma.globalApprover.findFirst({ where: { isActive: true } });
  if (existingGlobal) {
    await prisma.globalApprover.update({
      where: { id: existingGlobal.id },
      data:  { vcEmployeeId: 8, registrarEmployeeId: 7, updatedBy: 'seed' },
    });
  } else {
    await prisma.globalApprover.create({
      data: { vcEmployeeId: 8, registrarEmployeeId: 7, isActive: true, updatedBy: 'seed' },
    });
  }
  console.log('  ✓  GlobalApprover: VC → Employee #8, Registrar → Employee #7');

  // ── Credit 2026 leave balances for test employees ────────────────────────────
  console.log('⏳  Crediting 2026 leave balances for test employees…');
  const currentYear = new Date().getFullYear();

  // Fetch leave types by code
  const [cl, sl, vl, al, dl] = await Promise.all([
    prisma.leaveType.findUnique({ where: { code: 'CL' } }),
    prisma.leaveType.findUnique({ where: { code: 'SL' } }),
    prisma.leaveType.findUnique({ where: { code: 'VL' } }),
    prisma.leaveType.findUnique({ where: { code: 'AL' } }),
    prisma.leaveType.findUnique({ where: { code: 'DL' } }),
  ]);

  // Balances per employee category
  const teachingBalances = [
    { type: cl,  days: 12 },
    { type: sl,  days: 10 },
    { type: vl,  days: 21 },
    { type: al,  days: 0  }, // accrues on admin-managed basis
    { type: dl,  days: 0  },
  ];
  const nonTeachingBalances = [
    { type: cl, days: 12 },
    { type: sl, days: 10 },
    { type: dl, days: 0  },
  ];

  // Employees 3 + 4 are TEACHING; 5 + 6 are TEACHING; 7 + 8 are NON_TEACHING
  const balancesToSeed: { empId: number; balances: typeof teachingBalances }[] = [
    { empId: 3, balances: teachingBalances },
    { empId: 4, balances: teachingBalances },
    { empId: 5, balances: teachingBalances },
    { empId: 6, balances: teachingBalances },
    { empId: 7, balances: nonTeachingBalances },
    { empId: 8, balances: nonTeachingBalances },
  ];

  for (const { empId, balances } of balancesToSeed) {
    for (const { type, days } of balances) {
      if (!type) continue;
      await prisma.leaveBalance.upsert({
        where: { employeeId_leaveTypeId_year: { employeeId: empId, leaveTypeId: type.id, year: currentYear } },
        update: { totalCredited: days, available: days },
        create: {
          employeeId:    empId,
          leaveTypeId:   type.id,
          year:          currentYear,
          totalCredited: days,
          carryForward:  0,
          used:          0,
          pending:       0,
          available:     days,
        },
      });
    }
    console.log(`  ✓  Leave balances credited for Employee #${empId}`);
  }

  // ── Reset DB Sequences (Postgres specific) ──────────────────────────────────
  // Ensures manual IDs 1-8 don't break autoincrement for future employee creation
  try {
    await prisma.$executeRawUnsafe("SELECT setval('employees_id_seq', (SELECT MAX(id) FROM employees))");
    console.log('✅  Database sequences synchronized');
  } catch (err: any) {
    console.warn('⚠️  Could not reset sequences (non-critical):', err.message);
  }

  // ── Dummy attendance punches for UI/testing ─────────────────────────────────
  console.log('⏳  Seeding dummy attendance punches…');
  const attendanceRows = [
    { employeeId: 3, punchAt: new Date('2026-04-14T03:35:00.000Z'), terminalId: 'T1', punchType: 'IN', externalKey: 'DUMMY-3-2026-04-14-IN' },
    { employeeId: 3, punchAt: new Date('2026-04-14T12:10:00.000Z'), terminalId: 'T1', punchType: 'OUT', externalKey: 'DUMMY-3-2026-04-14-OUT' },
    { employeeId: 3, punchAt: new Date('2026-04-15T03:40:00.000Z'), terminalId: 'T1', punchType: 'IN', externalKey: 'DUMMY-3-2026-04-15-IN' },
    { employeeId: 3, punchAt: new Date('2026-04-15T12:20:00.000Z'), terminalId: 'T1', punchType: 'OUT', externalKey: 'DUMMY-3-2026-04-15-OUT' },

    { employeeId: 4, punchAt: new Date('2026-04-14T04:05:00.000Z'), terminalId: 'T2', punchType: 'IN', externalKey: 'DUMMY-4-2026-04-14-IN' },
    { employeeId: 4, punchAt: new Date('2026-04-14T11:55:00.000Z'), terminalId: 'T2', punchType: 'OUT', externalKey: 'DUMMY-4-2026-04-14-OUT' },
    { employeeId: 4, punchAt: new Date('2026-04-15T04:15:00.000Z'), terminalId: 'T2', punchType: 'IN', externalKey: 'DUMMY-4-2026-04-15-IN' },
    { employeeId: 4, punchAt: new Date('2026-04-15T12:05:00.000Z'), terminalId: 'T2', punchType: 'OUT', externalKey: 'DUMMY-4-2026-04-15-OUT' },
  ] as const;

  for (const row of attendanceRows) {
    await prisma.attendancePunch.upsert({
      where: { externalKey: row.externalKey },
      update: {
        punchAt: row.punchAt,
        terminalId: row.terminalId,
        punchType: row.punchType,
      },
      create: {
        employeeId: row.employeeId,
        punchAt: row.punchAt,
        source: 'ESSL',
        terminalId: row.terminalId,
        punchType: row.punchType,
        externalKey: row.externalKey,
      },
    });
  }
  console.log(`✅  ${attendanceRows.length} dummy attendance punches seeded`);

  console.log('✅  Demo employees and users seeded');
  console.log('');
  console.log('════════════════════════════════════════════════════════');
  console.log(' Admin      : employeeId = 1  | Full system access');
  console.log(' HR         : employeeId = 2  | HR staff');
  console.log(' Employee   : employeeId = 3  | GIT / COMPUTER ENGINEERING');
  console.log(' Employee   : employeeId = 4  | GIT / INFORMATION TECHNOLOGY');
  console.log(' HOD (GIT)  : employeeId = 5  | Approves CE & IT dept leaves');
  console.log(' HOI (GIT)  : employeeId = 6  | Approves all GIT leaves (step 2)');
  console.log(' Registrar  : employeeId = 7  | Final approval (step 3)');
  console.log(' VC         : employeeId = 8  | Final approval (step 3)');
  console.log(' Default PW : 01011998        | isFirstLogin=true on all');
  console.log('────────────────────────────────────────────────────────');
  console.log(' Leave flow : Employee (3/4)');
  console.log('           → HOD Dr. Amit Patel  (step 1 — dept)');
  console.log('           → HOI Dr. Rekha Shah  (step 2 — GIT institute)');
  console.log('           → Registrar + VC       (step 3 — university)');
  console.log('════════════════════════════════════════════════════════');
}

main()
  .catch((e) => { console.error(e); process.exit(1); })
  .finally(() => prisma.$disconnect());
