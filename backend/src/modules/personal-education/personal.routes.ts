import { Router } from 'express';
import { requireAuth } from '../../middleware/auth';
import { startAuditContext, flushAudit } from '../../middleware/audit';
import { personalController } from './personal.controller';

export const personalRouter = Router();

personalRouter.get('/:id/personal', requireAuth, personalController.get);
personalRouter.post('/:id/personal', requireAuth, startAuditContext, personalController.create, flushAudit);
personalRouter.patch('/:id/personal', requireAuth, startAuditContext, personalController.update, flushAudit);

