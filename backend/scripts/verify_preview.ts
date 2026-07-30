import dotenv from 'dotenv';
dotenv.config({ override: true });

async function main() {
  const { fetchPaytimeMeta, fetchPaytimePunchesInRange, resetPaytimeColumnCache } =
    await import('../src/modules/attendance/esslMssql.client');
  resetPaytimeColumnCache();
  const m = await fetchPaytimeMeta();
  console.log('META', m);
  const rows = await fetchPaytimePunchesInRange({ fromYmd: '2026-06-30', toYmd: '2026-06-30' });
  console.log('JUN30_ROWS', rows.length);
  console.log('SAMPLE', rows.slice(0, 3));
  const r82 = await fetchPaytimePunchesInRange({
    fromYmd: '2023-11-01',
    toYmd: '2026-06-30',
    punchId: '82',
  });
  console.log('CARD82', r82.length);
  const r1 = await fetchPaytimePunchesInRange({
    fromYmd: '2026-06-30',
    toYmd: '2026-06-30',
    punchId: '1',
  });
  console.log('CARD1_JUN30', r1.length);
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
