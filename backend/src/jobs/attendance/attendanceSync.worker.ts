import { Worker } from 'bullmq';
import { getBullmqConnection } from '../../config/bullmq';
import { attendanceSyncService } from '../../modules/attendance/attendanceSync.service';
import { ATTENDANCE_QUEUE_NAMES } from './attendance.queues';

export function startAttendanceSyncWorker() {
  const connection = getBullmqConnection();
  // eslint-disable-next-line no-new
  new Worker(
    ATTENDANCE_QUEUE_NAMES.SYNC_ESSL,
    async () => {
      const etime = await attendanceSyncService.syncEtimeofficePunches();
      const essl = await attendanceSyncService.syncEsslPunches();
      return { etime, essl };
    },
    { connection },
  );
}
