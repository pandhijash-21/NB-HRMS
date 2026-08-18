import type { NextFunction, Request, Response } from 'express';
import { Router } from 'express';
import { requireAuth } from '../../middleware/auth';
import {
  requireEmployeeDirectoryView,
  requireEmployeeDirectoryWrite,
} from '../../middleware/employeeDirectory';
import { employeeController } from './employee.controller';
import { fail } from '../../utils/response';

export const employeeRouter = Router();

function requireAdmin(req: Request, res: Response, next: NextFunction) {
  if (!req.user) return res.status(401).json(fail('Unauthenticated'));
  const role = String(req.user.roleName ?? req.user.role ?? '').toUpperCase();
  if (role !== 'ADMIN') {
    return res.status(403).json(fail('Only Admin can transfer institute or upgrade designation'));
  }
  return next();
}

function allowSelfOrDirectoryView(req: Request, res: Response, next: NextFunction) {
  const id = Number(req.params.id);
  if (req.user?.employeeId != null && Number(req.user.employeeId) === id) {
    return next();
  }
  return requireEmployeeDirectoryView()(req, res, next);
}

employeeRouter.get('/', requireAuth, requireEmployeeDirectoryView(), employeeController.list);
employeeRouter.get('/names', requireAuth, employeeController.listNames);
employeeRouter.post('/full', requireAuth, requireEmployeeDirectoryWrite(), employeeController.createFull);
employeeRouter.get('/:id', requireAuth, employeeController.getById);
employeeRouter.get('/:id/assignments', requireAuth, allowSelfOrDirectoryView, employeeController.listAssignments);
employeeRouter.post('/admin/backfill-assignments', requireAuth, requireEmployeeDirectoryWrite(), employeeController.backfillAssignments);
employeeRouter.post('/:id/institute-transfer', requireAuth, requireAdmin, employeeController.instituteTransfer);
employeeRouter.post('/:id/designation-upgrade', requireAuth, requireAdmin, employeeController.designationUpgrade);
employeeRouter.patch('/:id/position', requireAuth, requireEmployeeDirectoryWrite(), employeeController.assignPosition);
employeeRouter.patch('/:id', requireAuth, employeeController.update);
employeeRouter.delete('/:id', requireAuth, requireEmployeeDirectoryWrite(), employeeController.delete);
