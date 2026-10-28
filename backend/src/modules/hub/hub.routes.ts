import { Router } from 'express';
import { hubController } from './hub.controller';

export const hubRouter = Router();

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
