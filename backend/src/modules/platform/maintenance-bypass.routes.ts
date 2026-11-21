import { Router, Request, Response } from 'express';
import { ok, fail } from '../../utils/response';
import { maintenanceService } from './maintenance.service';

export const maintenanceBypassRouter = Router();

/**
 * Request OTP sent to it.nbdeveloper@gmail.com for 24-hour maintenance bypass.
 */
maintenanceBypassRouter.post('/request-otp', async (_req: Request, res: Response) => {
  try {
    const result = await maintenanceService.requestBypassOtp();
    if (!result.success) {
      return res.status(429).json(fail(result.message));
    }
    return res.json(ok(result));
  } catch (err: unknown) {
    return res.status(500).json(fail(err instanceof Error ? err.message : 'Failed to send verification code'));
  }
});

/**
 * Verify 6-digit OTP and issue a 24-hour bypass token.
 */
maintenanceBypassRouter.post('/verify-otp', async (req: Request, res: Response) => {
  try {
    const { otp } = req.body || {};
    if (!otp) {
      return res.status(400).json(fail('Verification code is required'));
    }
    const result = await maintenanceService.verifyBypassOtp(String(otp));
    return res.json(ok(result));
  } catch (err: unknown) {
    return res.status(400).json(fail(err instanceof Error ? err.message : 'Invalid verification code'));
  }
});

/**
 * Check if a provided bypass token is currently valid.
 */
maintenanceBypassRouter.get('/status', (req: Request, res: Response) => {
  const token = (req.headers['x-maintenance-bypass'] as string) || (req.query.token as string);
  const valid = !!token && maintenanceService.verifyBypassToken(token);
  return res.json(ok({ valid }));
});
