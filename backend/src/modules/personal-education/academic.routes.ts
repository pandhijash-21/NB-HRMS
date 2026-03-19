import { Router } from 'express';
import { requireAuth } from '../../middleware/auth';
import { academicController } from './academic.controller';

export const academicRouter = Router();

academicRouter.get('/:id/academic', requireAuth, academicController.list);
academicRouter.post('/:id/academic', requireAuth, academicController.create);
academicRouter.patch('/:id/academic/:qualId', requireAuth, academicController.update);

