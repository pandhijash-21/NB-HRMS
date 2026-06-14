import type { PrismaClient } from '@prisma/client';

const DEFAULT_INSTITUTES: { code: string; name: string }[] = [
  { code: 'GIT', name: 'Gandhinagar Institute of Technology' },
  { code: 'GIM', name: 'Gandhinagar Institute of Management' },
  { code: 'GIC', name: 'Gandhinagar Institute of Commerce' },
  { code: 'GIS', name: 'Gandhinagar Institute of Science' },
  { code: 'GIRD', name: 'Gandhinagar Institute of Research & Development' },
  { code: 'GILS', name: 'Gandhinagar Institute of Liberal Studies' },
  { code: 'GICSA', name: 'Gandhinagar Institute of Computer Science & Applications' },
  { code: 'GIL', name: 'Gandhinagar Institute of Law' },
  { code: 'GIVS', name: 'Gandhinagar Institute of Valuation Studies' },
  { code: 'GID', name: 'Gandhinagar Institute of Design' },
  { code: 'GIP', name: 'Gandhinagar Institute of Pharmacy' },
  { code: 'GIN', name: 'Gandhinagar Institute of Nursing' },
  { code: 'GISD', name: 'Gandhinagar Institute of Skill Development' },
  { code: 'GILIS', name: 'Gandhinagar Institute of Library & Information Science' },
  { code: 'GIVE', name: 'Gandhinagar Institute of Vocational Education' },
];

export async function seedInstitutes(prisma: PrismaClient) {
  console.log('⏳  Seeding institutes…');
  let sortOrder = 0;
  for (const row of DEFAULT_INSTITUTES) {
    await prisma.institute.upsert({
      where: { code: row.code },
      update: { name: row.name, sortOrder: sortOrder++, isActive: true },
      create: { code: row.code, name: row.name, sortOrder: sortOrder++ },
    });
  }
  console.log(`✅  ${DEFAULT_INSTITUTES.length} institutes seeded`);

  let general = 0;
  let slots = 0;
  for (const inst of await prisma.institute.findMany()) {
    const g = await prisma.employeeGeneralInfo.updateMany({
      where: {
        instituteId: null,
        subOrganization: { in: [inst.code, inst.name], mode: 'insensitive' },
      },
      data: { instituteId: inst.id, subOrganization: inst.code },
    });
    general += g.count;

    const s = await prisma.positionSlot.updateMany({
      where: {
        instituteId: null,
        OR: [
          { subOrganization: { in: [inst.code, inst.name], mode: 'insensitive' } },
          { code: { endsWith: `-${inst.code}`, mode: 'insensitive' } },
        ],
      },
      data: { instituteId: inst.id, subOrganization: inst.code },
    });
    slots += s.count;
  }
  if (general || slots) {
    console.log(`✅  Institute links backfilled (${general} employees, ${slots} alias accounts)`);
  }
}
