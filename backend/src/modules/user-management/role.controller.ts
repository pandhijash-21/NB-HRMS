import type { Request, Response } from 'express';
import { ok, fail } from '../../utils/response';
import { roleService } from './role.service';
import { CreateRoleSchema, UpdateRoleSchema } from './types';

export const roleController = {
  async list(req: Request, res: Response) {
    const positionsOnly = req.query.positionsOnly === 'true';
    const all = req.query.all === 'true';
    return res.json(
      ok(
        await roleService.list({
          positionsOnly,
          designationsOnly: !all && !positionsOnly,
        }),
      ),
    );
  },

  async getById(req: Request, res: Response) {
    const role = await roleService.getById(String(req.params.id));
    if (!role) return res.status(404).json(fail('Role not found'));
    return res.json(ok(role));
  },

  async create(req: Request, res: Response) {
    const body = CreateRoleSchema.safeParse(req.body);
    if (!body.success) {
      return res.status(400).json(fail(body.error.issues[0]?.message ?? 'Validation error'));
    }

    const result = await roleService.create(body.data, req.user!.id);
    if ('error' in result) return res.status(result.status ?? 400).json(fail(result.error ?? 'Error'));
    return res.status(201).json(ok(result));
  },

  async update(req: Request, res: Response) {
    const body = UpdateRoleSchema.safeParse(req.body);
    if (!body.success) {
      return res.status(400).json(fail(body.error.issues[0]?.message ?? 'Validation error'));
    }

    const result = await roleService.update(String(req.params.id), body.data, req.user!.id);
    if ('error' in result) return res.status(result.status ?? 400).json(fail(result.error ?? 'Error'));
    return res.json(ok(result));
  },

  async softDelete(req: Request, res: Response) {
    const result = await roleService.softDelete(String(req.params.id), req.user!.id);
    if ('error' in result) return res.status(result.status ?? 400).json(fail(result.error ?? 'Error'));
    return res.json(ok(result));
  },
};
