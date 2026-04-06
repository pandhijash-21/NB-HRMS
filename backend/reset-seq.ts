import { PrismaClient } from '@prisma/client';

const prisma = new PrismaClient();

async function main() {
  console.log('--- Resetting Database Sequences ---');
  
  // Sync 'employees' primary key sequence
  try {
    const [result]: any = await prisma.$queryRawUnsafe(`
      SELECT setval('employees_id_seq', (SELECT MAX(id) FROM employees))
    `);
    console.log('✅ Sequence employees_id_seq reset to:', result.setval);
  } catch (err: any) {
    console.error('❌ Error resetting employees_id_seq:', err.message);
  }

  // Any other tables? Most use UUIDs, but let's check for serial keys just in case
  // The system_modules might use ids if manually inserted.
  
  console.log('--- Sequence Synchronization Complete ---');
}

main()
  .catch((e) => {
    console.error(e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
