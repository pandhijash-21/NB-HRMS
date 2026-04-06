import { Router, Request, Response } from 'express';
import { z } from 'zod';
import { fail, ok } from '../../utils/response';
import { requireAuth } from '../../middleware/auth';
import { otpService } from './otp.service';
import { env } from '../../config/env';

const sendOtpSchema = z.object({
  email: z.string().email('Invalid email format'),
});

const verifyOtpSchema = z.object({
  email: z.string().email('Invalid email format'),
  otp: z.string().length(6, 'OTP must be 6 digits'),
});

export const otpRouter = Router();

otpRouter.post('/send', requireAuth, async (req: Request, res: Response) => {
  try {
    const body = sendOtpSchema.safeParse(req.body);
    if (!body.success) {
      return res.status(400).json(fail(body.error.message));
    }

    const { email } = body.data;
    const { id: userId, roleName } = req.user!;

    // Only ADMIN, HR can send OTP for any email
    // Others can only request OTP for their own verified email
    const privilegedRoles = ['ADMIN', 'HR'];
    if (!privilegedRoles.includes(roleName)) {
      return res.status(403).json(fail('Only HR/Admin can send OTP to any email'));
    }

    await otpService.sendOtp(email, userId);
    return res.json(ok({ message: 'OTP sent successfully' }));
  } catch (err: any) {
    console.error('OTP send error:', err);
    return res.status(err.status || 500).json(fail(err.message || 'Failed to send OTP'));
  }
});

otpRouter.post('/verify', requireAuth, async (req: Request, res: Response) => {
  try {
    const body = verifyOtpSchema.safeParse(req.body);
    if (!body.success) {
      return res.status(400).json(fail(body.error.message));
    }

    const { email, otp } = body.data;
    const { id: userId } = req.user!;

    const isValid = await otpService.verifyOtp(email, otp, userId);
    
    if (!isValid) {
      return res.status(400).json(fail('Invalid or expired OTP'));
    }

    return res.json(ok({ 
      message: 'Email verified successfully',
      verified: true 
    }));
  } catch (err: any) {
    console.error('OTP verify error:', err);
    return res.status(err.status || 500).json(fail(err.message || 'Verification failed'));
  }
});
