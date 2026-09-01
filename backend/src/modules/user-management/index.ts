import { Router } from 'express';
import { userRouter } from './user.routes';
import { roleRouter } from './role.routes';
import { permissionRouter } from './permission.routes';
import { storageRouter } from '../admin-storage';

const userMgmtRouter = Router();

// /api/admin/storage — register before parameterized /roles routes
userMgmtRouter.use('/storage', storageRouter);

// /api/admin/users
userMgmtRouter.use('/users', userRouter);

// /api/admin/roles
userMgmtRouter.use('/roles', roleRouter);

// /api/admin/modules and /api/admin/roles/:roleId/permissions
userMgmtRouter.use('/', permissionRouter);

export { userMgmtRouter };
