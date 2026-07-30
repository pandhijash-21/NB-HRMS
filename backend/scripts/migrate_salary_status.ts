import { prisma } from '../src/config/prisma';

async function main() {
  await prisma.$executeRawUnsafe(`
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM pg_enum e
    JOIN pg_type t ON e.enumtypid = t.oid
    WHERE t.typname = 'SalaryRecordStatus' AND e.enumlabel = 'DRAFT'
  ) THEN
    ALTER TYPE "SalaryRecordStatus" RENAME VALUE 'DRAFT' TO 'UNPAID';
  END IF;
END $$;
`);
  await prisma.$executeRawUnsafe(`
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM pg_enum e
    JOIN pg_type t ON e.enumtypid = t.oid
    WHERE t.typname = 'SalaryRecordStatus' AND e.enumlabel = 'FINALIZED'
  ) THEN
    ALTER TYPE "SalaryRecordStatus" RENAME VALUE 'FINALIZED' TO 'PAID';
  END IF;
END $$;
`);
  await prisma.$executeRawUnsafe(
    `ALTER TABLE "employee_salary_records" ALTER COLUMN "status" SET DEFAULT 'UNPAID'::"SalaryRecordStatus"`,
  );
  const rows = await prisma.$queryRawUnsafe<{ enumlabel: string }[]>(
    `SELECT e.enumlabel FROM pg_enum e JOIN pg_type t ON e.enumtypid = t.oid WHERE t.typname = 'SalaryRecordStatus' ORDER BY e.enumsortorder`,
  );
  console.log('SalaryRecordStatus values:', rows);
}

main()
  .catch((e) => {
    console.error(e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
