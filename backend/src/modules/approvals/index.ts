import { Router } from 'express';
import { approvalController } from './approval.controller';
import { requireAuth } from '../../middleware/auth';

export const approvalsRouter = Router();

approvalsRouter.use(requireAuth);

// Employee: check & submit change requests
approvalsRouter.get('/pending', approvalController.getPending);
approvalsRouter.post('/', approvalController.create);

// Admin/HR only
approvalsRouter.get('/', requireAuth, approvalController.list);
approvalsRouter.post('/:id/approve', approvalController.approve);
approvalsRouter.post('/:id/reject', approvalController.reject);
