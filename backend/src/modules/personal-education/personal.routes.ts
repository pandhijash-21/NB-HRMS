import { Router } from 'express';
import { requireAuth } from '../../middleware/auth';
import { requireSelfEmployeeOrPermission } from '../../middleware/rbac';
import { startAuditContext, flushAudit } from '../../middleware/audit';
import { personalController } from './personal.controller';

export const personalRouter = Router();

personalRouter.get('/:id/personal', requireAuth, requireSelfEmployeeOrPermission('id', 'PERSONAL_INFO', 'READ'), personalController.get);
personalRouter.post('/:id/personal', requireAuth, requireSelfEmployeeOrPermission('id', 'PERSONAL_INFO', 'WRITE'), startAuditContext, personalController.create, flushAudit);
personalRouter.patch('/:id/personal', requireAuth, requireSelfEmployeeOrPermission('id', 'PERSONAL_INFO', 'WRITE'), startAuditContext, personalController.update, flushAudit);

