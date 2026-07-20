/**
 * Wipe NB_CRM to a clean admin-only slate.
 * Keeps: SystemModule, Roles + RolePermissions, SystemLookup, LeaveSetting,
 *        AttendancePolicy, Employee #1 + ADMIN User.
 * Removes: all other employees/users, institutes, designations, position slots,
 *          leaves, attendance punches, salary employee data, etc.
 *
 * Run: npx tsx prisma/wipe-to-admin.ts
 */
import { PrismaClient } from '@prisma/client';
import bcrypt from 'bcryptjs';
import { seedSalaryCatalog } from './seeds/designationSalary.seed';

const prisma = new PrismaClient();

async function wipe() {
  console.log('⏳  Wiping database to ADMIN-only…');

  // ── Leave / attendance / salary employee data ────────────────────────────
  await prisma.leaveApprovalStep.deleteMany();
  await prisma.absenceRecord.deleteMany();
  await prisma.leaveApplication.deleteMany();
  await prisma.leaveBalance.deleteMany();
  await prisma.leaveAuditLog.deleteMany();
  await prisma.monthlyLWPRecord.deleteMany();
  await prisma.publicHoliday.deleteMany();
  await prisma.leaveType.deleteMany();
  console.log('  ✓ leave data');

  await prisma.attendancePunch.deleteMany();
  console.log('  ✓ attendance punches');

  await prisma.employeeSalaryColumnValue.deleteMany();
  await prisma.employeeSalaryRecord.deleteMany();
  await prisma.conditionalRuleCondition.deleteMany();
  await prisma.salaryColumnRule.deleteMany();
  await prisma.salaryStructureTemplate.deleteMany();
  // Keep pay commission catalog (5th/6th pay + column defs) — employee data only above
  await prisma.employeeSalaryInfo.deleteMany();
  await prisma.employeeBankInfo.deleteMany();
  console.log('  ✓ salary employee data (pay commission catalog kept)');

  // ── Approver maps ────────────────────────────────────────────────────────
  await prisma.departmentApprover.deleteMany();
  await prisma.instituteApprover.deleteMany();
  await prisma.globalApprover.deleteMany();
  console.log('  ✓ approver maps');

  // ── Institutional positions ──────────────────────────────────────────────
  await prisma.positionAssignment.deleteMany();
  await prisma.positionSlot.deleteMany();
  console.log('  ✓ position slots');

  // ── Profile sections / change requests / audit ───────────────────────────
  await prisma.changeRequest.deleteMany();
  await prisma.auditLog.deleteMany();
  await prisma.familyMember.deleteMany();
  await prisma.academicQualification.deleteMany();
  await prisma.employeeExperience.deleteMany();
  await prisma.employeeAddress.deleteMany();
  await prisma.employeePersonalInfo.deleteMany();
  await prisma.employeeOtherInfo.deleteMany();
  await prisma.employeeAssignment.deleteMany();
  console.log('  ✓ profile sections');

  // Clear FKs on general info that point at users / institutes / designations
  await prisma.employeeGeneralInfo.updateMany({
    data: {
      instituteId: null,
      designationId: null,
      firstApproverUserId: null,
      secondApproverUserId: null,
      thirdApproverUserId: null,
      firstReportingId: null,
      secondReportingId: null,
      thirdReportingId: null,
    },
  });

  // ── Users except admin (employeeId = 1) ──────────────────────────────────
  // Alias / position users have username and null employeeId
  await prisma.user.deleteMany({
    where: {
      OR: [
        { employeeId: { not: 1 } },
        { employeeId: null },
      ],
    },
  });
  console.log('  ✓ non-admin users');

  // ── Employees except id=1 ────────────────────────────────────────────────
  await prisma.employeeGeneralInfo.deleteMany({ where: { employeeId: { not: 1 } } });
  await prisma.employee.deleteMany({ where: { id: { not: 1 } } });
  console.log('  ✓ non-admin employees');

  // ── Designations (job + alias) & institutes ──────────────────────────────
  await prisma.designation.deleteMany();
  await prisma.institute.deleteMany();
  console.log('  ✓ designations & institutes');

  // ── Orphan RBAC roles (keep ADMIN + EMPLOYEE only) ─────────────────────
  const orphanRoles = await prisma.role.findMany({
    where: { name: { notIn: ['ADMIN', 'EMPLOYEE'] } },
    select: { id: true },
  });
  if (orphanRoles.length) {
    await prisma.rolePermission.deleteMany({
      where: { roleId: { in: orphanRoles.map((r) => r.id) } },
    });
    await prisma.role.deleteMany({
      where: { id: { in: orphanRoles.map((r) => r.id) } },
    });
  }
  console.log('  ✓ orphan roles removed (ADMIN + EMPLOYEE kept)');

  // ── Ensure admin employee + user still healthy ───────────────────────────
  const adminRole = await prisma.role.findUnique({ where: { name: 'ADMIN' } });
  if (!adminRole) {
    throw new Error('ADMIN role missing — run prisma seed first, then re-run this wipe.');
  }

  await prisma.employee.upsert({
    where: { id: 1 },
    update: { status: 'ACTIVE', abbreviation: 'ADM' },
    create: {
      id: 1,
      abbreviation: 'ADM',
      userId: 'pending-admin',
      status: 'ACTIVE',
    },
  });

  await prisma.employeeGeneralInfo.upsert({
    where: { employeeId: 1 },
    update: {
      fullName: 'SYSTEM ADMIN',
      designation: 'SYSTEM ADMINISTRATOR',
      department: 'IT DEPARTMENT',
      instituteId: null,
      designationId: null,
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

  const defaultHash = await bcrypt.hash('01011998', 12);
  const adminUser = await prisma.user.upsert({
    where: { employeeId: 1 },
    update: {
      passwordHash: defaultHash,
      roleId: adminRole.id,
      isActive: true,
      isFirstLogin: false,
      username: null,
    },
    create: {
      employeeId: 1,
      passwordHash: defaultHash,
      roleId: adminRole.id,
      isActive: true,
      isFirstLogin: false,
    },
  });

  await prisma.employee.update({
    where: { id: 1 },
    data: { userId: adminUser.id },
  });

  await seedSalaryCatalog(prisma);
  console.log('  ✓ pay commission catalog restored');

  const counts = {
    users: await prisma.user.count(),
    employees: await prisma.employee.count(),
    institutes: await prisma.institute.count(),
    designations: await prisma.designation.count(),
    positionSlots: await prisma.positionSlot.count(),
    leaveApps: await prisma.leaveApplication.count(),
    leaveTypes: await prisma.leaveType.count(),
    roles: await prisma.role.count(),
    payCommissions: await prisma.payCommission.count(),
  };

  console.log('✅  Wipe complete.');
  console.log(JSON.stringify(counts, null, 2));
  console.log('');
  console.log('Admin login: employeeId = 1');
  console.log('Password:    01011998');
}

wipe()
  .catch((e) => {
    console.error('❌  Wipe failed:', e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
