import { Queue } from 'bullmq';
import { getBullmqConnection } from '../../config/bullmq';

export const LEAVE_QUEUE_NAMES = {
  CREDIT: 'leave.credit',
  YEAR_END: 'leave.year_end',
  APPROVER_REMINDER: 'leave.approver_reminder',
  APPROVER_TIMEOUT: 'leave.approver_timeout',
  ABSENCE_EXPIRE: 'leave.absence_expire',
} as const;

const connection = getBullmqConnection();

export const leaveCreditQueue = new Queue(LEAVE_QUEUE_NAMES.CREDIT, { connection });
export const leaveYearEndQueue = new Queue(LEAVE_QUEUE_NAMES.YEAR_END, { connection });
export const leaveApproverReminderQueue = new Queue(LEAVE_QUEUE_NAMES.APPROVER_REMINDER, { connection });
export const leaveApproverTimeoutQueue = new Queue(LEAVE_QUEUE_NAMES.APPROVER_TIMEOUT, { connection });
export const leaveAbsenceExpireQueue = new Queue(LEAVE_QUEUE_NAMES.ABSENCE_EXPIRE, { connection });

