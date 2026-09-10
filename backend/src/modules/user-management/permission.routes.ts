import { Router } from 'express';
import { requireAuth } from '../../middleware/auth';
import { requirePermission } from '../../middleware/rbac';
import { permissionController } from './permission.controller';

export const permissionRouter = Router();

// Modules list & management — full freedom of module management for RBAC
permissionRouter.get(
  '/modules',
  requireAuth,
  requirePermission('ROLE_MGMT', 'READ'),
  permissionController.listModules
);

permissionRouter.post(
  '/modules',
  requireAuth,
  requirePermission('ROLE_MGMT', 'WRITE'),
  permissionController.createModule
);

permissionRouter.patch(
  '/modules/:key',
  requireAuth,
  requirePermission('ROLE_MGMT', 'WRITE'),
  permissionController.updateModule
);

permissionRouter.delete(
  '/modules/:key',
  requireAuth,
  requirePermission('ROLE_MGMT', 'DELETE'),
  permissionController.deleteModule
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
