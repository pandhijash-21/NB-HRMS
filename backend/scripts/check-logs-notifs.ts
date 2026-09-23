import { PrismaClient } from '@prisma/client';

const p = new PrismaClient();

async function main() {
  const notifications = await p.userNotification.count();
  const auditLogs = await p.auditLog.count();
  const recentAudit = await p.auditLog.findMany({
    orderBy: { changedAt: 'desc' },
    take: 5,
    select: {
      fieldName: true,
      employeeId: true,
      changedAt: true,
      changeReason: true,
    },
  });
  const recentNotif = await p.userNotification.findMany({
    orderBy: { createdAt: 'desc' },
    take: 5,
    select: { title: true, kind: true, body: true, createdAt: true },
  });
  const cols = await p.$queryRawUnsafe<Array<{ column_name: string }>>(
    `SELECT column_name FROM information_schema.columns WHERE table_name='family_members' AND column_name='is_emergency_contact'`,
  );
  console.log(
    JSON.stringify(
      {
        notifications,
        auditLogs,
        emergencyCol: cols,
        recentAudit,
        recentNotif,
      },
      null,
      2,
    ),
  );
}

main()
  .catch((e) => {
    console.error(e);
    process.exit(1);
  })
  .finally(async () => {
    await p.$disconnect();
  });
