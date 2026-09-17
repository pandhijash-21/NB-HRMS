import { prisma } from '../config/prisma';

/** Roles that already receive GPS / attendance admin mail. */
const ADMIN_ROLES = [
  'ADMIN',
  'SUPERADMIN',
  'SUPER_ADMIN',
  'SYSTEMADMIN',
  'SYSTEM_ADMIN',
  'SYSTEM_ADMINISTRATOR',
  'SYSTEMADMINISTRATOR',
  'HR',
  'DEVELOPER',
];

function collectEmails(
  addresses: { instituteEmail: string | null; personalEmail: string | null }[],
  into: Set<string>,
) {
  for (const addr of addresses) {
    for (const raw of [addr.instituteEmail, addr.personalEmail]) {
      const email = raw?.trim();
      if (email && email.includes('@')) into.add(email);
    }
  }
}

/** Native System Admins plus people Super Admin granted company-admin privileges. */
export async function resolveAdminNotificationEmails(): Promise<string[]> {
  const users = await prisma.user.findMany({
    where: {
      isActive: true,
      deletedAt: null,
      OR: [
        { role: { name: { in: ADMIN_ROLES } } },
        { companyAdminGranted: true },
      ],
    },
    select: {
      employee: {
        select: {
          addresses: {
            select: { instituteEmail: true, personalEmail: true },
          },
        },
      },
    },
  });

  const emails = new Set<string>();
  for (const u of users) {
    collectEmails(u.employee?.addresses ?? [], emails);
  }
  return [...emails];
}
