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
import { transportEncryptionMiddleware } from './middleware/transportEncryption';
import { lettersRouter } from './modules/letters';
import { reimbursementsRouter } from './modules/reimbursements';
import { recruitmentRouter } from './modules/recruitment';
import { repositoryRouter } from './modules/repository';
import { organizationRouter } from './modules/organization';
import { orgTreeRouter } from './modules/org-tree';

configureCloudinary();

export const app = express();

const configuredCorsOrigins = env.CORS_ALLOWED_ORIGINS?.split(',')
  .map((o) => o.trim())
  .filter(Boolean) ?? [
  'http://localhost:3000',
  'http://localhost:9695',
];

/** Allow configured origins, localhost (dev), Vercel, and Netlify hosts. */
function isAllowedCorsOrigin(origin: string | undefined): boolean {
  if (!origin) return true;
  if (configuredCorsOrigins.includes(origin)) return true;
  if (/^https?:\/\/(localhost|127\.0\.0\.1)(:\d+)?$/.test(origin)) return true;
  if (/^https:\/\/([a-z0-9-]+\.)*vercel\.app$/i.test(origin)) return true;
  // Netlify prod + deploy-preview URLs (e.g. abc--site.netlify.app)
  if (/^https:\/\/([a-z0-9-]+\.)*netlify\.app$/i.test(origin)) return true;
  return false;
}

app.set('trust proxy', 1);

app.use(cors({
  origin: (origin, callback) => {
    if (isAllowedCorsOrigin(origin)) {
      callback(null, true);
      return;
    }
    callback(null, false);
  },
  credentials: true,
  methods: ['GET', 'POST', 'PUT', 'PATCH', 'DELETE', 'OPTIONS'],
  allowedHeaders: ['Content-Type', 'Authorization', 'Accept', 'X-NB-Enc'],
}));
// Allow Flutter/web on Netlify/Vercel to read API responses (default helmet CORP is same-origin).
app.use(helmet({
  crossOriginResourcePolicy: { policy: 'cross-origin' },
  crossOriginOpenerPolicy: { policy: 'same-origin-allow-popups' },
}));
app.use(express.json({ limit: '2mb' }));
app.use(transportEncryptionMiddleware);

app.get('/', (_req, res) => {
  res.json(ok({ 
    message: 'HRMS Backend API is running', 
    version: '1.0.0',
    documentation: '/docs',
    health: '/health' 
  }));
});

app.get('/health', async (_req, res) => {
  let redisOk = false;
  try {
    await connectRedis();
    redisOk = true;
  } catch {
    // health should still return ok even if redis is temporarily unavailable
  }
  res.json(ok({
    status: 'ok',
    service: 'hrms-backend',
    port: env.PORT,
    redis: redisOk ? 'up' : 'down',
    env: env.NODE_ENV ?? 'development',
  }));
});

app.use('/actions', actionsRouter);
app.use('/events', eventsRouter);

import { trackingRouter } from './modules/tracking/tracking.routes';
import { tasksRouter } from './modules/tasks';

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
app.use('/api/recruitment', recruitmentRouter);
app.use('/api/repository', repositoryRouter);
app.use('/api', organizationRouter);
app.use('/api/org-tree', orgTreeRouter);
app.use('/api/admin', designationRouter);
app.use('/api', instituteRouter);
app.use('/api/salary', salaryRouter);
app.use('/api', lookupRouter);
app.use('/api/tracking', trackingRouter);
app.use('/api/tasks', tasksRouter);
app.use('/api/events', sseEventsRouter);

app.use((err: unknown, _req: express.Request, res: express.Response, _next: express.NextFunction) => {
  console.error(err);
  res.status(500).json(fail('Internal server error'));
});

