import { Router } from 'express';
import { requireAuth } from '../../middleware/auth';
import { startAuditContext, flushAudit } from '../../middleware/audit';
import { otherController } from './other.controller';

export const otherRouter = Router();

otherRouter.get('/:id/other',  requireAuth, otherController.get);
otherRouter.post('/:id/other', requireAuth, startAuditContext, otherController.create, flushAudit);
otherRouter.patch('/:id/other',requireAuth, startAuditContext, otherController.update, flushAudit);
