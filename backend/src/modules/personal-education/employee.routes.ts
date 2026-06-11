import { Router } from 'express';
import { requireAuth } from '../../middleware/auth';
import { requireRole } from '../../middleware/rbac';
import { employeeController } from './employee.controller';

export const employeeRouter = Router();

// HR/Admin can manage employees. HOI position accounts can read a scoped list.
const hrAdmin = requireRole(['HR', 'ADMIN']);
const employeeDirectory = requireRole(['HR', 'ADMIN', 'HOI']);

employeeRouter.get('/',       requireAuth, employeeDirectory, employeeController.list);
employeeRouter.get('/names',  requireAuth, employeeController.listNames);
employeeRouter.post('/full',  requireAuth, hrAdmin, employeeController.createFull);
employeeRouter.get('/:id',    requireAuth, employeeController.getById);
employeeRouter.get('/:id/assignments', requireAuth, hrAdmin, employeeController.listAssignments);
employeeRouter.post('/admin/backfill-assignments', requireAuth, hrAdmin, employeeController.backfillAssignments);
employeeRouter.post('/:id/institute-transfer', requireAuth, hrAdmin, employeeController.instituteTransfer);
employeeRouter.post('/:id/designation-upgrade', requireAuth, hrAdmin, employeeController.designationUpgrade);
employeeRouter.patch('/:id', requireAuth, hrAdmin, employeeController.update);
employeeRouter.delete('/:id',requireAuth, hrAdmin, employeeController.delete);
