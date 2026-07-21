import { Router } from 'express';
import { requireAuth } from '../../middleware/auth';
import { requireSelfEmployeeOrPermission } from '../../middleware/rbac';
import { experienceController } from './experience.controller';

export const experienceRouter = Router();

experienceRouter.get(
  '/:id/experience',
  requireAuth,
  requireSelfEmployeeOrPermission('id', 'EXPERIENCE', 'READ'),
  experienceController.list,
);
experienceRouter.post(
  '/:id/experience',
  requireAuth,
  requireSelfEmployeeOrPermission('id', 'EXPERIENCE', 'WRITE'),
  experienceController.create,
);
experienceRouter.patch(
  '/:id/experience/:experienceId',
  requireAuth,
  requireSelfEmployeeOrPermission('id', 'EXPERIENCE', 'WRITE'),
  experienceController.update,
);
experienceRouter.delete(
  '/:id/experience/:experienceId',
  requireAuth,
  requireSelfEmployeeOrPermission('id', 'EXPERIENCE', 'DELETE'),
  experienceController.remove,
);
