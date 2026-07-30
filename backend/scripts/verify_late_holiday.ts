import { attendanceService } from '../src/modules/attendance/attendance.service';

async function main() {
  const history = await attendanceService.getAdminEmployeeHistory({
    employeeId: 1,
    from: '2026-07-01',
    to: '2026-07-31',
  });
  const sample = history.days.filter((d) =>
    ['2026-07-07', '2026-07-09', '2026-07-12', '2026-07-19', '2026-07-20'].includes(d.date),
  );
  console.log(
    JSON.stringify(
      {
        policy: history.policy,
        sample: sample.map((d) => ({
          date: d.date,
          firstIn: d.firstIn,
          isLate: d.isLate,
          dayStatus: d.dayStatus,
        })),
      },
      null,
      2,
    ),
  );

  const history2 = await attendanceService.getAdminEmployeeHistory({
    employeeId: 2,
    from: '2026-07-01',
    to: '2026-07-31',
  });
  console.log('emp2 policy', JSON.stringify(history2.policy, null, 2));
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
