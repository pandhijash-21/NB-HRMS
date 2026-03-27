import { Router } from 'express';
import { requireAuth } from '../../middleware/auth';
import { requireRole } from '../../middleware/rbac';
import { employeeController } from './employee.controller';

export const employeeRouter = Router();

employeeRouter.post('/full', requireAuth, requireRole(['HR', 'ADMIN']), employeeController.createFull);
employeeRouter.get('/:id', requireAuth, employeeController.getById);
employeeRouter.delete('/:id', requireAuth, requireRole(['HR', 'ADMIN']), employeeController.delete);

