import { Worker } from 'bullmq';
import { getBullmqConnection } from '../../config/bullmq';
import { leaveAdminService } from '../../modules/leave/leaveAdmin.service';
import { LEAVE_QUEUE_NAMES } from './leave.queues';

export function startLeaveYearEndWorker() {
  const connection = getBullmqConnection();

  return new Worker(
    LEAVE_QUEUE_NAMES.YEAR_END,
    async (job) => {
      if (job.name !== 'year-end') return;
      const year = new Date().getUTCFullYear();
      const result = await leaveAdminService.runYearEnd(year, 'system');
      console.log('[leave.year_end]', result);
      return result;
    },
    { connection },
  );
}
