import { Router } from 'express';
import { requireAuth } from '../../middleware/auth';
import { requirePermission } from '../../middleware/rbac';
import { userController } from './user.controller';

export const userRouter = Router();

userRouter.get(  '/',    requireAuth, requirePermission('USER_MGMT', 'READ'),   userController.list);
userRouter.get(  '/:id', requireAuth, requirePermission('USER_MGMT', 'READ'),   userController.getById);
userRouter.post( '/',    requireAuth, requirePermission('USER_MGMT', 'WRITE'),  userController.create);
userRouter.patch('/:id', requireAuth, requirePermission('USER_MGMT', 'WRITE'),  userController.update);
userRouter.delete('/:id',requireAuth, requirePermission('USER_MGMT', 'DELETE'), userController.softDelete);
