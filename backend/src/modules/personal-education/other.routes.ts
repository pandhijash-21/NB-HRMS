import { Router } from 'express';
import { requireAuth } from '../../middleware/auth';
import { requireSelfEmployeeOrPermission } from '../../middleware/rbac';
import { startAuditContext, flushAudit } from '../../middleware/audit';
import { otherController } from './other.controller';

export const otherRouter = Router();

otherRouter.get('/:id/other',  requireAuth, requireSelfEmployeeOrPermission('id', 'PERSONAL_INFO', 'READ'), otherController.get);
otherRouter.post('/:id/other', requireAuth, requireSelfEmployeeOrPermission('id', 'PERSONAL_INFO', 'WRITE'), startAuditContext, otherController.create, flushAudit);
otherRouter.patch('/:id/other',requireAuth, requireSelfEmployeeOrPermission('id', 'PERSONAL_INFO', 'WRITE'), startAuditContext, otherController.update, flushAudit);
