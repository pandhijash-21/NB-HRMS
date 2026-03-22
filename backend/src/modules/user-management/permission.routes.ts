import { Router } from 'express';
import { requireAuth } from '../../middleware/auth';
import { requirePermission } from '../../middleware/rbac';
import { permissionController } from './permission.controller';

export const permissionRouter = Router();

// Modules list — needed for permission matrix UI
permissionRouter.get(
  '/modules',
  requireAuth,
  requirePermission('ROLE_MGMT', 'READ'),
  permissionController.listModules
);

// Role permissions
permissionRouter.get(
  '/roles/:roleId/permissions',
  requireAuth,
  requirePermission('ROLE_MGMT', 'READ'),
  permissionController.getForRole
);

permissionRouter.put(
  '/roles/:roleId/permissions',
  requireAuth,
  requirePermission('ROLE_MGMT', 'WRITE'),
  permissionController.replaceForRole
);

permissionRouter.patch(
  '/roles/:roleId/permissions/:moduleKey',
  requireAuth,
  requirePermission('ROLE_MGMT', 'WRITE'),
  permissionController.patchModulePermission
);
