import type { Request, Response } from 'express';
import { ok, fail } from '../../utils/response';
import { permissionService, type PermissionRequester } from './permission.service';
import {
  UpdatePermissionsSchema,
  PatchPermissionSchema,
  CreateModuleSchema,
  UpdateModuleSchema,
} from './types';

function requesterFrom(req: Request): PermissionRequester {
  return {
    id: req.user!.id,
    roleName: req.user!.roleName,
    role: req.user!.role,
    permissions: req.user!.permissions,
    organizationId: req.user!.organizationId,
    subOrganization: req.user!.subOrganization,
  };
}

export const permissionController = {
  async getForRole(req: Request, res: Response) {
    const result = await permissionService.getForRole(
      String(req.params.roleId),
      requesterFrom(req),
    );
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
      req.user!.id,
      requesterFrom(req),
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
      req.user!.id,
      requesterFrom(req),
    );

    if (result && 'error' in result) return res.status(result.status ?? 400).json(fail(result.error ?? 'Error'));
    return res.json(ok(result));
  },

  async listModules(_req: Request, res: Response) {
    return res.json(ok(await permissionService.listModules()));
  },

  async createModule(req: Request, res: Response) {
    const body = CreateModuleSchema.safeParse(req.body);
    if (!body.success) {
      return res.status(400).json(fail(body.error.issues[0]?.message ?? 'Validation error'));
    }
    const result = await permissionService.createModule(body.data, req.user!.id);
    if ('error' in result) return res.status(result.status ?? 400).json(fail(result.error ?? 'Error'));
    return res.status(201).json(ok(result));
  },

  async updateModule(req: Request, res: Response) {
    const body = UpdateModuleSchema.safeParse(req.body);
    if (!body.success) {
      return res.status(400).json(fail(body.error.issues[0]?.message ?? 'Validation error'));
    }
    const result = await permissionService.updateModule(String(req.params.key), body.data, req.user!.id);
    if ('error' in result) return res.status(result.status ?? 400).json(fail(result.error ?? 'Error'));
    return res.json(ok(result));
  },

  async deleteModule(req: Request, res: Response) {
    const result = await permissionService.deleteModule(String(req.params.key), req.user!.id);
    if ('error' in result) return res.status(result.status ?? 400).json(fail(result.error ?? 'Error'));
    return res.json(ok(result));
  },
};
