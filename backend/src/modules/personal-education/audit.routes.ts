import { Router } from 'express';
import { requireAuth } from '../../middleware/auth';
import { requireRole } from '../../middleware/rbac';
import { auditController } from './audit.controller';

export const auditRouter = Router();

auditRouter.get('/:id/audit-log', requireAuth, requireRole(['HR', 'ADMIN']), auditController.list);

