/**
 * Clear all employee/user person-data while keeping:
 *   - SUPERADMIN + ADMIN (System Admin) login accounts
 *   - Organizations, institutes, designations, roles, modules, org structure
 *
 * Deletes:
 *   - Every Employee row + photo/signature URLs, attendance, leave, salary,
 *     bank, docs, tracking, reimbursements, letters, change requests, etc.
 *   - Every non-ADMIN / non-SUPERADMIN User (+ their chat/meet/tasks/audit)
 *
 * Safety (required):
 *   CONFIRM_WIPE_USERS=YES
 *
 * Local:
 *   CONFIRM_WIPE_USERS=YES npx tsx scripts/wipe-user-data.ts
 *
 * Production (inside backend container):
 *   docker compose -f docker-compose.prod.yml --env-file backend/.env.production \
 *     exec -T -e CONFIRM_WIPE_USERS=YES backend npx tsx scripts/wipe-user-data.ts
 */
import { prisma } from '../src/config/prisma';
import { redis, connectRedis } from '../src/config/redis';
import { safelyDeleteUserIds } from '../src/modules/platform/platform.service';

const KEEP_ROLE_NAMES = [
  'SUPERADMIN',
  'ADMIN',
  'SYSTEM_ADMIN',
  'SYSTEM_ADMINISTRATOR',
  'SYSTEMADMIN',
];

async function clearRedisSessions() {
  try {
    await connectRedis();
    const keys = await redis.keys('session:*');
    const roleKeys = await redis.keys('role_users:*');
    const all = [...keys, ...roleKeys];
    if (all.length > 0) {
      await redis.del(all);
      console.log(`  ✓ cleared ${all.length} redis session/role keys`);
    } else {
      console.log('  ✓ redis sessions already empty');
    }
  } catch (err) {
    console.warn('  ! redis clear skipped:', err);
  }
}

async function deleteAllEmployeeRelatedData(empIds: number[]) {
  if (!empIds.length) return;

  // Leave workflow children first
  const apps = await prisma.leaveApplication.findMany({
    where: { employeeId: { in: empIds } },
    select: { id: true },
  });
  if (apps.length) {
    await prisma.leaveApprovalStep.deleteMany({
      where: { applicationId: { in: apps.map((a) => a.id) } },
    });
  }

  await prisma.leaveApplication.deleteMany({ where: { employeeId: { in: empIds } } });
  await prisma.leaveBalance.deleteMany({ where: { employeeId: { in: empIds } } });
  await prisma.leaveAuditLog.deleteMany({ where: { employeeId: { in: empIds } } });
  await prisma.monthlyLWPRecord.deleteMany({ where: { employeeId: { in: empIds } } });
  await prisma.absenceRecord.deleteMany({ where: { employeeId: { in: empIds } } });
  await prisma.attendancePunch.deleteMany({ where: { employeeId: { in: empIds } } });
  await prisma.employeeAttendanceSettings.deleteMany({ where: { employeeId: { in: empIds } } });

  const salaryRecords = await prisma.employeeSalaryRecord.findMany({
    where: { employeeId: { in: empIds } },
    select: { id: true },
  });
  if (salaryRecords.length) {
    await prisma.employeeSalaryColumnValue.deleteMany({
      where: { salaryRecordId: { in: salaryRecords.map((r) => r.id) } },
    });
  }
  await prisma.employeeSalaryRecord.deleteMany({ where: { employeeId: { in: empIds } } });
  await prisma.employeeSalaryInfo.deleteMany({ where: { employeeId: { in: empIds } } });
  await prisma.employeeBankInfo.deleteMany({ where: { employeeId: { in: empIds } } });

  await prisma.employeeLetterDocument.deleteMany({ where: { employeeId: { in: empIds } } });
  await prisma.reimbursementClaim.deleteMany({ where: { employeeId: { in: empIds } } });
  await prisma.changeRequest.deleteMany({ where: { employeeId: { in: empIds } } });
  await prisma.auditLog.deleteMany({ where: { employeeId: { in: empIds } } });

  await prisma.locationHistory.deleteMany({ where: { employeeId: { in: empIds } } });
  await prisma.trip.deleteMany({ where: { employeeId: { in: empIds } } });
  await prisma.trackingEvent.deleteMany({ where: { employeeId: { in: empIds } } });

  await prisma.positionAssignment.deleteMany({ where: { holderEmployeeId: { in: empIds } } });
  await prisma.employeeAssignment.deleteMany({ where: { employeeId: { in: empIds } } });

  await prisma.departmentApprover.deleteMany({ where: { hodEmployeeId: { in: empIds } } });
  await prisma.instituteApprover.deleteMany({ where: { hoiEmployeeId: { in: empIds } } });
  await prisma.globalApprover.updateMany({
    where: { vcEmployeeId: { in: empIds } },
    data: { vcEmployeeId: null },
  });
  await prisma.globalApprover.updateMany({
    where: { registrarEmployeeId: { in: empIds } },
    data: { registrarEmployeeId: null },
  });

  await prisma.orgTreeContact.deleteMany({ where: { employeeId: { in: empIds } } });
  await prisma.crmFollowUp.updateMany({
    where: { assignedToId: { in: empIds } },
    data: { assignedToId: null },
  });

  await prisma.familyMember.deleteMany({ where: { employeeId: { in: empIds } } });
  await prisma.academicQualification.deleteMany({ where: { employeeId: { in: empIds } } });
  await prisma.employeeExperience.deleteMany({ where: { employeeId: { in: empIds } } });
  await prisma.employeeAddress.deleteMany({ where: { employeeId: { in: empIds } } });
  await prisma.employeePersonalInfo.deleteMany({ where: { employeeId: { in: empIds } } });
  await prisma.employeeOtherInfo.deleteMany({ where: { employeeId: { in: empIds } } });
  await prisma.employeeGeneralInfo.deleteMany({ where: { employeeId: { in: empIds } } });

  // Photos/signatures live on Employee row — removed with deleteMany below
  await prisma.employee.deleteMany({ where: { id: { in: empIds } } });
}

