import { Router } from 'express';
import { requireAuth } from '../../middleware/auth';
import { requireRole } from '../../middleware/rbac';
import { startAuditContext, flushAudit } from '../../middleware/audit';
import { generalController } from './general.controller';

export const generalRouter = Router();

const hrAdminHoi = requireRole(['HR', 'ADMIN', 'HOI']);

generalRouter.get('/:id/general',  requireAuth, generalController.get);
generalRouter.post('/:id/general', requireAuth, hrAdminHoi, startAuditContext, generalController.create, flushAudit);
generalRouter.patch('/:id/general',requireAuth, hrAdminHoi, startAuditContext, generalController.update, flushAudit);
