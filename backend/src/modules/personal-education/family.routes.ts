import { Router } from 'express';
import { requireAuth } from '../../middleware/auth';
import { requireSelfEmployeeOrPermission } from '../../middleware/rbac';
import { startAuditContext, flushAudit } from '../../middleware/audit';
import { familyController } from './family.controller';

export const familyRouter = Router();

familyRouter.get('/:id/family', requireAuth, requireSelfEmployeeOrPermission('id', 'PERSONAL_INFO', 'READ'), familyController.list);
familyRouter.post('/:id/family', requireAuth, requireSelfEmployeeOrPermission('id', 'PERSONAL_INFO', 'WRITE'), startAuditContext, familyController.create, flushAudit);
familyRouter.patch('/:id/family/:memberId', requireAuth, requireSelfEmployeeOrPermission('id', 'PERSONAL_INFO', 'WRITE'), startAuditContext, familyController.update, flushAudit);
familyRouter.delete('/:id/family/:memberId', requireAuth, requireSelfEmployeeOrPermission('id', 'PERSONAL_INFO', 'DELETE'), startAuditContext, familyController.softDelete, flushAudit);

