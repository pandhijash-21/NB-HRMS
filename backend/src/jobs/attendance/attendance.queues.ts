import { Queue } from 'bullmq';
import { getBullmqConnection } from '../../config/bullmq';

export const ATTENDANCE_QUEUE_NAMES = {
  SYNC_ESSL: 'attendance.sync_essl',
} as const;

const connection = getBullmqConnection();

export const attendanceSyncQueue = new Queue(ATTENDANCE_QUEUE_NAMES.SYNC_ESSL, { connection });

