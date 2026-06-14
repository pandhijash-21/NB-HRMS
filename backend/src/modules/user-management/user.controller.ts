import type { Request, Response } from 'express';
import { ok, fail } from '../../utils/response';
import { userService } from './user.service';
import { CreateUserSchema, UpdateUserSchema } from './types';

export const userController = {
  async list(req: Request, res: Response) {
    const { roleId, isActive, search } = req.query;
    const users = await userService.list({
      roleId:   typeof roleId === 'string'   ? roleId   : undefined,
      isActive: isActive === 'true' ? true : isActive === 'false' ? false : undefined,
      search:   typeof search === 'string'   ? search   : undefined,
    });
    return res.json(ok(users));
  },

  async getCredentials(req: Request, res: Response) {
    const creds = await userService.getCredentials(String(req.params.id));
    if (!creds) return res.status(404).json(fail('User not found'));
    return res.json(ok(creds));
  },

  async getById(req: Request, res: Response) {
    const user = await userService.getById(String(req.params.id));
    if (!user) return res.status(404).json(fail('User not found'));
    return res.json(ok(user));
  },

  async create(req: Request, res: Response) {
    const body = CreateUserSchema.safeParse(req.body);
    if (!body.success) {
      return res.status(400).json(fail(body.error.issues[0]?.message ?? 'Validation error'));
    }

    const result = await userService.create(body.data, req.user!.id);
    if ('error' in result) return res.status(result.status ?? 400).json(fail(result.error ?? 'Error'));
    return res.status(201).json(ok(result));
  },

  async update(req: Request, res: Response) {
    const body = UpdateUserSchema.safeParse(req.body);
    if (!body.success) {
      return res.status(400).json(fail(body.error.issues[0]?.message ?? 'Validation error'));
    }

    const result = await userService.update(String(req.params.id), body.data, req.user!.id);
    if ('error' in result) return res.status(result.status ?? 400).json(fail(result.error ?? 'Error'));
    return res.json(ok(result));
  },

  async softDelete(req: Request, res: Response) {
    const result = await userService.softDelete(String(req.params.id), req.user!.id);
    if ('error' in result) return res.status(result.status ?? 400).json(fail(result.error ?? 'Error'));
    return res.json(ok(result));
  },
};
