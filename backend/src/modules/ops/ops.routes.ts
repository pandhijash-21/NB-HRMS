import { Router } from 'express';
import { requireAuth } from '../../middleware/auth';
import { opsController } from './ops.controller';

export const opsRouter = Router();

opsRouter.use(requireAuth);

opsRouter.get('/dashboard', (req, res) => void opsController.dashboard(req, res));
opsRouter.get('/backups', (req, res) => void opsController.backups(req, res));
opsRouter.post('/backups', (req, res) => void opsController.createBackup(req, res));
opsRouter.get('/live-logs', (req, res) => void opsController.liveLogs(req, res));
