import { Router } from 'express';
import { requireAuth } from '../../middleware/auth';
import { uploadController } from './upload.controller';

export const uploadRouter = Router();

uploadRouter.post('/photo', requireAuth, uploadController.photo);
uploadRouter.post('/signature', requireAuth, uploadController.signature);
uploadRouter.post('/aadhaar-card', requireAuth, uploadController.aadhaarCard);
uploadRouter.post('/pan-card', requireAuth, uploadController.panCard);
uploadRouter.post('/marksheet', requireAuth, uploadController.marksheet);
uploadRouter.post('/certificate', requireAuth, uploadController.certificate);

