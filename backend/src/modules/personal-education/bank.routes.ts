import { Router } from 'express';
import { requireAuth } from '../../middleware/auth';
import { startAuditContext, flushAudit } from '../../middleware/audit';
import { bankController } from './bank.controller';

export const bankRouter = Router();

bankRouter.get('/:id/bank',  requireAuth, bankController.get);
bankRouter.patch('/:id/bank', requireAuth, startAuditContext, bankController.upsert, flushAudit);
