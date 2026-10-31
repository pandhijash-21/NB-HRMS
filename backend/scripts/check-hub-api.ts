/**
 * Quick connectivity check against NB Hub REST API.
 * Usage: npx ts-node --transpile-only scripts/check-hub-api.ts
 */
import 'dotenv/config';
import { HubApiService } from '../src/modules/hub/hub.service';

async function main() {
  const hub = new HubApiService();
  console.log(`[Hub check] baseUrl=${hub.getBaseUrl()}`);
  const result = await hub.healthCheck();
  if (!result.ok) {
    console.error('[Hub check] FAILED:', result.message);
    process.exit(1);
  }
  console.log(`[Hub check] OK — ${result.count ?? 0} active partner(s)`);
  process.exit(0);
}

main().catch((err) => {
  console.error('[Hub check] ERROR:', err?.message || err);
  process.exit(1);
});
