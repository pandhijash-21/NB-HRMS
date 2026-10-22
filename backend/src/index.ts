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
    // eslint-disable-next-line @typescript-eslint/no-var-requires
    const { prisma } = require('./config/prisma') as typeof import('./config/prisma');
    await prisma.$executeRawUnsafe(`
      DO $$ BEGIN
        IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'organizations') THEN
          ALTER TABLE "organizations" ADD COLUMN IF NOT EXISTS "deleted_at" TIMESTAMP(3);
        END IF;
        IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'institutes') THEN
          ALTER TABLE "institutes" ADD COLUMN IF NOT EXISTS "deleted_at" TIMESTAMP(3);
        END IF;
        IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'users') THEN
          ALTER TABLE "users" ADD COLUMN IF NOT EXISTS "deleted_at" TIMESTAMP(3);
        END IF;
        IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'position_slots') THEN
          ALTER TABLE "position_slots" ADD COLUMN IF NOT EXISTS "deleted_at" TIMESTAMP(3);
        END IF;
        IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'designations') THEN
          ALTER TABLE "designations" ADD COLUMN IF NOT EXISTS "deleted_at" TIMESTAMP(3);
        END IF;
      END $$;
    `);
    console.log('Database soft-delete columns verified');

    // Clean up corrupted legacy subOrganization entries (e.g. 4-digit years like '2020')
    await prisma.$executeRawUnsafe(`
      DO $$ BEGIN
        IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'employee_general_info') THEN
          UPDATE "employee_general_info"
          SET "sub_organization" = NULL
          WHERE "sub_organization" ~ '^\\d{4}$';
        END IF;
        IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'employee_assignments') THEN
          UPDATE "employee_assignments"
          SET "sub_organization" = NULL
          WHERE "sub_organization" ~ '^\\d{4}$';
        END IF;
        IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'system_modules') THEN
          UPDATE "system_modules"
          SET "category" = 'COLLABORATION'
          WHERE "key" IN ('CHAT', 'MEETINGS', 'TASKS', 'ORG_TREE', 'SUPPORT');
        END IF;
      END $$;
    `);

    // Wipe all PRE-sales data from Real Estate CRM (Finserve preserved)
    const presalesWipeRecord = await prisma.crmSetting.findUnique({
      where: { key: 'real_estate_presales_wiped_v1' },
    });
    if (!presalesWipeRecord) {
      console.log('==> One-time Real Estate Pre-Sales data wipe starting...');
      await prisma.$executeRawUnsafe(`
        DO $$ BEGIN
          IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'crm_leads') THEN
            IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'crm_proposals') THEN
              DELETE FROM crm_proposals WHERE lead_id IN (SELECT id FROM crm_leads WHERE scope != 'NB_FINSERVE' OR scope IS NULL);
            END IF;
            IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'crm_follow_ups') THEN
              DELETE FROM crm_follow_ups WHERE lead_id IN (SELECT id FROM crm_leads WHERE scope != 'NB_FINSERVE' OR scope IS NULL);
            END IF;
            IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'crm_call_logs') THEN
              UPDATE crm_call_logs SET lead_id = NULL WHERE lead_id IN (SELECT id FROM crm_leads WHERE scope != 'NB_FINSERVE' OR scope IS NULL);
            END IF;
            DELETE FROM crm_leads WHERE scope != 'NB_FINSERVE' OR scope IS NULL;
          END IF;
        END $$;
      `);
      await prisma.crmSetting.upsert({
        where: { key: 'real_estate_presales_wiped_v1' },
        update: { value: new Date().toISOString() },
        create: {
          key: 'real_estate_presales_wiped_v1',
          value: new Date().toISOString(),
          description: 'One-time wipe of Real Estate Pre-Sales leads and sales records',
        },
      });
      console.log('==> One-time Real Estate Pre-Sales data wipe completed successfully!');
    }
  } catch (err) {
    console.warn('Database schema column verify notice:', err);
  }

  try {
    // eslint-disable-next-line @typescript-eslint/no-var-requires
    const { ensureErpModulePermissions } = require('./bootstrap/erpModules') as typeof import('./bootstrap/erpModules');
    await ensureErpModulePermissions();
  } catch (err) {
    console.warn('ERP module permission bootstrap skipped:', err);
  }

  try {
    const { syncAllEmployeeRolesWithDesignations } = require('./modules/designation/designationRole.util') as typeof import('./modules/designation/designationRole.util');
    await syncAllEmployeeRolesWithDesignations();
  } catch (err) {
    console.warn('Designation role sync bootstrap skipped:', err);
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

      // Purge expired trips once a day (based on trip_retention_days setting)
      let lastTripPurgeDay = '';
      const runTripPurgeIfDue = () => {
        const day = new Date().toISOString().slice(0, 10);
        if (day === lastTripPurgeDay) return;
        lastTripPurgeDay = day;
        trackingService
          .purgeExpiredTrips()
          .then((r) => {
            if (!r.skipped && (r.deletedTrips > 0 || r.deletedPoints > 0)) {
              console.log(
                `[tracking] purged ${r.deletedTrips} trips / ${r.deletedPoints} points (retention ${r.days}d)`,
              );
            }
          })
          .catch(console.error);
      };
      runTripPurgeIfDue();
      setInterval(runTripPurgeIfDue, 60 * 60 * 1000);
      
    } catch (err) {
      console.warn('Leave jobs could not be started:', err);
    }
  }

  const { runPunchReminders } = require('./modules/attendance/punchReminder.job') as typeof import('./modules/attendance/punchReminder.job');
  void runPunchReminders();
  setInterval(() => {
    void runPunchReminders();
  }, 60 * 1000);
  console.log('Punch reminders run every minute');

  // CRM Untouched Leads Recovery & Waiting Queue Auto-Dispatcher (Every 60s)
  try {
    const { crmService } = require('./modules/crm/crm.service') as typeof import('./modules/crm/crm.service');
    const runCrmLeadRecoveryWorker = async () => {
      try {
        await crmService.recoverUntouchedLeadsAndDispatch('NB_DEVELOPER');
        await crmService.recoverUntouchedLeadsAndDispatch('NB_FINSERVE');
      } catch (workerErr) {
        console.error('[CRM Lead Recovery Worker Error]:', workerErr);
      }
    };
    // Run initial pass after 10s warmup, then every 60s
    setTimeout(() => {
      void runCrmLeadRecoveryWorker();
    }, 10000);
    setInterval(() => {
      void runCrmLeadRecoveryWorker();
    }, 60 * 1000);
    console.log('CRM 30-min untouched lead recovery and waiting queue worker started (60s)');
  } catch (err) {
    console.warn('CRM lead recovery worker setup notice:', err);
  }

  server.listen(env.PORT, () => {
    console.log(`Server running on port ${env.PORT}`);
  });
}

start();

export default app;
