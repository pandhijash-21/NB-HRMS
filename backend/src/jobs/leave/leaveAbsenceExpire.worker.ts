import { Worker } from 'bullmq';
import { getBullmqConnection } from '../../config/bullmq';
import { absenceLwpService } from '../../modules/leave/absenceLwp.service';
import { LEAVE_QUEUE_NAMES } from './leave.queues';

export function startLeaveAbsenceExpireWorker() {
  const connection = getBullmqConnection();

  return new Worker(
    LEAVE_QUEUE_NAMES.ABSENCE_EXPIRE,
    async (job) => {
      if (job.name !== 'expire') return;
      const { absenceRecordId } = job.data as { absenceRecordId: string };
      if (!absenceRecordId) return;
      await absenceLwpService.convertToLwpOnExpiry(absenceRecordId);
    },
    { connection },
  );
}
