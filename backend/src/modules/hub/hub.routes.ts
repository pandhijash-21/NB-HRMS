import { Router, Request, Response, NextFunction } from 'express';
import { requirePermission, type PermissionAction } from '../../middleware/rbac';
import { hubController } from './hub.controller';

export const hubRouter = Router();

function actionFor(method: string): PermissionAction {
  return ['POST', 'PUT', 'PATCH', 'DELETE'].includes(method) ? 'WRITE' : 'READ';
}

function requirePartners(req: Request, res: Response, next: NextFunction) {
  return requirePermission('CRM_PARTNERS', actionFor(req.method))(req, res, next);
}

hubRouter.use(requirePartners);

// Trash / archived records (must precede /:identifier)
hubRouter.get('/trash', hubController.getTrash);
hubRouter.get('/trash/records', hubController.getTrash);

// Explicit profile endpoint
hubRouter.get('/profile', hubController.getPartnerByIdentifier);
hubRouter.get('/profile/:identifier', hubController.getPartnerByIdentifier);

// Collection operations
hubRouter.get('/', hubController.getPartners);
hubRouter.post('/', hubController.createPartner);

// Item operations (fetch by email or username, update by ID, delete by ID)
hubRouter.get('/:identifier', hubController.getPartnerByIdentifier);
hubRouter.put('/:id', hubController.updatePartner);
hubRouter.delete('/:id', hubController.deletePartner);
