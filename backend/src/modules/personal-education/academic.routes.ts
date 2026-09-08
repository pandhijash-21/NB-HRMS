import { Router } from 'express';
import { requireAuth } from '../../middleware/auth';
import { requireSelfEmployeeOrPermission } from '../../middleware/rbac';
import { academicController } from './academic.controller';

export const academicRouter = Router();

academicRouter.get('/:id/academic',              requireAuth, requireSelfEmployeeOrPermission('id', 'EDUCATION', 'READ'), academicController.list);
academicRouter.post('/:id/academic',             requireAuth, requireSelfEmployeeOrPermission('id', 'EDUCATION', 'WRITE'), academicController.create);
academicRouter.patch('/:id/academic/:qualId',    requireAuth, requireSelfEmployeeOrPermission('id', 'EDUCATION', 'WRITE'), academicController.update);
academicRouter.delete('/:id/academic/:qualId',   requireAuth, requireSelfEmployeeOrPermission('id', 'EDUCATION', 'DELETE'), academicController.softDelete);

