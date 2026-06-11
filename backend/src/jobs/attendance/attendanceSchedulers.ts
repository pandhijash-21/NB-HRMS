import { attendanceSyncQueue } from './attendance.queues';

/**
 * Runs every 10 minutes (UTC). Safe to run even without MSSQL creds (sync is a no-op until configured).
 */
export async function ensureAttendanceRepeatableJobs() {
  await attendanceSyncQueue.add(
    'sync-essl',
    {},
    { repeat: { pattern: '*/10 * * * *', tz: 'UTC' } }
  );
}

