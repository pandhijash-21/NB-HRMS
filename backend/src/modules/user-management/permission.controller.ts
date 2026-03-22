import type { Request, Response } from 'express';
import { ok, fail } from '../../utils/response';
import { permissionService } from './permission.service';
import { UpdatePermissionsSchema, PatchPermissionSchema } from './types';

export const permissionController = {
  async getForRole(req: Request, res: Response) {
    const result = await permissionService.getForRole(String(req.params.roleId));
    if ('error' in result) return res.status(result.status ?? 400).json(fail(result.error ?? 'Error'));
    return res.json(ok(result));
  },

  async replaceForRole(req: Request, res: Response) {
    const body = UpdatePermissionsSchema.safeParse(req.body);
    if (!body.success) {
      return res.status(400).json(fail(body.error.issues[0]?.message ?? 'Validation error'));
    }

    const result = await permissionService.replaceForRole(
      String(req.params.roleId),
      body.data,
      req.user!.id
    );

    if (result && 'error' in result) return res.status(result.status ?? 400).json(fail(result.error ?? 'Error'));
    return res.json(ok(result));
  },

  async patchModulePermission(req: Request, res: Response) {
    const body = PatchPermissionSchema.safeParse(req.body);
    if (!body.success) {
      return res.status(400).json(fail(body.error.issues[0]?.message ?? 'Validation error'));
    }

    const result = await permissionService.patchModulePermission(
      String(req.params.roleId),
      String(req.params.moduleKey),
      body.data,
      req.user!.id
    );

    if (result && 'error' in result) return res.status(result.status ?? 400).json(fail(result.error ?? 'Error'));
    return res.json(ok(result));
  },

  async listModules(_req: Request, res: Response) {
    return res.json(ok(await permissionService.listModules()));
  },
};
