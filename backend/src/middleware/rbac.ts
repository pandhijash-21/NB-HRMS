import type { NextFunction, Request, Response } from 'express';
import { fail } from '../utils/response';
import { isAdminRole } from '../modules/auth/permissions-map';

export type PermissionAction = 'READ' | 'WRITE' | 'APPROVE' | 'DELETE' | 'EXPORT';

/**
 * New permission middleware — checks the granular permissions map from the JWT.
 * Usage: requirePermission('PERSONAL_INFO', 'WRITE')
 */
export function requirePermission(moduleKey: string, action: PermissionAction) {
  return (req: Request, res: Response, next: NextFunction) => {
    if (!req.user) return res.status(401).json(fail('Unauthenticated'));

    if (isAdminRole(req.user.roleName ?? req.user.role)) {
      return next();
    }

    const actions = req.user.permissions?.[moduleKey] ?? [];
    if (!actions.includes(action)) {
      return res
        .status(403)
        .json(fail(`You do not have ${action} permission on ${moduleKey}`));
    }

    return next();
  };
}

/** Allow access when the route employeeId matches the logged-in employee, else require module permission. */
export function requireSelfEmployeeOrPermission(
  paramName: string,
  moduleKey: string,
  action: PermissionAction,
) {
  return (req: Request, res: Response, next: NextFunction) => {
    if (!req.user) return res.status(401).json(fail('Unauthenticated'));

    const raw = req.params[paramName];
    const targetId = Number(Array.isArray(raw) ? raw[0] : raw);
    const selfId = req.user.employeeId;

    if (Number.isFinite(targetId) && selfId != null && selfId === targetId) {
      return next();
    }

    if (isAdminRole(req.user.roleName ?? req.user.role)) {
      return next();
    }

    const actions = req.user.permissions?.[moduleKey] ?? [];
    if (!actions.includes(action)) {
      return res
        .status(403)
        .json(fail(`You do not have ${action} permission on ${moduleKey}`));
    }

    return next();
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
