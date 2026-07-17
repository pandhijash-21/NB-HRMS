import { PrismaClient } from '@prisma/client';
import { seedSystemLookups } from './lookups.seed';

const prisma = new PrismaClient();

async function main() {
  await seedSystemLookups(prisma);
}

main()
  .catch((e) => {
    console.error(e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
