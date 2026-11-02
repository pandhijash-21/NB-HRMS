/**
 * Manual runner for the same logic that runs once on server boot.
 * Run: npx tsx scripts/backfill-manual-lead-self-alloc.ts
 */
import { prisma } from '../src/config/prisma';
import { crmService } from '../src/modules/crm/crm.service';

async function main() {
  const result = await crmService.backfillManualLeadSelfAllocation();
  console.log(JSON.stringify(result, null, 2));
}

main()
  .catch((e) => {
    console.error(e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
