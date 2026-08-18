import type { Request, Response } from 'express';
import { ok, fail } from '../../utils/response';
import { authService } from './auth.service';
import { LoginSchema, ChangePasswordSchema } from './auth.types';

export const authController = {
  async login(req: Request, res: Response) {
    const body = LoginSchema.safeParse(req.body);
    if (!body.success) {
      return res.status(400).json(fail(body.error.issues[0]?.message ?? 'Validation error'));
    }

    try {
      const result = await authService.login(body.data);

      if ('error' in result) {
        return res.status(result.status ?? 400).json(fail(result.error ?? 'Error'));
      }

      return res.json(ok(result));
    } catch (err) {
      console.error('LOGIN FAILED', err);
      return res.status(500).json(fail('Internal server error'));
    }
  },

  async logout(req: Request, res: Response) {
    const user = req.user!;
    await authService.logout(user.id, user.roleId);
    return res.json(ok({ message: 'Logged out' }));
  },

  async changePassword(req: Request, res: Response) {
    const body = ChangePasswordSchema.safeParse(req.body);
    if (!body.success) {
      return res.status(400).json(fail(body.error.issues[0]?.message ?? 'Validation error'));
    }

    const result = await authService.changePassword(req.user!.id, body.data);

    if ('error' in result) {
      return res.status(result.status ?? 400).json(fail(result.error ?? 'Error'));
    }

    return res.json(ok(result));
  },

  async resetPassword(req: Request, res: Response) {
    const userId = String(req.params.userId);
    const customPassword = typeof req.body?.password === 'string' ? req.body.password : undefined;

    const result = customPassword
      ? await authService.adminSetPassword(userId, req.user!.id, customPassword)
      : await authService.resetPassword(userId, req.user!.id);

    if ('error' in result) {
      return res.status(result.status ?? 400).json(fail(result.error ?? 'Error'));
    }

    return res.json(ok(result));
  },

  getMe(req: Request, res: Response) {
    return res.json(ok(authService.getMe(req.user!)));
  },
};
