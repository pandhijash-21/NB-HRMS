import express from 'express';
import cors from 'cors';
import helmet from 'helmet';

import actionsRouter from './actions';
import eventsRouter from './events';
import { personalEducationRouter } from './modules/personal-education';
import { authRouter } from './modules/auth';
import { userMgmtRouter } from './modules/user-management';
import { approvalsRouter } from './modules/approvals';
import { eventsRouter as sseEventsRouter } from './modules/events';
import { env } from './config/env';
import { configureCloudinary } from './config/cloudinary';
import { connectRedis } from './config/redis';
import { fail, ok } from './utils/response';

configureCloudinary();

export const app = express();

app.use(cors({
  origin: env.CORS_ALLOWED_ORIGINS?.split(',').map((o) => o.trim()) ?? [
    'http://localhost:3000',
    'http://localhost:9695',
  ],
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
app.use('/api/admin', userMgmtRouter);
app.use('/api/approvals', approvalsRouter);
app.use('/api/events', sseEventsRouter);

app.use((err: unknown, _req: express.Request, res: express.Response, _next: express.NextFunction) => {
  console.error(err);
  res.status(500).json(fail('Internal server error'));
});

