import { Router } from 'express';
import { requireAuth } from '../../middleware/auth';
import { requirePermission } from '../../middleware/rbac';
import { roleController } from './role.controller';

export const roleRouter = Router();

roleRouter.get(   '/',    requireAuth, requirePermission('ROLE_MGMT', 'READ'),   roleController.list);
roleRouter.get(   '/:id', requireAuth, requirePermission('ROLE_MGMT', 'READ'),   roleController.getById);
roleRouter.post(  '/',    requireAuth, requirePermission('ROLE_MGMT', 'WRITE'),  roleController.create);
roleRouter.patch( '/:id', requireAuth, requirePermission('ROLE_MGMT', 'WRITE'),  roleController.update);
roleRouter.delete('/:id', requireAuth, requirePermission('ROLE_MGMT', 'DELETE'), roleController.softDelete);
