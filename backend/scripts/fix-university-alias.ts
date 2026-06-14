/**
 * One-off: fix a university-wide alias (e.g. IA-GIT) — clear institute binding + grant role university access.
 * Usage: npx tsx scripts/fix-university-alias.ts IA-GIT
 */
import { PrismaClient } from '@prisma/client';
import { grantFullUniversityAccess } from '../src/modules/user-management/universityAccess.util';

const code = process.argv[2]?.trim().toUpperCase();
if (!code) {
  console.error('Usage: npx tsx scripts/fix-university-alias.ts <ALIAS_CODE>');
  process.exit(1);
}

const prisma = new PrismaClient();

async function main() {
  const slot = await prisma.positionSlot.findUnique({
    where: { code },
    include: { user: true, linkedRole: true },
  });
  if (!slot?.userId) {
    console.error(`Alias ${code} not found`);
    process.exit(1);
  }

  await prisma.user.update({
    where: { id: slot.userId },
    data: { subOrganization: null },
  });

  await prisma.positionSlot.update({
    where: { id: slot.id },
    data: { instituteId: null, subOrganization: null },
  });

  await grantFullUniversityAccess(slot.linkedRoleId, 'system-fix');

  console.log(`✅ ${code} → university-wide, role ${slot.linkedRole.name} granted full access. Re-login required.`);
}

main()
  .catch((e) => {
    console.error(e);
    process.exit(1);
  })
  .finally(() => prisma.$disconnect());
