import { Router, Request, Response } from 'express';
import { z } from 'zod';
import { fail, ok } from '../../utils/response';
import { requireAuth } from '../../middleware/auth';
import { otpService } from './otp.service';

const sendOtpSchema = z.object({
  email: z.string().email('Invalid email format'),
});

const verifyOtpSchema = z.object({
  email: z.string().email('Invalid email format'),
  otp: z.string().length(6, 'OTP must be 6 digits'),
});

export const otpRouter = Router();

/** Pending personal / institutional emails for the signed-in employee. */
otpRouter.get('/status', requireAuth, async (req: Request, res: Response) => {
  try {
    const { id: userId, employeeId } = req.user!;
    const status = await otpService.getEmailVerificationStatus(userId, employeeId ?? null);
    const emails = await Promise.all(
      status.emails.map(async (e) => ({
        ...e,
        cooldownSeconds: e.verified ? 0 : await otpService.getCooldownRemaining(e.email),
      })),
    );
    return res.json(
      ok({
        needsEmailVerification: status.needsEmailVerification,
        emails,
      }),
    );
  } catch (err: any) {
    console.error('OTP status error:', err);
    return res.status(err.status || 500).json(fail(err.message || 'Failed to load verification status'));
  }
});

otpRouter.post('/send', requireAuth, async (req: Request, res: Response) => {
  try {
    const body = sendOtpSchema.safeParse(req.body);
    if (!body.success) {
      return res.status(400).json(fail(body.error.message));
    }

    const { email } = body.data;
    const { id: userId, roleName, employeeId } = req.user!;
    const privilegedRoles = ['ADMIN', 'HR'];
    const isPrivileged = privilegedRoles.includes(roleName ?? '');

    // Employees may only send OTP to their own profile emails.
    if (!isPrivileged) {
      await otpService.assertOwnsEmail(employeeId ?? null, email);
    }

    const result = await otpService.sendOtp(email, userId);
    return res.json(
      ok({
        message: 'OTP sent successfully',
        cooldownSeconds: result.cooldownSeconds,
      }),
    );
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
    const { id: userId, employeeId, roleName } = req.user!;
    const privilegedRoles = ['ADMIN', 'HR'];
    const isPrivileged = privilegedRoles.includes(roleName ?? '');

    let ownsEmail = false;
    if (employeeId != null) {
      try {
        await otpService.assertOwnsEmail(employeeId, email);
        ownsEmail = true;
      } catch {
        ownsEmail = false;
      }
    }

    if (!ownsEmail && !isPrivileged) {
      return res.status(403).json(fail('You can only verify your own personal or institutional email'));
    }

    if (ownsEmail) {
      const result = await otpService.verifyOtp(email, otp, userId, employeeId ?? null);
      return res.json(
        ok({
          message: 'Email verified successfully',
          verified: true,
          kind: result.kind,
          needsEmailVerification: result.needsEmailVerification,
        }),
      );
    }

    // HR/Admin verifying an email during employee create (not on their own profile).
    await otpService.verifyOtpCodeOnly(email, otp, userId);
    return res.json(ok({ message: 'Email verified successfully', verified: true }));
  } catch (err: any) {
    console.error('OTP verify error:', err);
    return res.status(err.status || 500).json(fail(err.message || 'Verification failed'));
  }
});
