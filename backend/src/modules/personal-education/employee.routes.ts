import { Router } from 'express';
import { requireAuth } from '../../middleware/auth';
import { requireRole } from '../../middleware/rbac';
import { employeeController } from './employee.controller';

export const employeeRouter = Router();

const hrAdmin = requireRole(['HR', 'ADMIN']);

employeeRouter.get('/',      requireAuth, hrAdmin, employeeController.list);
employeeRouter.post('/full', requireAuth, hrAdmin, employeeController.createFull);
employeeRouter.get('/:id',   requireAuth, employeeController.getById);
employeeRouter.patch('/:id', requireAuth, hrAdmin, employeeController.update);
employeeRouter.delete('/:id',requireAuth, hrAdmin, employeeController.delete);
