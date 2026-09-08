import { Router } from 'express';
import { requireAuth } from '../../middleware/auth';
import { requirePermission } from '../../middleware/rbac';
import { startAuditContext, flushAudit } from '../../middleware/audit';
import { bankController } from './bank.controller';

export const bankRouter = Router();

bankRouter.get('/:id/bank',  requireAuth, requirePermission('BANK_DETAILS', 'READ'), bankController.get);
bankRouter.patch('/:id/bank', requireAuth, requirePermission('BANK_DETAILS', 'WRITE'), startAuditContext, bankController.upsert, flushAudit);
