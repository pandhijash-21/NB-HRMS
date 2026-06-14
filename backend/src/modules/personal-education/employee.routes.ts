import { Router } from 'express';
import { requireAuth } from '../../middleware/auth';
import { requirePermission } from '../../middleware/rbac';
import {
  requireEmployeeDirectoryView,
  requireEmployeeDirectoryWrite,
} from '../../middleware/employeeDirectory';
import { employeeController } from './employee.controller';

export const employeeRouter = Router();

employeeRouter.get('/', requireAuth, requireEmployeeDirectoryView(), employeeController.list);
employeeRouter.get('/names', requireAuth, employeeController.listNames);
employeeRouter.post('/full', requireAuth, requireEmployeeDirectoryWrite(), employeeController.createFull);
employeeRouter.get('/:id', requireAuth, employeeController.getById);
employeeRouter.get('/:id/assignments', requireAuth, requireEmployeeDirectoryView(), employeeController.listAssignments);
employeeRouter.post('/admin/backfill-assignments', requireAuth, requireEmployeeDirectoryWrite(), employeeController.backfillAssignments);
employeeRouter.post('/:id/institute-transfer', requireAuth, requireEmployeeDirectoryWrite(), employeeController.instituteTransfer);
employeeRouter.post('/:id/designation-upgrade', requireAuth, requireEmployeeDirectoryWrite(), employeeController.designationUpgrade);
employeeRouter.patch('/:id/position', requireAuth, requireEmployeeDirectoryWrite(), employeeController.assignPosition);
employeeRouter.patch('/:id', requireAuth, employeeController.update);
employeeRouter.delete('/:id', requireAuth, requireEmployeeDirectoryWrite(), employeeController.delete);
