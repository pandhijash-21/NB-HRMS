import { Router } from 'express';
import { requireAuth } from '../../middleware/auth';
import { uploadController } from './upload.controller';

export const uploadRouter = Router();

// Existing uploads
uploadRouter.post('/photo', requireAuth, uploadController.photo);
uploadRouter.post('/signature', requireAuth, uploadController.signature);
uploadRouter.post('/aadhaar-card', requireAuth, uploadController.aadhaarCard);
uploadRouter.post('/pan-card', requireAuth, uploadController.panCard);
uploadRouter.post('/other-document', requireAuth, uploadController.otherDocument);
uploadRouter.post('/offer-letter', requireAuth, uploadController.offerLetter);
uploadRouter.post('/marksheet', requireAuth, uploadController.marksheet);
uploadRouter.post('/certificate', requireAuth, uploadController.certificate);

// NEW: Additional uploads
uploadRouter.post('/passport', requireAuth, uploadController.passport);
uploadRouter.post('/aadhaar-family', requireAuth, uploadController.aadhaarFamily);
uploadRouter.post('/experience-letter', requireAuth, uploadController.experienceLetter);
uploadRouter.post('/last-paycheck', requireAuth, uploadController.lastPaycheck);
uploadRouter.post('/recommendation', requireAuth, uploadController.recommendation);
uploadRouter.post('/cancelled-cheque', requireAuth, uploadController.cancelledCheque);
uploadRouter.post('/passbook', requireAuth, uploadController.passbook);
uploadRouter.post('/leave-document', requireAuth, uploadController.leaveDocument);
uploadRouter.post('/reimbursement-proof', requireAuth, uploadController.reimbursementProof);