async function main() {
  if (process.env.CONFIRM_WIPE_USERS !== 'YES') {
    throw new Error('Refusing to wipe: set CONFIRM_WIPE_USERS=YES');
  }

  console.log('⏳  Clearing users + employee data (keeping SUPERADMIN + ADMIN accounts, orgs)…');

  const keepUsers = await prisma.user.findMany({
    where: {
      OR: [
        { username: 'superadmin' },
        { role: { name: { in: KEEP_ROLE_NAMES } } },
      ],
    },
    select: {
      id: true,
      username: true,
      employeeId: true,
      role: { select: { name: true } },
    },
  });
  const keepIds = new Set(keepUsers.map((u) => u.id));
  console.log(
    `  keeping ${keepUsers.length} admin accounts:`,
    keepUsers.map((u) => `${u.username ?? u.id}(${u.role.name})`).join(', ') || '(none)',
  );

  // 1) Unlink employee FKs on kept users, then wipe ALL employees (+ photos/attendance/etc.)
  await prisma.user.updateMany({ data: { employeeId: null } });
  const allEmployees = await prisma.employee.findMany({ select: { id: true } });
  const empIds = allEmployees.map((e) => e.id);
  console.log(`  deleting ${empIds.length} employees + related person data…`);
  await deleteAllEmployeeRelatedData(empIds);
  console.log('  ✓ employees / photos / attendance / leave / salary / docs cleared');

  // 2) Delete non-kept users (chat, meetings, tasks, audit for those users)
  const toDelete = await prisma.user.findMany({
    where: { id: { notIn: [...keepIds] } },
    select: { id: true, username: true },
  });
  console.log(`  deleting ${toDelete.length} non-admin users…`);
  if (toDelete.length) {
    await safelyDeleteUserIds(toDelete.map((u) => u.id));
    console.log('  ✓ non-admin users deleted');
  }

  // 3) Clear leftover person-scoped noise that may not be tied to deleted users
  await prisma.leaveApprovalStep.deleteMany({}).catch(() => {});
  await prisma.leaveApplication.deleteMany({});
  await prisma.leaveBalance.deleteMany({});
  await prisma.attendancePunch.deleteMany({});
  await prisma.absenceRecord.deleteMany({});
  await prisma.monthlyLWPRecord.deleteMany({});

  await clearRedisSessions();

  const leftUsers = await prisma.user.findMany({
    select: { username: true, role: { select: { name: true } } },
    orderBy: { username: 'asc' },
  });
  const orgCount = await prisma.organization.count();
  const instituteCount = await prisma.institute.count();
  const empCount = await prisma.employee.count();

  console.log('✅  Wipe complete.');
  console.log(`   users left (${leftUsers.length}):`, leftUsers.map((u) => `${u.username}/${u.role.name}`).join(', '));
  console.log(`   organizations=${orgCount}, institutes=${instituteCount}, employees=${empCount}`);
  console.log('   Orgs / sub-orgs / designations / roles kept. Re-create employees as needed.');
}

main()
  .catch((err) => {
    console.error('❌  Wipe failed:', err);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect().catch(() => {});
  });
