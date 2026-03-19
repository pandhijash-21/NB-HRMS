import { Router } from 'express';
import { requireAuth } from '../../middleware/auth';
import { startAuditContext, flushAudit } from '../../middleware/audit';
import { addressController } from './address.controller';

export const addressRouter = Router();

addressRouter.get('/:id/address/:type', requireAuth, addressController.getByType);
addressRouter.post('/:id/address', requireAuth, startAuditContext, addressController.upsert, flushAudit);
addressRouter.patch('/:id/address/:type', requireAuth, startAuditContext, addressController.updateByType, flushAudit);

