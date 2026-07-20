import express from 'express';
import cors from 'cors';
import helmet from 'helmet';

import actionsRouter from './actions';
import eventsRouter from './events';
import { personalEducationRouter } from './modules/personal-education';
import { authRouter, otpRouter } from './modules/auth';
import { userMgmtRouter } from './modules/user-management';
import { approvalsRouter } from './modules/approvals';
import { eventsRouter as sseEventsRouter } from './modules/events';
import { leaveRouter } from './modules/leave';
import { attendanceRouter } from './modules/attendance';
import { designationRouter } from './modules/designation';
import { instituteRouter } from './modules/institute';
import { salaryRouter } from './modules/salary';
import { lookupRouter } from './modules/lookups/lookup.routes';
import { env } from './config/env';
import { configureCloudinary } from './config/cloudinary';
import { connectRedis } from './config/redis';
import { fail, ok } from './utils/response';
import { lettersRouter } from './modules/letters';
import { reimbursementsRouter } from './modules/reimbursements';

configureCloudinary();

export const app = express();

const configuredCorsOrigins = env.CORS_ALLOWED_ORIGINS?.split(',')
  .map((o) => o.trim())
  .filter(Boolean) ?? [
  'http://localhost:3000',
  'http://localhost:9695',
];

/** Allow configured origins plus any localhost / 127.0.0.1 port (Flutter web). */
function isAllowedCorsOrigin(origin: string | undefined): boolean {
  if (!origin) return true;
  if (configuredCorsOrigins.includes(origin)) return true;
  return /^https?:\/\/(localhost|127\.0\.0\.1)(:\d+)?$/.test(origin);
}

app.use(cors({
  origin: (origin, callback) => {
    if (isAllowedCorsOrigin(origin)) {
      callback(null, true);
      return;
    }
    callback(null, false);
  },
  credentials: true,
}));
app.use(helmet());
app.use(express.json({ limit: '2mb' }));

app.get('/', (_req, res) => {
  res.json(ok({ 
    message: 'HRMS Backend API is running', 
    version: '1.0.0',
    documentation: '/docs',
    health: '/health' 
  }));
});

app.get('/health', async (_req, res) => {
  try {
    await connectRedis();
  } catch {
    // health should still return ok even if redis is temporarily unavailable
  }
  res.json(ok({ status: 'ok', service: 'hrms-backend', port: env.PORT }));
});

app.use('/actions', actionsRouter);
app.use('/events', eventsRouter);

// Generic /api prefix - personal-education module
app.use('/api', personalEducationRouter);

// Specific routes
app.use('/api/auth',  authRouter);
app.use('/api/otp', otpRouter);
app.use('/api/admin', userMgmtRouter);
app.use('/api/approvals', approvalsRouter);
app.use('/api/leave', leaveRouter);
app.use('/api/attendance', attendanceRouter);
app.use('/api/letters', lettersRouter);
app.use('/api/reimbursements', reimbursementsRouter);
app.use('/api/admin', designationRouter);
app.use('/api', instituteRouter);
app.use('/api/salary', salaryRouter);
app.use('/api', lookupRouter);
app.use('/api/events', sseEventsRouter);

app.use((err: unknown, _req: express.Request, res: express.Response, _next: express.NextFunction) => {
  console.error(err);
  res.status(500).json(fail('Internal server error'));
});

