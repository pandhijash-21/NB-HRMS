import { PrismaClient } from '@prisma/client';

const prisma = new PrismaClient();

async function main() {
  console.log('Running subOrganization cleanup...');

  // 1. EmployeeGeneralInfo
  const giResult = await prisma.$executeRawUnsafe(`
    UPDATE "employee_general_info"
    SET "sub_organization" = NULL
    WHERE "sub_organization" ~ '^\\d{4}$';
  `);
  console.log(`Cleaned up ${giResult} rows in employee_general_info`);

  // 2. EmployeeAssignment
  const asResult = await prisma.$executeRawUnsafe(`
    UPDATE "employee_assignments"
    SET "sub_organization" = NULL
    WHERE "sub_organization" ~ '^\\d{4}$';
  `);
  console.log(`Cleaned up ${asResult} rows in employee_assignments`);

  // 3. Sync institute codes if institute_id is present but sub_organization is null
  const syncGi = await prisma.$executeRawUnsafe(`
    UPDATE "employee_general_info" gi
    SET "sub_organization" = i."code"
    FROM "institutes" i
    WHERE gi."institute_id" = i."id"
      AND (gi."sub_organization" IS NULL OR gi."sub_organization" ~ '^\\d{4}$');
  `);
  console.log(`Synced ${syncGi} general_info rows with institute code`);

  const syncAs = await prisma.$executeRawUnsafe(`
    UPDATE "employee_assignments" ea
    SET "sub_organization" = i."code"
    FROM "institutes" i
    WHERE ea."institute_id" = i."id"
      AND (ea."sub_organization" IS NULL OR ea."sub_organization" ~ '^\\d{4}$');
  `);
  console.log(`Synced ${syncAs} assignment rows with institute code`);

  console.log('Cleanup completed successfully.');
}

main()
  .catch((e) => {
    console.error('Error during cleanup:', e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
