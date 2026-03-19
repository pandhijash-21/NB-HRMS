import { Router } from 'express';
import { requireAuth } from '../../middleware/auth';
import { startAuditContext, flushAudit } from '../../middleware/audit';
import { familyController } from './family.controller';

export const familyRouter = Router();

familyRouter.get('/:id/family', requireAuth, familyController.list);
familyRouter.post('/:id/family', requireAuth, startAuditContext, familyController.create, flushAudit);
familyRouter.patch('/:id/family/:memberId', requireAuth, startAuditContext, familyController.update, flushAudit);
familyRouter.delete('/:id/family/:memberId', requireAuth, startAuditContext, familyController.softDelete, flushAudit);

