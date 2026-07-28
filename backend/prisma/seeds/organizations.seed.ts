import { PrismaClient } from '@prisma/client';

const ORG_SEEDS = [
  { code: 'GANDHINAGAR_UNIVERSITY', name: 'Gandhinagar University', sortOrder: 1 },
  { code: 'PLATINUM_FOUNDATION', name: 'Platinum Foundation', sortOrder: 2 },
];

/** Upsert Organization rows from known ORGANIZATION lookup codes. */
export async function seedOrganizations(prisma: PrismaClient) {
  for (const org of ORG_SEEDS) {
    await prisma.organization.upsert({
      where: { code: org.code },
      update: { name: org.name, sortOrder: org.sortOrder, isActive: true },
      create: {
        code: org.code,
        name: org.name,
        sortOrder: org.sortOrder,
        isActive: true,
      },
    });
  }

  // Also pull any extra ORGANIZATION lookups not in the hard-coded list.
  const lookups = await prisma.systemLookup.findMany({
    where: { category: 'ORGANIZATION', isActive: true },
  });
  for (const row of lookups) {
    await prisma.organization.upsert({
      where: { code: row.code },
      update: {},
      create: {
        code: row.code,
        name: row.label,
        sortOrder: row.sortOrder,
        isActive: true,
      },
    });
  }

  console.log(`✅  Organizations seeded (${ORG_SEEDS.length}+ lookups)`);
}
