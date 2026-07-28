import { PrismaClient } from '@prisma/client';
import { seedOrganizations } from './organizations.seed';

async function main() {
  const prisma = new PrismaClient();
  try {
    await seedOrganizations(prisma);
  } finally {
    await prisma.$disconnect();
  }
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
