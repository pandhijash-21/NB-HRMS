import dotenv from 'dotenv';
// Load backend/.env even in Docker (Compose DB/Redis/MinIO hostnames must still win).
dotenv.config({ override: !process.env.DOCKER });

// IMPORTANT: load env AFTER dotenv.config() runs.
// Using require here avoids ESM import hoisting ordering issues in tsx/nodemon.
// eslint-disable-next-line @typescript-eslint/no-var-requires
const { app } = require('./app') as typeof import('./app');
// eslint-disable-next-line @typescript-eslint/no-var-requires
const { env } = require('./config/env') as typeof import('./config/env');
// eslint-disable-next-line @typescript-eslint/no-var-requires
const { connectRedis } = require('./config/redis') as typeof import('./config/redis');
// eslint-disable-next-line @typescript-eslint/no-var-requires
const { ensureLeaveRepeatableJobs } = require('./jobs/leave/leaveSchedulers') as typeof import('./jobs/leave/leaveSchedulers');
// eslint-disable-next-line @typescript-eslint/no-var-requires
const { startLeaveCreditWorker } = require('./jobs/leave/leaveCredit.worker') as typeof import('./jobs/leave/leaveCredit.worker');
// eslint-disable-next-line @typescript-eslint/no-var-requires
const { startLeaveAbsenceExpireWorker } = require('./jobs/leave/leaveAbsenceExpire.worker') as typeof import('./jobs/leave/leaveAbsenceExpire.worker');
// eslint-disable-next-line @typescript-eslint/no-var-requires
const { startLeaveYearEndWorker } = require('./jobs/leave/leaveYearEnd.worker') as typeof import('./jobs/leave/leaveYearEnd.worker');
// eslint-disable-next-line @typescript-eslint/no-var-requires
const { startLeaveApproverTimeoutWorker } = require('./jobs/leave/leaveApproverTimeout.worker') as typeof import('./jobs/leave/leaveApproverTimeout.worker');
// eslint-disable-next-line @typescript-eslint/no-var-requires
const { ensureAttendanceRepeatableJobs } = require('./jobs/attendance/attendanceSchedulers') as typeof import('./jobs/attendance/attendanceSchedulers');
// eslint-disable-next-line @typescript-eslint/no-var-requires
const { startAttendanceSyncWorker } = require('./jobs/attendance/attendanceSync.worker') as typeof import('./jobs/attendance/attendanceSync.worker');

async function start() {
  let redisReady = false;
  try {
    await connectRedis();
    console.log('Redis connected');
    redisReady = true;
  } catch (err) {
    console.warn('Redis unavailable on startup — sessions will be JWT-only:', err);
  }

  // eslint-disable-next-line @typescript-eslint/no-var-requires
  const http = require('http') as typeof import('http');
  const server = http.createServer(app);
  try {
    // eslint-disable-next-line @typescript-eslint/no-var-requires
    const { setupCollaborationSocket } = require('./modules/collaboration/socket') as typeof import('./modules/collaboration/socket');
    await setupCollaborationSocket(server);
    console.log('Chat & meet socket ready');
  } catch (err) {
    console.warn('Collaboration socket failed to start:', err);
  }

  try {
    const { ensureErpModulePermissions } = require('./bootstrap/erpModules') as typeof import('./bootstrap/erpModules');
    await ensureErpModulePermissions();
  } catch (err) {
    console.warn('ERP module permission bootstrap skipped:', err);
  }

  if (redisReady) {
    try {
      startLeaveCreditWorker();
      startLeaveAbsenceExpireWorker();
      startLeaveYearEndWorker();
      startLeaveApproverTimeoutWorker();
      startAttendanceSyncWorker();
      await ensureLeaveRepeatableJobs();
      await ensureAttendanceRepeatableJobs();
      console.log('Leave & attendance jobs started');

      // Tracking Hub Background Polling (Every 60s)
      // eslint-disable-next-line @typescript-eslint/no-var-requires
      const { trackingService } = require('./modules/tracking/tracking.service') as typeof import('./modules/tracking/tracking.service');
      setInterval(() => {
        trackingService.checkMissingHeartbeats().catch(console.error);
      }, 60000);
      
    } catch (err) {
      console.warn('Leave jobs could not be started:', err);
    }
  }

  server.listen(env.PORT, () => {
    console.log(`Server running on port ${env.PORT}`);
  });
}

start();

export default app;
