import { Router } from 'express';
import type { NextFunction, Request, Response } from 'express';
import { requireAuth } from '../../middleware/auth';
import { requirePermission } from '../../middleware/rbac';
import { userController } from './user.controller';
import { fail } from '../../utils/response';

export const userRouter = Router();

import { isSuperAdminRole } from '../auth/permissions-map';

function requireUnblockLogin(req: Request, res: Response, next: NextFunction) {
  if (!req.user) return res.status(401).json(fail('Unauthenticated'));
  if (isSuperAdminRole(req.user.roleName ?? req.user.role)) return next();
  const held = req.user.permissions?.USER_MGMT ?? [];
  if (held.includes('WRITE') || held.includes('APPROVE')) return next();
  return res.status(403).json(fail('You do not have permission to unblock login'));
}

userRouter.get(  '/',    requireAuth, requirePermission('USER_MGMT', 'READ'),   userController.list);
userRouter.get(  '/:id/credentials', requireAuth, requirePermission('USER_MGMT', 'READ'), userController.getCredentials);
userRouter.post('/:id/unblock-login', requireAuth, requireUnblockLogin, userController.unblockLogin);
userRouter.get(  '/:id', requireAuth, requirePermission('USER_MGMT', 'READ'),   userController.getById);
userRouter.post( '/',    requireAuth, requirePermission('USER_MGMT', 'WRITE'),  userController.create);
userRouter.patch('/:id', requireAuth, requirePermission('USER_MGMT', 'WRITE'),  userController.update);
userRouter.delete('/:id',requireAuth, requirePermission('USER_MGMT', 'DELETE'), userController.softDelete);
