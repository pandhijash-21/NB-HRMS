import { Router } from 'express';
import { userRouter } from './user.routes';
import { roleRouter } from './role.routes';
import { permissionRouter } from './permission.routes';

const userMgmtRouter = Router();

// /api/admin/users
userMgmtRouter.use('/users', userRouter);

// /api/admin/roles
userMgmtRouter.use('/roles', roleRouter);

// /api/admin/modules and /api/admin/roles/:roleId/permissions
userMgmtRouter.use('/', permissionRouter);

export { userMgmtRouter };
