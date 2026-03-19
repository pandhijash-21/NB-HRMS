import express from 'express';
import cors from 'cors';
import helmet from 'helmet';

import actionsRouter from './actions';
import eventsRouter from './events';
import { personalEducationRouter } from './modules/personal-education';
import { env } from './config/env';
import { configureCloudinary } from './config/cloudinary';
import { connectRedis } from './config/redis';
import { fail, ok } from './utils/response';

configureCloudinary();

export const app = express();

app.use(cors());
app.use(helmet());
app.use(express.json({ limit: '2mb' }));

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
app.use('/api', personalEducationRouter);

app.use((err: unknown, _req: express.Request, res: express.Response, _next: express.NextFunction) => {
  console.error(err);
  res.status(500).json(fail('Internal server error'));
});

