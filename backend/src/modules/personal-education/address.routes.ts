import { Router } from 'express';
import { requireAuth } from '../../middleware/auth';
import { requireSelfEmployeeOrPermission } from '../../middleware/rbac';
import { startAuditContext, flushAudit } from '../../middleware/audit';
import { addressController } from './address.controller';

export const addressRouter = Router();

addressRouter.get('/:id/address/:type', requireAuth, requireSelfEmployeeOrPermission('id', 'PERSONAL_INFO', 'READ'), addressController.getByType);
addressRouter.post('/:id/address', requireAuth, requireSelfEmployeeOrPermission('id', 'PERSONAL_INFO', 'WRITE'), startAuditContext, addressController.upsert, flushAudit);
addressRouter.patch('/:id/address/:type', requireAuth, requireSelfEmployeeOrPermission('id', 'PERSONAL_INFO', 'WRITE'), startAuditContext, addressController.updateByType, flushAudit);

