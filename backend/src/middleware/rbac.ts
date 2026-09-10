import type { NextFunction, Request, Response } from 'express';
import { prisma } from '../config/prisma';
import { buildPermissionsMap } from '../modules/auth/permissions-map';
import { fail } from '../utils/response';
import { isAdminRole, isSuperAdminRole } from '../modules/auth/permissions-map';

export type PermissionAction = 'READ' | 'WRITE' | 'APPROVE' | 'DELETE' | 'EXPORT';

async function refreshUserPermissions(req: Request): Promise<boolean> {
  if (!req.user?.roleId) return false;
  const role = await prisma.role.findUnique({
    where: { id: req.user.roleId },
    include: { permissions: true },
  });
  if (!role) return false;
  req.user.permissions = buildPermissionsMap(role.permissions);
  return true;
}

/**
 * New permission middleware — checks the granular permissions map from the JWT.
 * Falls back to DB when JWT is stale (e.g. new module added after login).
 * Usage: requirePermission('PERSONAL_INFO', 'WRITE')
 */
export function requirePermission(moduleKey: string, action: PermissionAction) {
  return async (req: Request, res: Response, next: NextFunction) => {
    if (!req.user) return res.status(401).json(fail('Unauthenticated'));

    if (isAdminRole(req.user.roleName ?? req.user.role)) {
      return next();
    }

    let actions = req.user.permissions?.[moduleKey] ?? [];
    if (!actions.includes(action)) {
      await refreshUserPermissions(req);
      actions = req.user.permissions?.[moduleKey] ?? [];
    }
    if (!actions.includes(action)) {
      return res
        .status(403)
        .json(fail(`You do not have ${action} permission on ${moduleKey}`));
    }

    return next();
  };
}

/**
 * Check if the user has permission on ANY of the specified module keys.
 * Allows checking granular submodule keys with fallback to parent module keys (e.g. ['DPR', 'WORK_ORDERS']).
 */
export function requireAnyPermission(moduleKeys: string[], action: PermissionAction) {
  return async (req: Request, res: Response, next: NextFunction) => {
    if (!req.user) return res.status(401).json(fail('Unauthenticated'));

    if (isAdminRole(req.user.roleName ?? req.user.role)) {
      return next();
    }

    const hasAny = (keys: string[]) => {
      for (const k of keys) {
        const actions = req.user?.permissions?.[k] ?? [];
        if (actions.includes(action)) return true;
      }
      return false;
    };

    if (hasAny(moduleKeys)) {
      return next();
    }

    await refreshUserPermissions(req);

    if (hasAny(moduleKeys)) {
      return next();
    }

    return res
      .status(403)
      .json(fail(`You do not have ${action} permission on ${moduleKeys.join(' or ')}`));
  };
}

/** Enforce that the user has module permission, and either accesses their own record or has elevated role/scope. */
export function requireSelfEmployeeOrPermission(
  paramName: string,
  moduleKey: string,
  action: PermissionAction,
) {
  return async (req: Request, res: Response, next: NextFunction) => {
    if (!req.user) return res.status(401).json(fail('Unauthenticated'));

    if (isAdminRole(req.user.roleName ?? req.user.role)) {
      return next();
    }

    // 1. User MUST have the action permission on moduleKey
    let actions = req.user.permissions?.[moduleKey] ?? [];
    if (!actions.includes(action)) {
      await refreshUserPermissions(req);
      actions = req.user.permissions?.[moduleKey] ?? [];
    }
    if (!actions.includes(action)) {
      return res
        .status(403)
        .json(fail(`You do not have ${action} permission on ${moduleKey}`));
    }

    const raw = req.params[paramName];
    const targetId = Number(Array.isArray(raw) ? raw[0] : raw);
    const selfId = req.user.employeeId;

    // 2. If it's self-access, permitted since user holds the permission
    if (Number.isFinite(targetId) && selfId != null && selfId === targetId) {
      return next();
    }

    // 3. Accessing another employee's record requires elevated role or workforce view scope
    const elevatedRoles = ['HR', 'HR_MANAGER', 'HOI', 'REGISTRAR', 'VC'];
    const roleName = String(req.user.roleName ?? req.user.role ?? '').toUpperCase();
    if (elevatedRoles.includes(roleName)) {
      return next();
    }

    const scope = req.user.employeeViewScope;
    if (scope === 'INSTITUTE' || scope === 'UNIVERSITY') {
      return next();
    }

    return res.status(403).json(fail('You can only access your own profile record.'));
  };
}

/**
 * Backward-compatible role guard — still used by existing personal-education routes.
 * Checks req.user.roleName (or req.user.role alias).
 */
export function requireRole(allowed: string[]) {
  return (req: Request, res: Response, next: NextFunction) => {
    if (!req.user) return res.status(401).json(fail('Unauthenticated'));
    const role = req.user.roleName ?? req.user.role;
    if (!role || !allowed.includes(role)) {
      return res.status(403).json(fail('Forbidden'));
    }
    return next();
  };
}

/**
 * Superadmin-only guard — restricts route strictly to the SaaS Platform Provider (SUPERADMIN).
 * Client company System Admins and regular users will be rejected with 403.
 */
export function requireSuperAdmin() {
  return (req: Request, res: Response, next: NextFunction) => {
    if (!req.user) return res.status(401).json(fail('Unauthenticated'));
    const role = req.user.roleName ?? req.user.role;
    if (!isSuperAdminRole(role)) {
      return res
        .status(403)
        .json(fail('Forbidden: Requires SaaS Platform Superadmin privileges'));
    }
    return next();
  };
}

