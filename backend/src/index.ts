import dotenv from 'dotenv';
if (!process.env.DOCKER) {
  dotenv.config({ override: true });
}

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

async function start() {
  let redisReady = false;
  try {
    await connectRedis();
    console.log('Redis connected');
    redisReady = true;
  } catch (err) {
    console.warn('Redis unavailable on startup — sessions will be JWT-only:', err);
  }

  if (redisReady) {
    try {
      startLeaveCreditWorker();
      startLeaveAbsenceExpireWorker();
      await ensureLeaveRepeatableJobs();
      console.log('Leave jobs started');
    } catch (err) {
      console.warn('Leave jobs could not be started:', err);
    }
  }

  app.listen(env.PORT, () => {
    console.log(`Server running on port ${env.PORT}`);
  });
}

start();

export default app;
