import { Router } from 'express';
import { requireAuth } from '../../middleware/auth';
import { requirePermission } from '../../middleware/rbac';
import { authController } from './auth.controller';

export const authRouter = Router();

// Public
authRouter.post('/login',  authController.login);
authRouter.get('/branding', authController.getBranding);

// Authenticated
authRouter.post('/logout',          requireAuth, authController.logout);
authRouter.post('/change-password', requireAuth, authController.changePassword);
authRouter.get('/me',               requireAuth, authController.getMe);
authRouter.post('/software-tour/seen', requireAuth, authController.markSoftwareTourSeen);

// HR/Admin only — reset any user's password to default (DOB)
authRouter.post(
  '/reset-password/:userId',
  requireAuth,
  requirePermission('USER_MGMT', 'WRITE'),
  authController.resetPassword
);
