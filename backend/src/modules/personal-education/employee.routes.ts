import { Router } from 'express';
import { requireAuth } from '../../middleware/auth';
import { requireRole } from '../../middleware/rbac';
import { employeeController } from './employee.controller';

export const employeeRouter = Router();

employeeRouter.get('/:id', requireAuth, employeeController.getById);
employeeRouter.post('/', requireAuth, requireRole(['HR', 'ADMIN']), employeeController.create);
employeeRouter.patch('/:id', requireAuth, employeeController.update);

