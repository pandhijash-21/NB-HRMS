import type { NextFunction, Request, Response } from 'express';
import path from 'path';
import { requireAuth } from './auth';
import { fail } from '../utils/response';

/** Protect local collab upload fallback — presigned MinIO URLs are preferred in production. */
export function collabUploadAuth(req: Request, res: Response, next: NextFunction) {
  const file = path.basename(req.path);
  if (!file || file === '.' || file === '..') {
    return res.status(404).json(fail('Not found'));
  }
  return requireAuth(req, res, next);
}
