/**
 * One-time: copy NB Capital loan data from CrmLead.customFields into CrmLoan* tables.
 *
 * Usage (from backend/):
 *   npx ts-node scripts/migrate-finserve-loan-tables.ts
 */
import { migrateLoanDataFromCustomFields } from '../src/modules/crm/loanApplication.helpers';

async function main() {
  const result = await migrateLoanDataFromCustomFields();
  console.log(JSON.stringify(result, null, 2));
}

main()
  .then(() => process.exit(0))
  .catch((err) => {
    console.error(err);
    process.exit(1);
  });
