import type { NextFunction, Request, Response } from 'express';
import { fail } from '../utils/response';
import { canViewEmployeeDirectory, canWriteEmployeeDirectory } from '../modules/personal-education/employeeDirectory.util';

export function requireEmployeeDirectoryView() {
  return (req: Request, res: Response, next: NextFunction) => {
    if (!req.user) return res.status(401).json(fail('Unauthenticated'));
    if (!canViewEmployeeDirectory(req.user)) {
      return res.status(403).json(fail('You do not have permission to view the employee directory'));
    }
    return next();
  };
}

export function requireEmployeeDirectoryWrite() {
  return (req: Request, res: Response, next: NextFunction) => {
    if (!req.user) return res.status(401).json(fail('Unauthenticated'));
    if (!canWriteEmployeeDirectory(req.user)) {
      return res.status(403).json(fail('You do not have permission to modify employee records'));
    }
    return next();
  };
}
