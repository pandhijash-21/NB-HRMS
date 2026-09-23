import { PrismaClient } from '@prisma/client';

const p = new PrismaClient();

async function main() {
  for (const row of [
    { code: 'AGENCY', label: 'Agency', sortOrder: 1 },
    { code: 'CONTRACTOR', label: 'Contractor', sortOrder: 2 },
    { code: 'SUPPLIER', label: 'Supplier', sortOrder: 3 },
  ]) {
    await p.systemLookup.upsert({
      where: { category_code: { category: 'CONTRACTOR_TYPE', code: row.code } },
      create: {
        category: 'CONTRACTOR_TYPE',
        code: row.code,
        label: row.label,
        sortOrder: row.sortOrder,
        isActive: true,
      },
      update: { label: row.label, sortOrder: row.sortOrder, isActive: true },
    });
  }
  await p.systemLookup.updateMany({
    where: {
      category: 'CONTRACTOR_TYPE',
      code: { in: ['CIVIL', 'ELECTRICAL', 'PLUMBING', 'FINISHING', 'GENERAL'] },
    },
    data: { isActive: false },
  });
  const rows = await p.systemLookup.findMany({
    where: { category: 'CONTRACTOR_TYPE', isActive: true },
    orderBy: { sortOrder: 'asc' },
  });
  console.log(rows.map((r) => `${r.code}:${r.label}`).join(', '));
}

main()
  .catch((e) => {
    console.error(e);
    process.exit(1);
  })
  .finally(async () => {
    await p.$disconnect();
  });
